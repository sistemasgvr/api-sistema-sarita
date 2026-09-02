import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import {
  CreateInventarioMovimientoDto,
  CreateTrasladoLoteInventarioDto,
  FiltroInventarioMovimientosDto,
} from '../dto/inventario-movimientos.dto';
import { InventarioMovimientosModel } from '../models/inventario-movimientos.model';

@Injectable()
export class InventarioMovimientosLogic {
  constructor(private readonly inventarioMovimientosModel: InventarioMovimientosModel) {}

  async listar(filtros: FiltroInventarioMovimientosDto) {
    const result = await this.inventarioMovimientosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.inventarioMovimientosModel.obtenerPorId(id);
    return mapSingleResult(result, `Movimiento ${id} no encontrado`);
  }

  async crear(dto: CreateInventarioMovimientoDto) {
    if (dto.codigoTipoMovimiento === 'TRASLADO') {
      if (!dto.idAlmacenOrigen || !dto.idAlmacenDestino) {
        throw new BadRequestException(
          'Traslado requiere almacén origen y destino',
        );
      }
      if (dto.idAlmacenOrigen === dto.idAlmacenDestino) {
        throw new BadRequestException(
          'El almacén de destino debe ser distinto al de origen',
        );
      }
    }
    const result = await this.inventarioMovimientosModel.crear(dto);
    return mapSingleResult(result, 'No se pudo registrar el movimiento');
  }

  async crearTrasladoLote(dto: CreateTrasladoLoteInventarioDto) {
    const result = await this.inventarioMovimientosModel.crearTrasladoLote(dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.success(
      {
        registros: result.registros ?? [],
        total: Number(result.total ?? 0),
      },
      'Traslado lote registrado',
    );
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.inventarioMovimientosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Movimiento ${id} no encontrado`);
  }
}
