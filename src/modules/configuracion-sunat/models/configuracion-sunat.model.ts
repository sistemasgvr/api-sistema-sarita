import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class ConfiguracionSunatModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>(
      'gen_listar_configuraciones_sunat',
      [filtros.buscar ?? '', filtros.limite ?? 10, filtros.offset],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_obtener_configuracion_sunat',
      [id],
    );
  }

  crear(
    idEmpresa: number,
    usuarioSol: string,
    claveSol: string,
    certificadoDigital: string | null,
    claveCertificado: string | null,
    idAmbiente: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_crear_configuracion_sunat',
      [
        idEmpresa,
        usuarioSol,
        claveSol,
        certificadoDigital,
        claveCertificado,
        idAmbiente,
        idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(
    id: number,
    idEmpresa: number | null,
    usuarioSol: string | null,
    claveSol: string | null,
    certificadoDigital: string | null,
    claveCertificado: string | null,
    idAmbiente: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_actualizar_configuracion_sunat',
      [
        id,
        idEmpresa,
        usuarioSol,
        claveSol,
        certificadoDigital,
        claveCertificado,
        idAmbiente,
        idUsuarioAuditoria ?? null,
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
