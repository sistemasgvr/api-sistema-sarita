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
      filtros.soloActivos === undefined ? 1 : filtros.soloActivos,
      filtros.idAlmacen ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('pro_obtener_producto', [id]);
  }

  generarCodigoUbicacion(prefijo?: string | null, idProducto?: number | null) {
    return this.db.callFunctionJson<AuthSingleResult<{ codigo_ubicacion: string }>>(
      'pro_generar_codigo_ubicacion',
      [prefijo?.trim() || null, idProducto ?? null],
    );
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
    codigoUbicacion: string | null,
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
      codigoUbicacion,
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
    codigoUbicacion: string | null | undefined,
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
      codigoUbicacion === undefined ? null : codigoUbicacion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_eliminar_producto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  restaurar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('pro_restaurar_producto', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
