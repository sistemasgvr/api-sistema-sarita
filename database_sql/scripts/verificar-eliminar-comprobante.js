// Prueba las funciones nuevas en desarrollo y revierte TODO al finalizar.
const fs = require('fs');
const { Client } = require('pg');
async function main() {
  const line = fs.readFileSync('.env', 'utf8').split(/\r?\n/).find(l => l.startsWith('DATABASE_URL='));
  const client = new Client({ connectionString: line.slice(13).trim(), ssl: { rejectUnauthorized: false } });
  await client.connect();
  try {
    await client.query('BEGIN');
    const sql = fs.readFileSync('database_sql/migraciones/20261007_eliminar_comprobante_atomico.sql', 'utf8');
    await client.query(sql.replace(/^BEGIN;$/m, '').replace(/^COMMIT;$/m, ''));
    const rows = (await client.query("select c.id from ven_comprobante c left join gen_lista_opciones es on es.id=c.id_estado_sunat where c.estado=1 and coalesce(es.nombre,'') not in ('ACEPTADO','BAJA') order by c.id desc limit 5")).rows;
    for (const { id } of rows) {
      await client.query('SAVEPOINT caso');
      const snapshot = async () => JSON.stringify((await client.query(`select
        (select jsonb_agg(to_jsonb(s) order by id) from pro_stock s) stocks,
        (select jsonb_agg(to_jsonb(b) order by id) from bal_balon b) balones,
        (select jsonb_agg(to_jsonb(m) order by id) from inv_movimiento m) movimientos`)).rows);
      const before = await snapshot();
      const result = (await client.query('select ven_eliminar_comprobante($1) r', [id])).rows[0].r;
      if (result.eliminado) {
        const state = (await client.query('select estado from ven_comprobante where id=$1', [id])).rows[0].estado;
        if (state !== 0) throw new Error('La baja no cambió estado a 0');
        const after = await snapshot();
        const second = (await client.query('select ven_eliminar_comprobante($1) r', [id])).rows[0].r;
        if (second.eliminado) throw new Error('La segunda eliminación no es idempotente');
        if (await snapshot() !== after) throw new Error('La segunda eliminación modificó el inventario');
      } else if (await snapshot() !== before) {
        throw new Error('Una eliminación fallida modificó el inventario');
      }
      console.log(JSON.stringify({ id, ...result }));
      await client.query('ROLLBACK TO SAVEPOINT caso');
    }
  } finally {
    await client.query('ROLLBACK');
    await client.end();
  }
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });
