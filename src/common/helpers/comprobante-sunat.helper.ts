import { BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { DatabaseService } from '../../database/database.service';
import { FacturacionApisperuClient } from '../../integrations/facturacion-apisperu/facturacion-apisperu.client';
import { FacturacionCredentialsService } from '../../integrations/facturacion-electronica/facturacion-credentials.service';
import { resolverEstadoGre, type GreEstado } from '../../modules/documentos-salida/helpers/gre-estado';

/**
 * Piezas comunes a los comprobantes que salen por el PSE (percepción,
 * retención): emisor con domicilio fiscal, contraparte desde cli_clientes,
 * estado SUNAT por evidencia (CDR) y documentos oficiales en `cdr_respuesta`.
 */

export interface EmpresaEmisoraPse {
  id: number;
  ruc: string;
  razon_social: string;
  nombre_comercial: string | null;
  direccion: string | null;
  nombre_provincia: string | null;
  nombre_departamento: string | null;
  nombre_distrito: string | null;
  codigo_ubigeo: string | null;
}

export interface ContrapartePse {
  documento: string;
  nombre: string;
  tipo_documento: string | null;
}

export async function obtenerEmpresaEmisoraPse(db: DatabaseService, idEmpresa: number): Promise<EmpresaEmisoraPse> {
  const { rows } = await db.query<EmpresaEmisoraPse>(
    `SELECT e.id, e.ruc, e.razon_social, e.nombre_comercial, e.direccion,
            dist.codigo_ubigeo, dist.nombre AS nombre_distrito,
            prov.nombre AS nombre_provincia, dep.nombre AS nombre_departamento
     FROM gen_empresa e
     LEFT JOIN gen_distrito dist ON dist.id = e.id_distrito
     LEFT JOIN gen_provincia prov ON prov.id = dist.id_provincia
     LEFT JOIN gen_departamento dep ON dep.id = prov.id_departamento
     WHERE e.estado = 1 AND e.id = $1`,
    [idEmpresa],
  );
  const empresa = rows[0];
  if (!empresa) throw new BadRequestException('Empresa emisora no encontrada o inactiva');
  if (!/^\d{11}$/.test((empresa.ruc ?? '').trim())) {
    throw new BadRequestException('El RUC de la empresa emisora debe tener 11 dígitos');
  }
  if (!/^\d{6}$/.test((empresa.codigo_ubigeo ?? '').trim())) {
    throw new BadRequestException(
      'Registra el distrito fiscal (ubigeo) de la empresa emisora en Configuración → Empresa',
    );
  }
  return empresa;
}

/** Clientes y proveedores viven en cli_clientes (numero_documento, razón social o nombres). */
export async function obtenerContrapartePse(db: DatabaseService, idCliente: number, rol: string): Promise<ContrapartePse> {
  const { rows } = await db.query<ContrapartePse>(
    `SELECT c.numero_documento AS documento,
            COALESCE(NULLIF(TRIM(c.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')) AS nombre,
            td.nombre AS tipo_documento
     FROM cli_clientes c
     LEFT JOIN gen_lista_opciones td ON td.id = c.id_tipo_documento
     WHERE c.estado = 1 AND c.id = $1`,
    [idCliente],
  );
  const contraparte = rows[0];
  if (!contraparte) throw new BadRequestException(`${rol} no encontrado o inactivo`);
  if (!(contraparte.documento ?? '').trim()) {
    throw new BadRequestException(`El ${rol.toLowerCase()} no tiene número de documento`);
  }
  return contraparte;
}

export async function resolverIdEstadoSunat(db: DatabaseService, nombre: GreEstado): Promise<number | null> {
  const { rows } = await db.query<{ id: number }>(
    `SELECT o.id FROM gen_lista_opciones o
     INNER JOIN gen_lista l ON o.id_lista = l.id
     WHERE l.nombre = 'EstadoSunat' AND o.nombre = $1 AND o.estado = 1
     ORDER BY o.id LIMIT 1`,
    [nombre],
  );
  return rows[0]?.id ?? null;
}

/**
 * Acceso al PSE con las credenciales de la empresa (token o usuario/clave).
 * Percepción y retención no usan OAuth GRE: no se exige.
 */
export async function assertPseConfigurado(
  credentials: FacturacionCredentialsService,
  client: FacturacionApisperuClient,
  idEmpresa: number,
): Promise<void> {
  const status = await credentials.withEmpresa(idEmpresa, () => client.getConfigStatus());
  if (!status.enabled) {
    throw new ServiceUnavailableException('La integración de facturación electrónica está deshabilitada');
  }
  if (!status.configured) {
    throw new BadRequestException('Configure token o usuario/clave del PSE en Configuración → SUNAT');
  }
}

/** `success: true` no es aceptación: hace falta el CDR (misma regla que la GRE). */
export function estadoDesdeRespuestaPse(sunatResponse: unknown): GreEstado {
  return resolverEstadoGre(sunatResponse);
}

export function leerCdrJson(cdrRespuesta: string | null | undefined): Record<string, unknown> {
  if (!cdrRespuesta) return {};
  try {
    const parsed: unknown = JSON.parse(cdrRespuesta);
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : {};
  } catch {
    return {};
  }
}

export function documentoOficialBase64(cdrRespuesta: string | null | undefined, clave: 'pdf_oficial' | 'xml_oficial'): string | null {
  const valor = leerCdrJson(cdrRespuesta)[clave];
  return typeof valor === 'string' && valor.trim() ? valor : null;
}

/**
 * Tasas vigentes por régimen (catálogos SUNAT 22 y 23). La UI las propone y el
 * servidor las usa por defecto; una tasa distinta debe venir explícita.
 */
export const TASAS_PERCEPCION: Record<string, number> = { '01': 2, '02': 1, '03': 0.5 };
export const TASAS_RETENCION: Record<string, number> = { '01': 3, '02': 6 };

export function redondear2(valor: number): number {
  return Math.round((valor + Number.EPSILON) * 100) / 100;
}

/**
 * Importe del tributo y neto de una línea. La percepción se suma a lo que
 * cobra el emisor; la retención se descuenta de lo que paga.
 */
export function calcularLineaTributo(
  impTotal: number,
  tasa: number,
  tipo: 'percepcion' | 'retencion',
): { tributo: number; neto: number } {
  const total = redondear2(Number(impTotal));
  const tributo = redondear2((total * tasa) / 100);
  const neto = redondear2(tipo === 'percepcion' ? total + tributo : total - tributo);
  return { tributo, neto };
}
