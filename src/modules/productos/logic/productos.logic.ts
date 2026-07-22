import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { StorageLogic } from '../../storage/logic/storage.logic';
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

type ProductoListadoRegistro = {
  imagen_principal_ruta?: string | null;
  url_imagen_principal?: string | null;
  [key: string]: unknown;
};

@Injectable()
export class ProductosLogic {
  private readonly logger = new Logger(ProductosLogic.name);

  constructor(
    private readonly productosModel: ProductosModel,
    private readonly ubicacionPdfGenerator: ProductoUbicacionPdfGenerator,
    private readonly storageLogic: StorageLogic,
  ) {}

  async listar(filtros: FiltroProductosDto) {
    const result = await this.productosModel.listar(filtros);
    const mapped = mapListResult(result, filtros);
    const registros = (mapped.data ?? []) as ProductoListadoRegistro[];
    mapped.data = await this.conUrlsImagenPrincipal(registros);
    return mapped;
  }

  private async conUrlsImagenPrincipal(
    registros: ProductoListadoRegistro[],
  ): Promise<ProductoListadoRegistro[]> {
    const rutas = [
      ...new Set(
        registros
          .map((registro) => registro.imagen_principal_ruta?.trim())
          .filter((ruta): ruta is string => Boolean(ruta)),
      ),
    ];

    const urlPorRuta = new Map<string, string>();
    await Promise.all(
      rutas.map(async (ruta) => {
        try {
          const signed = await this.storageLogic.firmarUrl(ruta);
          urlPorRuta.set(ruta, signed.signedUrl);
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          this.logger.warn(
            `No se pudo firmar imagen principal [${ruta}]: ${message}`,
          );
        }
      }),
    );

    return registros.map((registro) => {
      const ruta = registro.imagen_principal_ruta?.trim() || null;
      const { imagen_principal_ruta: _ruta, ...rest } = registro;
      return {
        ...rest,
        url_imagen_principal: ruta ? (urlPorRuta.get(ruta) ?? null) : null,
      };
    });
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
    const esAlquilable = dto.esAlquilable ?? false;
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
      esAlquilable,
      dto.afectaStock ?? true,
      dto.precio ?? 0,
      dto.codigoUbicacion?.trim() || null,
      dto.idUsuarioAuditoria,
      dto.precioCompra ?? 0,
      esAlquilable ? (dto.precioGarantia ?? 0) : 0,
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
      dto.precioCompra ?? null,
      dto.esAlquilable === false
        ? 0
        : (dto.precioGarantia ?? null),
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
