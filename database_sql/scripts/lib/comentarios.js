/**
 * Quita comentarios SQL (`--` y `/* *\/`, anidables) fuera de literales.
 *
 * Opacos (no se tocan): '...' (con '' y E'..\''), "identificadores",
 * dollar-quotes $tag$...$tag$.
 * Transparente: el cuerpo de la función en el nivel superior ($function$ / $body$,
 * o cualquier dollar-quote precedido por AS / DO). Se recorre por dentro; los
 * dollar-quotes anidados dentro del cuerpo siguen siendo opacos.
 *
 * Formato:
 * - Al quitar `--` se quita también el espacio horizontal previo.
 * - Una línea que queda vacía por haber quitado un comentario se elimina.
 * - Las líneas vacías repetidas (fuera de literales) se colapsan en una.
 */

const TAGS_CUERPO = new Set(['$function$', '$body$'])

function esIdent(ch) {
  return ch !== undefined && /[A-Za-z0-9_$]/.test(ch)
}

function esBlanco(s) {
  return /^[ \t\r]*$/.test(s)
}

/** Salida por líneas: evita indexar un string enorme (lento en V8) al revisar el final. */
class Salida {
  constructor() {
    this.lineas = [] // líneas completas, cada una con su '\n'
    this.linea = '' // línea en curso
  }
  agregar(texto) {
    const partes = texto.split('\n')
    this.linea += partes[0]
    for (let k = 1; k < partes.length; k++) {
      this.lineas.push(this.linea + '\n')
      this.linea = partes[k]
    }
  }
  recortarFinal() {
    this.linea = this.linea.replace(/[ \t]+$/, '')
  }
  lineaEnBlanco() {
    return /^[ \t]*$/.test(this.linea)
  }
  /** La línea en curso está en blanco y la anterior también (o la anterior es el inicio). */
  dosLineasEnBlanco() {
    if (!esBlanco(this.linea) || this.lineas.length === 0) return false
    const previa = this.lineas[this.lineas.length - 1]
    return esBlanco(previa.slice(0, -1))
  }
  cola() {
    const previa = this.lineas.length ? this.lineas[this.lineas.length - 1] : ''
    return (previa + this.linea).slice(-64)
  }
  texto() {
    return this.lineas.join('') + this.linea
  }
}

/** Si el resto de la línea en src desde i es solo espacio, devuelve el índice tras el \n (o fin). */
function finDeLineaVacia(src, i, end) {
  let j = i
  while (j < end && (src[j] === ' ' || src[j] === '\t' || src[j] === '\r')) j++
  if (j >= end) return end
  if (src[j] === '\n') return j + 1
  return -1
}

function palabraPrevia(out) {
  const m = /([A-Za-z]+)\s*$/.exec(out.cola())
  return m ? m[1].toUpperCase() : ''
}

function scan(src, start, end, permitirCuerpo, out) {
  let i = start
  while (i < end) {
    const ch = src[i]
    const sig = i + 1 < end ? src[i + 1] : undefined // nunca mirar más allá del límite

    // Comentario de línea
    if (ch === '-' && sig === '-') {
      let j = i + 2
      while (j < end && src[j] !== '\n') j++
      out.recortarFinal()
      i = j
      if (out.linea.length === 0 && i < end && src[i] === '\n') i++
      continue
    }

    // Comentario de bloque (anidable)
    if (ch === '/' && sig === '*') {
      let depth = 1
      let j = i + 2
      while (j < end && depth > 0) {
        if (src[j] === '/' && j + 1 < end && src[j + 1] === '*') { depth++; j += 2 }
        else if (src[j] === '*' && j + 1 < end && src[j + 1] === '/') { depth--; j += 2 }
        else j++
      }
      i = j
      if (out.lineaEnBlanco()) {
        const k = finDeLineaVacia(src, i, end)
        if (k !== -1) {
          out.recortarFinal()
          i = k
        }
      }
      continue
    }

    // Literal de texto '...'
    if (ch === "'") {
      const conEscape = (src[i - 1] === 'E' || src[i - 1] === 'e') && !esIdent(src[i - 2])
      let j = i + 1
      while (j < end) {
        if (conEscape && src[j] === '\\') { j = Math.min(j + 2, end); continue }
        if (src[j] === "'") {
          if (j + 1 < end && src[j + 1] === "'") { j += 2; continue }
          j++
          break
        }
        j++
      }
      out.agregar(src.slice(i, j))
      i = j
      continue
    }

    // Identificador "..."
    if (ch === '"') {
      let j = i + 1
      while (j < end) {
        if (src[j] === '"') {
          if (j + 1 < end && src[j + 1] === '"') { j += 2; continue }
          j++
          break
        }
        j++
      }
      out.agregar(src.slice(i, j))
      i = j
      continue
    }

    // Dollar-quote
    if (ch === '$' && !esIdent(src[i - 1])) {
      const m = /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/.exec(src.slice(i, Math.min(end, i + 64)))
      if (m) {
        const tag = m[0]
        const iniCuerpo = i + tag.length
        let cierre = src.indexOf(tag, iniCuerpo)
        if (cierre === -1 || cierre + tag.length > end) {
          // Sin cierre: se copia tal cual hasta el final.
          out.agregar(src.slice(i, end))
          i = end
          continue
        }
        const transparente =
          permitirCuerpo && (TAGS_CUERPO.has(tag) || ['AS', 'DO'].includes(palabraPrevia(out)))
        if (transparente) {
          out.agregar(tag)
          scan(src, iniCuerpo, cierre, false, out)
          out.agregar(tag)
        } else {
          out.agregar(src.slice(i, cierre + tag.length))
        }
        i = cierre + tag.length
        continue
      }
    }

    // Salto de línea: colapsar líneas vacías repetidas
    if (ch === '\n') {
      if (out.dosLineasEnBlanco()) out.linea = ''
      else out.agregar('\n')
      i++
      continue
    }

    out.linea += ch
    i++
  }
}

function quitarComentarios(sql) {
  const src = String(sql == null ? '' : sql)
  const out = new Salida()
  scan(src, 0, src.length, true, out)
  return out.texto()
}

module.exports = { quitarComentarios }
