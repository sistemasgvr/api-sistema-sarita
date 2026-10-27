/**
 * Genera database_sql/migraciones/sync-prod-desde-dev.sql y sync-dev-desde-prod.sql
 * desde .cache/decisiones-funciones.json, las cachés de catálogo y los archivos de
 * tablas/ y funciones/. No se conecta a ninguna base y NO ejecuta los scripts.
 *
 * Cada script (una transacción): tablas nuevas (CREATE ... IF NOT EXISTS, constraints
 * con guarda), columnas que faltan en tablas comunes (ADD COLUMN IF NOT EXISTS), FKs,
 * funciones del origen correspondiente (DROP de firmas obsoletas + DROP/CREATE por firma),
 * triggers (después de sus funciones) y filas de catálogo/datos idempotentes.
 *
 * Uso: node database_sql/scripts/generar-sync.js
 */
const fs = require('fs')
const path = require('path')
const { quitarComentarios } = require('./lib/comentarios')
const { moduloDe } = require('./lib/modulos')
const { renderFuncion } = require('./lib/render')
const { formatearSql } = require('./lib/formato')
const { limpiarDdl } = require('./regenerar-tablas')

const DB = path.join(__dirname, '..')
const CACHE = path.join(DB, '.cache')
const MIG = path.join(DB, 'migraciones')
const leerJson = (f) => JSON.parse(fs.readFileSync(path.join(CACHE, f), 'utf8'))

const decisiones = leerJson('decisiones-funciones.json')
const catalogo = { dev: leerJson('catalogo-dev.json'), prod: leerJson('catalogo-prod.json') }
const tablasDe = (b) => new Map(catalogo[b].tablas.map((t) => [t.nombre, limpiarDdl(t.ddl)]))
const tablas = { dev: tablasDe('dev'), prod: tablasDe('prod') }

/** Pendientes cuya versión de PROD solo difiere del repo en la ortografía de tipos de la cabecera. */
const PENDIENTE_A_DEV_DESDE_PROD = ['ven_actualizar_comprobante']

/** Divide por ';' fuera de literales, identificadores y dollar-quotes. */
function dividir(sql) {
  const out = []
  let actual = ''
  let i = 0
  while (i < sql.length) {
    const ch = sql[i]
    if (ch === "'" || ch === '"') {
      const j = sql.indexOf(ch, i + 1)
      if (j < 0) throw new Error(`dividir: comilla ${ch} sin cerrar cerca de: ${sql.slice(i, i + 80)}`)
      actual += sql.slice(i, j + 1)
      i = j + 1
      continue
    }
    const m = ch === '$' && sql.slice(i).match(/^\$(\w*)\$/)
    if (m) {
      const j = sql.indexOf(m[0], i + m[0].length)
      if (j < 0) throw new Error(`dividir: dollar-quote ${m[0]} sin cerrar cerca de: ${sql.slice(i, i + 80)}`)
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

const plano = (s) => s.replace(/\s+/g, ' ').trim()

function guarda(condicion, sentencia) {
  return `DO $sync$\nBEGIN\n  IF NOT EXISTS (${condicion}) THEN\n    ${sentencia.replace(/\n/g, '\n    ')};\n  END IF;\nEND\n$sync$`
}

/** Clasifica las sentencias del archivo de una tabla nueva en fases. */
function ddlTablaNueva(nombre, fases) {
  const archivo = path.join(DB, 'tablas', moduloDe(nombre).modulo, `${nombre}.sql`)
  const texto = quitarComentarios(fs.readFileSync(archivo, 'utf8').replace(/\r\n/g, '\n'))
  for (const s of dividir(texto)) {
    const p = plano(s)
    let m
    if (/^CREATE TABLE public\./i.test(p)) fases.tablas.push(s.replace(/^CREATE TABLE /i, 'CREATE TABLE IF NOT EXISTS '))
    else if (/^CREATE SEQUENCE /i.test(p)) fases.tablas.push(s.replace(/^CREATE SEQUENCE /i, 'CREATE SEQUENCE IF NOT EXISTS '))
    else if (/^CREATE (UNIQUE )?INDEX /i.test(p)) fases.tablas.push(s.replace(/^CREATE (UNIQUE )?INDEX /i, (x, u) => `CREATE ${u || ''}INDEX IF NOT EXISTS `))
    else if (/^CREATE TRIGGER /i.test(p)) fases.triggers.push(s.replace(/^CREATE TRIGGER /i, 'CREATE OR REPLACE TRIGGER '))
    else if (/^(ALTER SEQUENCE .* OWNED BY|ALTER TABLE .* ALTER COLUMN \w+ SET DEFAULT|COMMENT ON )/i.test(p)) fases.tablas.push(s)
    else if ((m = p.match(/ALTER COLUMN (\w+) ADD GENERATED/i)))
      fases.tablas.push(guarda(`SELECT 1 FROM pg_attribute WHERE attrelid = 'public.${nombre}'::regclass AND attname = '${m[1]}' AND attidentity <> ''`, s))
    else if ((m = p.match(/ADD CONSTRAINT (\w+) (FOREIGN KEY)?/i)))
      (m[2] ? fases.fks : fases.tablas).push(guarda(`SELECT 1 FROM pg_constraint WHERE conrelid = 'public.${nombre}'::regclass AND conname = '${m[1]}'`, s))
    else throw new Error(`Sentencia no clasificada en ${nombre}: ${p.slice(0, 120)}`)
  }
}

/** Columnas de CREATE TABLE (pg_dump) → Map(nombre → definición). */
function columnas(ddl) {
  const m = ddl.match(/CREATE TABLE public\.\w+ \(\n([\s\S]*?)\n\);/)
  const cols = new Map()
  for (const l of m[1].split('\n')) {
    const t = l.trim().replace(/,$/, '')
    if (!t || /^CONSTRAINT /.test(t)) continue
    cols.set(t.split(/\s+/)[0], t)
  }
  return cols
}

/** Constraints inline de CREATE TABLE (pg_dump) → Map(nombre → definición). */
function constraintsInline(ddl) {
  const m = ddl.match(/CREATE TABLE public\.\w+ \(\n([\s\S]*?)\n\);/)
  const out = new Map()
  for (const l of m[1].split('\n')) {
    const t = l.trim().replace(/,$/, '')
    const c = t.match(/^CONSTRAINT (\w+) /)
    if (c) out.set(c[1], t)
  }
  return out
}

/**
 * Normaliza las dos ortografías equivalentes de pg para IN-lists de CHECK:
 *   (ARRAY['A'::character varying, 'B'::character varying])::text[]
 *   ARRAY[('A'::character varying)::text, ('B'::character varying)::text]
 */
function normalizarDefinicion(def) {
  return plano(def).replace(/\(ARRAY\[([^\]]*)\]\)::text\[\]/g, (x, elems) =>
    `ARRAY[${elems.split(/,\s*/).map((e) => `(${e.trim()})::text`).join(', ')}]`,
  )
}

/** Columnas y constraints presentes en ambas bases deben coincidir (salvo ortografía equivalente). */
function compararDefiniciones(nombre, ddlO, ddlD) {
  for (const [tipo, extraer] of [['columna', columnas], ['constraint', constraintsInline]]) {
    const o = extraer(ddlO)
    const d = extraer(ddlD)
    for (const [k, defO] of o) {
      if (!d.has(k)) continue
      if (normalizarDefinicion(defO) !== normalizarDefinicion(d.get(k))) {
        throw new Error(`Diferencia de ${tipo} no manejada en ${nombre}.${k}:\n  origen:  ${defO}\n  destino: ${d.get(k)}`)
      }
    }
  }
}

/** Lo que tiene `origen` y le falta a `destino` en tablas comunes: columnas, comentarios y triggers. */
function diferenciasTablas(origen, destino, fases, resumen) {
  for (const [nombre, ddlO] of tablas[origen]) {
    const ddlD = tablas[destino].get(nombre)
    if (!ddlD || ddlD === ddlO) continue
    compararDefiniciones(nombre, ddlO, ddlD)
    const colsD = columnas(ddlD)
    const nuevas = [...columnas(ddlO)].filter(([c]) => !colsD.has(c))
    for (const [c, def] of nuevas) {
      fases.tablas.push(`ALTER TABLE public.${nombre}\nADD COLUMN IF NOT EXISTS ${def}`)
      resumen.columnas.push(`${nombre}.${c}`)
      const com = dividir(ddlO).find((s) => s.startsWith(`COMMENT ON COLUMN public.${nombre}.${c} IS`))
      if (com) fases.tablas.push(com)
    }
    const sentD = new Set(dividir(ddlD).map(plano))
    for (const s of dividir(ddlO)) {
      const p = plano(s)
      if (sentD.has(p) || /^(CREATE TABLE|COMMENT ON)/.test(p)) continue
      if (/^CREATE TRIGGER (\w+)/.test(p)) {
        fases.triggers.push(p.replace(/^CREATE TRIGGER /, 'CREATE OR REPLACE TRIGGER '))
        resumen.triggers.push(`${nombre}: ${p.match(/^CREATE TRIGGER (\w+)/)[1]}`)
      } else throw new Error(`Diferencia no manejada en ${nombre}: ${p.slice(0, 160)}`)
    }
  }
}

function sinDescripcion(texto) {
  return texto.replace(/\r\n/g, '\n').replace(/^-- [^\n]*\n/, '').trim()
}

function bloqueFunciones(origen, fases, resumen) {
  const elegidas = decisiones.filter((d) => d.origen === origen || (origen === 'prod' && PENDIENTE_A_DEV_DESDE_PROD.includes(d.nombre)))
  const lenguaje = (d) => (/LANGUAGE sql\b/i.test(d.firmas.map((f) => f.def).join('\n')) ? 1 : 0)
  elegidas.sort((a, b) => lenguaje(a) - lenguaje(b) || a.nombre.localeCompare(b.nombre))
  for (const d of elegidas) {
    const partes = d.firmasObsoletas.map((args) => `DROP FUNCTION IF EXISTS public.${d.nombre}(${args});`)
    if (d.origen === 'pendiente') {
      const firmas = catalogo[origen].funciones.filter((f) => f.nombre === d.nombre)
      partes.push(sinDescripcion(renderFuncion(d.nombre, '', firmas)))
      resumen.firmas += firmas.length
    } else {
      let texto = sinDescripcion(fs.readFileSync(path.join(DB, 'funciones', d.modulo, `${d.nombre}.sql`), 'utf8'))
      // Funciones de trigger: sin DROP (fallaría si el trigger ya existe); CREATE OR REPLACE basta.
      if (d.firmas.every((f) => /\bRETURNS trigger\b/i.test(f.def))) {
        texto = texto.replace(/^DROP FUNCTION IF EXISTS[^;]*;\s*/gm, '')
        resumen.sinDrop.push(d.nombre)
      }
      partes.push(texto)
      resumen.firmas += d.firmas.length
    }
    resumen.obsoletas.push(...d.firmasObsoletas.map((a) => `${d.nombre}(${a})`))
    resumen.funciones.push(d.nombre)
    fases.funciones.push(partes.join('\n\n'))
  }
}

/** Permisos de PROD que DEV no tiene (20260903_doc_salida_permisos y 20261006_permisos_faltantes). */
function permisosFaltantes(origen, destino) {
  const enDestino = new Set(catalogo[destino].seeds.auth_permisos.map((p) => p.nombre))
  const faltan = catalogo[origen].seeds.auth_permisos.filter((p) => !enDestino.has(p.nombre)).sort((a, b) => a.nombre.localeCompare(b.nombre))
  if (!faltan.length) return []
  const lit = (v) => (v == null ? 'NULL' : `'${String(v).replace(/'/g, "''")}'`)
  const valores = faltan.map((p) => `  (${lit(p.nombre)}, ${lit(p.descripcion)})`).join(',\n')
  return [
    "SELECT setval('auth_permisos_id_seq', GREATEST((SELECT MAX(id) FROM auth_permisos), 1))",
    `INSERT INTO auth_permisos (nombre, descripcion)\nSELECT v.nombre, v.descripcion\nFROM (\n  VALUES\n${valores}\n) AS v (nombre, descripcion)\nWHERE NOT EXISTS (SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre)`,
  ].map((s) => ({ s, n: faltan.length }))
}

const DATOS = {
  'prod-desde-dev': () => [
    {
      fuente: '20261026_caja_sesion_evento.sql (backfill de eventos de sesiones existentes)',
      s: `INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario, fecha_hora)
SELECT s.id, v.tipo, v.monto, v.diferencia, v.observacion, v.id_usuario, v.fecha_hora
FROM fin_caja_sesion s
CROSS JOIN LATERAL (
  VALUES
    (1, 'ABRIR', s.monto_inicial, NULL::numeric, s.observacion_apertura, s.id_usuario_apertura, s.fecha_apertura AT TIME ZONE 'America/Lima'),
    (2, 'CERRAR', s.monto_efectivo_contado, s.diferencia, s.observacion_cierre, s.id_usuario_cierre, s.fecha_cierre AT TIME ZONE 'America/Lima')
) AS v (orden, tipo, monto, diferencia, observacion, id_usuario, fecha_hora)
WHERE (v.tipo = 'ABRIR' OR s.fecha_cierre IS NOT NULL)
  AND NOT EXISTS (SELECT 1 FROM fin_caja_sesion_evento e WHERE e.id_sesion = s.id)
ORDER BY s.id, v.orden`,
    },
  ],
  'dev-desde-prod': () => [
    {
      fuente: '20261017_cpe_edicion_segura_pre_emision.sql / 20261017_vsd_correccion_cambio_seguro.sql (opción CAMBIO_VSD)',
      s: `INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT id, 'CAMBIO_VSD', 'Cambio físico de balón de venta sin documento'
FROM gen_lista
WHERE nombre = 'TipoDocumentoRef'
  AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id_lista = gen_lista.id AND nombre = 'CAMBIO_VSD')`,
    },
    ...permisosFaltantes('prod', 'dev').map((x) => ({ fuente: `20260903_doc_salida_permisos.sql + 20261006_permisos_faltantes.sql (${x.n} permisos; valores de catalogo-prod)`, s: x.s })),
  ],
}

function generar(clave, origen, destino, cabecera) {
  const fases = { tablas: [], fks: [], funciones: [], triggers: [] }
  const resumen = { tablasNuevas: [], columnas: [], triggers: [], funciones: [], firmas: 0, obsoletas: [], sinDrop: [], datos: [] }
  for (const t of [...tablas[origen].keys()].filter((t) => !tablas[destino].has(t)).sort()) {
    resumen.tablasNuevas.push(t)
    const antes = fases.triggers.length
    ddlTablaNueva(t, fases)
    for (const tr of fases.triggers.slice(antes)) resumen.triggers.push(`${t}: ${plano(tr).match(/TRIGGER (\w+)/)[1]}`)
  }
  diferenciasTablas(origen, destino, fases, resumen)
  bloqueFunciones(origen, fases, resumen)
  const datos = DATOS[clave]()
  resumen.datos = [...new Set(datos.map((d) => d.fuente))]
  const pendientes = decisiones.filter((d) => d.origen === 'pendiente' && !(origen === 'prod' && PENDIENTE_A_DEV_DESDE_PROD.includes(d.nombre))).map((d) => d.nombre)
  const conPuntoComa = (s) => (s.trimEnd().endsWith(';') ? s.trimEnd() : `${s.trimEnd()};`)
  const cuerpo = [...fases.tablas, ...fases.fks, ...fases.funciones, ...fases.triggers, ...datos.map((d) => d.s)].map(conPuntoComa)
  let texto = [
    ...cabecera.map((l) => `-- ${l}`),
    `-- Funciones pendientes no incluidas (${pendientes.join(', ')}): ver database_sql/.cache/reporte-funciones.md`,
    '',
    'BEGIN;',
    '',
    cuerpo.join('\n\n'),
    '',
    'COMMIT;',
    '',
  ].join('\n')
  const f = formatearSql(texto)
  if (f.ok) texto = f.texto
  else console.warn(`  formato no aplicado (${f.error})`)
  fs.writeFileSync(path.join(MIG, `sync-${clave}.sql`), texto)
  return resumen
}

function main() {
  fs.mkdirSync(MIG, { recursive: true })
  const r1 = generar('prod-desde-dev', 'dev', 'prod', [
    'Lleva a PROD lo elegido de DEV: tablas solo de DEV, funciones con origen dev y datos asociados.',
    'Respaldar la base de PROD antes de aplicarlo.',
    'No ejecutar sin revisión: generado por database_sql/scripts/generar-sync.js.',
  ])
  const r2 = generar('dev-desde-prod', 'prod', 'dev', [
    'Lleva a DEV lo elegido de PROD: tablas y columnas solo de PROD, funciones con origen prod y catálogos asociados.',
    'Respaldar la base de DEV antes de aplicarlo.',
    'No ejecutar sin revisión: generado por database_sql/scripts/generar-sync.js.',
  ])
  console.log(JSON.stringify({ 'sync-prod-desde-dev.sql': r1, 'sync-dev-desde-prod.sql': r2 }, null, 2))
}

if (require.main === module) main()
