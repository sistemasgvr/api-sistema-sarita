/**
 * Sincroniza funciones PL/pgSQL desde DATABASE_URL activa (dev)
 * hacia database_sql/funciones/, preservando carpetas existentes.
 *
 * - Si existe archivo cuyo nombre = proname.sql → sobrescribe
 * - Si no, busca archivo que ya defina esa función → sobrescribe
 * - Si no hay match → carpeta por prefijo (o _from_db)
 * - Huérfanos (en repo, no en BD) → se eliminan del repo
 *
 * Uso:
 *   node database_sql/scripts/sync-functions-from-dev.js
 *   node database_sql/scripts/sync-functions-from-dev.js --dry-run
 */
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '../..')
const FUNCIONES_DIR = path.join(ROOT, 'database_sql', 'funciones')
const FROM_DB_DIR = path.join(FUNCIONES_DIR, '_from_db')
const dryRun = process.argv.includes('--dry-run')

/** Prefijo → carpeta existente bajo funciones/ */
const PREFIX_FOLDERS = [
  ['dash_', 'dashboard'],
  ['bal_prestamo_', 'prestamos'],
  ['bal_', 'balones'],
  ['cli_', 'clientes'],
  ['ven_', 'comprobantes'],
  ['com_', 'compras'],
  ['fin_', 'finanzas'],
  ['pro_', 'productos'],
  ['inv_', 'inventario-movimientos'],
  ['gen_', 'utilidades'],
  ['auth_', 'login'],
  ['usu_', 'usuarios'],
  ['rol_', 'roles'],
  ['tra_', 'personal'],
  ['alm_', 'almacenes'],
  ['suc_', 'sucursales'],
  ['gua_', 'guias-remision'],
  ['gar_', 'garantias'],
  ['rec_', 'recojos'],
  ['rut_', 'rutas-pueblos'],
  ['veh_', 'vehiculos'],
  ['cho_', 'choferes'],
  ['caj_', 'caja'],
  ['not_', 'notificaciones'],
  ['doc_', 'documentos-vencimiento'],
  ['cat_', 'categorias'],
  ['emp_', 'empresas'],
  ['ubi_', 'ubigeo'],
  ['ses_', 'sesiones'],
  ['lic_', 'licencias'],
  ['man_', 'mantenimientos'],
  ['act_', 'activos'],
  ['alq_', 'alquileres'],
]

function loadActiveUrl() {
  const raw = fs.readFileSync(path.join(ROOT, '.env'), 'utf8')
  for (const line of raw.split(/\r?\n/)) {
    const t = line.trim()
    if (t.startsWith('DATABASE_URL=')) return t.slice('DATABASE_URL='.length).trim()
  }
  throw new Error('DATABASE_URL activa no encontrada en .env')
}

function walkSql(dir, out = []) {
  if (!fs.existsSync(dir)) return out
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (entry.name.startsWith('_') && entry.isDirectory()) continue
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) walkSql(full, out)
    else if (entry.isFile() && entry.name.toLowerCase().endsWith('.sql')) out.push(full)
  }
  return out
}

function extractFunctionNames(sql) {
  const names = new Set()
  const re = /CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)\s*\(/gi
  let m
  while ((m = re.exec(sql))) names.add(m[1].toLowerCase())
  return [...names]
}

function buildIndex(files) {
  /** @type {Map<string, string[]>} */
  const byName = new Map()
  /** @type {Map<string, string>} */
  const byExactFile = new Map()

  for (const file of files) {
    const base = path.basename(file, '.sql').toLowerCase()
    byExactFile.set(base, file)
    let sql = ''
    try {
      sql = fs.readFileSync(file, 'utf8')
    } catch {
      continue
    }
    for (const name of extractFunctionNames(sql)) {
      if (!byName.has(name)) byName.set(name, [])
      byName.get(name).push(file)
    }
  }
  return { byName, byExactFile }
}

function normalizeDef(def, identityArgs) {
  let sql = def.trim()
  sql = sql.replace(/^CREATE\s+FUNCTION\s+/i, 'CREATE OR REPLACE FUNCTION ')
  sql = sql.replace(/CREATE OR REPLACE FUNCTION\s+public\./i, 'CREATE OR REPLACE FUNCTION ')
  const name = extractPrimaryName(sql)
  const drop = `DROP FUNCTION IF EXISTS ${name}(${identityArgs});`
  if (!sql.endsWith(';')) sql += ';'
  return `${drop}\n\n${sql}\n`
}

function extractPrimaryName(sql) {
  const m = /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z0-9_]+)\s*\(/i.exec(sql)
  return m ? m[1] : 'unknown'
}

function resolveTarget(proname, index) {
  const key = proname.toLowerCase()
  if (index.byExactFile.has(key)) return index.byExactFile.get(key)

  const hits = index.byName.get(key) || []
  const singles = hits.filter((f) => {
    const names = extractFunctionNames(fs.readFileSync(f, 'utf8'))
    return names.length === 1 && names[0] === key
  })
  if (singles.length === 1) return singles[0]
  if (hits.length === 1) {
    const names = extractFunctionNames(fs.readFileSync(hits[0], 'utf8'))
    if (names.length === 1) return hits[0]
    // Multi-function file: if basename matches this function, use it (we'll overwrite with only this fn)
    if (path.basename(hits[0], '.sql').toLowerCase() === key) return hits[0]
    return null
  }
  return null
}

function folderForNew(proname) {
  const lower = proname.toLowerCase()
  // Special cases
  if (lower.includes('resumen_diario') || lower.includes('correlativo_resumen')) {
    return path.join(FUNCIONES_DIR, 'resumen-diario')
  }
  if (lower.includes('facturacion_apisperu')) {
    return path.join(FUNCIONES_DIR, 'configuracion-servicios')
  }
  for (const [prefix, folder] of PREFIX_FOLDERS) {
    if (lower.startsWith(prefix)) {
      const dir = path.join(FUNCIONES_DIR, folder)
      if (fs.existsSync(dir)) return dir
    }
  }
  return FROM_DB_DIR
}

function writeFile(dest, content) {
  if (dryRun) return
  fs.mkdirSync(path.dirname(dest), { recursive: true })
  fs.writeFileSync(dest, content, 'utf8')
}

function wrapContent(proname, overloads, body) {
  const header = [
    `-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js`,
    `-- Function: ${proname}`,
    `-- Overloads: ${overloads.length}`,
    `-- Generated: ${new Date().toISOString()}`,
    '',
  ].join('\n')
  return `${header}${body}`
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

  console.log('SOURCE_DEV', hint)
  console.log('DRY_RUN', dryRun)

  const files = walkSql(FUNCIONES_DIR)
  const index = buildIndex(files)
  console.log('REPO_SQL_FILES', files.length)

  const client = new Client({
    connectionString: url,
    ssl: { rejectUnauthorized: false },
    statement_timeout: 180000,
  })
  await client.connect()

  const r = await client.query(`
    SELECT
      p.oid,
      p.proname,
      pg_get_function_identity_arguments(p.oid) AS identity_args,
      pg_get_functiondef(p.oid) AS def,
      p.pronargs
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind = 'f'
      AND p.proname NOT LIKE 'pg_%'
      AND p.proname NOT LIKE 'uuid_%'
      AND p.proname NOT LIKE 'gtrgm_%'
      AND p.proname NOT LIKE 'gin_%'
      AND p.proname NOT LIKE 'gist_%'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        JOIN pg_extension e ON d.refobjid = e.oid
        WHERE d.objid = p.oid AND d.deptype = 'e'
      )
    ORDER BY p.proname, p.pronargs DESC, pg_get_function_identity_arguments(p.oid)
  `)

  console.log('DB_FUNCTIONS', r.rowCount)

  /** @type {Map<string, Array<{args:string, def:string}>>} */
  const byProname = new Map()
  for (const row of r.rows) {
    const name = row.proname
    if (!byProname.has(name)) byProname.set(name, [])
    byProname.get(name).push({
      args: row.identity_args || '',
      def: row.def,
    })
  }

  let updated = 0
  let created = 0
  let splitFromMulti = 0
  const createdPaths = []
  const updatedPaths = []

  for (const [proname, overloads] of byProname) {
    const body = overloads.map((o) => normalizeDef(o.def, o.args)).join('\n')
    const content = wrapContent(proname, overloads, body)
    const key = proname.toLowerCase()
    let target = resolveTarget(proname, index)

    if (target && fs.existsSync(target)) {
      const existingNames = extractFunctionNames(fs.readFileSync(target, 'utf8'))
      const otherNames = existingNames.filter((n) => n !== key)

      // Multi-function file whose basename is this function: overwrite with this fn only;
      // sibling functions will be written when their turn comes (or we seed them now).
      if (otherNames.length > 0 && path.basename(target, '.sql').toLowerCase() === key) {
        writeFile(target, content)
        updated++
        updatedPaths.push(path.relative(ROOT, target) + ' (split-base)')
        // Ensure siblings get their own files in same folder if not already exact-named
        for (const sibling of otherNames) {
          if (index.byExactFile.has(sibling)) continue
          if (!byProname.has(sibling) && ![...byProname.keys()].some((k) => k.toLowerCase() === sibling)) {
            continue
          }
          // Will be handled when we process sibling; mark so resolve finds folder
          const siblingDest = path.join(path.dirname(target), `${sibling}.sql`)
          if (!index.byExactFile.has(sibling)) {
            index.byExactFile.set(sibling, siblingDest)
            splitFromMulti++
          }
        }
        continue
      }

      if (otherNames.length > 0) {
        // Ambiguous: don't clobber; write to folder placement
        const dest = path.join(folderForNew(proname), `${proname}.sql`)
        writeFile(dest, content)
        created++
        createdPaths.push(path.relative(ROOT, dest) + ' (from-multi)')
        index.byExactFile.set(key, dest)
        continue
      }

      writeFile(target, content)
      updated++
      updatedPaths.push(path.relative(ROOT, target))
      continue
    }

    // Prefijado por split multi-función o destino nuevo por carpeta
    const dest =
      target && !fs.existsSync(target)
        ? target
        : path.join(folderForNew(proname), `${proname}.sql`)
    writeFile(dest, content)
    created++
    createdPaths.push(path.relative(ROOT, dest))
    index.byExactFile.set(key, dest)
  }

  // Orphans: repo files whose defined functions are all missing in DB → delete
  const dbNames = new Set([...byProname.keys()].map((n) => n.toLowerCase()))
  const orphans = []
  for (const file of files) {
    const names = extractFunctionNames(fs.readFileSync(file, 'utf8'))
    if (!names.length) continue
    if (names.every((n) => !dbNames.has(n))) {
      orphans.push(file)
    }
  }

  const deletedOrphans = []
  for (const file of orphans) {
    deletedOrphans.push(path.relative(ROOT, file))
    if (!dryRun) fs.unlinkSync(file)
  }

  await client.end()

  console.log('\n=== RESULT ===')
  console.log('updated', updated)
  console.log('created', created)
  console.log('split_multi_hints', splitFromMulti)
  console.log('orphans_deleted', deletedOrphans.length)
  if (createdPaths.length) {
    console.log('\nCreated (first 50):')
    for (const p of createdPaths.slice(0, 50)) console.log(' ', p)
    if (createdPaths.length > 50) console.log(`  ... +${createdPaths.length - 50}`)
  }
  if (deletedOrphans.length) {
    console.log('\nDeleted (absent in DB):')
    for (const p of deletedOrphans) console.log(' ', p)
  }
  console.log(dryRun ? '\n(dry-run: no files written)' : '\nDone.')
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
