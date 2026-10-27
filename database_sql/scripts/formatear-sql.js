/**
 * Aplica el formato SQL común (lib/formato.js) a database_sql/funciones, tablas y seeds.
 * Re-ejecutable: solo reescribe los archivos cuyo texto cambia. Nunca altera literales,
 * cuerpos dollar-quoted ni comentarios (si el formato no es equivalente, deja el archivo igual).
 *
 * Uso: npm run format:sql   (o: node database_sql/scripts/formatear-sql.js [dir...])
 */
const fs = require('fs')
const path = require('path')
const { formatearSql } = require('./lib/formato')

const DB = path.join(__dirname, '..')
const DIRS = process.argv.slice(2).length ? process.argv.slice(2) : ['funciones', 'tablas', 'seeds']

function listarSql(dir) {
  if (!fs.existsSync(dir)) return []
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) return listarSql(p)
    return e.name.endsWith('.sql') ? [p] : []
  })
}

let total = 0
let cambiados = 0
const fallos = []
for (const d of DIRS) {
  for (const archivo of listarSql(path.resolve(DB, d))) {
    total++
    const antes = fs.readFileSync(archivo, 'utf8')
    const r = formatearSql(antes)
    if (!r.ok) {
      fallos.push(`${path.relative(DB, archivo)}: ${r.error}`)
      continue
    }
    if (r.texto !== antes) {
      fs.writeFileSync(archivo, r.texto)
      cambiados++
    }
  }
}
console.log(`Archivos: ${total}, reformateados: ${cambiados}, sin formatear: ${fallos.length}`)
for (const f of fallos) console.log(`  ${f}`)
if (fallos.length) process.exitCode = 1
