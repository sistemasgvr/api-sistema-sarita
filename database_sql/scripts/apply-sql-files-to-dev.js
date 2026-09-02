/**
 * Aplica un conjunto de .sql a la DATABASE_URL activa (dev).
 * Uso: node database_sql/scripts/apply-sql-files-to-dev.js [file...]
 * Sin args: aplica lista F1 de limpieza + seeds inventario.
 */
const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

function loadActiveUrl() {
  const raw = fs.readFileSync(path.join(__dirname, '../../.env'), 'utf8')
  for (const line of raw.split(/\r?\n/)) {
    const t = line.trim()
    if (t.startsWith('DATABASE_URL=')) return t.slice('DATABASE_URL='.length).trim()
  }
  throw new Error('DATABASE_URL activa no encontrada')
}

const DEFAULT_FILES = [
  'database_sql/funciones/comprobantes/ven_revertir_efectos_comprobante.sql',
  'database_sql/funciones/recargas-planta/bal_actualizar_recarga_planta.sql',
  'database_sql/funciones/compras/com_revertir_cilindros_recarga_compra.sql',
  'database_sql/funciones/movimientos-recarga/bal_eliminar_movimiento_recarga.sql',
  'database_sql/funciones/balones/bal_listar_balones.sql',
  'database_sql/funciones/balones/bal_eliminar_balon.sql',
  'database_sql/funciones/recojos/bal_registrar_resultado_recojo.sql',
  'database_sql/funciones/balones/bal_listar_stock_gas.sql',
  'database_sql/seeds/inv_permisos_banderas.sql',
]

async function main() {
  const root = path.join(__dirname, '../..')
  const args = process.argv.slice(2)
  const files = (args.length ? args : DEFAULT_FILES).map((f) =>
    path.isAbsolute(f) ? f : path.join(root, f),
  )
  const url = loadActiveUrl()
  const hint = (() => {
    try {
      return new URL(url).hostname.split('.')[0]
    } catch {
      return 'dev'
    }
  })()
  console.log('TARGET_DEV', hint)
  console.log('FILES', files.length)

  const client = new Client({
    connectionString: url,
    ssl: { rejectUnauthorized: false },
    statement_timeout: 180000,
  })
  await client.connect()

  let ok = 0
  const failed = []
  for (const file of files) {
    const rel = path.relative(root, file)
    if (!fs.existsSync(file)) {
      failed.push({ file: rel, message: 'missing file' })
      console.warn('MISS', rel)
      continue
    }
    let sql = fs.readFileSync(file, 'utf8')
    if (sql.charCodeAt(0) === 0xfeff) sql = sql.slice(1)
    try {
      await client.query(sql)
      ok++
      console.log('OK', rel)
    } catch (e) {
      failed.push({ file: rel, message: e.message })
      console.warn('FAIL', rel, e.message)
    }
  }

  await client.end()
  console.log(`Done ok=${ok} failed=${failed.length}`)
  if (failed.length) process.exitCode = 1
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
