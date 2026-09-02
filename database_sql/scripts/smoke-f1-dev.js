const { Client } = require('pg')
const fs = require('fs')
const path = require('path')

function loadActiveUrl() {
  const raw = fs.readFileSync(path.join(__dirname, '../../.env'), 'utf8')
  for (const line of raw.split(/\r?\n/)) {
    const t = line.trim()
    if (t.startsWith('DATABASE_URL=')) return t.slice('DATABASE_URL='.length).trim()
  }
  throw new Error('no DATABASE_URL')
}

async function main() {
  const c = new Client({
    connectionString: loadActiveUrl(),
    ssl: { rejectUnauthorized: false },
  })
  await c.connect()

  const checks = [
    ['inv_movimiento', `SELECT to_regclass('public.inv_movimiento') IS NOT NULL AS ok`],
    ['pro_movimientos gone', `SELECT to_regclass('public.pro_movimientos') IS NULL AS ok`],
    ['bal_movimiento gone', `SELECT to_regclass('public.bal_movimiento') IS NULL AS ok`],
    ['inv_registrar', `SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='inv_registrar_movimiento') AS ok`],
    ['inv_revertir', `SELECT EXISTS(SELECT 1 FROM pg_proc WHERE proname='inv_revertir_por_documento') AS ok`],
    ['no contenido col', `SELECT NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name='bal_balon' AND column_name='id_estado_contenido') AS ok`],
  ]
  for (const [label, sql] of checks) {
    const r = await c.query(sql)
    console.log(r.rows[0].ok ? 'OK' : 'FAIL', label)
  }

  try {
    const r = await c.query(
      `SELECT inv_listar_movimientos($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) AS j`,
      ['', 5, 0, null, null, null, null, null, null, null, null, null],
    )
    console.log('OK call inv_listar', JSON.stringify(r.rows[0].j).slice(0, 120))
  } catch (e) {
    console.log('FAIL call inv_listar', e.message)
  }

  try {
    const r = await c.query(`SELECT bal_listar_stock_gas($1,$2,$3,$4,$5) AS j`, [
      '',
      5,
      0,
      null,
      null,
    ])
    console.log('OK call stock_gas', JSON.stringify(r.rows[0].j).slice(0, 160))
  } catch (e) {
    console.log('FAIL call stock_gas', e.message)
  }

  await c.end()
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})
