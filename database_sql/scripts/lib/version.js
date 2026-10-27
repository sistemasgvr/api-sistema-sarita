/**
 * Elige qué versión de una función (conjunto de firmas) va al repo.
 * Firma = { args: string, def: string }
 *
 * - Solo en una base → esa base.
 * - En ambas e iguales (cuerpos normalizados por firma) → 'ambas'.
 * - Difieren: si algún cuerpo del repo coincide con una firma de DEV → 'dev';
 *   si coincide con PROD → 'prod'; si ninguno → 'pendiente' (firmas de PROD como referencia).
 * - firmasObsoletas = args de la otra base ausentes en la elegida.
 *
 * Línea base opcional (`base` = decisión anterior { origen, firmas } de .cache/decisiones-funciones.json):
 * solo se usa si la decisión anterior fue 'ambas' (sus firmas son el último cuerpo conocido de las
 * dos bases). Si ahora DEV ≠ PROD:
 *   - solo DEV cambió respecto de la base → 'dev'
 *   - solo PROD cambió → 'prod'
 *   - cambiaron las dos → 'pendiente'
 * Sin base (o base no 'ambas') → regla de coincidencia con el repo de arriba.
 */
const { quitarComentarios } = require('./comentarios')

function normalizarCuerpo(def) {
  return quitarComentarios(def).replace(/\s+/g, '').toLowerCase()
}

function normArgs(args) {
  return String(args || '').replace(/\s+/g, ' ').trim()
}

function mapa(firmas) {
  const m = new Map()
  for (const f of firmas) m.set(normArgs(f.args), normalizarCuerpo(f.def))
  return m
}

function iguales(a, b) {
  const ma = mapa(a)
  const mb = mapa(b)
  if (ma.size !== mb.size) return false
  for (const [k, v] of ma) if (mb.get(k) !== v) return false
  return true
}

function obsoletas(elegidas, otras) {
  const presentes = new Set(elegidas.map((f) => normArgs(f.args)))
  return otras.filter((f) => !presentes.has(normArgs(f.args))).map((f) => f.args)
}

function elegirVersion({ dev, prod, repoCuerpos = new Set(), base = null }) {
  const hayDev = Array.isArray(dev) && dev.length > 0
  const hayProd = Array.isArray(prod) && prod.length > 0
  if (!hayDev && !hayProd) throw new Error('elegirVersion: la función no existe en DEV ni en PROD')
  if (hayDev && !hayProd) return { origen: 'dev', firmas: dev, firmasObsoletas: [] }
  if (hayProd && !hayDev) return { origen: 'prod', firmas: prod, firmasObsoletas: [] }

  if (iguales(dev, prod)) return { origen: 'ambas', firmas: dev, firmasObsoletas: [] }

  if (base && base.origen === 'ambas' && Array.isArray(base.firmas) && base.firmas.length) {
    const cambioDev = !iguales(dev, base.firmas)
    const cambioProd = !iguales(prod, base.firmas)
    if (cambioDev && !cambioProd) return { origen: 'dev', firmas: dev, firmasObsoletas: obsoletas(dev, prod) }
    if (cambioProd && !cambioDev) return { origen: 'prod', firmas: prod, firmasObsoletas: obsoletas(prod, dev) }
    return { origen: 'pendiente', firmas: prod, firmasObsoletas: obsoletas(prod, dev) }
  }

  const coincide = (firmas) => firmas.some((f) => repoCuerpos.has(normalizarCuerpo(f.def)))
  if (coincide(dev)) return { origen: 'dev', firmas: dev, firmasObsoletas: obsoletas(dev, prod) }
  if (coincide(prod)) return { origen: 'prod', firmas: prod, firmasObsoletas: obsoletas(prod, dev) }
  return { origen: 'pendiente', firmas: prod, firmasObsoletas: obsoletas(prod, dev) }
}

module.exports = { elegirVersion, normalizarCuerpo }
