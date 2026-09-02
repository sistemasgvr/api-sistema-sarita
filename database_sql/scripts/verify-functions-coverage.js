/** Verifica cobertura: cada función DEV tiene archivo en repo. */
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '../..')
const FUNCIONES_DIR = path.join(ROOT, 'database_sql', 'funciones')

function loadActiveUrl() {
  const raw = fs.readFileSync(path.join(ROOT, '.env'), 'utf8')
  for (const line of raw.split(/\r?\n/)) {
    const t = line.trim()
    if (t.startsWith('DATABASE_URL=')) return t.slice('DATABASE_URL='.length).trim()
  }
  throw new Error('no DATABASE_URL')
}

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name === '_orphans' && e.isDirectory()) continue
    const full = path.join(dir, e.name)
    if (e.isDirectory()) walk(full, out)
    else if (e.name.endsWith('.sql')) out.push(full)
  }
  return out
}

function namesIn(sql) {
  const s = new Set()
  const re = /CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(?:public\.)?([a-zA-Z0-9_]+)\s*\(/gi
  let m
  while ((m = re.exec(sql))) s.add(m[1].toLowerCase())
  return s
}

async function main() {
  const files = walk(FUNCIONES_DIR)
  const repo = new Set()
  for (const f of files) {
    for (const n of namesIn(fs.readFileSync(f, 'utf8'))) repo.add(n)
  }

  const client = new Client({
    connectionString: loadActiveUrl(),
    ssl: { rejectUnauthorized: false },
  })
  await client.connect()
  const r = await client.query(`
    SELECT DISTINCT p.proname
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.prokind = 'f'
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        JOIN pg_extension e ON d.refobjid = e.oid
        WHERE d.objid = p.oid AND d.deptype = 'e'
      )
      AND p.proname NOT LIKE 'pg_%'
      AND p.proname NOT LIKE 'uuid_%'
    ORDER BY 1
  `)
  await client.end()

  const db = new Set(r.rows.map((x) => x.proname.toLowerCase()))
  const missingInRepo = [...db].filter((n) => !repo.has(n))
  const extraInRepo = [...repo].filter((n) => !db.has(n))

  console.log('db_unique', db.size)
  console.log('repo_unique', repo.size)
  console.log('sql_files', files.length)
  console.log('missing_in_repo', missingInRepo.length, missingInRepo.slice(0, 20))
  console.log('extra_in_repo', extraInRepo.length, extraInRepo.slice(0, 20))
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
