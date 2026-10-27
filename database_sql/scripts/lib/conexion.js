/**
 * Conexión de SOLO LECTURA a DEV / PROD.
 *
 * URL: DATABASE_URL_DEV / DATABASE_URL_PROD en .env si existen; si no, la línea
 * DATABASE_URL= (comentada o no) de .env que contenga el ref del proyecto.
 * La URL y la contraseña nunca se imprimen: todos los errores pasan por sanear().
 */
const { Client } = require('pg')
const { spawnSync, execFile } = require('child_process')
const fs = require('fs')
const path = require('path')

const ROOT = path.join(__dirname, '../../..')
const REFS = { dev: 'adhxtqjxklnujajdunin', prod: 'ebotjjfdgcuwrfoappsa' }

const PG_DUMP_CANDIDATES = [
  process.env.PG_DUMP_PATH,
  'C:\\Program Files\\PostgreSQL\\18\\bin\\pg_dump.exe',
  'C:\\Program Files\\PostgreSQL\\17\\bin\\pg_dump.exe',
  'pg_dump',
].filter(Boolean)

/** Valores secretos conocidos en este proceso, para borrarlos de cualquier mensaje. */
const secretos = new Set()

function registrarSecretos(url) {
  secretos.add(url)
  try {
    const u = new URL(url)
    if (u.password) {
      secretos.add(u.password)
      secretos.add(decodeURIComponent(u.password))
    }
  } catch {
    /* URL no parseable: basta con la URL completa */
  }
}

function sanear(texto) {
  let s = String(texto == null ? '' : texto)
  const lista = [...secretos].filter((x) => x && x.length >= 4).sort((a, b) => b.length - a.length)
  for (const x of lista) s = s.split(x).join('***')
  // Cualquier URL postgres residual: ocultar credenciales
  s = s.replace(/(postgres(?:ql)?:\/\/)[^@\s]*@/gi, '$1***@')
  s = s.replace(/password=\S+/gi, 'password=***')
  return s
}

function validarEnv(env) {
  if (env !== 'dev' && env !== 'prod') throw new Error(`Entorno inválido: "${env}" (usar dev | prod)`)
}

function leerEnvLineas() {
  const archivo = path.join(ROOT, '.env')
  if (!fs.existsSync(archivo)) throw new Error('No existe .env en la raíz del repo')
  return fs.readFileSync(archivo, 'utf8').split(/\r?\n/)
}

function valorDe(linea, clave) {
  const m = new RegExp(`^\\s*#?\\s*${clave}\\s*=\\s*(.*)$`).exec(linea)
  if (!m) return null
  return m[1].trim().replace(/^["']|["']$/g, '')
}

function urlDe(env) {
  validarEnv(env)
  const lineas = leerEnvLineas()
  const clave = `DATABASE_URL_${env.toUpperCase()}`
  // 1) DATABASE_URL_DEV / DATABASE_URL_PROD (solo líneas no comentadas)
  for (const l of lineas) {
    if (/^\s*#/.test(l)) continue
    const v = valorDe(l, clave)
    if (v) {
      registrarSecretos(v)
      return v
    }
  }
  // 2) DATABASE_URL= (comentada o no) que contenga el ref del proyecto
  const ref = REFS[env]
  for (const l of lineas) {
    const v = valorDe(l, 'DATABASE_URL')
    if (v && v.includes(ref)) {
      registrarSecretos(v)
      return v
    }
  }
  throw new Error(
    `No se encontró URL para ${env.toUpperCase()}: define ${clave} en .env o una línea DATABASE_URL= con el ref del proyecto`,
  )
}

/** Quita sslmode/ssl de la URL para que la opción ssl del cliente se respete. */
function sinSslmode(url) {
  try {
    const u = new URL(url)
    u.searchParams.delete('sslmode')
    u.searchParams.delete('ssl')
    return u.toString()
  } catch {
    return url
  }
}

async function conectar(env) {
  const url = urlDe(env)
  const client = new Client({ connectionString: sinSslmode(url), ssl: { rejectUnauthorized: false } })
  client.on('error', () => {}) // errores asíncronos del socket: se reportan en la consulta
  try {
    // Sin SET de sesión: con el pooler de Supabase (6543) el ajuste se queda en la
    // conexión del servidor y lo heredan otros clientes (la API). Las consultas usan
    // BEGIN TRANSACTION READ ONLY, que solo dura la transacción.
    await client.connect()
  } catch (err) {
    try {
      await client.end()
    } catch {
      /* ignorar */
    }
    throw new Error(`No se pudo conectar a ${env.toUpperCase()}: ${sanear(err.message)}`)
  }
  return client
}

function buscarPgDump() {
  for (const c of PG_DUMP_CANDIDATES) {
    if (c === 'pg_dump' || fs.existsSync(c)) return c
  }
  throw new Error('pg_dump no encontrado. Define PG_DUMP_PATH.')
}


/**
 * Configuración de pg_dump que funcionó por entorno: { puerto, soloLectura }.
 * Orden de intentos: puerto de la URL con solo lectura → sin opciones de arranque
 * (por si el pooler rechaza PGOPTIONS) → lo mismo en 5432 si la URL usa 6543.
 */
const configElegida = {}

const PGOPTIONS_SOLO_LECTURA = '-c default_transaction_read_only=on'

function intentos(env, url) {
  if (configElegida[env]) return [configElegida[env]]
  const puertoUrl = new URL(url).port || '5432'
  const puertos = puertoUrl === '6543' ? ['6543', '5432'] : [puertoUrl]
  const lista = []
  // Sin PGOPTIONS de solo lectura: el pooler podría dejarlo en la conexión del
  // servidor. pg_dump ya trabaja dentro de su propia transacción READ ONLY.
  for (const puerto of puertos) lista.push({ puerto, soloLectura: false })
  return lista
}

function envPg(url, { puerto, soloLectura }) {
  const u = new URL(url)
  const env = {
    ...process.env,
    PGHOST: u.hostname,
    PGPORT: String(puerto || u.port || 5432),
    PGUSER: decodeURIComponent(u.username),
    PGPASSWORD: decodeURIComponent(u.password),
    PGDATABASE: decodeURIComponent(u.pathname.replace(/^\//, '')) || 'postgres',
    PGSSLMODE: 'require',
    PGCONNECT_TIMEOUT: '20',
  }
  if (soloLectura) env.PGOPTIONS = PGOPTIONS_SOLO_LECTURA
  else delete env.PGOPTIONS
  return env
}

function identTabla(tabla) {
  return /^[a-z_][a-z0-9_]*$/.test(tabla) ? tabla : `"${tabla.replace(/"/g, '""')}"`
}

function argsPgDump(tabla) {
  return ['--schema-only', '--no-owner', '--no-privileges', '-t', `public.${identTabla(tabla)}`]
}

const OPCIONES_EXEC = { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, windowsHide: true }

function ejecutarPgDump(pgDump, url, config, tabla) {
  return spawnSync(pgDump, argsPgDump(tabla), { ...OPCIONES_EXEC, env: envPg(url, config) })
}

function ejecutarPgDumpAsync(pgDump, url, config, tabla) {
  return new Promise((resolve) => {
    execFile(pgDump, argsPgDump(tabla), { ...OPCIONES_EXEC, env: envPg(url, config) }, (error, stdout, stderr) => {
      const status = error ? (typeof error.code === 'number' ? error.code : 1) : 0
      resolve({ status, stdout, stderr, error: error && typeof error.code !== 'number' ? error : null })
    })
  })
}

function ok(r) {
  return !r.error && r.status === 0
}

function errorPgDump(env, tabla, r) {
  const detalle = r.error ? r.error.message : r.stderr || r.stdout
  return new Error(`pg_dump falló para ${tabla} (${env.toUpperCase()}): ${sanear(detalle).trim()}`)
}

/** DDL de una tabla con pg_dump --schema-only (sesión de solo lectura; fallback 6543 → 5432). */
function pgDumpEsquema(env, tabla) {
  const url = urlDe(env)
  const pgDump = buscarPgDump()
  let r
  for (const config of intentos(env, url)) {
    r = ejecutarPgDump(pgDump, url, config, tabla)
    if (ok(r)) {
      configElegida[env] = config
      return r.stdout
    }
  }
  throw errorPgDump(env, tabla, r)
}

/** Igual que pgDumpEsquema pero asíncrono (permite varias tablas en paralelo). */
async function pgDumpEsquemaAsync(env, tabla) {
  const url = urlDe(env)
  const pgDump = buscarPgDump()
  let r
  for (const config of intentos(env, url)) {
    r = await ejecutarPgDumpAsync(pgDump, url, config, tabla)
    if (ok(r)) {
      configElegida[env] = config
      return r.stdout
    }
  }
  throw errorPgDump(env, tabla, r)
}

/** Configuración de pg_dump usada en este proceso (sin credenciales), para reportes. */
function configPgDump(env) {
  return configElegida[env] ? { ...configElegida[env] } : null
}

module.exports = { urlDe, conectar, pgDumpEsquema, pgDumpEsquemaAsync, configPgDump, sanear, ROOT }
