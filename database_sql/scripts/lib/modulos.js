/**
 * Módulo (carpeta) de un objeto de base de datos según el prefijo de su nombre.
 * Prefijo = texto antes del primer "_". Desconocido → general (conocido: false).
 */
const MODULOS = {
  actividades: ['age'],
  activos: ['act'],
  auth: ['auth'],
  balones: ['bal'],
  clientes: ['cli'],
  compras: ['com'],
  dashboard: ['dash'],
  'documentos-salida': ['doc', 'gre'],
  finanzas: ['fin'],
  general: ['gen'],
  inventario: ['inv'],
  personal: ['tra'],
  productos: ['pro'],
  ventas: ['ven'],
}

const PREFIJO_A_MODULO = new Map()
for (const [modulo, prefijos] of Object.entries(MODULOS)) {
  for (const p of prefijos) PREFIJO_A_MODULO.set(p, modulo)
}

function moduloDe(nombre) {
  const limpio = String(nombre || '').trim().toLowerCase().replace(/^public\./, '')
  const i = limpio.indexOf('_')
  const prefijo = i > 0 ? limpio.slice(0, i) : limpio
  const modulo = PREFIJO_A_MODULO.get(prefijo)
  return modulo ? { modulo, conocido: true } : { modulo: 'general', conocido: false }
}

module.exports = { MODULOS, moduloDe }

/**
 * Orden de aplicación de módulos al reconstruir el esquema (dependencias aproximadas:
 * general y auth primero, ventas y dashboard al final). Módulos no listados van al final.
 */
const ORDEN_MODULOS = [
  'general',
  'auth',
  'productos',
  'inventario',
  'clientes',
  'balones',
  'compras',
  'finanzas',
  'personal',
  'actividades',
  'activos',
  'documentos-salida',
  'ventas',
  'dashboard',
]

function indiceModulo(modulo) {
  const i = ORDEN_MODULOS.indexOf(modulo)
  return i === -1 ? ORDEN_MODULOS.length : i
}

module.exports.ORDEN_MODULOS = ORDEN_MODULOS
module.exports.indiceModulo = indiceModulo
