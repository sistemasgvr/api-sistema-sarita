/**
 * Verifica cobertura de funciones: cada función/procedimiento `public` de la base elegida
 * tiene archivo en database_sql/funciones/<modulo>/<nombre>.sql, y al revés.
 * Conexión de solo lectura (lib/conexion.js); nunca imprime la URL.
 *
 * Uso:
 *   node database_sql/scripts/verify-functions-coverage.js --env dev
 *   node database_sql/scripts/verify-functions-coverage.js --env prod
 *
 * Sale con código 1 si falta alguna función en el repo.
 */
const fs = require('fs')
const path = require('path')
const { conectar, sanear } = require('./lib/conexion')
const { moduloDe } = require('./lib/modulos')

const FUNCIONES_DIR = path.join(__dirname, '..', 'funciones')

function leerEnv() {
  const i = process.argv.indexOf('--env')
  const env = i !== -1 ? process.argv[i + 1] : null
  if (env !== 'dev' && env !== 'prod') {
    throw new Error('Uso: node database_sql/scripts/verify-functions-coverage.js --env dev|prod')
  }
  return env
}

/** Archivos .sql de funciones/<modulo>/ → [{ modulo, archivo }]. */
function archivosRepo() {
  const out = []
  for (const modulo of fs.readdirSync(FUNCIONES_DIR, { withFileTypes: true })) {
    if (!modulo.isDirectory()) continue
    const dir = path.join(FUNCIONES_DIR, modulo.name)
    for (const f of fs.readdirSync(dir)) {
      if (f.endsWith('.sql')) out.push({ modulo: modulo.name, archivo: path.join(dir, f) })
    }
  }
  return out
}

function nombresEn(sql) {
  const s = new Set()
  const re = /CREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\s+(?:public\.)?"?([a-zA-Z0-9_]+)"?\s*\(/gi
  let m
  while ((m = re.exec(sql))) s.add(m[1].toLowerCase())
  return s
}

const SQL = `
  SELECT DISTINCT p.proname AS nombre
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind IN ('f', 'p')
    AND NOT EXISTS (
      SELECT 1 FROM pg_depend d
      WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e'
    )
  ORDER BY 1`

async function main() {
  const env = leerEnv()
  const archivos = archivosRepo()
  const repo = new Set()
  const malUbicados = []
  for (const { modulo, archivo } of archivos) {
    const base = path.basename(archivo, '.sql').toLowerCase()
    for (const n of nombresEn(fs.readFileSync(archivo, 'utf8'))) repo.add(n)
    const esperado = moduloDe(base).modulo
    if (esperado !== modulo) malUbicados.push(`${modulo}/${base}.sql (esperado ${esperado}/)`)
  }

  const client = await conectar(env)
  let filas
  try {
    await client.query('BEGIN TRANSACTION READ ONLY')
    filas = (await client.query(SQL)).rows
    await client.query('ROLLBACK')
  } finally {
    await client.end().catch(() => {})
  }

  const db = new Set(filas.map((x) => x.nombre.toLowerCase()))
  const faltantes = [...db].filter((n) => !repo.has(n)).sort()
  const sobrantes = [...repo].filter((n) => !db.has(n)).sort()

  console.log(`[${env}] funciones en base (nombres): ${db.size}`)
  console.log(`[${env}] funciones en repo (nombres): ${repo.size} en ${archivos.length} archivos`)
  console.log(`[${env}] faltan en repo: ${faltantes.length}`, faltantes.slice(0, 30))
  console.log(`[${env}] en repo pero no en la base: ${sobrantes.length}`, sobrantes.slice(0, 30))
  console.log(`[${env}] archivos fuera de su módulo: ${malUbicados.length}`, malUbicados.slice(0, 30))
  if (faltantes.length) process.exitCode = 1
}

main().catch((err) => {
  console.error(`Error: ${sanear(err && err.message)}`)
  process.exit(1)
})
