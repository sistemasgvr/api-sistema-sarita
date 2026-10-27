/**
 * Regenera database_sql/funciones/<modulo>/<nombre>.sql desde las cachés de catálogo
 * (database_sql/.cache/catalogo-dev.json y catalogo-prod.json). No se conecta a ninguna base.
 *
 * Por cada nombre en DEV ∪ PROD:
 *   elegirVersion (repoCuerpos = sentencias CREATE del árbol funciones/ actual que definen ese nombre;
 *   base = decisión anterior en .cache/decisiones-funciones.json, si existe: ver lib/version.js)
 *   → renderFuncion (descripción + DROP exacto + definición sin comentarios) → formato → archivo.
 * 'pendiente' (DEV y PROD difieren y el repo no coincide con ninguna): se escribe la versión
 * actual del repo (solo sin comentarios) y se documenta en .cache/reporte-funciones.md con los
 * diffs repo vs DEV y repo vs PROD.
 *
 * Salidas:
 *   database_sql/funciones/**                  (el árbol anterior se borra antes de escribir)
 *   database_sql/.cache/decisiones-funciones.json  [{ nombre, modulo, origen, firmas, firmasObsoletas }]
 *   database_sql/.cache/reporte-funciones.md
 *
 * Uso: node database_sql/scripts/regenerar-funciones.js [--dry-run]
 */
const fs = require('fs')
const os = require('os')
const path = require('path')
const { execFileSync } = require('child_process')
const { quitarComentarios } = require('./lib/comentarios')
const { elegirVersion, normalizarCuerpo } = require('./lib/version')
const { renderFuncion } = require('./lib/render')
const { descripcionDe } = require('./lib/descripcion')
const { moduloDe } = require('./lib/modulos')
const { formatearSql } = require('./lib/formato')

const DB = path.join(__dirname, '..')
const FUNCIONES = path.join(DB, 'funciones')
const CACHE = path.join(DB, '.cache')
const DRY = process.argv.includes('--dry-run')
const DRIFT = path.join(CACHE, 'repo-drift')
const TIPOS_DRIFT = ['cuerpo', 'cabecera-distinta', 'cabecera-equivalente']

/** --repo-original <dir>: árbol original (database_sql/ o su funciones/). Por defecto, funciones/ actual. */
function dirRepoOriginal() {
  const i = process.argv.indexOf('--repo-original')
  if (i < 0) return FUNCIONES
  const dir = process.argv[i + 1]
  if (!dir) throw new Error('--repo-original requiere un directorio')
  const conFunciones = path.join(dir, 'funciones')
  return fs.existsSync(conFunciones) ? conFunciones : dir
}

function listarSql(dir) {
  if (!fs.existsSync(dir)) return []
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) return listarSql(p)
    return e.name.endsWith('.sql') ? [p] : []
  })
}

/**
 * Sentencias CREATE FUNCTION/PROCEDURE de un texto sin comentarios.
 * Devuelve { nombre, kind, argsCabecera, def } con el nombre calificado como public.<nombre>
 * en `def` (solo la cabecera; el cuerpo queda intacto).
 */
function sentenciasCreate(sql) {
  const out = []
  const re = /CREATE\s+(?:OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s+((?:"?public"?\.)?"?([A-Za-z_][A-Za-z0-9_]*)"?)\s*\(/gi
  let m
  while ((m = re.exec(sql))) {
    const ini = m.index
    let p = re.lastIndex
    let depth = 1
    while (p < sql.length && depth > 0) {
      if (sql[p] === '(') depth++
      else if (sql[p] === ')') depth--
      p++
    }
    const argsCabecera = sql.slice(re.lastIndex, p - 1)
    const tag = /\$[A-Za-z_]*\$/.exec(sql.slice(p))
    if (!tag) throw new Error(`Sentencia sin cuerpo dollar-quoted: ${m[3]}`)
    const abre = p + tag.index
    const cierra = sql.indexOf(tag[0], abre + tag[0].length)
    if (cierra < 0) throw new Error(`Cuerpo sin cierre: ${m[3]}`)
    let fin = sql.indexOf(';', cierra + tag[0].length)
    if (fin < 0) fin = sql.length
    const nombre = m[3].toLowerCase()
    const cabecera = m[0].replace(m[2], `public.${nombre}`)
    const def = cabecera + sql.slice(re.lastIndex, fin).trim()
    out.push({ nombre, kind: m[1].toUpperCase() === 'PROCEDURE' ? 'p' : 'f', argsCabecera, def })
    re.lastIndex = fin
  }
  return out
}

/** Divide por comas de nivel superior. */
function dividirArgs(s) {
  const partes = []
  let depth = 0
  let actual = ''
  let enLit = false
  for (const ch of s) {
    if (ch === "'") enLit = !enLit
    if (!enLit && ch === '(') depth++
    if (!enLit && ch === ')') depth--
    if (!enLit && depth === 0 && ch === ',') { partes.push(actual); actual = ''; continue }
    actual += ch
  }
  if (actual.trim()) partes.push(actual)
  return partes.map((x) => x.replace(/\s+/g, ' ').trim())
}

/** Argumentos de identidad (para DROP) a partir de la cabecera: sin DEFAULT / =. */
function argsIdentidad(argsCabecera) {
  return dividirArgs(argsCabecera)
    .map((a) => a.replace(/\s+(DEFAULT\b|=).*$/i, '').trim())
    .join(', ')
}

const ALIAS_TIPOS = [
  [/\bvarchar\b/g, 'character varying'],
  [/\bint4?\b/g, 'integer'],
  [/\bint8\b/g, 'bigint'],
  [/\bint2\b/g, 'smallint'],
  [/\bbool\b/g, 'boolean'],
  [/\bdecimal\b/g, 'numeric'],
  [/\btimestamp\b(?! with)/g, 'timestamp without time zone'],
]

/** Clave comparable de una lista de argumentos (alias de tipos normalizados). */
function claveArgs(args) {
  let s = String(args || '').toLowerCase().replace(/\s+/g, ' ').trim()
  for (const [re, v] of ALIAS_TIPOS) s = s.replace(re, v)
  return s
}

function porNombre(funciones) {
  const m = new Map()
  for (const f of funciones) {
    if (!m.has(f.nombre)) m.set(f.nombre, [])
    m.get(f.nombre).push({ args: f.args, kind: f.kind, def: f.def })
  }
  return m
}

/** Diff unificado de dos textos (git diff --no-index, solo lectura; sin tocar el repo). */
function diffUnificado(a, b, etiquetaA, etiquetaB) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'regen-fn-'))
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

function textoFirmas(firmas) {
  return firmas.map((f) => quitarComentarios(f.def.replace(/\r\n/g, '\n')).trim()).join('\n\n') + '\n'
}

/** Cuerpo dollar-quoted (tras AS) sin comentarios, espacios ni mayúsculas: compara sin la cabecera. */
function cuerpoInterno(def) {
  const sql = quitarComentarios(String(def).replace(/\r\n/g, '\n'))
  const m = /\bAS\s+(\$[A-Za-z_]*\$)/i.exec(sql)
  if (!m) return normalizarCuerpo(sql)
  const ini = m.index + m[0].length
  const fin = sql.indexOf(m[1], ini)
  return sql.slice(ini, fin < 0 ? sql.length : fin).replace(/\s+/g, '').toLowerCase()
}

/**
 * Cabecera (todo salvo el cuerpo dollar-quoted) en forma comparable: minúsculas, sin espacios,
 * alias de tipos normalizados y sin casts `::tipo` (pg_get_functiondef añade `DEFAULT NULL::integer`).
 */
function cabeceraCanonica(def) {
  const sql = quitarComentarios(String(def).replace(/\r\n/g, '\n'))
  const m = /\bAS\s+(\$[A-Za-z_]*\$)/i.exec(sql)
  let h = m ? sql.slice(0, m.index) + ' ' + sql.slice(sql.lastIndexOf(m[1]) + m[1].length) : sql
  h = h.toLowerCase().replace(/\s+/g, ' ')
  h = h.replace(/::\s*(character varying|time without time zone|timestamp without time zone|timestamp with time zone|double precision|[a-z_][a-z0-9_]*)(\s*\[\])?/g, '')
  for (const [re, v] of ALIAS_TIPOS) h = h.replace(re, v)
  return h.replace(/\s+/g, '').replace(/;$/, '')
}

/** 'cuerpo' | 'cabecera-distinta' | 'cabecera-equivalente' para un nombre cuyo repo no coincide con la base. */
function clasificarDrift(delRepo, firmas) {
  const dbInternos = new Set(firmas.map((f) => cuerpoInterno(f.def)))
  if (!delRepo.every((s) => dbInternos.has(cuerpoInterno(s.def)))) return 'cuerpo'
  const dbCabeceras = new Set(firmas.map((f) => cabeceraCanonica(f.def)))
  return delRepo.every((s) => dbCabeceras.has(cabeceraCanonica(s.def))) ? 'cabecera-equivalente' : 'cabecera-distinta'
}

/**
 * Línea base: decisiones de la regeneración anterior (.cache/decisiones-funciones.json), por nombre.
 * Si una función era 'ambas', sus firmas son el último cuerpo conocido de DEV y PROD; elegirVersion
 * la usa para saber qué base cambió desde entonces (una edición directa en DEV no se revierte a PROD).
 * Sin archivo → mapa vacío (regla de coincidencia con el repo).
 */
function leerLineaBase() {
  const archivo = path.join(CACHE, 'decisiones-funciones.json')
  if (!fs.existsSync(archivo)) return new Map()
  const lista = JSON.parse(fs.readFileSync(archivo, 'utf8'))
  return new Map(lista.map((d) => [d.nombre, { origen: d.origen, firmas: d.firmas || [] }]))
}

function main() {
  const dev =porNombre(JSON.parse(fs.readFileSync(path.join(CACHE, 'catalogo-dev.json'), 'utf8')).funciones)
  const prod = porNombre(JSON.parse(fs.readFileSync(path.join(CACHE, 'catalogo-prod.json'), 'utf8')).funciones)
  const descripciones = JSON.parse(fs.readFileSync(path.join(__dirname, 'descripciones.json'), 'utf8'))

  // 1. Repo actual (antes de borrar): sentencias por nombre.
  const repo = new Map()
  const repoDir = dirRepoOriginal()
  const repoRaiz = path.dirname(repoDir)
  for (const archivo of listarSql(repoDir)) {
    const original = fs.readFileSync(archivo, 'utf8')
    const sql = quitarComentarios(original.replace(/\r\n/g, '\n'))
    for (const s of sentenciasCreate(sql)) {
      if (!repo.has(s.nombre)) repo.set(s.nombre, [])
      repo.get(s.nombre).push({ ...s, original, archivo: path.relative(repoRaiz, archivo).split(path.sep).join('/') })
    }
  }

  // 2. Decisiones.
  const nombres = [...new Set([...dev.keys(), ...prod.keys()])].sort()
  const decisiones = []
  const salidas = []
  const pendientes = []
  const fallosFormato = []
  const drift = []
  const lineaBase = leerLineaBase()
  const porLineaBase = []
  for (const nombre of nombres) {
    const delRepo = repo.get(nombre) || []
    const repoCuerpos = new Set(delRepo.map((s) => normalizarCuerpo(s.def)))
    const base = lineaBase.get(nombre) || null
    const r = elegirVersion({ dev: dev.get(nombre), prod: prod.get(nombre), repoCuerpos, base })
    const sinBase = base ? elegirVersion({ dev: dev.get(nombre), prod: prod.get(nombre), repoCuerpos }).origen : r.origen
    if (sinBase !== r.origen) porLineaBase.push(`${nombre} (${sinBase} → ${r.origen})`)
    let { firmas, firmasObsoletas } = r
    if (r.origen === 'pendiente') {
      if (!delRepo.length) throw new Error(`${nombre}: pendiente sin versión en el repo`)
      firmas = delRepo.map((s) => ({ args: argsIdentidad(s.argsCabecera), kind: s.kind, def: s.def }))
      const elegidas = new Set(firmas.map((f) => claveArgs(f.args)))
      const otras = [...(dev.get(nombre) || []), ...(prod.get(nombre) || [])]
      firmasObsoletas = [...new Set(otras.map((f) => f.args))].filter((a) => !elegidas.has(claveArgs(a)))
      pendientes.push({ nombre, delRepo, dev: dev.get(nombre) || [], prod: prod.get(nombre) || [], firmas })
    }
    if (r.origen === 'ambas' && delRepo.length) {
      const dbCuerpos = new Set(firmas.map((f) => normalizarCuerpo(f.def)))
      if (delRepo.some((s) => !dbCuerpos.has(normalizarCuerpo(s.def)))) {
        const tipo = clasificarDrift(delRepo, firmas)
        drift.push({ nombre, tipo, delRepo, firmas })
      }
    }
    const { modulo } = moduloDe(nombre)
    const crudo = renderFuncion(nombre, descripcionDe(nombre, descripciones), firmas)
    const fmt = formatearSql(crudo)
    if (!fmt.ok) fallosFormato.push(`${nombre}: ${fmt.error}`)
    salidas.push({ archivo: path.join(FUNCIONES, modulo, `${nombre}.sql`), texto: fmt.texto })
    decisiones.push({
      nombre,
      modulo,
      origen: r.origen,
      firmas: firmas.map((f) => ({ args: f.args, kind: f.kind || 'f', def: quitarComentarios(f.def).trim() })),
      firmasObsoletas,
    })
  }

  // 3. Resumen.
  const conteo = {}
  const conteoFirmas = {}
  const porModulo = {}
  for (const d of decisiones) {
    conteo[d.origen] = (conteo[d.origen] || 0) + 1
    conteoFirmas[d.origen] = (conteoFirmas[d.origen] || 0) + d.firmas.length
    porModulo[d.modulo] = (porModulo[d.modulo] || 0) + 1
  }
  const sinCatalogo = [...repo.keys()].filter((n) => !dev.has(n) && !prod.has(n)).sort()
  console.log(`Nombres: ${nombres.length} (DEV ${dev.size}, PROD ${prod.size})`)
  console.log('Por origen (nombres):', JSON.stringify(conteo))
  console.log('Por origen (firmas):', JSON.stringify(conteoFirmas))
  console.log('Por módulo:', JSON.stringify(porModulo))
  console.log('En el repo sin catálogo:', sinCatalogo.length ? sinCatalogo.join(', ') : '(ninguno)')
  console.log(`Repo distinto de ambas bases: ${drift.length}`)
  for (const d of drift) console.log(`  [${d.tipo}] ${d.nombre} — ${[...new Set(d.delRepo.map((s) => s.archivo))].join(', ')}`)
  console.log('Fallos de formato:', fallosFormato.length ? fallosFormato.join('; ') : '(ninguno)')
  console.log(`Línea base: ${lineaBase.size ? `${lineaBase.size} decisiones anteriores` : '(sin decisiones-funciones.json)'}; decididas por la línea base: ${porLineaBase.length ? porLineaBase.join(', ') : '(ninguna)'}`)
  if (DRY) return

  // 4. Escribir.
  fs.rmSync(FUNCIONES, { recursive: true, force: true })
  for (const s of salidas) {
    fs.mkdirSync(path.dirname(s.archivo), { recursive: true })
    fs.writeFileSync(s.archivo, s.texto)
  }
  // repo-drift/ solo se reemplaza si hay drift nuevo que guardar: sin drift, la evidencia anterior
  // se conserva (la de la limpieza está congelada aparte en .cache/limpieza-2026-10-27/).
  const driftAGuardar = drift.filter((x) => x.tipo !== 'cabecera-equivalente')
  if (driftAGuardar.length) {
    fs.rmSync(DRIFT, { recursive: true, force: true })
    fs.mkdirSync(DRIFT, { recursive: true })
  }
  for (const d of driftAGuardar) {
    const archivos = [...new Map(d.delRepo.map((s) => [s.archivo, s.original])).entries()]
    const texto = archivos.length === 1
      ? archivos[0][1]
      : archivos.map(([a, t]) => `-- ==== archivo original: ${a} ====\n${t}`).join('\n')
    fs.writeFileSync(path.join(DRIFT, `${d.nombre}.sql`), texto)
  }
  fs.writeFileSync(path.join(CACHE, 'decisiones-funciones.json'), JSON.stringify(decisiones, null, 2) + '\n')
  fs.writeFileSync(
    path.join(CACHE, 'reporte-funciones.md'),
    reporte({ nombres, conteo, conteoFirmas, porModulo, decisiones, pendientes, sinCatalogo, fallosFormato, drift }),
  )
  console.log(`Escritos ${salidas.length} archivos en funciones/, decisiones-funciones.json y reporte-funciones.md`)
}

function reporte({ nombres, conteo, conteoFirmas, porModulo, decisiones, pendientes, sinCatalogo, fallosFormato, drift }) {
  const l = []
  l.push('# Reporte de regeneración de funciones', '')
  l.push(`Generado: ${new Date().toISOString()} — fuente: cachés .cache/catalogo-dev.json y catalogo-prod.json.`, '')
  l.push(`Nombres (DEV ∪ PROD): ${nombres.length}`, '')
  l.push('| Origen | Nombres | Firmas |', '|---|---|---|')
  for (const o of ['ambas', 'dev', 'prod', 'pendiente']) l.push(`| ${o} | ${conteo[o] || 0} | ${conteoFirmas[o] || 0} |`)
  l.push('', '## Por módulo', '', '| Módulo | Archivos |', '|---|---|')
  for (const m of Object.keys(porModulo).sort()) l.push(`| ${m} | ${porModulo[m]} |`)
  l.push('', '## Elegidas por base (difieren DEV y PROD, o solo existen en una)', '')
  for (const o of ['dev', 'prod']) {
    const ns = decisiones.filter((d) => d.origen === o)
    l.push(`### ${o} (${ns.length})`, '')
    for (const d of ns) {
      const obs = d.firmasObsoletas.length ? ` — firmas obsoletas: ${d.firmasObsoletas.map((a) => `(${a})`).join('; ')}` : ''
      l.push(`- ${d.nombre}${obs}`)
    }
    l.push('')
  }
  l.push('## En el repo sin catálogo (no se regeneran)', '', sinCatalogo.length ? sinCatalogo.map((n) => `- ${n}`).join('\n') : '(ninguno)', '')
  l.push('## Fallos de formato', '', fallosFormato.length ? fallosFormato.map((n) => `- ${n}`).join('\n') : '(ninguno)', '')
  l.push(`## Pendientes (${pendientes.length})`, '')
  l.push('DEV y PROD difieren y ningún cuerpo del repo coincide con ninguna de las dos. Se escribió la',
    'versión actual del repo (solo sin comentarios). Decidir cuál queda. Diffs sin comentarios.', '')
  for (const p of pendientes) {
    const repoTxt = textoFirmas(p.delRepo)
    l.push(`### ${p.nombre}`, '')
    l.push(`Archivo(s) del repo: ${[...new Set(p.delRepo.map((s) => s.archivo))].join(', ')}`, '')
    l.push(`Firmas escritas: ${p.firmas.map((f) => `(${f.args})`).join('; ')}`, '')
    l.push('#### repo vs DEV', '', '```diff', diffUnificado(repoTxt, textoFirmas(p.dev), 'repo', 'dev'), '```', '')
    l.push('#### repo vs PROD', '', '```diff', diffUnificado(repoTxt, textoFirmas(p.prod), 'repo', 'prod'), '```', '')
  }
  const porTipo = (t) => drift.filter((d) => d.tipo === t)
  l.push(`## Repo distinto de ambas bases (${drift.length})`, '')
  l.push('DEV y PROD coinciden (origen ambas) y en funciones/ se escribió esa versión, pero alguna sentencia',
    'del repo original (todos los archivos que definían el nombre) no coincide con ella.',
    '- "cabecera-equivalente": cuerpo dollar-quoted igual y cabecera igual salvo formato, casts `::tipo` de',
    '  los DEFAULT y alias de tipos (varchar = character varying). Inofensivo.',
    '- "cabecera-distinta": cuerpo igual, pero la cabecera difiere de verdad (firma, DEFAULT, RETURNS, opciones).',
    '- "cuerpo": el cuerpo difiere. El texto original del repo (con comentarios) se guardó en',
    '  .cache/repo-drift/<nombre>.sql (también para "cabecera-distinta").', '')
  for (const t of TIPOS_DRIFT) {
    l.push(`- ${t} (${porTipo(t).length}): ${porTipo(t).map((d) => d.nombre).join(', ') || '(ninguno)'}`)
  }
  l.push('')
  for (const d of TIPOS_DRIFT.flatMap(porTipo)) {
    l.push(`### ${d.nombre} [${d.tipo}]`, '')
    const dbCuerpos = new Set(d.firmas.map((f) => normalizarCuerpo(f.def)))
    l.push('Sentencias del repo original:')
    for (const s of d.delRepo) {
      const estado = dbCuerpos.has(normalizarCuerpo(s.def)) ? 'igual a la base' : clasificarDrift([s], d.firmas)
      l.push(`- ${s.archivo}: ${estado}`)
    }
    l.push('')
    l.push('```diff', diffUnificado(textoFirmas(d.delRepo), textoFirmas(d.firmas), 'repo', 'db (dev = prod)'), '```', '')
  }
  return l.join('\n') + '\n'
}

if (require.main === module) main()

module.exports = { sentenciasCreate, argsIdentidad, claveArgs }
