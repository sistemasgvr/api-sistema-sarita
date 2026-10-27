/**
 * Formato SQL común (sql-formatter, postgresql, palabras clave en mayúsculas).
 *
 * Seguridad: tras formatear se comprueba que el texto es equivalente al original:
 * - literales '...', identificadores "..." y dollar-quotes ($function$...$function$)
 *   idénticos byte a byte (el cuerpo de las funciones nunca cambia);
 * - comentarios idénticos (sin espacios a los extremos);
 * - el resto igual salvo espacios y mayúsculas/minúsculas.
 * Si no se puede formatear o la comprobación falla, se devuelve el texto original
 * con `ok: false` (nunca se escribe algo que no sea equivalente).
 */
const { format } = require('sql-formatter')

const OPCIONES = { language: 'postgresql', keywordCase: 'upper' }

/** Divide en piezas: { t: 'lit'|'com'|'cod', v }. */
function piezas(src) {
  const out = []
  let cod = ''
  const flush = () => {
    if (cod) out.push({ t: 'cod', v: cod })
    cod = ''
  }
  let i = 0
  const n = src.length
  while (i < n) {
    const ch = src[i]
    const sig = src[i + 1]
    if (ch === '-' && sig === '-') {
      let j = src.indexOf('\n', i)
      if (j === -1) j = n
      flush()
      out.push({ t: 'com', v: src.slice(i, j).trim() })
      i = j
      continue
    }
    if (ch === '/' && sig === '*') {
      let depth = 1
      let j = i + 2
      while (j < n && depth > 0) {
        if (src[j] === '/' && src[j + 1] === '*') { depth++; j += 2 }
        else if (src[j] === '*' && src[j + 1] === '/') { depth--; j += 2 }
        else j++
      }
      flush()
      out.push({ t: 'com', v: src.slice(i, j).trim() })
      i = j
      continue
    }
    if (ch === "'" || ch === '"') {
      const conEscape = ch === "'" && /[Ee]/.test(src[i - 1] || '') && !/[A-Za-z0-9_]/.test(src[i - 2] || '')
      let j = i + 1
      while (j < n) {
        if (conEscape && src[j] === '\\') { j += 2; continue }
        if (src[j] === ch) {
          if (src[j + 1] === ch) { j += 2; continue }
          j++
          break
        }
        j++
      }
      flush()
      out.push({ t: 'lit', v: src.slice(i, j) })
      i = j
      continue
    }
    if (ch === '$' && !/[A-Za-z0-9_$]/.test(src[i - 1] || '')) {
      const m = /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/.exec(src.slice(i, i + 64))
      if (m) {
        const c = src.indexOf(m[0], i + m[0].length)
        const j = c === -1 ? n : c + m[0].length
        flush()
        out.push({ t: 'lit', v: src.slice(i, j) })
        i = j
        continue
      }
    }
    cod += ch
    i++
  }
  flush()
  return out
}

/** Firma comparable: literales y comentarios exactos; código sin espacios y en minúsculas. */
function firma(src) {
  const res = []
  let cod = ''
  for (const p of piezas(src)) {
    if (p.t === 'cod') { cod += p.v.replace(/\s+/g, '').toLowerCase(); continue }
    if (cod) res.push('C:' + cod)
    cod = ''
    res.push((p.t === 'lit' ? 'L:' : 'K:') + p.v)
  }
  if (cod) res.push('C:' + cod)
  return res.join('\u0000')
}

function equivalentes(a, b) {
  return firma(a) === firma(b)
}

/** Formatea un archivo SQL completo. Devuelve { texto, ok, error? }. */
function formatearSql(sql) {
  const original = String(sql).replace(/\r\n/g, '\n')
  let texto
  try {
    texto = format(original, OPCIONES).trimEnd() + '\n'
  } catch (e) {
    return { texto: original, ok: false, error: String(e.message || e).split('\n')[0] }
  }
  if (!equivalentes(original, texto)) {
    return { texto: original, ok: false, error: 'el formato alteraría literales, comentarios o código' }
  }
  return { texto, ok: true }
}

module.exports = { formatearSql, equivalentes, OPCIONES }
