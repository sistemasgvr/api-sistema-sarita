import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroProductosDto } from '../dto/productos.dto';

@Injectable()
export class ProductosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroProductosDto) {
    return this.db.callFunctionJson<AuthListResult>('pro_listar_productos', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.idSubCategoria ?? null,
      filtros.idCategoria ?? null,
      filtros.esGas ?? null,
      filtros.esServicio ?? null,
      filtros.esAlquilable ?? null,
      filtros.afectaStock ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_producto', [id]);
  }

  crear(
    codigo: string,
    nombre: string,
    idSubCategoria: number | null,
    codigoBarra: string | null,
    idUnidadMedida: number | null,
    marca: string | null,
    presentacion: string | null,
    esGas: boolean,
    esServicio: boolean,
    esAlquilable: boolean,
    afectaStock: boolean,
    precio: number,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_crear_producto', [
      codigo,
      nombre,
      idSubCategoria,
      codigoBarra,
      idUnidadMedida,
      marca,
      presentacion,
      esGas,
      esServicio,
      esAlquilable,
      afectaStock,
      precio,
      idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(
    id: number,
    codigo: string | null,
    codigoBarra: string | null,
    nombre: string | null,
    idSubCategoria: number | null,
    idUnidadMedida: number | null,
    marca: string | null,
    presentacion: string | null,
    esGas: boolean | null,
    esServicio: boolean | null,
    esAlquilable: boolean | null,
    afectaStock: boolean | null,
    precio: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_actualizar_producto', [
      id,
      codigo,
      codigoBarra,
      nombre,
      idSubCategoria,
      idUnidadMedida,
      marca,
      presentacion,
      esGas,
      esServicio,
      esAlquilable,
      afectaStock,
      precio,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_producto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
