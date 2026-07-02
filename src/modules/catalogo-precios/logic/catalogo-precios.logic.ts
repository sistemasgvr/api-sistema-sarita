import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateCatalogoPrecioDto,
  FiltroCatalogoPreciosDto,
  UpdateCatalogoPrecioDto,
} from '../dto/catalogo-precios.dto';
import { CatalogoPreciosModel } from '../models/catalogo-precios.model';

@Injectable()
export class CatalogoPreciosLogic {
  constructor(private readonly catalogoPreciosModel: CatalogoPreciosModel) {}

  async listar(filtros: FiltroCatalogoPreciosDto) {
    const result = await this.catalogoPreciosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.catalogoPreciosModel.obtenerPorId(id);
    return mapSingleResult(result, `Ítem de catálogo ${id} no encontrado`);
  }

  async crear(dto: CreateCatalogoPrecioDto) {
    const result = await this.catalogoPreciosModel.crear(
      dto.idTipoCatalogo,
      dto.nombreItem,
      dto.periodo ?? null,
      dto.idProducto ?? null,
      dto.idTipoBalon ?? null,
      dto.idProveedor ?? null,
      dto.clasificacion ?? null,
      dto.modelo ?? null,
      dto.capacidad ?? null,
      dto.idUnidadMedida ?? null,
      dto.descripcionPresentacion ?? null,
      dto.costoProducto ?? 0,
      dto.costoFlete ?? 0,
      dto.porcentajeMargen ?? null,
      dto.precioFinal ?? null,
      dto.precioGarantia ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el ítem de catálogo');
  }

  async actualizar(id: number, dto: UpdateCatalogoPrecioDto) {
    const result = await this.catalogoPreciosModel.actualizar(
      id,
      dto.idTipoCatalogo ?? null,
      dto.periodo ?? null,
      dto.nombreItem ?? null,
      dto.idProducto ?? null,
      dto.idTipoBalon ?? null,
      dto.idProveedor ?? null,
      dto.clasificacion ?? null,
      dto.modelo ?? null,
      dto.capacidad ?? null,
      dto.idUnidadMedida ?? null,
      dto.descripcionPresentacion ?? null,
      dto.costoProducto ?? null,
      dto.costoFlete ?? null,
      dto.porcentajeMargen ?? null,
      dto.precioFinal ?? null,
      dto.precioGarantia ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Ítem de catálogo ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.catalogoPreciosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Ítem de catálogo ${id} no encontrado`);
  }
}
