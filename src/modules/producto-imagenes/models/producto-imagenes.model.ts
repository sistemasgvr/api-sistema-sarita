import { Injectable } from '@nestjs/common';
import {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroProductoImagenesDto } from '../dto/producto-imagenes.dto';
import {
  ProductoImagenDeleteResult,
  ProductoImagenRegistro,
} from '../interfaces/producto-imagen.interface';

@Injectable()
export class ProductoImagenesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(idProducto: number, filtros: FiltroProductoImagenesDto) {
    return this.db.callFunctionJson<AuthListResult<ProductoImagenRegistro>>(
      'pro_listar_producto_imagenes',
      [idProducto, filtros.limite ?? 50, filtros.offset],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult<ProductoImagenRegistro>>(
      'pro_obtener_producto_imagen',
      [id],
    );
  }

  crear(
    idProducto: number,
    idArchivo: number,
    orden: number | null,
    esPrincipal: boolean,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult<ProductoImagenRegistro>>(
      'pro_crear_producto_imagen',
      [
        idProducto,
        idArchivo,
        orden,
        esPrincipal,
        idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(
    id: number,
    orden: number | null,
    esPrincipal: boolean | null,
    idArchivo: number | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult<ProductoImagenRegistro>>(
      'pro_actualizar_producto_imagen',
      [
        id,
        orden,
        esPrincipal,
        idArchivo,
        idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<ProductoImagenDeleteResult>(
      'pro_eliminar_producto_imagen',
      [id, idUsuarioAuditoria ?? null],
    );
  }
}
