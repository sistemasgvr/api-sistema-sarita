/**
 * Actualiza database_sql/funciones/<modulo>/ desde una base (solo lectura).
 *
 *   node database_sql/scripts/sync-functions.js --env dev          # refresca caché DEV y regenera
 *   node database_sql/scripts/sync-functions.js --env prod --dry-run
 *   node database_sql/scripts/sync-functions.js --env ambos         # refresca DEV y PROD
 *   node database_sql/scripts/sync-functions.js --sin-catalogo      # solo regenera desde las cachés
 *
 * Equivale a `catalogo.js --env <env>` + `regenerar-funciones.js`. La versión elegida por función
 * sigue la regla de lib/version.js (DEV vs PROD vs repo), por eso hacen falta ambas cachés.
 * Reporte: database_sql/.cache/reporte-funciones.md. Nunca escribe en una base.
 */
const { ejecutarSync } = require('./lib/sync')
const { sanear } = require('./lib/conexion')

try {
  ejecutarSync('sync-functions.js', 'regenerar-funciones.js')
} catch (err) {
  console.error(`Error: ${sanear(err && err.message)}`)
  process.exit(1)
}
