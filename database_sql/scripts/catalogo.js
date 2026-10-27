/**
 * Lee el catálogo de DEV o PROD (solo lectura) y lo guarda en
 * database_sql/.cache/catalogo-<env>.json:
 *   { funciones: [{ nombre, args, kind, def }], tablas: [{ nombre, ddl }], seeds: { <tabla>: [filas] } }
 *
 * Solo imprime conteos. Nunca imprime ni escribe la URL de conexión.
 *
 * Uso:
 *   node database_sql/scripts/catalogo.js --env dev
 *   node database_sql/scripts/catalogo.js --env prod
 */
const fs = require('fs')
const path = require('path')
const { conectar, pgDumpEsquemaAsync, sanear, ROOT } = require('./lib/conexion')

const CACHE_DIR = path.join(ROOT, 'database_sql', '.cache')
const CONCURRENCIA = 8

/**
 * Tablas de catálogo cuyos datos regenera la Tarea 6 (nombres confirmados en
 * seeds/*_permisos_banderas.sql, auth_roles_operativos.sql, fin_medio_pago_config.sql,
 * gen_condiciones_pago_estandar.sql y cli_clientes_varios.sql).
 */
const SEEDS = [
  { tabla: 'gen_lista' },
  { tabla: 'gen_lista_opciones' },
  { tabla: 'auth_permisos' },
  { tabla: 'auth_roles' },
  { tabla: 'auth_roles_permisos' },
  { tabla: 'fin_medio_pago_config' },
  { tabla: 'gen_condicion_pago' },
  // Clientes Varios: lookup estable por codigo_interno (seeds/cli_clientes_varios.sql)
  { tabla: 'cli_clientes', where: "codigo_interno = 'CVARIOS'" },
]

const SQL_FUNCIONES = `
  SELECT p.proname AS nombre,
         pg_get_function_identity_arguments(p.oid) AS args,
         p.prokind::text AS kind,
         pg_get_functiondef(p.oid) AS def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.prokind IN ('f', 'p')
    AND NOT EXISTS (
      SELECT 1 FROM pg_depend d
      WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e'
    )
  ORDER BY p.proname, args`

const SQL_TABLAS = `
  SELECT c.relname AS nombre
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relkind IN ('r', 'p')
    AND NOT c.relispartition
    AND NOT EXISTS (
      SELECT 1 FROM pg_depend d
      WHERE d.classid = 'pg_class'::regclass AND d.objid = c.oid AND d.deptype = 'e'
    )
  ORDER BY c.relname`

function leerEnv() {
  const i = process.argv.indexOf('--env')
  const env = i !== -1 ? process.argv[i + 1] : null
  if (env !== 'dev' && env !== 'prod') {
    throw new Error('Uso: node database_sql/scripts/catalogo.js --env dev|prod')
  }
  return env
}

async function main() {
  const env = leerEnv()
  const client = await conectar(env)
  let funciones, nombresTablas
  const seeds = {}
  try {
    // Transacción explícita de solo lectura (el pooler en modo transacción no conserva
    // los SET de sesión entre transacciones).
    await client.query('BEGIN TRANSACTION READ ONLY')
    funciones = (await client.query(SQL_FUNCIONES)).rows
    nombresTablas = (await client.query(SQL_TABLAS)).rows.map((r) => r.nombre)
    for (const s of SEEDS) {
      if (!nombresTablas.includes(s.tabla)) {
        seeds[s.tabla] = null // no existe en esta base
        continue
      }
      const where = s.where ? ` WHERE ${s.where}` : ''
      seeds[s.tabla] = (await client.query(`SELECT * FROM public.${s.tabla}${where} ORDER BY 1`)).rows
    }
    await client.query('ROLLBACK')
  } finally {
    await client.end().catch(() => {})
  }

  // pg_dump tarda ~13 s por tabla (consulta todo el catálogo): se ejecutan en paralelo.
  const tablas = new Array(nombresTablas.length)
  let siguiente = 0
  async function trabajador() {
    while (siguiente < nombresTablas.length) {
      const k = siguiente++
      const nombre = nombresTablas[k]
      tablas[k] = { nombre, ddl: await pgDumpEsquemaAsync(env, nombre) }
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCIA }, trabajador))

  fs.mkdirSync(CACHE_DIR, { recursive: true })
  const salida = path.join(CACHE_DIR, `catalogo-${env}.json`)
  fs.writeFileSync(salida, JSON.stringify({ funciones, tablas, seeds }, null, 2) + '\n', 'utf8')

  const nombresFn = new Set(funciones.map((f) => f.nombre))
  console.log(`[${env}] funciones: ${funciones.length} firmas (${nombresFn.size} nombres)`)
  console.log(`[${env}] tablas: ${tablas.length}`)
  for (const [t, filas] of Object.entries(seeds)) {
    console.log(`[${env}] seed ${t}: ${filas === null ? 'no existe' : filas.length + ' filas'}`)
  }
  console.log(`[${env}] escrito: database_sql/.cache/catalogo-${env}.json`)
}

main().catch((err) => {
  console.error(`Error: ${sanear(err && err.message)}`)
  process.exit(1)
})
