/**
 * Actualiza database_sql/tablas/<modulo>/ desde una base (solo lectura, pg_dump --schema-only).
 *
 *   node database_sql/scripts/sync-tables.js --env dev
 *   node database_sql/scripts/sync-tables.js --env prod --dry-run
 *   node database_sql/scripts/sync-tables.js --env ambos
 *   node database_sql/scripts/sync-tables.js --sin-catalogo
 *
 * Equivale a `catalogo.js --env <env>` + `regenerar-tablas.js` (usa ambas cachés: si el DDL difiere
 * entre DEV y PROD se escribe PROD y se anota en .cache/reporte-tablas.md). Nunca escribe en una base.
 */
const { ejecutarSync } = require('./lib/sync')
const { sanear } = require('./lib/conexion')

try {
  ejecutarSync('sync-tables.js', 'regenerar-tablas.js')
} catch (err) {
  console.error(`Error: ${sanear(err && err.message)}`)
  process.exit(1)
}
