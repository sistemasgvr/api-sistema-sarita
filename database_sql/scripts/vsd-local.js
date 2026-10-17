// Intentionally fixed to the task's local Docker DB. Never reads .env.
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
if (mode === 'apply' || mode === 'apply-cpe') {
  const files = ['tablas/ventas/ven_vsd_operacion.sql', 'funciones/comprobantes/ven_validar_edicion_pre_emision.sql', 'funciones/comprobantes/ven_actualizar_comprobante.sql',
    'funciones/comprobantes/ven_obtener_comprobante.sql', 'funciones/comprobantes/ven_cantidad_gas_balon_vsd.sql', 'funciones/comprobantes/ven_cambiar_balon_vsd.sql',
    'funciones/comprobantes/ven_eliminar_comprobante.sql', 'funciones/comprobantes/ven_revertir_efectos_comprobante.sql', 'funciones/comprobantes/ven_crear_comprobante.sql'];
  const catalog = `INSERT INTO gen_lista_opciones(id_lista,nombre,descripcion)
    SELECT id,'CAMBIO_VSD','Cambio físico de balón de venta sin documento' FROM gen_lista WHERE nombre='TipoDocumentoRef'
      AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id_lista=gen_lista.id AND nombre='CAMBIO_VSD');`;
  const migration = 'BEGIN;\n' + files.map(f => fs.readFileSync(path.join(base, f), 'utf8')).join('\n') + '\n' + catalog + '\nCOMMIT;\n';
  fs.writeFileSync(path.join(base, mode === 'apply-cpe' ? 'migraciones/20261017_cpe_edicion_segura_pre_emision.sql' : 'migraciones/20261017_vsd_correccion_cambio_seguro.sql'), migration);
  console.log(query(migration));
} else if (mode === 'test') {
  console.log(query(fs.readFileSync(path.resolve(process.argv[3]), 'utf8')));
} else if (mode === 'snapshot') {
  const tables = ['ven_comprobante','ven_comprobante_detalle','bal_balon','pro_stock','inv_movimiento','bal_prestamo','bal_prestamo_detalle','bal_movimiento_recarga','ven_garantia','ven_comprobante_pago','fin_cuenta'];
  const snapshots = tables.map(t => JSON.parse(query(`SELECT json_build_object('table','${t}','rows',count(*),'hash',md5(COALESCE(string_agg(row_to_json(x)::text, E'\n' ORDER BY row_to_json(x)::text),''))) FROM ${t} x;`).trim()));
  const output = path.resolve(base, '../../outputs/ventas-seguras', process.argv[3] || 'snapshot.json');
  fs.writeFileSync(output, JSON.stringify(snapshots, null, 2));
  console.log(JSON.stringify(snapshots));
} else throw new Error('Use apply | test archivo.sql | snapshot nombre.json');
