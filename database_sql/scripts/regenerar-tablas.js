/**
 * Regenera database_sql/tablas/<modulo>/<tabla>.sql desde las cachés de catálogo
 * (database_sql/.cache/catalogo-dev.json y catalogo-prod.json, DDL de pg_dump --schema-only).
 * No se conecta a ninguna base.
 *
 * Por cada tabla de DEV ∪ PROD: DDL de la base donde existe; si existe en ambas y el DDL
 * (limpio) difiere, se usa PROD y se anota el diff en .cache/reporte-tablas.md.
 * Limpieza: \restrict/\unrestrict, SET ..., SELECT pg_catalog.set_config(...), comentarios
 * `--` de pg_dump y líneas vacías repetidas. Primera línea: `-- <descripción>`.
 * Secuencias, índices, constraints y triggers vienen en el DDL de cada tabla.
 *
 * Antes de borrar tablas/ se compara cada archivo del repo con el DDL de ambas bases
 * (sentencias normalizadas: sin comentarios, espacios, mayúsculas, `public.`, `ONLY`,
 * `IF NOT EXISTS`). Los que no coinciden con ninguna base se listan en el reporte
 * ("Repo distinto de las bases") y su texto original se guarda en .cache/repo-drift-tablas/.
 *
 * Uso: node database_sql/scripts/regenerar-tablas.js [--dry-run]
 */
const fs = require('fs')
const os = require('os')
const path = require('path')
const { execFileSync } = require('child_process')
const { quitarComentarios } = require('./lib/comentarios')
const { descripcionDe } = require('./lib/descripcion')
const { moduloDe } = require('./lib/modulos')
const { formatearSql } = require('./lib/formato')

const DB = path.join(__dirname, '..')
const TABLAS = path.join(DB, 'tablas')
const CACHE = path.join(DB, '.cache')
const DRIFT = path.join(CACHE, 'repo-drift-tablas')
const DRY = process.argv.includes('--dry-run')

function listarSql(dir) {
  if (!fs.existsSync(dir)) return []
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) return listarSql(p)
    return e.name.endsWith('.sql') ? [p] : []
  })
}

/** DDL de pg_dump sin ruido: \restrict, SET, set_config, comentarios `--` y vacías repetidas. */
function limpiarDdl(ddl) {
  const lineas = String(ddl)
    .replace(/\r\n/g, '\n')
    .split('\n')
    .filter((l) => !/^\\(un)?restrict\b/.test(l))
    .filter((l) => !/^SET\s/.test(l))
    .filter((l) => !/^SELECT pg_catalog\.set_config\(/.test(l))
    .filter((l) => !/^--/.test(l))
  const out = []
  for (const l of lineas) {
    if (!l.trim() && (!out.length || !out[out.length - 1].trim())) continue
    out.push(l.trimEnd())
  }
  while (out.length && !out[out.length - 1].trim()) out.pop()
  return out.join('\n') + '\n'
}

/** Divide por ';' fuera de literales '...' y "...". */
function dividirSentencias(sql) {
  const out = []
  let actual = ''
  let q = null
  for (const ch of sql) {
    if (q) {
      if (ch === q) q = null
    } else if (ch === "'" || ch === '"') q = ch
    else if (ch === ';') {
      out.push(actual)
      actual = ''
      continue
    }
    actual += ch
  }
  out.push(actual)
  return out
}

/**
 * Sentencias normalizadas (lista ordenada) para comparar repo vs base sin formato.
 * Se ignoran COMMENT ON (el repo previo no los traía; no son columnas ni constraints).
 * laxa: además quita paréntesis, casts `::tipo` y `USING btree` (pg_dump los añade).
 */
function sentenciasCanonicas(sql, laxa = false) {
  const sinCom = quitarComentarios(String(sql).replace(/\r\n/g, '\n'))
  return dividirSentencias(sinCom)
    .filter((s) => !/^\s*COMMENT\s+ON\b/i.test(s))
    .map((s) =>
      laxa
        ? s
            .replace(/::\s*[a-z_][a-z0-9_ ]*?(\[\])?(?=[\s,)\]]|$)/gi, '')
            .replace(/\busing\s+btree\b/gi, '')
            .replace(/[()]/g, '')
        : s,
    )
    .map((s) =>
      s
        .toLowerCase()
        .replace(/\bif not exists\b/g, '')
        .replace(/\bonly\b/g, '')
        .replace(/"?public"?\./g, '')
        .replace(/\s+/g, ''),
    )
    .filter(Boolean)
    .sort()
}

function mismoContenido(a, b) {
  return a.length === b.length && a.every((x, i) => x === b[i])
}

/** Diff unificado de dos textos (git diff --no-index, solo lectura). */
function diffUnificado(a, b, etiquetaA, etiquetaB) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'regen-tab-'))
  const fa = path.join(dir, 'a.sql')
  const fb = path.join(dir, 'b.sql')
  fs.writeFileSync(fa, a)
  fs.writeFileSync(fb, b)
  let salida = ''
  try {
    salida = execFileSync('git', ['-c', 'core.autocrlf=false', 'diff', '--no-index', '--no-color', '-U3', fa, fb], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] })
  } catch (e) {
    salida = String(e.stdout || '')
  } finally {
    fs.rmSync(dir, { recursive: true, force: true })
  }
  const lineas = salida.split('\n')
  const i = lineas.findIndex((l) => l.startsWith('@@'))
  if (i < 0) return '(sin diferencias)'
  return [`--- ${etiquetaA}`, `+++ ${etiquetaB}`, ...lineas.slice(i)].join('\n').trimEnd()
}

function porNombre(tablas) {
  return new Map(tablas.map((t) => [t.nombre, limpiarDdl(t.ddl)]))
}

function main() {
  const dev = porNombre(JSON.parse(fs.readFileSync(path.join(CACHE, 'catalogo-dev.json'), 'utf8')).tablas)
  const prod = porNombre(JSON.parse(fs.readFileSync(path.join(CACHE, 'catalogo-prod.json'), 'utf8')).tablas)
  const descripciones = JSON.parse(fs.readFileSync(path.join(__dirname, 'descripciones.json'), 'utf8'))

  // 1. Repo actual (antes de borrar).
  const repo = new Map()
  for (const archivo of listarSql(TABLAS)) {
    const nombre = path.basename(archivo, '.sql').toLowerCase()
    repo.set(nombre, { archivo: path.relative(DB, archivo).split(path.sep).join('/'), original: fs.readFileSync(archivo, 'utf8') })
  }

  // 2. Decisiones.
  const nombres = [...new Set([...dev.keys(), ...prod.keys()])].sort()
  const salidas = []
  const difieren = []
  const soloDev = []
  const soloProd = []
  const fallosFormato = []
  const drift = []
  const equivalentes = []
  const porModulo = {}
  for (const nombre of nombres) {
    const d = dev.get(nombre)
    const p = prod.get(nombre)
    let ddl
    let origen
    if (d && p) {
      ddl = p
      origen = d === p ? 'ambas' : 'prod'
      if (d !== p) difieren.push({ nombre, dev: d, prod: p })
    } else if (p) {
      ddl = p
      origen = 'prod'
      soloProd.push(nombre)
    } else {
      ddl = d
      origen = 'dev'
      soloDev.push(nombre)
    }
    const r = repo.get(nombre)
    if (r) {
      const canon = sentenciasCanonicas(r.original)
      const coincide = [d, p].filter(Boolean).some((x) => mismoContenido(canon, sentenciasCanonicas(x)))
      if (!coincide) {
        const canonLaxa = sentenciasCanonicas(r.original, true)
        const equivalente = [d, p].filter(Boolean).some((x) => mismoContenido(canonLaxa, sentenciasCanonicas(x, true)))
        if (equivalente) equivalentes.push(nombre)
        else drift.push({ nombre, archivo: r.archivo, original: r.original, ddl, origen })
      }
    }
    const { modulo } = moduloDe(nombre)
    porModulo[modulo] = (porModulo[modulo] || 0) + 1
    const crudo = `-- ${descripcionDe(nombre, descripciones)}\n${ddl}`
    const fmt = formatearSql(crudo)
    if (!fmt.ok) fallosFormato.push(`${nombre}: ${fmt.error}`)
    salidas.push({ archivo: path.join(TABLAS, modulo, `${nombre}.sql`), texto: fmt.texto })
  }
  const sinCatalogo = [...repo.keys()].filter((n) => !dev.has(n) && !prod.has(n)).sort()
  for (const n of sinCatalogo) drift.push({ nombre: n, ...repo.get(n), ddl: null, origen: 'sin catálogo' })

  // 3. Resumen.
  const conTrigger = salidas.filter((s) => /CREATE TRIGGER/i.test(s.texto)).map((s) => path.basename(s.archivo, '.sql'))
  console.log(`Tablas: ${nombres.length} (DEV ${dev.size}, PROD ${prod.size})`)
  console.log('Por módulo:', JSON.stringify(porModulo))
  console.log('Solo DEV:', soloDev.join(', ') || '(ninguna)')
  console.log('Solo PROD:', soloProd.join(', ') || '(ninguna)')
  console.log('DEV ≠ PROD (se usa PROD):', difieren.map((x) => x.nombre).join(', ') || '(ninguna)')
  console.log('Repo distinto de las bases:', drift.map((x) => x.nombre).join(', ') || '(ninguna)')
  console.log('Repo equivalente salvo formato/COMMENT ON:', equivalentes.join(', ') || '(ninguna)')
  console.log('Con CREATE TRIGGER:', conTrigger.join(', ') || '(ninguna)')
  console.log('Fallos de formato:', fallosFormato.length ? fallosFormato.join('; ') : '(ninguno)')
  if (DRY) return

  // 4. Escribir.
  // repo-drift-tablas/ solo se reemplaza si hay drift nuevo; sin drift se conserva la evidencia
  // anterior (la de la limpieza está congelada en .cache/limpieza-2026-10-27/).
  if (drift.length) {
    fs.rmSync(DRIFT, { recursive: true, force: true })
    fs.mkdirSync(DRIFT, { recursive: true })
  }
  for (const x of drift) {
    fs.writeFileSync(path.join(DRIFT, `${x.nombre}.sql`), x.original)
  }
  fs.rmSync(TABLAS, { recursive: true, force: true })
  for (const s of salidas) {
    fs.mkdirSync(path.dirname(s.archivo), { recursive: true })
    fs.writeFileSync(s.archivo, s.texto)
  }
  fs.writeFileSync(
    path.join(CACHE, 'reporte-tablas.md'),
    reporte({ nombres, dev, prod, porModulo, soloDev, soloProd, difieren, drift, equivalentes, sinCatalogo, conTrigger, fallosFormato }),
  )
  console.log(`Escritos ${salidas.length} archivos en tablas/ y reporte-tablas.md`)
}

function reporte({ nombres, dev, prod, porModulo, soloDev, soloProd, difieren, drift, equivalentes, sinCatalogo, conTrigger, fallosFormato }) {
  const l = []
  l.push('# Reporte de regeneración de tablas', '')
  l.push(`Generado: ${new Date().toISOString()} — fuente: cachés .cache/catalogo-dev.json y catalogo-prod.json (pg_dump --schema-only).`, '')
  l.push(`Tablas (DEV ∪ PROD): ${nombres.length} (DEV ${dev.size}, PROD ${prod.size})`, '')
  l.push('## Por módulo', '', '| Módulo | Archivos |', '|---|---|')
  for (const m of Object.keys(porModulo).sort()) l.push(`| ${m} | ${porModulo[m]} |`)
  l.push('', `## Solo en DEV (${soloDev.length})`, '', soloDev.map((n) => `- ${n}`).join('\n') || '(ninguna)', '')
  l.push(`## Solo en PROD (${soloProd.length})`, '', soloProd.map((n) => `- ${n}`).join('\n') || '(ninguna)', '')
  l.push(`## Con CREATE TRIGGER (${conTrigger.length})`, '', conTrigger.map((n) => `- ${n}`).join('\n') || '(ninguna)', '')
  l.push('## Fallos de formato', '', fallosFormato.map((n) => `- ${n}`).join('\n') || '(ninguno)', '')
  l.push(`## DEV ≠ PROD (${difieren.length}) — se escribió PROD; decidir`, '')
  l.push('Diff del DDL limpio (sin \\restrict, SET, set_config ni comentarios de pg_dump).', '')
  for (const x of difieren) {
    l.push(`### ${x.nombre}`, '', '```diff', diffUnificado(x.dev, x.prod, 'dev', 'prod'), '```', '')
  }
  l.push(`## Repo distinto de las bases (${drift.length})`, '')
  l.push('Archivos de tablas/ previos cuyas sentencias (normalizadas: sin comentarios, espacios, mayúsculas,',
    '`public.`, `ONLY`, `IF NOT EXISTS`) no coinciden con el DDL de ninguna base. Texto original guardado',
    'en .cache/repo-drift-tablas/<tabla>.sql.', '')
  for (const x of drift) l.push(`- ${x.nombre} — ${x.archivo} (escrito: ${x.origen})`)
  l.push('', `Equivalentes salvo COMMENT ON / paréntesis / casts / USING btree (no se guardan, ${equivalentes.length}): ${equivalentes.join(', ') || '(ninguna)'}`, '')
  if (sinCatalogo.length) l.push(`En el repo sin catálogo (no se regeneran): ${sinCatalogo.join(', ')}`, '')
  for (const x of drift) {
    if (!x.ddl) continue
    l.push(`### ${x.nombre}`, '', '```diff',
      diffUnificado(quitarComentarios(x.original.replace(/\r\n/g, '\n')).trim() + '\n', x.ddl, 'repo (sin comentarios)', `db (${x.origen})`),
      '```', '')
  }
  return l.join('\n') + '\n'
}

if (require.main === module) main()

module.exports = { limpiarDdl, sentenciasCanonicas }
