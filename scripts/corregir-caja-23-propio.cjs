// Por defecto valida en una copia temporal. --apply aplica el ajuste autorizado.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { Client } = require('pg');
const root = path.resolve(__dirname, '..');
const apply = process.argv.includes('--apply');
const raw = fs.readFileSync(path.join(root, '.env'), 'utf8');
const entry = [...raw.matchAll(/^\s*#?\s*DATABASE_URL(?:_DEV|_PROD)?\s*=\s*["']?([^\s"']+)/gm)]
  .find((m) => m[1].includes('ebotjjfdgcuwrfoappsa'));
if (!entry) throw new Error('No se encontro la configuracion de produccion');
const db = new Client({ connectionString: entry[1], ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000, options: '-c statement_timeout=15000 -c lock_timeout=5000' });

async function main() {
  await db.connect();
  try {
    await db.query('BEGIN');
    await db.query("SET LOCAL TIME ZONE 'America/Lima'");
    const before = (await db.query('SELECT * FROM public.fin_caja_sesion WHERE id=23 FOR UPDATE')).rows[0];
    const events = (await db.query('SELECT * FROM public.fin_caja_sesion_evento WHERE id_sesion=23 ORDER BY id')).rows;
    let sql = fs.readFileSync(path.join(root, 'database_sql/correcciones/20261031_caja_23_propio_sr_gc.sql'), 'utf8')
      .replace(/^BEGIN;\s*$/m, '').replace(/^COMMIT;\s*$/m, '');
    let table = 'public.fin_caja_sesion';
    let backup;
    if (apply) {
      const folder = path.join(root, '.tmp', 'correccion-caja-23');
      fs.mkdirSync(folder, { recursive: true });
      backup = path.join(folder, `antes-${Date.now()}.json`);
      fs.writeFileSync(backup, JSON.stringify({ sesion: before, eventos: events }, null, 2), { flag: 'wx' });
    } else {
      await db.query('CREATE TEMP TABLE prueba_caja_sesion ON COMMIT DROP AS SELECT * FROM public.fin_caja_sesion WHERE id=23');
      table = 'pg_temp.prueba_caja_sesion';
      sql = sql.replaceAll('public.fin_caja_sesion', table);
    }
    await db.query(sql);
    const after = (await db.query(`SELECT * FROM ${table} WHERE id=23`)).rows[0];
    assert.equal(Number(after.monto_esperado), 4052.10);
    assert.equal(Number(after.monto_efectivo_contado), 4052.10);
    assert.equal(Number(after.diferencia), 0);
    assert.ok(after.observacion_cierre.startsWith(before.observacion_cierre + '\n'));
    for (const key of Object.keys(before)) {
      if (!['totales_cierre','monto_esperado','diferencia','observacion_cierre','fecha_modificacion'].includes(key))
        assert.deepEqual(after[key], before[key], key);
    }
    assert.deepEqual((await db.query('SELECT * FROM public.fin_caja_sesion_evento WHERE id_sesion=23 ORDER BY id')).rows, events);
    const cash = after.totales_cierre.porMedio.find((m) => m.idMedioPago === 198);
    const propio = after.totales_cierre.porMedio.find((m) => m.idMedioPago === 441);
    assert.equal(cash.gastos, 34);
    assert.equal(propio.gastos, 1300);
    assert.equal(after.totales_cierre.porMedio.reduce((n,m) => n + Number(m.gastos), 0), 1576);
    if (apply) {
      const result = (await db.query("SELECT public.fin_obtener_caja_dia('2026-10-30',1) resultado")).rows[0].resultado.registro;
      assert.equal(result.efectivoEsperado, 4052.10);
      assert.equal(result.diferencia, 0);
      assert.deepEqual(result.totales, after.totales_cierre);
      fs.writeFileSync(backup.replace('antes-', 'despues-'), JSON.stringify({ sesion: after }, null, 2), { flag: 'wx' });
      await db.query('COMMIT');
    } else {
      await db.query('ROLLBACK');
    }
    console.log(JSON.stringify({ aplicado: apply, pruebaTemporal: !apply, backup,
      gastosPropio: propio.gastos, gastosEfectivo: cash.gastos,
      ventasEfectivo: cash.ventas, efectivoEsperado: Number(after.monto_esperado),
      contado: Number(after.monto_efectivo_contado), diferencia: Number(after.diferencia),
      eventosOriginalesConservados: true, explicacionGuardada: apply }));
  } catch (error) {
    await db.query('ROLLBACK');
    throw error;
  } finally {
    await db.end();
  }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
