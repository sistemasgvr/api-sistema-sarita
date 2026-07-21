import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroConfiguracionSunatDto } from '../dto/configuracion-sunat.dto';

export interface CredencialesFacturacionDb {
  id: number;
  id_empresa: number;
  ruc_empresa?: string | null;
  proveedor_pse?: string | null;
  pse_habilitado?: boolean | null;
  api_base_url?: string | null;
  api_token?: string | null;
  api_usuario?: string | null;
  api_clave?: string | null;
  ruc_emisor?: string | null;
  client_id?: string | null;
  client_secret?: string | null;
  timeout_ms?: number | null;
}

export interface ConfiguracionSunatWriteParams {
  idEmpresa: number | null;
  usuarioSol: string | null;
  claveSol: string | null;
  certificadoDigital: string | null;
  claveCertificado: string | null;
  idAmbiente: number | null;
  proveedorPse: string | null;
  pseHabilitado: boolean | null;
  apiBaseUrl: string | null;
  apiToken: string | null;
  apiUsuario: string | null;
  apiClave: string | null;
  rucEmisor: string | null;
  clientId: string | null;
  clientSecret: string | null;
  timeoutMs: number | null;
  idUsuarioAuditoria?: number;
}

@Injectable()
export class ConfiguracionSunatModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroConfiguracionSunatDto) {
    return this.db.callFunctionJson<AuthListResult>(
      'gen_listar_configuraciones_sunat',
      [
        filtros.buscar ?? '',
        filtros.limite ?? 10,
        filtros.offset,
        filtros.idEmpresa ?? null,
      ],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_obtener_configuracion_sunat',
      [id],
    );
  }

  /** Interno: incluye secretos. No exponer por HTTP. */
  obtenerCredencialesFacturacion() {
    return this.db.callFunctionJson<AuthSingleResult<CredencialesFacturacionDb>>(
      'gen_obtener_credenciales_facturacion',
      [],
    );
  }

  crear(params: ConfiguracionSunatWriteParams) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_crear_configuracion_sunat',
      [
        params.idEmpresa,
        params.usuarioSol,
        params.claveSol,
        params.certificadoDigital,
        params.claveCertificado,
        params.idAmbiente,
        params.proveedorPse,
        params.pseHabilitado ?? true,
        params.apiBaseUrl,
        params.apiToken,
        params.apiUsuario,
        params.apiClave,
        params.rucEmisor,
        params.clientId,
        params.clientSecret,
        params.timeoutMs,
        params.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, params: ConfiguracionSunatWriteParams) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_actualizar_configuracion_sunat',
      [
        id,
        params.idEmpresa,
        params.usuarioSol,
        params.claveSol,
        params.certificadoDigital,
        params.claveCertificado,
        params.idAmbiente,
        params.proveedorPse,
        params.pseHabilitado,
        params.apiBaseUrl,
        params.apiToken,
        params.apiUsuario,
        params.apiClave,
        params.rucEmisor,
        params.clientId,
        params.clientSecret,
        params.timeoutMs,
        params.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'gen_eliminar_configuracion_sunat',
      [id, idUsuarioAuditoria ?? null],
    );
  }
}
