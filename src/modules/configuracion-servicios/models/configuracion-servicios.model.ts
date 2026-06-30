import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class ConfiguracionServiciosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>(
      'gen_listar_configuraciones_servicio',
      [filtros.buscar ?? '', filtros.limite ?? 10, filtros.offset],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_obtener_configuracion_servicio',
      [id],
    );
  }

  crear(
    codigo: string,
    nombre: string,
    usuario: string | null,
    contrasena: string | null,
    email: string | null,
    url: string | null,
    observacion: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_crear_configuracion_servicio',
      [
        codigo,
        nombre,
        usuario,
        contrasena,
        email,
        url,
        observacion,
        idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(
    id: number,
    codigo: string | null,
    nombre: string | null,
    usuario: string | null,
    contrasena: string | null,
    email: string | null,
    url: string | null,
    observacion: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_actualizar_configuracion_servicio',
      [
        id,
        codigo,
        nombre,
        usuario,
        contrasena,
        email,
        url,
        observacion,
        idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'gen_eliminar_configuracion_servicio',
      [id, idUsuarioAuditoria ?? null],
    );
  }
}
