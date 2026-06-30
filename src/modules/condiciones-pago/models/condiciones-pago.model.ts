import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class CondicionesPagoModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPaginacionDto) {
    return this.db.callFunctionJson<AuthListResult>(
      'gen_listar_condiciones_pago',
      [filtros.buscar ?? '', filtros.limite ?? 10, filtros.offset],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_obtener_condicion_pago',
      [id],
    );
  }

  crear(
    codigo: string,
    nombre: string,
    diasCredito: number,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_crear_condicion_pago',
      [codigo, nombre, diasCredito, idUsuarioAuditoria ?? null],
    );
  }

  actualizar(
    id: number,
    codigo: string | null,
    nombre: string | null,
    diasCredito: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_actualizar_condicion_pago',
      [id, codigo, nombre, diasCredito, idUsuarioAuditoria ?? null],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'gen_eliminar_condicion_pago',
      [id, idUsuarioAuditoria ?? null],
    );
  }
}
