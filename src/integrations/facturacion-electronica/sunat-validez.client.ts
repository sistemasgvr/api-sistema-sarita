import { BadGatewayException, BadRequestException, Injectable } from '@nestjs/common';
import axios from 'axios';
import { DatabaseService } from '../../database/database.service';

@Injectable()
export class SunatValidezClient {
  constructor(private readonly db: DatabaseService) {}

  /** Consulta independiente de emisión y GRE: nunca escribe en la base. */
  async consultar(idEmpresa: number, doc: { tipo: string; serie: string; numero: string; fecha: string; total: number }) {
    const { rows } = await this.db.query<{
      ruc: string; validez_client_id: string; validez_client_secret: string;
    }>(`SELECT e.ruc, cs.validez_client_id, cs.validez_client_secret
        FROM gen_configuracion_sunat cs JOIN gen_empresa e ON e.id=cs.id_empresa AND e.estado=1
        WHERE cs.estado=1 AND cs.id_empresa=$1`, [idEmpresa]);
    if (rows.length !== 1 || !rows[0].validez_client_id?.trim() || !rows[0].validez_client_secret?.trim()) {
      throw new BadRequestException('Configura el Client ID y Client Secret de validez de esta empresa en Configuración SUNAT.');
    }
    const cfg = rows[0];
    const [year, month, day] = doc.fecha.slice(0, 10).split('-');
    if (!/^\d{11}$/.test(cfg.ruc) || !/^\d+$/.test(doc.numero) || Number(doc.numero) < 1 ||
        !Number.isFinite(doc.total) || !/^\d{4}-\d{2}-\d{2}$/.test(doc.fecha.slice(0, 10))) {
      throw new BadRequestException('El comprobante no tiene datos completos para consultar su validez.');
    }
    try {
      const token = await axios.post(
        `https://api-seguridad.sunat.gob.pe/v1/clientesextranet/${encodeURIComponent(cfg.validez_client_id.trim())}/oauth2/token/`,
        new URLSearchParams({ grant_type: 'client_credentials',
          scope: 'https://api.sunat.gob.pe/v1/contribuyente/contribuyentes',
          client_id: cfg.validez_client_id.trim(), client_secret: cfg.validez_client_secret.trim() }),
        { timeout: 30000, maxRedirects: 0, validateStatus: () => true },
      );
      if (token.status !== 200 || !token.data.access_token) {
        throw new BadGatewayException('SUNAT no autorizó las credenciales de validez. Revisa la aplicación de Consulta de Validez en SOL; las credenciales GRE son independientes.');
      }
      const consulta = { numRuc: cfg.ruc, codComp: doc.tipo, numeroSerie: doc.serie,
        numero: Number(doc.numero), fechaEmision: `${day}/${month}/${year}`, monto: doc.total };
      const result = await axios.post(
        `https://api.sunat.gob.pe/v1/contribuyente/contribuyentes/${cfg.ruc}/validarcomprobante`, consulta,
        { headers: { Authorization: `Bearer ${token.data.access_token}` },
          timeout: 30000, maxRedirects: 0, validateStatus: () => true },
      );
      const code = String(result.data?.data?.estadoCp ?? '');
      if (result.status !== 200 || result.data?.success !== true || !['0','1','2','3','4'].includes(code)) {
        throw new BadGatewayException('SUNAT no pudo confirmar la validez. El resultado de esta consulta no cambia el estado del comprobante.');
      }
      const estados: Record<string, string> = { '0': 'NO INFORMADO', '1': 'ACEPTADO', '2': 'ANULADO', '3': 'AUTORIZADO', '4': 'NO AUTORIZADO' };
      return { fuente: 'SUNAT — consulta integrada', soloLectura: true, consultadoEn: new Date().toISOString(),
        consulta, codigo: code, estado: estados[code], estadoRuc: result.data.data.estadoRuc ?? null,
        condicionRuc: result.data.data.condDomiRuc ?? null, observaciones: result.data.data.Observaciones ?? [] };
    } catch (error) {
      if (error instanceof BadGatewayException) throw error;
      throw new BadGatewayException('No se pudo comunicar con SUNAT para consultar la validez. Intenta la consulta nuevamente; no se ha emitido ni modificado el comprobante.');
    }
  }
}
