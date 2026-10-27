/**
 * Renderiza el archivo .sql de una función: descripción en la primera línea y,
 * por cada firma, su DROP exacto seguido de la definición sin comentarios.
 * Firma = { args, def, kind? } (kind 'p' = procedimiento).
 */
const { quitarComentarios } = require('./comentarios')

function renderFuncion(nombre, descripcion, firmas) {
  const partes = []
  const desc = String(descripcion || '').replace(/\s+/g, ' ').trim()
  for (const f of firmas) {
    const tipo = f.kind === 'p' ? 'PROCEDURE' : 'FUNCTION'
    let def = quitarComentarios(f.def).trim()
    if (!def.endsWith(';')) def += ';'
    partes.push(`DROP ${tipo} IF EXISTS public.${nombre}(${f.args});\n\n${def}\n`)
  }
  return (desc ? `-- ${desc}\n` : '') + partes.join('\n')
}

module.exports = { renderFuncion }
