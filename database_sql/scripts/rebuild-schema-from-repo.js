/**
 * Reconstruye o actualiza el esquema desde el repo (fuente de verdad):
 * database_sql/tablas/<modulo>, funciones/<modulo> y seeds/<modulo>, recorridos en el orden
 * de módulos de lib/modulos.js (general, auth, productos, inventario, clientes, …, ventas, dashboard).
 *
 * Orden con --full --wipe:
 *   1. Tablas, fase A: cada archivo de tablas/ SIN sus `ALTER TABLE … ADD CONSTRAINT … FOREIGN KEY`
 *      ni sus `CREATE TRIGGER` (tabla, secuencias, defaults, PK/UNIQUE/CHECK, índices, comentarios).
 *   2. Tablas, fase B: todas las FKs (así los ciclos de FK entre tablas no importan).
 *   3. Funciones (con check_function_bodies = off, como pg_restore).
 *   4. Triggers de las tablas (necesitan sus funciones).
 *   5. Seeds: todos los listas.sql → todos los permisos.sql → datos-base.sql en el orden
 *      general, finanzas, clientes, (otros), auth al final (asigna permisos de todos los módulos).
 *
 * Uso:
 *   # Reaplica todas las funciones del repo, sin transacción. SOLO para una base reconstruida
 *   # desde este repo: en DEV/PROD vivos mezclaría versiones (el repo tiene funciones 'prod' y
 *   # 'dev'; ver .cache/decisiones-funciones.json). Para publicar usar migraciones/sync-*.sql.
 *   node database_sql/scripts/rebuild-schema-from-repo.js --functions
 *
 *   # Esquema desde 0 (DESTRUCTIVO): DROP SCHEMA public CASCADE, tablas, funciones, seeds.
 *   # CONFIRM_REBUILD debe ser el nombre exacto de la base de destino.
 *   CONFIRM_REBUILD=<nombre_base> node database_sql/scripts/rebuild-schema-from-repo.js --full --wipe
 *
 *   # Solo lista lo que aplicaría, en orden. NO se conecta a ninguna base.
 *   node database_sql/scripts/rebuild-schema-from-repo.js --functions --dry-run
 *   CONFIRM_REBUILD=<nombre_base> node database_sql/scripts/rebuild-schema-from-repo.js --full --wipe --dry-run
 *
 * Conexión (solo sin --dry-run): DATABASE_URL del entorno o la línea DATABASE_URL= activa de .env.
 * La URL nunca se imprime: solo host y nombre de base. Sin --permitir-remoto, --functions y --full
 * se niegan (antes de conectar) si el host termina en supabase.com / supabase.co o la URL contiene
 * el ref de DEV o PROD.
 */
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')
const { quitarComentarios } = require('./lib/comentarios')
const { indiceModulo } = require('./lib/modulos')

const ROOT = path.join(__dirname, '../..')
const TABLAS_DIR = path.join(ROOT, 'database_sql', 'tablas')
const FUNCIONES_DIR = path.join(ROOT, 'database_sql', 'funciones')
const SEEDS_DIR = path.join(ROOT, 'database_sql', 'seeds')

const dryRun = process.argv.includes('--dry-run')
const applyFunctions = process.argv.includes('--functions')
const full = process.argv.includes('--full')
const wipe = process.argv.includes('--wipe')
const permitirRemoto = process.argv.includes('--permitir-remoto')

/** Refs de los proyectos Supabase vivos (DEV y PROD). */
const REFS_VIVOS = ['adhxtqjxklnujajdunin', 'ebotjjfdgcuwrfoappsa']

/** Host y nombre de base de una URL de conexión (sin usuario ni contraseña). No conecta. */
function destino(url) {
  let u
  try {
    u = new URL(url)
  } catch {
    throw new Error('DATABASE_URL no es una URL válida')
  }
  const host = u.hostname.toLowerCase()
  const base = decodeURIComponent(u.pathname.replace(/^\//, '')) || 'postgres'
  const usuario = decodeURIComponent(u.username || '').toLowerCase()
  const remoto =
    /(^|\.)supabase\.(com|co)$/.test(host) ||
    REFS_VIVOS.some((ref) => host.includes(ref) || usuario.includes(ref) || base.includes(ref))
  return { host, base, remoto }
}

/** Orden de los datos-base.sql: general, finanzas, clientes, (resto por módulo), auth al final. */
const DATOS_BASE_PRIMERO = ['general', 'finanzas', 'clientes']
const DATOS_BASE_ULTIMO = 'auth'

function loadDatabaseUrl() {
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL
  const envPath = path.join(ROOT, '.env')
  const line = fs
    .readFileSync(envPath, 'utf8')
    .split(/\r?\n/)
    .find((entry) => entry.trim().startsWith('DATABASE_URL='))
  if (!line) throw new Error('DATABASE_URL no encontrada')
  return line.trim().slice('DATABASE_URL='.length).trim()
}

function rel(file) {
  return path.relative(ROOT, file).replace(/\\/g, '/')
}

/** Archivos .sql de <dir>/<modulo>/ ordenados por módulo (lib/modulos.js) y luego por nombre. */
function sqlPorModulo(dir) {
  if (!fs.existsSync(dir)) return []
  const modulos = fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isDirectory() && !e.name.startsWith('_') && !e.name.startsWith('.'))
    .map((e) => e.name)
    .sort((a, b) => indiceModulo(a) - indiceModulo(b) || a.localeCompare(b))
  const out = []
  for (const modulo of modulos) {
    const archivos = fs
      .readdirSync(path.join(dir, modulo))
      .filter((f) => f.toLowerCase().endsWith('.sql'))
      .sort()
    for (const f of archivos) out.push({ modulo, archivo: path.join(dir, modulo, f) })
  }
  return out
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

/** Divide por ';' fuera de literales, identificadores y dollar-quotes (texto sin comentarios). */
function dividir(sql) {
  const out = []
  let actual = ''
  let i = 0
  while (i < sql.length) {
    const ch = sql[i]
    if (ch === "'" || ch === '"') {
      const j = sql.indexOf(ch, i + 1)
      if (j < 0) throw new Error(`comilla ${ch} sin cerrar cerca de: ${sql.slice(i, i + 80)}`)
      actual += sql.slice(i, j + 1)
      i = j + 1
      continue
    }
    const m = ch === '$' && sql.slice(i).match(/^\$(\w*)\$/)
    if (m) {
      const j = sql.indexOf(m[0], i + m[0].length)
      if (j < 0) throw new Error(`dollar-quote ${m[0]} sin cerrar cerca de: ${sql.slice(i, i + 80)}`)
      actual += sql.slice(i, j + m[0].length)
      i = j + m[0].length
      continue
    }
    if (ch === ';') {
      if (actual.trim()) out.push(actual.trim())
      actual = ''
    } else actual += ch
    i++
  }
  if (actual.trim()) out.push(actual.trim())
  return out
}

const ES_FK = /^ALTER\s+TABLE\s+(?:ONLY\s+)?\S+\s+ADD\s+CONSTRAINT\s+\S+\s+FOREIGN\s+KEY\b/i
const ES_TRIGGER = /^CREATE\s+(?:OR\s+REPLACE\s+)?(?:CONSTRAINT\s+)?TRIGGER\b/i

/**
 * Separa cada archivo de tabla en: base (fase A), FKs (fase B) y triggers (tras funciones).
 * Devuelve unidades { etiqueta, sql } listas para ejecutar.
 */
function separarTablas(tablas) {
  const faseA = []
  const fks = []
  const triggers = []
  for (const { archivo } of tablas) {
    const sentencias = dividir(quitarComentarios(fs.readFileSync(archivo, 'utf8').replace(/\r\n/g, '\n')))
    const base = []
    for (const s of sentencias) {
      if (ES_FK.test(s)) fks.push({ etiqueta: `${rel(archivo)} [FK]`, sql: `${s};` })
      else if (ES_TRIGGER.test(s)) triggers.push({ etiqueta: `${rel(archivo)} [trigger]`, sql: `${s};` })
      else base.push(`${s};`)
    }
    faseA.push({ etiqueta: rel(archivo), sql: base.join('\n\n') })
  }
  return { faseA, fks, triggers }
}

function unidadesDeArchivos(lista, transformar = (s) => s) {
  return lista.map(({ archivo }) => ({ etiqueta: rel(archivo), sql: transformar(fs.readFileSync(archivo, 'utf8')) }))
}

/** Seeds en fases: listas → permisos → datos-base (general, finanzas, clientes, otros, auth). */
function ordenarSeeds(seeds) {
  const fase = (f) => ({ 'listas.sql': 0, 'permisos.sql': 1, 'datos-base.sql': 2 })[path.basename(f).toLowerCase()] ?? 3
  const ordenDatosBase = (modulo) => {
    if (modulo === DATOS_BASE_ULTIMO) return 1000
    const i = DATOS_BASE_PRIMERO.indexOf(modulo)
    return i !== -1 ? i : DATOS_BASE_PRIMERO.length + indiceModulo(modulo)
  }
  return [...seeds].sort((a, b) => {
    const fa = fase(a.archivo)
    const fb = fase(b.archivo)
    if (fa !== fb) return fa - fb
    if (fa === 2) return ordenDatosBase(a.modulo) - ordenDatosBase(b.modulo)
    return indiceModulo(a.modulo) - indiceModulo(b.modulo) || a.archivo.localeCompare(b.archivo)
  })
}

async function aplicar(client, unidades, label) {
  let i = 0
  for (const u of unidades) {
    i += 1
    if (dryRun) {
      console.log(`DRY ${label} ${String(i).padStart(3)} ${u.etiqueta} (${u.sql.length} bytes)`)
      continue
    }
    try {
      await client.query(u.sql)
    } catch (error) {
      throw new Error(`${label} ${u.etiqueta}: ${error.message}`)
    }
    if (i % 50 === 0) console.log(`${label} ${i}/${unidades.length}`)
  }
  console.log(`${label} ${unidades.length}/${unidades.length}${dryRun ? ' (dry-run)' : ''}`)
}

async function main() {
  if (!applyFunctions && !full) {
    console.error('Indica --functions (base reconstruida desde el repo) o --full --wipe (esquema desde 0).')
    process.exit(1)
  }
  if (full && !wipe) {
    console.error('--full requiere --wipe (DROP SCHEMA public CASCADE).')
    process.exit(1)
  }

  // Destino: solo se interpreta la URL (no se conecta). Nunca se imprime la URL.
  const url = loadDatabaseUrl()
  const { host, base, remoto } = destino(url)
  console.log(`Destino: host ${host}, base ${base}${dryRun ? ' (dry-run: no se conecta)' : ''}`)
  if (remoto && !permitirRemoto) {
    const msg =
      `Destino remoto (Supabase / DEV / PROD): ${host}. --functions y --full solo son para una base ` +
      'reconstruida desde este repo (local). Para publicar en DEV/PROD usa migraciones/sync-*.sql. ' +
      'Si de verdad es lo que quieres, añade --permitir-remoto.'
    if (!dryRun) {
      console.error(`RECHAZADO. ${msg}`)
      process.exit(1)
    }
    console.log(`AVISO (dry-run): sin --dry-run se rechazaría. ${msg}`)
  }
  if (full && wipe && process.env.CONFIRM_REBUILD !== base) {
    console.error(
      `Reconstrucción destructiva de la base "${base}" en ${host}: exporta CONFIRM_REBUILD=${base} ` +
        '(nombre exacto de la base de destino) y vuelve a ejecutar.',
    )
    process.exit(1)
  }

  const tablas = sqlPorModulo(TABLAS_DIR)
  const funciones = sqlPorModulo(FUNCIONES_DIR).sort((a, b) => {
    const m = indiceModulo(a.modulo) - indiceModulo(b.modulo)
    if (m) return m
    return functionPriority(a.archivo) - functionPriority(b.archivo) || a.archivo.localeCompare(b.archivo)
  })
  const seeds = ordenarSeeds(sqlPorModulo(SEEDS_DIR))

  const { faseA, fks, triggers } = separarTablas(tablas)
  const unidadesFunciones = unidadesDeArchivos(funciones, ensureSqlTerminators)
  const unidadesSeeds = unidadesDeArchivos(seeds)

  console.log('tablas', tablas.length, `(FKs ${fks.length}, triggers ${triggers.length})`)
  console.log('funciones', funciones.length)
  console.log('seeds', seeds.length)
  if (dryRun) console.log('DRY-RUN: no se conecta a ninguna base ni ejecuta SQL.')

  // --dry-run nunca crea el cliente: imposible ejecutar SQL.
  const client = dryRun
    ? null
    : new Client({ connectionString: url, ssl: { rejectUnauthorized: false } })
  if (client) await client.connect()
  try {
    if (full && wipe) {
      console.log(`${dryRun ? '(dry-run) ' : ''}WIPING public schema`)
      if (!dryRun) {
        await client.query('DROP SCHEMA IF EXISTS public CASCADE')
        await client.query('CREATE SCHEMA public')
        await client.query('GRANT ALL ON SCHEMA public TO public')
        await client.query('CREATE EXTENSION IF NOT EXISTS pgcrypto')
        await client.query('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')
      }
      await aplicar(client, faseA, 'tablas')
      await aplicar(client, fks, 'fks')
      if (!dryRun) await client.query('SET check_function_bodies = off')
      await aplicar(client, unidadesFunciones, 'funciones')
      if (!dryRun) await client.query('RESET check_function_bodies')
      await aplicar(client, triggers, 'triggers')
      await aplicar(client, unidadesSeeds, 'seeds')
    } else if (applyFunctions) {
      await aplicar(client, unidadesFunciones, 'funciones')
    }
    console.log(dryRun ? 'OK rebuild-schema-from-repo (dry-run)' : 'OK rebuild-schema-from-repo')
  } finally {
    if (client) await client.end()
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})
