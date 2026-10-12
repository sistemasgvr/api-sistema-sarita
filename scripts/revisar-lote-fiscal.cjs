// Por defecto solo lectura. --descartar-preparacion cambia únicamente los borradores
// de este lote, si no existe ningún intento de envío. Nunca modifica las ventas.
require('ts-node/register/transpile-only');
const fs = require('node:fs');
const path = require('node:path');
const { ConfigService } = require('@nestjs/config');
const { DatabaseService } = require('../src/database/database.service');
const env = require('dotenv').parse(fs.readFileSync(path.join(__dirname, '../.env')));
const db = new DatabaseService(new ConfigService({ database: { url: env.DATABASE_URL } }));
async function main() {
  const loteId = '6e066593-30f9-4730-ace0-47f40ede5227';
  if (process.argv.includes('--descartar-preparacion')) {
    await db.withTransaction(async () => {
      const lote = (await db.query('SELECT estado FROM ven_cpe_correccion_lote WHERE id=$1 FOR UPDATE', [loteId])).rows[0];
      if (!lote) throw new Error('No existe el lote');
      if (lote.estado === 'DESCARTADO_SOLO_ORDEN_VENTAS') return;
      if (lote.estado !== 'PREPARADO') throw new Error('El lote ya salió de preparación; requiere revisión');
      const notas = (await db.query('SELECT id,estado,cdr_respuesta FROM ven_cpe_correccion_nota WHERE id_lote=$1 FOR UPDATE', [loteId])).rows;
      if (notas.length !== 6 || notas.some(n => n.estado !== 'PREPARADO' || n.cdr_respuesta)) throw new Error('Existen notas con actividad fiscal');
      const intentos = (await db.query(`SELECT COUNT(*)::int AS cantidad FROM ven_cpe_correccion_intento i
        JOIN ven_cpe_correccion_nota n ON n.id=i.id_nota WHERE n.id_lote=$1`, [loteId])).rows[0].cantidad;
      if (intentos !== 0) throw new Error('Hay intentos de envío; no se puede descartar como borrador');
      await db.query("UPDATE ven_cpe_correccion_nota SET estado='DESCARTADO_NO_EMITIDO',actualizado_en=NOW() WHERE id_lote=$1", [loteId]);
      await db.query("UPDATE ven_cpe_correccion_lote SET estado='DESCARTADO_SOLO_ORDEN_VENTAS',motivo=$2,actualizado_en=NOW() WHERE id=$1", [loteId,
        'Usuario confirmó que el único motivo es ordenar por fecha de venta. Los CPE aceptados tienen fecha fiscal 12/10/2026; no se identificó una causal para NC. Se conserva el plan como evidencia no aplicada.']);
    });
  }
  const result = await db.query(`
    SELECT l.id, l.estado, l.fecha_fiscal::text,
      jsonb_array_length(l.plan) AS documentos_propuestos,
      (SELECT COUNT(*)::int FROM ven_cpe_correccion_nota n WHERE n.id_lote=l.id) AS notas_preparadas,
      (SELECT COUNT(*)::int FROM ven_cpe_correccion_intento i
        JOIN ven_cpe_correccion_nota n ON n.id=i.id_nota WHERE n.id_lote=l.id) AS intentos_envio_notas,
      (SELECT COUNT(*)::int FROM ven_cpe_correccion_nota n
        WHERE n.id_lote=l.id AND n.cdr_respuesta IS NOT NULL) AS notas_con_respuesta,
      (SELECT COUNT(*)::int FROM jsonb_array_elements(l.plan) p
        JOIN ven_comprobante c ON c.id=(p->>'id')::int
        WHERE c.serie=p->>'serie' AND c.numero=p->>'numeroNuevo') AS referencias_propuestas_aplicadas
    FROM ven_cpe_correccion_lote l WHERE l.id=$1`, [loteId]);
  if (result.rows.length !== 1) throw new Error('No se encontró el lote preparado');
  const output = { revisadoEn: new Date().toISOString(), soloLectura: !process.argv.includes('--descartar-preparacion'), ...result.rows[0] };
  fs.writeFileSync(path.join(__dirname, '../../diagnosticos/reordenamiento-fiscal-20261012/estado-verificado.json'), JSON.stringify(output, null, 2));
  console.log(JSON.stringify(output));
}
main().catch(error => { console.error(error.message); process.exitCode=1; }).finally(() => db.onModuleDestroy());
