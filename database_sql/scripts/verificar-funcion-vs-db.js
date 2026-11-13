/**
 * Compara una (o varias) funciones PL/pgSQL del repo contra la BD activa (DATABASE_URL del .env).
 *
 * Responde: ¿el .sql que tengo en el repo es realmente lo que está corriendo en la base?
 *
 * Usa EXACTAMENTE la misma normalización que sync-functions-from-dev.js, así que
 * si no hay diferencias reales el resultado es IDENTICA (sin falsos positivos por
 * formato, por el header "Generated:" ni por el DROP FUNCTION).
 *
 * Uso:
 *   node database_sql/scripts/verificar-funcion-vs-db.js bal_reporte_balones_propietario
 *   node database_sql/scripts/verificar-funcion-vs-db.js bal_reporte_balones_propietario --diff
 *   node database_sql/scripts/verificar-funcion-vs-db.js --todas            (audita TODO el repo)
 *   node database_sql/scripts/verificar-funcion-vs-db.js --todas --solo-desfasadas
 *
 * Solo lee. No escribe ni modifica nada: ni el repo ni la base de datos.
 */
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '../..')
const FUNCIONES_DIR = path.join(ROOT, 'database_sql', 'funciones')

const args = process.argv.slice(2)
const showDiff = args.includes('--diff')
const auditarTodas = args.includes('--todas')
const soloDesfasadas = args.includes('--solo-desfasadas')
const objetivos = args.filter((a) => !a.startsWith('--')).map((a) => a.toLowerCase())

/* ----------------------------------------------------------------------- */
/* Helpers copiados tal cual de sync-functions-from-dev.js                   */
/* ----------------------------------------------------------------------- */

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

function extractPrimaryName(sql) {
  const m = /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z0-9_]+)\s*\(/i.exec(sql)
  return m ? m[1] : 'unknown'
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

/* ----------------------------------------------------------------------- */
/* Comparación                                                              */
/* ----------------------------------------------------------------------- */

/** Quita el header "-- Synced from DEV ... -- Generated: <fecha>" y normaliza saltos de línea. */
function stripHeader(contenido) {
  const lineas = contenido.replace(/\r\n/g, '\n').split('\n')
  let i = 0
  while (i < lineas.length && lineas[i].startsWith('--')) i++
  while (i < lineas.length && lineas[i].trim() === '') i++
  return lineas.slice(i).join('\n')
}

/** Normaliza espacios en blanco irrelevantes para evitar falsos positivos. */
function canonical(sql) {
  return sql
    .replace(/\r\n/g, '\n')
    .split('\n')
    .map((l) => l.replace(/[ \t]+$/, ''))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

/** Diff línea a línea, simple y legible. */
function diffLineas(repo, db, maxLineas = 60) {
  const a = repo.split('\n')
  const b = db.split('\n')
  const salida = []
  const max = Math.max(a.length, b.length)
  for (let i = 0; i < max; i++) {
    if (a[i] === b[i]) continue
    if (a[i] !== undefined) salida.push(`  ${String(i + 1).padStart(4)} - REPO | ${a[i]}`)
    if (b[i] !== undefined) salida.push(`  ${String(i + 1).padStart(4)} + BD   | ${b[i]}`)
    if (salida.length >= maxLineas) {
      salida.push(`  ... (diff truncado, hay más diferencias)`)
      break
    }
  }
  return salida
}

/** Indexa los .sql del repo por nombre de función definida. */
function indexarRepo(files) {
  const porFuncion = new Map()
  for (const file of files) {
    const contenido = fs.readFileSync(file, 'utf8')
    const re = /CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z0-9_]+)\s*\(/gi
    let m
    const vistos = new Set()
    while ((m = re.exec(contenido))) vistos.add(m[1].toLowerCase())
    for (const nombre of vistos) {
      if (!porFuncion.has(nombre)) porFuncion.set(nombre, [])
      porFuncion.get(nombre).push(file)
    }
  }
  return porFuncion
}

async function main() {
  if (!auditarTodas && objetivos.length === 0) {
    console.error('Uso: node database_sql/scripts/verificar-funcion-vs-db.js <nombre_funcion> [--diff]')
    console.error('     node database_sql/scripts/verificar-funcion-vs-db.js --todas [--solo-desfasadas]')
    process.exit(1)
  }

  const url = loadActiveUrl()
  const hint = (() => {
    try {
      return new URL(url).hostname.split('.')[0]
    } catch {
      return 'desconocido'
    }
  })()

  console.log('='.repeat(78))
  console.log('VERIFICACION REPO vs BASE DE DATOS  (solo lectura)')
  console.log('='.repeat(78))
  console.log('BD destino :', hint)
  console.log('Modo       :', auditarTodas ? 'auditar TODAS las funciones' : objetivos.join(', '))
  console.log('')

  const files = walkSql(FUNCIONES_DIR)
  const indiceRepo = indexarRepo(files)

  const client = new Client({
    connectionString: url,
    ssl: { rejectUnauthorized: false },
    statement_timeout: 180000,
  })
  await client.connect()

  const r = await client.query(`
    SELECT
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

  const porProname = new Map()
  for (const row of r.rows) {
    const nombre = row.proname.toLowerCase()
    if (!porProname.has(nombre)) porProname.set(nombre, [])
    porProname.get(nombre).push({ args: row.identity_args || '', def: row.def })
  }

  await client.end()

  const aRevisar = auditarTodas
    ? [...new Set([...porProname.keys(), ...indiceRepo.keys()])].sort()
    : objetivos

  const resultados = { identicas: [], desfasadas: [], faltaEnRepo: [], faltaEnBd: [], ambiguas: [] }

  for (const nombre of aRevisar) {
    const enBd = porProname.get(nombre)
    const archivos = indiceRepo.get(nombre) || []

    if (!enBd) {
      resultados.faltaEnBd.push({ nombre, archivos })
      continue
    }
    if (archivos.length === 0) {
      resultados.faltaEnRepo.push({ nombre })
      continue
    }
    if (archivos.length > 1) {
      resultados.ambiguas.push({ nombre, archivos })
      continue
    }

    const archivo = archivos[0]
    const repoSql = canonical(stripHeader(fs.readFileSync(archivo, 'utf8')))
    const dbSql = canonical(enBd.map((o) => normalizeDef(o.def, o.args)).join('\n'))

    const registro = {
      nombre,
      archivo: path.relative(ROOT, archivo),
      overloadsBd: enBd.length,
      repoSql,
      dbSql,
    }

    if (repoSql === dbSql) resultados.identicas.push(registro)
    else resultados.desfasadas.push(registro)
  }

  /* --------------------------- Reporte --------------------------- */

  const linea = '-'.repeat(78)

  if (!soloDesfasadas && resultados.identicas.length) {
    console.log(linea)
    console.log(`IDENTICAS (repo = BD): ${resultados.identicas.length}`)
    console.log(linea)
    if (!auditarTodas) {
      for (const x of resultados.identicas) {
        console.log(`  OK  ${x.nombre}`)
        console.log(`      ${x.archivo}  (overloads en BD: ${x.overloadsBd})`)
      }
    }
    console.log('')
  }

  if (resultados.desfasadas.length) {
    console.log(linea)
    console.log(`DESFASADAS (el repo NO refleja la BD): ${resultados.desfasadas.length}`)
    console.log(linea)
    for (const x of resultados.desfasadas) {
      const dRepo = x.repoSql.split('\n').length
      const dDb = x.dbSql.split('\n').length
      console.log(`  DISTINTA  ${x.nombre}`)
      console.log(`      ${x.archivo}`)
      console.log(`      lineas repo: ${dRepo}  |  lineas BD: ${dDb}  |  overloads BD: ${x.overloadsBd}`)
      if (showDiff || (!auditarTodas && resultados.desfasadas.length === 1)) {
        console.log('')
        console.log('      --- DIFERENCIAS (- REPO / + BD) ---')
        for (const l of diffLineas(x.repoSql, x.dbSql)) console.log(l)
      }
      console.log('')
    }
  }

  if (resultados.faltaEnRepo.length) {
    console.log(linea)
    console.log(`EXISTEN EN BD PERO NO EN EL REPO: ${resultados.faltaEnRepo.length}`)
    console.log(linea)
    for (const x of resultados.faltaEnRepo) console.log(`  FALTA_REPO  ${x.nombre}`)
    console.log('')
  }

  if (resultados.faltaEnBd.length) {
    console.log(linea)
    console.log(`EXISTEN EN EL REPO PERO NO EN LA BD: ${resultados.faltaEnBd.length}`)
    console.log(linea)
    for (const x of resultados.faltaEnBd) {
      console.log(`  FALTA_BD  ${x.nombre}`)
      for (const f of x.archivos) console.log(`      ${path.relative(ROOT, f)}`)
    }
    console.log('')
  }

  if (resultados.ambiguas.length) {
    console.log(linea)
    console.log(`AMBIGUAS (definidas en varios .sql del repo): ${resultados.ambiguas.length}`)
    console.log(linea)
    for (const x of resultados.ambiguas) {
      console.log(`  AMBIGUA  ${x.nombre}`)
      for (const f of x.archivos) console.log(`      ${path.relative(ROOT, f)}`)
    }
    console.log('')
  }

  console.log('='.repeat(78))
  console.log('RESUMEN')
  console.log('='.repeat(78))
  console.log(`  identicas        : ${resultados.identicas.length}`)
  console.log(`  desfasadas       : ${resultados.desfasadas.length}`)
  console.log(`  solo en BD       : ${resultados.faltaEnRepo.length}`)
  console.log(`  solo en repo     : ${resultados.faltaEnBd.length}`)
  console.log(`  ambiguas         : ${resultados.ambiguas.length}`)
  console.log('')

  const hayProblema =
    resultados.desfasadas.length > 0 ||
    resultados.faltaEnRepo.length > 0 ||
    resultados.faltaEnBd.length > 0

  if (!hayProblema) {
    console.log('  >> El repo esta sincronizado. Es seguro editar el .sql como base.')
  } else if (resultados.desfasadas.length) {
    console.log('  >> OJO: hay funciones desfasadas. NO uses el .sql del repo como base')
    console.log('     sin antes revisar el diff o correr sync-functions-from-dev.js.')
  }
  console.log('')

  process.exit(hayProblema ? 1 : 0)
}

main().catch((err) => {
  console.error('\nERROR:', err.message)
  process.exit(2)
})
