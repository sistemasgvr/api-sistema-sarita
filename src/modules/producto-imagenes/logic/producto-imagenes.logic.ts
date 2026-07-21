import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { StorageLogic } from '../../storage/logic/storage.logic';
import {
  FiltroProductoImagenesDto,
  UpdateProductoImagenDto,
} from '../dto/producto-imagenes.dto';
import { ProductoImagenRegistro } from '../interfaces/producto-imagen.interface';
import { ProductoImagenesModel } from '../models/producto-imagenes.model';

@Injectable()
export class ProductoImagenesLogic {
  private readonly logger = new Logger(ProductoImagenesLogic.name);

  constructor(
    private readonly productoImagenesModel: ProductoImagenesModel,
    private readonly storageLogic: StorageLogic,
  ) {}

  async listar(
    idProducto: number,
    filtros: FiltroProductoImagenesDto,
    conUrlFirmada = true,
  ) {
    const result = await this.productoImagenesModel.listar(idProducto, filtros);
    const mapped = mapListResult(result, filtros);

    if (!conUrlFirmada || !Array.isArray(mapped.data)) {
      return mapped;
    }

    const registros = await Promise.all(
      (mapped.data as ProductoImagenRegistro[]).map((item) =>
        this.conUrlFirmada(item),
      ),
    );

    return { ...mapped, data: registros };
  }

  async obtenerPorId(id: number, conUrlFirmada = true) {
    const result = await this.productoImagenesModel.obtenerPorId(id);
    const registro = mapSingleResult(
      result,
      `Imagen de producto ${id} no encontrada`,
    ) as ProductoImagenRegistro;

    return conUrlFirmada ? this.conUrlFirmada(registro) : registro;
  }

  async crear(
    idProducto: number,
    file: Express.Multer.File | undefined,
    orden?: number,
    esPrincipal = false,
    idUsuarioAuditoria?: number,
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('Debes enviar un archivo en el campo "file"');
    }

    const path = this.buildStoragePath(idProducto, file.originalname);
    const uploaded = await this.storageLogic.subir(
      path,
      file,
      false,
      undefined,
      idUsuarioAuditoria,
    );

    const archivo = uploaded.archivo as { id: number };
    if (!archivo?.id) {
      throw new BadRequestException('No se pudo registrar el archivo subido');
    }

    try {
      const result = await this.productoImagenesModel.crear(
        idProducto,
        archivo.id,
        orden ?? null,
        esPrincipal,
        idUsuarioAuditoria,
      );
      const registro = mapSingleResult(
        result,
        'No se pudo asociar la imagen al producto',
      ) as ProductoImagenRegistro;

      return this.conUrlFirmada(registro);
    } catch (error) {
      await this.limpiarStorageSeguro([uploaded.path], idUsuarioAuditoria);
      throw error;
    }
  }

  async actualizar(id: number, dto: UpdateProductoImagenDto) {
    const result = await this.productoImagenesModel.actualizar(
      id,
      dto.orden ?? null,
      dto.esPrincipal ?? null,
      null,
      dto.idUsuarioAuditoria,
    );
    const registro = mapSingleResult(
      result,
      `Imagen de producto ${id} no encontrada`,
    ) as ProductoImagenRegistro;

    return this.conUrlFirmada(registro);
  }

  async reemplazarArchivo(
    id: number,
    file: Express.Multer.File | undefined,
    idUsuarioAuditoria?: number,
  ) {
    if (!file?.buffer?.length) {
      throw new BadRequestException('Debes enviar un archivo en el campo "file"');
    }

    const actual = (await this.obtenerPorId(id, false)) as ProductoImagenRegistro;
    const path = this.buildStoragePath(actual.id_producto, file.originalname);

    const uploaded = await this.storageLogic.subir(
      path,
      file,
      false,
      undefined,
      idUsuarioAuditoria,
    );

    const archivo = uploaded.archivo as { id: number };
    if (!archivo?.id) {
      throw new BadRequestException('No se pudo registrar el archivo subido');
    }

    try {
      const result = await this.productoImagenesModel.actualizar(
        id,
        null,
        null,
        archivo.id,
        idUsuarioAuditoria,
      );
      const registro = mapSingleResult(
        result,
        `Imagen de producto ${id} no encontrada`,
      ) as ProductoImagenRegistro;

      await this.limpiarStorageSeguro([actual.ruta], idUsuarioAuditoria);
      return this.conUrlFirmada(registro);
    } catch (error) {
      await this.limpiarStorageSeguro([uploaded.path], idUsuarioAuditoria);
      throw error;
    }
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.productoImagenesModel.eliminar(
      id,
      idUsuarioAuditoria,
    );

    if (result.error) {
      throw new BadRequestException(result.error);
    }
    if (!result.eliminado) {
      throw new NotFoundException(`Imagen de producto ${id} no encontrada`);
    }

    if (result.ruta) {
      await this.limpiarStorageSeguro([result.ruta], idUsuarioAuditoria);
    }

    return result;
  }

  async eliminarTodasDeProducto(
    idProducto: number,
    idUsuarioAuditoria?: number,
  ) {
    const listado = await this.productoImagenesModel.listar(idProducto, {
      limite: 500,
      pagina: 1,
    } as FiltroProductoImagenesDto);

    const registros = listado.registros ?? [];
    for (const imagen of registros) {
      try {
        await this.eliminar(imagen.id, idUsuarioAuditoria);
      } catch (error) {
        const message =
          error instanceof Error ? error.message : String(error);
        this.logger.warn(
          `No se pudo eliminar imagen ${imagen.id} del producto ${idProducto}: ${message}`,
        );
      }
    }
  }

  private buildStoragePath(
    idProducto: number,
    originalName?: string,
  ): string {
    const safeName = (originalName || 'imagen')
      .replace(/[^a-zA-Z0-9._-]/g, '_')
      .slice(0, 120);
    return `productos/${idProducto}/${randomUUID()}-${safeName}`;
  }

  private async conUrlFirmada(
    registro: ProductoImagenRegistro,
  ): Promise<ProductoImagenRegistro> {
    if (!registro?.ruta) return registro;

    try {
      const signed = await this.storageLogic.firmarUrl(registro.ruta);
      return {
        ...registro,
        url_firmada: signed.signedUrl,
        expires_in: signed.expiresIn,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(
        `No se pudo firmar URL de imagen ${registro.id}: ${message}`,
      );
      return registro;
    }
  }

  private async limpiarStorageSeguro(
    paths: string[],
    idUsuarioAuditoria?: number,
  ) {
    try {
      await this.storageLogic.eliminar(paths, idUsuarioAuditoria);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(
        `No se pudo limpiar storage [${paths.join(', ')}]: ${message}`,
      );
    }
  }
}
