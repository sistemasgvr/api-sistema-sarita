import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { FiltroContactoDto } from '../dto/filtros-contacto.dto';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateContactoDto,
  UpdateContactoDto,
} from '../dto/crear-contacto.dto';

@Injectable()
export class ContactosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroContactoDto) {
    return this.db.callFunctionJson<AuthListResult>('cli_listar_contactos', [
      filtros.soloActivos ?? null,
      filtros.idCliente ?? null,
      filtros.buscar ?? null,
      filtros.limite ?? 50,
      filtros.pagina ?? 1,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_obtener_por_id_contacto',
      [id],
    );
  }

  crear(dto: CreateContactoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_crear_contacto',
      [
        dto.idCliente,
        dto.nombre ?? null,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.direccion ?? null,
        dto.email ?? null,
        dto.telefono1 ?? null,
        dto.telefono2 ?? null,
        dto.telefono3 ?? null,
        dto.esPrincipal ?? false,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateContactoDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'cli_editar_contacto',
      [
        id,
        dto.idCliente ?? null,
        dto.nombre ?? null,
        dto.apellidoPaterno ?? null,
        dto.apellidoMaterno ?? null,
        dto.direccion ?? null,
        dto.email ?? null,
        dto.telefono1 ?? null,
        dto.telefono2 ?? null,
        dto.telefono3 ?? null,
        dto.esPrincipal ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('cli_eliminar_contacto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
