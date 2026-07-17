import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import {
  CreateCuentaBancariaDto,
  FiltroCuentaBancariaDto,
  UpdateCuentaBancariaDto,
} from '../dto/cuentas-bancarias.dto';

@Injectable()
export class CuentasBancariasModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroCuentaBancariaDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_cuentas_bancarias', [
      filtros.isActivos ?? null,
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset ?? 0,
      filtros.idCliente ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_obtener_cuenta_bancaria',
      [id],
    );
  }

  crear(dto: CreateCuentaBancariaDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_crear_cuenta_bancaria',
      [
        dto.idCliente ?? null,
        dto.idBanco ?? null,
        dto.idTipoCuenta ?? null,
        dto.titular ?? null,
        dto.numeroCuenta ?? null,
        dto.numeroCuentaInterbancaria ?? null,
        dto.telefonoBilletera ?? null,
        dto.esPrincipal ?? false,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateCuentaBancariaDto) {
    return this.db.callFunctionJson<AuthSingleResult<any>>(
      'gen_actualizar_cuenta_bancaria',
      [
        id,
        dto.idCliente ?? null,
        dto.idBanco ?? null,
        dto.idTipoCuenta ?? null,
        dto.titular ?? null,
        dto.numeroCuenta ?? null,
        dto.numeroCuentaInterbancaria ?? null,
        dto.telefonoBilletera ?? null,
        dto.esPrincipal ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_cuenta_bancaria', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
