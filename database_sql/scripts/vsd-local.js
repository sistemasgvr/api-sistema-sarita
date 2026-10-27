// Intentionally fixed to the task's local Docker DB. Never reads .env.
// Modos: test <archivo.sql> | snapshot [nombre.json].
// Los modos apply/apply-cpe (escribían migraciones/20261017_*.sql) se eliminaron el 2026-10-27.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const base = path.resolve(__dirname, '..');
function query(sql) {
  const r = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local', 'psql', '-X', '-U', 'supabase_admin', '-d', 'sarita_vsd_20261017', '-v', 'ON_ERROR_STOP=1', '-At'],
    { input: sql, encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(r.stderr || r.error?.message || 'Local SQL failed');
  return r.stdout;
}
const mode = process.argv[2];
if (mode === 'test') {
  console.log(query(fs.readFileSync(path.resolve(process.argv[3]), 'utf8')));
} else if (mode === 'snapshot') {
  const tables = ['ven_comprobante','ven_comprobante_detalle','bal_balon','pro_stock','inv_movimiento','bal_prestamo','bal_prestamo_detalle','bal_movimiento_recarga','ven_garantia','ven_comprobante_pago','fin_cuenta'];
  const snapshots = tables.map(t => JSON.parse(query(`SELECT json_build_object('table','${t}','rows',count(*),'hash',md5(COALESCE(string_agg(row_to_json(x)::text, E'\n' ORDER BY row_to_json(x)::text),''))) FROM ${t} x;`).trim()));
  const output = path.resolve(base, '../../outputs/ventas-seguras', process.argv[3] || 'snapshot.json');
  fs.writeFileSync(output, JSON.stringify(snapshots, null, 2));
  console.log(JSON.stringify(snapshots));
} else throw new Error('Use test archivo.sql | snapshot nombre.json');
