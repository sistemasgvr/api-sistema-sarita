import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CreatePrestamosBalonDto,
  FiltroPrestamosAntiguedadDto,
  FiltroPrestamosBalonDto,
  UpdatePrestamosBalonDto,
} from '../dto/prestamos-balon.dto';

export interface PrestamosAntiguedadResult extends AuthListResult {
  resumen?: {
    total_pendientes?: number;
    reciente_0_30?: number;
    atencion_30_90?: number;
    seguimiento_90_180?: number;
    critico_180?: number;
  };
}

@Injectable()
export class PrestamosBalonModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroPrestamosBalonDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_prestamos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoPrestamo ?? null,
      filtros.idCliente ?? null,
      filtros.idEstado ?? null,
    ]);
  }

  reporteAntiguedad(filtros: FiltroPrestamosAntiguedadDto) {
    return this.db.callFunctionJson<PrestamosAntiguedadResult>(
      'bal_reporte_prestamos_antiguedad',
      [
        filtros.buscar ?? '',
        filtros.limite ?? 50,
        filtros.offset,
        filtros.idCliente ?? null,
        filtros.rangoDias ?? null,
        filtros.excluirBajas ?? true,
        filtros.soloPendientes ?? true,
      ],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_prestamo', [id]);
  }

  crear(dto: CreatePrestamosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_prestamo', [
      dto.idTipoPrestamo ?? null,
      dto.numeroPrestamo ?? null,
      dto.idCliente ?? null,
      dto.idProveedor ?? null,
      dto.idAlmacen ?? null,
      dto.fechaSalida ?? null,
      dto.fechaRetornoPactada ?? null,
      dto.fechaRetornoReal ?? null,
      dto.titulo ?? null,
      dto.observacion ?? null,
      dto.idEstado ?? null,
      dto.idComprobanteVenta ?? null,
      dto.idComprobanteCompra ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdatePrestamosBalonDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_actualizar_prestamo', [
      id,
      dto.numeroPrestamo ?? null,
      dto.idTipoPrestamo ?? null,
      dto.idCliente ?? null,
      dto.idProveedor ?? null,
      dto.idAlmacen ?? null,
      dto.fechaSalida ?? null,
      dto.fechaRetornoPactada ?? null,
      dto.fechaRetornoReal ?? null,
      dto.titulo ?? null,
      dto.observacion ?? null,
      dto.idEstado ?? null,
      dto.idComprobanteVenta ?? null,
      dto.idComprobanteCompra ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_prestamo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
