/**
 * Sincroniza DDL de tablas public desde DATABASE_URL activa (dev)
 * hacia database_sql/tablas/, un archivo por tabla.
 *
 * Usa pg_dump --schema-only por tabla (incluye columnas, constraints,
 * indexes, sequences owned y triggers de esa tabla).
 *
 * - Si existe {tabla}.sql → sobrescribe
 * - Si no → carpeta por prefijo
 * - Huérfanos (en repo, no en BD) → se eliminan
 *
 * Uso:
 *   node database_sql/scripts/sync-tables-from-dev.js
 *   node database_sql/scripts/sync-tables-from-dev.js --dry-run
 */
const { Client } = require('pg')
const { spawnSync } = require('child_process')
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '../..')
const TABLAS_DIR = path.join(ROOT, 'database_sql', 'tablas')
const dryRun = process.argv.includes('--dry-run')

const PG_DUMP_CANDIDATES = [
  process.env.PG_DUMP_PATH,
  'C:\\Program Files\\PostgreSQL\\18\\bin\\pg_dump.exe',
  'C:\\Program Files\\PostgreSQL\\17\\bin\\pg_dump.exe',
  'C:\\Program Files\\PostgreSQL\\16\\bin\\pg_dump.exe',
  'pg_dump',
].filter(Boolean)

/** Prefijo de tabla → carpeta bajo tablas/ */
const PREFIX_FOLDERS = [
  ['act_', 'activos'],
  ['age_', 'actividades'],
  ['auth_', 'auth'],
  ['bal_', 'balones'],
  ['cli_', 'clientes'],
  ['com_', 'compras'],
  ['fin_', 'finanzas'],
  ['gen_', 'general'],
  ['gre_', 'guias-remision'],
  ['inv_', 'inventario'],
  ['pro_', 'productos'],
  ['tra_', 'personal'],
  ['ven_', 'ventas'],
]

function loadActiveUrl() {
  const raw = fs.readFileSync(path.join(ROOT, '.env'), 'utf8')
  for (const line of raw.split(/\r?\n/)) {
    const t = line.trim()
    if (t.startsWith('DATABASE_URL=')) return t.slice('DATABASE_URL='.length).trim()
  }
  throw new Error('DATABASE_URL activa no encontrada en .env')
}

function findPgDump() {
  for (const c of PG_DUMP_CANDIDATES) {
    if (c === 'pg_dump') return c
    if (fs.existsSync(c)) return c
  }
  throw new Error('pg_dump no encontrado. Define PG_DUMP_PATH o instala PostgreSQL client tools.')
}

function walkSql(dir, out = []) {
  if (!fs.existsSync(dir)) return out
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    // Skip private dirs except _misc (fallback domain folder)
    if (entry.isDirectory() && entry.name.startsWith('_') && entry.name !== '_misc') continue
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walkSql(full, out)
    else if (entry.isFile() && entry.name.toLowerCase().endsWith('.sql')) out.push(full)
  }
  return out
}

function extractTableNames(sql) {
  const names = new Set()
  const re = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s*[(\s]/gi
  let m
  while ((m = re.exec(sql))) names.add(m[1].toLowerCase())
  return [...names]
}

function buildIndex(files) {
  /** @type {Map<string, string>} */
  const byExactFile = new Map()
  for (const file of files) {
    const base = path.basename(file, '.sql').toLowerCase()
    byExactFile.set(base, file)
  }
  return { byExactFile }
}

function folderFor(tableName) {
  const lower = tableName.toLowerCase()
  for (const [prefix, folder] of PREFIX_FOLDERS) {
    if (lower.startsWith(prefix)) return path.join(TABLAS_DIR, folder)
  }
  return path.join(TABLAS_DIR, '_misc')
}

function cleanDump(raw, tableName) {
  const lines = raw.split(/\r?\n/)
  const kept = []
  for (const line of lines) {
    if (line.startsWith('--')) continue
    if (line.startsWith('SET ')) continue
    if (line.startsWith('SELECT pg_catalog.')) continue
    // pg_dump 17+ injects session tokens; never keep them in repo
    if (line.startsWith('\\restrict') || line.startsWith('\\unrestrict')) continue
    if (line.trim() === '') {
      if (kept.length && kept[kept.length - 1] !== '') kept.push('')
      continue
    }
    kept.push(line)
  }
  while (kept.length && kept[0] === '') kept.shift()
  while (kept.length && kept[kept.length - 1] === '') kept.pop()

  let body = kept.join('\n').trim()
  // Normalize CREATE TABLE public.x → CREATE TABLE x
  body = body.replace(/CREATE TABLE (?:ONLY )?public\./gi, 'CREATE TABLE ')
  body = body.replace(/ALTER TABLE (?:ONLY )?public\./gi, 'ALTER TABLE ')
  body = body.replace(/CREATE (UNIQUE )?INDEX ([a-zA-Z0-9_]+) ON public\./gi, 'CREATE $1INDEX $2 ON ')
  body = body.replace(/CREATE SEQUENCE public\./gi, 'CREATE SEQUENCE ')
  body = body.replace(/ALTER SEQUENCE public\./gi, 'ALTER SEQUENCE ')
  body = body.replace(/CREATE TRIGGER /gi, 'CREATE TRIGGER ')

  const header = [
    `-- Synced from DEV via database_sql/scripts/sync-tables-from-dev.js`,
    `-- Table: ${tableName}`,
    `-- Generated: ${new Date().toISOString()}`,
    '',
  ].join('\n')

  return `${header}${body}\n`
}

function dumpTable(pgDump, connectionUrl, tableName) {
  const result = spawnSync(
    pgDump,
    [
      '--schema-only',
      '--no-owner',
      '--no-privileges',
      '--no-comments',
      '-t',
      `public.${tableName}`,
      connectionUrl,
    ],
    {
      encoding: 'utf8',
      maxBuffer: 20 * 1024 * 1024,
      windowsHide: true,
    },
  )
  if (result.error) throw result.error
  if (result.status !== 0) {
    throw new Error(`pg_dump failed for ${tableName}: ${result.stderr || result.stdout}`)
  }
  return result.stdout || ''
}

async function listPublicTables(client) {
  const r = await client.query(`
    SELECT c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        JOIN pg_extension e ON d.refobjid = e.oid
        WHERE d.objid = c.oid AND d.deptype = 'e'
      )
    ORDER BY c.relname
  `)
  return r.rows.map((row) => row.table_name)
}

async function main() {
  const url = loadActiveUrl()
  const hint = (() => {
    try {
      return new URL(url).hostname.split('.')[0]
    } catch {
      return 'dev'
    }
  })()
  const pgDump = findPgDump()

  console.log('SOURCE_DEV', hint)
  console.log('PG_DUMP', pgDump)
  console.log('DRY_RUN', dryRun)

  if (!fs.existsSync(TABLAS_DIR) && !dryRun) {
    fs.mkdirSync(TABLAS_DIR, { recursive: true })
  }

  const files = walkSql(TABLAS_DIR)
  const index = buildIndex(files)
  console.log('REPO_SQL_FILES', files.length)

  const client = new Client({
    connectionString: url,
    ssl: { rejectUnauthorized: false },
    statement_timeout: 120000,
  })
  await client.connect()
  const tables = await listPublicTables(client)
  await client.end()
  console.log('DB_TABLES', tables.length)

  let updated = 0
  let created = 0
  const createdPaths = []
  const updatedPaths = []
  const errors = []

  for (const tableName of tables) {
    try {
      const raw = dumpTable(pgDump, url, tableName)
      const content = cleanDump(raw, tableName)
      const key = tableName.toLowerCase()
      const existing = index.byExactFile.get(key)
      const dest = existing || path.join(folderFor(tableName), `${tableName}.sql`)

      if (!dryRun) {
        fs.mkdirSync(path.dirname(dest), { recursive: true })
        fs.writeFileSync(dest, content, 'utf8')
      }

      if (existing) {
        updated++
        updatedPaths.push(path.relative(ROOT, dest))
      } else {
        created++
        createdPaths.push(path.relative(ROOT, dest))
        index.byExactFile.set(key, dest)
      }
    } catch (e) {
      errors.push({ tableName, message: e.message || String(e) })
    }
  }

  // Orphans: repo files without a matching DB table
  const dbNames = new Set(tables.map((t) => t.toLowerCase()))
  const deletedOrphans = []
  for (const file of files) {
    const base = path.basename(file, '.sql').toLowerCase()
    const names = extractTableNames(fs.readFileSync(file, 'utf8'))
    const covered = dbNames.has(base) || names.some((n) => dbNames.has(n))
    if (covered) continue
    deletedOrphans.push(path.relative(ROOT, file))
    if (!dryRun && fs.existsSync(file)) fs.unlinkSync(file)
  }

  console.log('\n=== RESULT ===')
  console.log('updated', updated)
  console.log('created', created)
  console.log('orphans_deleted', deletedOrphans.length)
  console.log('errors', errors.length)
  if (createdPaths.length) {
    console.log('\nCreated (first 40):')
    for (const p of createdPaths.slice(0, 40)) console.log(' ', p)
    if (createdPaths.length > 40) console.log(`  ... +${createdPaths.length - 40}`)
  }
  if (deletedOrphans.length) {
    console.log('\nDeleted:')
    for (const p of deletedOrphans) console.log(' ', p)
  }
  if (errors.length) {
    console.log('\nErrors:')
    for (const e of errors) console.log(`  ${e.tableName}: ${e.message}`)
  }
  console.log(dryRun ? '\n(dry-run: no files written)' : '\nDone.')
  if (errors.length) process.exitCode = 1
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
