/** Verifica cobertura: cada tabla public en DEV tiene archivo en database_sql/tablas. */
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '../..')
const TABLAS_DIR = path.join(ROOT, 'database_sql', 'tablas')

function loadActiveUrl() {
  const raw = fs.readFileSync(path.join(ROOT, '.env'), 'utf8')
  for (const line of raw.split(/\r?\n/)) {
    const t = line.trim()
    if (t.startsWith('DATABASE_URL=')) return t.slice('DATABASE_URL='.length).trim()
  }
  throw new Error('no DATABASE_URL')
}

function walk(dir, out = []) {
  if (!fs.existsSync(dir)) return out
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name.startsWith('_') && e.isDirectory() && e.name !== '_misc') continue
    const full = path.join(dir, e.name)
    if (e.isDirectory()) walk(full, out)
    else if (e.name.endsWith('.sql')) out.push(full)
  }
  return out
}

function namesIn(sql) {
  const s = new Set()
  const re = /CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:ONLY\s+)?(?:public\.)?([a-zA-Z0-9_]+)\s*[(\s]/gi
  let m
  while ((m = re.exec(sql))) s.add(m[1].toLowerCase())
  return s
}

async function main() {
  const files = walk(TABLAS_DIR)
  const repo = new Set()
  const byBase = new Set()
  for (const f of files) {
    byBase.add(path.basename(f, '.sql').toLowerCase())
    for (const n of namesIn(fs.readFileSync(f, 'utf8'))) repo.add(n)
  }

  const client = new Client({
    connectionString: loadActiveUrl(),
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()
  const r = await client.query(`
    SELECT c.relname AS table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        JOIN pg_extension e ON d.refobjid = e.oid
        WHERE d.objid = c.oid AND d.deptype = 'e'
      )
    ORDER BY 1
  `)
  await client.end()

  const db = new Set(r.rows.map((x) => x.table_name.toLowerCase()))
  const missingInRepo = [...db].filter((n) => !repo.has(n) && !byBase.has(n))
  const extraInRepo = [...byBase].filter((n) => !db.has(n))

  console.log('db_tables', db.size)
  console.log('repo_files', files.length)
  console.log('repo_tables_detected', repo.size)
  console.log('missing_in_repo', missingInRepo.length, missingInRepo.slice(0, 30))
  console.log('extra_in_repo', extraInRepo.length, extraInRepo.slice(0, 30))
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
