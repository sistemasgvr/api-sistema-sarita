/**
 * Reconstruye o actualiza el esquema desde el repo (fuente de verdad).
 *
 * Las migraciones históricas (p.ej. 20260901_inv_movimiento_*) NO se reejecutan:
 * incrustan funciones que referencian columnas ya dropeadas. El esquema vivo
 * es database_sql/tablas + funciones + seeds.
 *
 * Uso:
 *   # DEV vivo: aplica todas las funciones del repo (no borra datos).
 *   node database_sql/scripts/rebuild-schema-from-repo.js --functions
 *
 *   # Esquema desde 0 (DESTRUCTIVO): DROP SCHEMA public CASCADE, tablas, funciones, seeds.
 *   CONFIRM_REBUILD=1 node database_sql/scripts/rebuild-schema-from-repo.js --full --wipe
 *
 *   node database_sql/scripts/rebuild-schema-from-repo.js --functions --dry-run
 */
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '../..')
const TABLAS_DIR = path.join(ROOT, 'database_sql', 'tablas')
const FUNCIONES_DIR = path.join(ROOT, 'database_sql', 'funciones')
const SEEDS_DIR = path.join(ROOT, 'database_sql', 'seeds')

const dryRun = process.argv.includes('--dry-run')
const applyFunctions = process.argv.includes('--functions')
const full = process.argv.includes('--full')
const wipe = process.argv.includes('--wipe')

function loadDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL
  const envPath = path.join(ROOT, '.env')
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((entry) => entry.trim().startsWith('DATABASE_URL='))
  if (!line) throw new Error('DATABASE_URL no encontrada')
  return line.slice('DATABASE_URL='.length).trim()
}

function walkSql(dir, out = []) {
  if (!fs.existsSync(dir)) return out
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.isDirectory() && entry.name.startsWith('_')) continue
    const fullPath = path.join(dir, entry.name)
    if (entry.isDirectory()) walkSql(fullPath, out)
    else if (entry.isFile() && entry.name.toLowerCase().endsWith('.sql')) out.push(fullPath)
  }
  return out
}

function rel(file) {
  return path.relative(ROOT, file).replace(/\\/g, '/')
}

function functionPriority(file) {
  const base = path.basename(file).toLowerCase()
  if (base === 'inv_signo_tipo_movimiento.sql') return 0
  if (base.startsWith('inv_')) return 1
  return 2
}

/** pg_get_functiondef omite el `;` tras el cierre `$function$`. Solo el tag en línea propia (cierre). */
function ensureSqlTerminators(sql) {
  return sql
    .replace(/(^|\n)(\$function\$)\s*;?/g, '$1$2;')
    .replace(/(^|\n)(\$BODY\$)\s*;?/gi, '$1$2;')
}

async function applyFile(client, file) {
  const sql = ensureSqlTerminators(fs.readFileSync(file, 'utf8'))
  if (dryRun) {
    console.log('DRY', rel(file), `(${sql.length} bytes)`)
    return
  }
  await client.query(sql)
}

async function applyWithRetries(client, files, label) {
  const pending = files.map((f) => ({ file: f, lastError: null }))
  const applied = []
  const maxRounds = 12

  for (let round = 1; round <= maxRounds && pending.length; round++) {
    let progress = 0
    for (let i = pending.length - 1; i >= 0; i--) {
      const item = pending[i]
      try {
        await applyFile(client, item.file)
        applied.push(item.file)
        pending.splice(i, 1)
        progress += 1
      } catch (error) {
        item.lastError = error
      }
    }
    console.log(`${label} round ${round}: applied ${progress}, remaining ${pending.length}`)
    if (!progress) break
  }

  if (pending.length) {
    const sample = pending.slice(0, 8).map((p) => `${rel(p.file)}: ${p.lastError?.message}`)
    throw new Error(`${label}: ${pending.length} archivos no aplicaron\n${sample.join('\n')}`)
  }
  return applied
}

async function applyInOrder(client, files, label) {
  let i = 0
  for (const file of files) {
    i += 1
    try {
      await applyFile(client, file)
    } catch (error) {
      throw new Error(`${label} ${rel(file)}: ${error.message}`)
    }
    if (i % 50 === 0) console.log(`${label} ${i}/${files.length}`)
  }
  console.log(`${label} ${files.length}/${files.length}`)
}

async function main() {
  if (!applyFunctions && !full) {
    console.error('Indica --functions (DEV vivo) o --full --wipe (esquema desde 0).')
    process.exit(1)
  }
  if (full && !wipe) {
    console.error('--full requiere --wipe (DROP SCHEMA public CASCADE).')
    process.exit(1)
  }
  if (full && wipe && process.env.CONFIRM_REBUILD !== '1') {
    console.error('Reconstrucción destructiva: exporta CONFIRM_REBUILD=1 y vuelve a ejecutar.')
    process.exit(1)
  }

  const tableFiles = walkSql(TABLAS_DIR).sort()
  const functionFiles = walkSql(FUNCIONES_DIR).sort((a, b) => {
    const pa = functionPriority(a)
    const pb = functionPriority(b)
    if (pa !== pb) return pa - pb
    return a.localeCompare(b)
  })
  const seedFiles = walkSql(SEEDS_DIR).sort((a, b) => {
    const an = path.basename(a)
    const bn = path.basename(b)
    if (an === 'auth_roles_operativos.sql') return 1
    if (bn === 'auth_roles_operativos.sql') return -1
    return a.localeCompare(b)
  })

  console.log('tablas', tableFiles.length)
  console.log('funciones', functionFiles.length)
  console.log('seeds', seedFiles.length)

  const client = new Client({
    connectionString: loadDatabaseUrl(),
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()
  try {
    if (full && wipe) {
      console.log('WIPING public schema')
      if (!dryRun) {
        await client.query('DROP SCHEMA IF EXISTS public CASCADE')
        await client.query('CREATE SCHEMA public')
        await client.query('GRANT ALL ON SCHEMA public TO public')
        await client.query('CREATE EXTENSION IF NOT EXISTS pgcrypto')
        await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
      }
      await applyWithRetries(client, tableFiles, 'tablas')
      await applyInOrder(client, functionFiles, 'funciones')
      await applyInOrder(client, seedFiles, 'seeds')
    } else if (applyFunctions) {
      await applyInOrder(client, functionFiles, 'funciones')
    }
    console.log('OK rebuild-schema-from-repo')
  } finally {
    await client.end()
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})
