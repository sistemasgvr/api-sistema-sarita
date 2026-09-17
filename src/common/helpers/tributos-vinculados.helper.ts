import { DatabaseService } from '../../database/database.service';
import { AuthSingleResult } from '../interfaces/auth-db.interface';

/**
 * Percepciones (sobre comprobantes de venta) y retenciones (sobre compras)
 * vinculadas a un origen, para mostrarlas al reabrir el comprobante. La
 * creación vive en los módulos de percepciones/retenciones: aquí solo lectura.
 */
export async function adjuntarTributos<R extends AuthSingleResult<unknown>>(
  db: DatabaseService,
  tipo: 'percepcion' | 'retencion',
  id: number,
  result: R,
): Promise<R> {
  if (!result.registro) return result;
  const venta = tipo === 'percepcion';
  const { rows } = await db.query<{ id: number; serie: string; numero: string; nombre_estado_sunat: string | null }>(
    `SELECT DISTINCT t.id, t.serie, t.numero, es.nombre AS nombre_estado_sunat
     FROM ${venta ? 'ven_percepcion' : 'com_retencion'} t
     JOIN ${venta ? 'ven_percepcion_detalle' : 'com_retencion_detalle'} d
       ON d.${venta ? 'id_percepcion' : 'id_retencion'} = t.id AND d.estado = 1
     LEFT JOIN gen_lista_opciones es ON es.id = t.id_estado_sunat
     WHERE d.${venta ? 'id_comprobante' : 'id_compra'} = $1 AND t.estado = 1
     ORDER BY t.id`,
    [id],
  );
  return { ...result, registro: { ...result.registro, [venta ? 'percepciones' : 'retenciones']: rows } };
}
