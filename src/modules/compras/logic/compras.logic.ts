import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import {
  ActualizarCompraCabeceraDto,
  ActualizarCompraDetalleDto,
  CreateCompraDetalleLineaDto,
  CreateCompraDto,
  FiltroComprasDto,
  RegistrarBalonesCompraDto,
} from '../dto/compras.dto';
import { ComprasModel } from '../models/compras.model';

@Injectable()
export class ComprasLogic {
  constructor(private readonly comprasModel: ComprasModel) {}

  async listar(filtros: FiltroComprasDto) {
    const result = await this.comprasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async registrarBalones(id: number, dto: RegistrarBalonesCompraDto) {
    const result = await this.comprasModel.registrarBalones(id, dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.success({
      creados: result.registro?.creados ?? 0,
      idBalones: result.registro?.id_balones ?? [],
      gasIngresado: Number(result.registro?.gas_ingresado ?? 0),
    });
  }

  async obtenerPorId(id: number) {
    const result = await this.comprasModel.obtenerPorId(id);
    return mapSingleResult(result, `Comprobante de compra ${id} no encontrado`);
  }

  async crear(dto: CreateCompraDto) {
    const result = await this.comprasModel.crear(dto);
    return mapSingleResult(
      result,
      'No se pudo registrar el comprobante de compra',
    );
  }

  async actualizarCabecera(id: number, dto: ActualizarCompraCabeceraDto) {
    const result = await this.comprasModel.actualizarCabecera(id, dto);
    return mapSingleResult(result, `Comprobante de compra ${id} no encontrado`);
  }

  async crearDetalle(idComprobante: number, dto: CreateCompraDetalleLineaDto) {
    const result = await this.comprasModel.crearDetalle(idComprobante, dto);
    return mapSingleResult(
      result,
      `No se pudo agregar línea a la compra ${idComprobante}`,
    );
  }

  async actualizarDetalle(idDetalle: number, dto: ActualizarCompraDetalleDto) {
    const result = await this.comprasModel.actualizarDetalle(idDetalle, dto);
    return mapSingleResult(
      result,
      `No se pudo actualizar el detalle de compra ${idDetalle}`,
    );
  }

  async eliminarDetalle(idDetalle: number, idUsuarioAuditoria?: number) {
    const result = await this.comprasModel.eliminarDetalle(
      idDetalle,
      idUsuarioAuditoria,
    );
    return mapDeleteResult(
      result,
      `Detalle de compra ${idDetalle} no encontrado`,
    );
  }

  async anular(id: number, idUsuarioAuditoria?: number) {
    const result = await this.comprasModel.anular(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Comprobante de compra ${id} no encontrado`);
  }
}
