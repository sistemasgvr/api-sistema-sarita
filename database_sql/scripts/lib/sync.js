/**
 * Flujo común de sync-functions.js / sync-tables.js:
 *   1. catalogo.js --env <env> (lectura de solo lectura; refresca .cache/catalogo-<env>.json)
 *   2. regenerar-<tipo>.js [--dry-run] (combina DEV y PROD desde las cachés; no se conecta)
 *
 * regenerar-* siempre necesita las DOS cachés (la regla de versión compara DEV, PROD y repo),
 * así que --env solo decide qué caché se refresca; la otra debe existir. --env ambos refresca las dos.
 * Nunca escribe en una base.
 */
const { spawnSync } = require('child_process')
const fs = require('fs')
const path = require('path')

const SCRIPTS = path.join(__dirname, '..')
const CACHE = path.join(SCRIPTS, '..', '.cache')

function opciones(argv, uso) {
  const i = argv.indexOf('--env')
  const env = i !== -1 ? argv[i + 1] : null
  const sinCatalogo = argv.includes('--sin-catalogo')
  if (!sinCatalogo && !['dev', 'prod', 'ambos'].includes(env)) throw new Error(uso)
  return { envs: sinCatalogo ? [] : env === 'ambos' ? ['dev', 'prod'] : [env], dryRun: argv.includes('--dry-run') }
}

function correr(script, args) {
  console.log(`\n> node database_sql/scripts/${script} ${args.join(' ')}`.trimEnd())
  const r = spawnSync(process.execPath, [path.join(SCRIPTS, script), ...args], { stdio: 'inherit' })
  if (r.error) throw r.error
  if (r.status !== 0) throw new Error(`${script} terminó con código ${r.status}`)
}

function ejecutarSync(script, regenerar, argv = process.argv.slice(2)) {
  const uso = `Uso: node database_sql/scripts/${script} --env dev|prod|ambos [--dry-run]  |  --sin-catalogo [--dry-run]`
  const { envs, dryRun } = opciones(argv, uso)
  for (const env of envs) correr('catalogo.js', ['--env', env])
  for (const env of ['dev', 'prod']) {
    if (!fs.existsSync(path.join(CACHE, `catalogo-${env}.json`))) {
      throw new Error(`Falta .cache/catalogo-${env}.json: ejecuta antes "node database_sql/scripts/catalogo.js --env ${env}" (o usa --env ambos)`)
    }
  }
  correr(regenerar, dryRun ? ['--dry-run'] : [])
}

module.exports = { ejecutarSync, opciones }
