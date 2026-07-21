import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ProductoImagenesLogic } from '../../producto-imagenes/logic/producto-imagenes.logic';
import {
  CreateProductoDto,
  FiltroProductosDto,
  UpdateProductoDto,
} from '../dto/productos.dto';
import { ProductosModel } from '../models/productos.model';

@Injectable()
export class ProductosLogic {
  constructor(
    private readonly productosModel: ProductosModel,
    private readonly productoImagenesLogic: ProductoImagenesLogic,
  ) {}

  async listar(filtros: FiltroProductosDto) {
    const result = await this.productosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.productosModel.obtenerPorId(id);
    return mapSingleResult(result, `Producto ${id} no encontrado`);
  }

  async crear(dto: CreateProductoDto) {
    const result = await this.productosModel.crear(
      dto.codigo,
      dto.nombre,
      dto.idSubCategoria ?? null,
      dto.codigoBarra ?? null,
      dto.idUnidadMedida ?? null,
      dto.marca ?? null,
      dto.presentacion ?? null,
      dto.esGas ?? false,
      dto.esServicio ?? false,
      dto.esAlquilable ?? false,
      dto.afectaStock ?? true,
      dto.precio ?? 0,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el producto');
  }

  async actualizar(id: number, dto: UpdateProductoDto) {
    const result = await this.productosModel.actualizar(
      id,
      dto.codigo ?? null,
      dto.codigoBarra ?? null,
      dto.nombre ?? null,
      dto.idSubCategoria ?? null,
      dto.idUnidadMedida ?? null,
      dto.marca ?? null,
      dto.presentacion ?? null,
      dto.esGas ?? null,
      dto.esServicio ?? null,
      dto.esAlquilable ?? null,
      dto.afectaStock ?? null,
      dto.precio ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Producto ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.eliminar(id, idUsuarioAuditoria);
    const eliminado = mapDeleteResult(
      result,
      `Producto ${id} no encontrado`,
    );

    await this.productoImagenesLogic.eliminarTodasDeProducto(
      id,
      idUsuarioAuditoria,
    );

    return eliminado;
  }
}
