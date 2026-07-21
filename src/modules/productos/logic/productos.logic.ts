import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateProductoDto,
  FiltroProductosDto,
  GenerarCodigoUbicacionDto,
  ImprimirUbicacionesProductoDto,
  UpdateProductoDto,
} from '../dto/productos.dto';
import { ProductosModel } from '../models/productos.model';
import {
  ProductoUbicacionLabelItem,
  ProductoUbicacionPdfGenerator,
} from '../services/producto-ubicacion-pdf.generator';
import { buildCodigoUbicacionPrefijo } from '../utils/codigo-ubicacion.util';

type ProductoUbicacionRegistro = {
  id?: number;
  codigo?: string | null;
  codigo_ubicacion?: string | null;
  nombre?: string | null;
};

@Injectable()
export class ProductosLogic {
  constructor(
    private readonly productosModel: ProductosModel,
    private readonly ubicacionPdfGenerator: ProductoUbicacionPdfGenerator,
  ) {}

  async listar(filtros: FiltroProductosDto) {
    const result = await this.productosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.productosModel.obtenerPorId(id);
    return mapSingleResult(result, `Producto ${id} no encontrado`);
  }

  async generarCodigoUbicacion(dto: GenerarCodigoUbicacionDto) {
    const prefijo = buildCodigoUbicacionPrefijo(dto.nombre, dto.marca);
    const result = await this.productosModel.generarCodigoUbicacion(
      prefijo,
      dto.idProducto ?? null,
    );
    return mapSingleResult(result, 'No se pudo generar el código de ubicación');
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
      dto.codigoUbicacion?.trim() || null,
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
      dto.codigoUbicacion === undefined
        ? undefined
        : dto.codigoUbicacion.trim() || '',
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Producto ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Producto ${id} no encontrado`);
  }

  async restaurar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productosModel.restaurar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Producto ${id} no encontrado o ya está activo`);
  }

  async generarPdfUbicaciones(dto: ImprimirUbicacionesProductoDto) {
    const uniqueIds = [...new Set(dto.ids)];
    const labels: ProductoUbicacionLabelItem[] = [];
    const seenUbicaciones = new Set<string>();

    for (const id of uniqueIds) {
      const producto = (await this.obtenerPorId(id)) as ProductoUbicacionRegistro;
      const codigoUbicacion = (producto.codigo_ubicacion ?? '').trim();

      if (!codigoUbicacion) {
        throw new BadRequestException(
          `El producto ${id} no tiene código de ubicación`,
        );
      }

      const ubicacionKey = codigoUbicacion.toLowerCase();
      if (seenUbicaciones.has(ubicacionKey)) {
        throw new BadRequestException(
          `Código de ubicación duplicado en la selección: ${codigoUbicacion}`,
        );
      }
      seenUbicaciones.add(ubicacionKey);

      labels.push({
        codigo_ubicacion: codigoUbicacion,
        codigo: (producto.codigo ?? '').trim(),
        nombre: (producto.nombre ?? '').trim(),
      });
    }

    if (!labels.length) {
      throw new BadRequestException(
        'No hay productos con ubicación para imprimir',
      );
    }

    const buffer = await this.ubicacionPdfGenerator.generarTarjetas(labels);
    const stamp = new Date().toISOString().slice(0, 10);
    const filename = `ubicaciones-productos-${stamp}.pdf`;

    return { buffer, filename };
  }
}
