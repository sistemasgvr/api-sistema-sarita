import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import {
  CreateMovimientosRecargaDto,
  CreateRecargaClienteDto,
  FiltroMovimientosRecargaDto,
  FiltroOrigenRecargaDto,
  UpdateMovimientosRecargaDto,
  VincularRecargaClienteComprobanteDto,
} from '../dto/movimientos-recarga.dto';
import { MovimientosRecargaModel } from '../models/movimientos-recarga.model';

@Injectable()
export class MovimientosRecargaLogic {
  constructor(private readonly model: MovimientosRecargaModel) {}

  async listar(filtros: FiltroMovimientosRecargaDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async listarOrigenes(filtros: FiltroOrigenRecargaDto) {
    const result = (await this.model.listarOrigenes(filtros)) as {
      registros?: unknown[];
      total?: number;
      error?: string;
    };
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.paginated(result.registros ?? [], {
      pagina: 1,
      limite: filtros.limite ?? 50,
      total: Number(result.total ?? 0),
    });
  }

  async sugerirOrigen(filtros: FiltroOrigenRecargaDto) {
    const result = await this.model.sugerirOrigen(filtros);
    return mapSingleResult(
      result,
      result.error ??
        'No hay balón empresa LLENO del mismo gas con capacidad suficiente en almacén',
    );
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Movimiento de recarga ${id} no encontrado`);
  }

  async crear(dto: CreateMovimientosRecargaDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async crearRecargaCliente(dto: CreateRecargaClienteDto) {
    const result = await this.model.crearRecargaCliente(dto);
    return mapSingleResult(result, 'No se pudo registrar la recarga del cliente');
  }

  async vincularRecargaClienteComprobante(dto: VincularRecargaClienteComprobanteDto) {
    const result = await this.model.vincularRecargaClienteComprobante(dto);
    return mapSingleResult(result, 'No se pudo vincular la recarga al comprobante');
  }

  async actualizar(id: number, dto: UpdateMovimientosRecargaDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Movimiento de recarga ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Movimiento de recarga ${id} no encontrado`);
  }
}
