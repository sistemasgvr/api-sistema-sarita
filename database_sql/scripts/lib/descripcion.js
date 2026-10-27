/**
 * Descripción de una línea para una función o tabla.
 *
 * Usa `mapa[nombre]` si existe; si no, aplica una regla por verbo CRUD.
 * El verbo puede ir al inicio (`listar_X`) o tras el prefijo de módulo
 * (`gen_listar_X`). X = resto del nombre con `_` → espacio.
 * Sin entrada ni regla → lanza (no se inventa).
 */

const REGLAS = {
  listar: (x) => `Lista ${x} con filtros y paginación`,
  obtener: (x) => `Obtiene ${x} por id`,
  crear: (x) => `Crea ${x}`,
  actualizar: (x) => `Actualiza ${x}`,
  eliminar: (x) => `Elimina (lógicamente) ${x}`,
  restaurar: (x) => `Restaura ${x} eliminado`,
}

function reglaAutomatica(nombre) {
  const partes = nombre.split('_').filter(Boolean)
  for (const i of [0, 1]) {
    const regla = Object.prototype.hasOwnProperty.call(REGLAS, partes[i]) ? REGLAS[partes[i]] : null
    const resto = partes.slice(i + 1)
    if (regla && resto.length) return regla(resto.join(' '))
  }
  return null
}

function descripcionDe(nombre, mapa) {
  if (mapa && Object.prototype.hasOwnProperty.call(mapa, nombre)) return mapa[nombre]
  const auto = reglaAutomatica(nombre)
  if (auto) return auto
  throw new Error(`Sin descripción para "${nombre}": agréguela a descripciones.json`)
}

module.exports = { descripcionDe, reglaAutomatica }
