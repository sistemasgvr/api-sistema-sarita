import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroCatalogoPreciosDto } from '../dto/catalogo-precios.dto';

@Injectable()
export class CatalogoPreciosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroCatalogoPreciosDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_catalogo_precios', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idTipoCatalogo ?? null,
      filtros.idProducto ?? null,
      filtros.idProveedor ?? null,
      filtros.periodo ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_catalogo_precio', [id]);
  }

  crear(
    idTipoCatalogo: number,
    nombreItem: string,
    periodo: string | null,
    idProducto: number | null,
    idTipoBalon: number | null,
    idProveedor: number | null,
    clasificacion: string | null,
    modelo: string | null,
    capacidad: number | null,
    idUnidadMedida: number | null,
    descripcionPresentacion: string | null,
    costoProducto: number,
    costoFlete: number,
    porcentajeMargen: number | null,
    precioFinal: number | null,
    precioGarantia: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_catalogo_precio', [
      idTipoCatalogo,
      nombreItem,
      periodo,
      idProducto,
      idTipoBalon,
      idProveedor,
      clasificacion,
      modelo,
      capacidad,
      idUnidadMedida,
      descripcionPresentacion,
      costoProducto,
      costoFlete,
      porcentajeMargen,
      precioFinal,
      precioGarantia,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    idTipoCatalogo: number | null,
    periodo: string | null,
    nombreItem: string | null,
    idProducto: number | null,
    idTipoBalon: number | null,
    idProveedor: number | null,
    clasificacion: string | null,
    modelo: string | null,
    capacidad: number | null,
    idUnidadMedida: number | null,
    descripcionPresentacion: string | null,
    costoProducto: number | null,
    costoFlete: number | null,
    porcentajeMargen: number | null,
    precioFinal: number | null,
    precioGarantia: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_catalogo_precio', [
      id,
      idTipoCatalogo,
      periodo,
      nombreItem,
      idProducto,
      idTipoBalon,
      idProveedor,
      clasificacion,
      modelo,
      capacidad,
      idUnidadMedida,
      descripcionPresentacion,
      costoProducto,
      costoFlete,
      porcentajeMargen,
      precioFinal,
      precioGarantia,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_catalogo_precio', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
