import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { CreateArchivoDto, FiltroArchivosDto } from '../dto/archivos.dto';

@Injectable()
export class ArchivosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroArchivosDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_archivos', [
      filtros.buscar ?? '',
      filtros.idEmpresa ?? null,
      filtros.limite ?? 10,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_archivo', [
      id,
    ]);
  }

  obtenerPorRuta(bucket: string, ruta: string) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_obtener_archivo_por_ruta',
      [bucket, ruta],
    );
  }

  crear(dto: CreateArchivoDto) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_archivo', [
      dto.nombreOriginal,
      dto.nombreAlmacenado,
      dto.ruta,
      dto.bucket,
      dto.mimeType ?? null,
      dto.extension ?? null,
      dto.tamanioBytes ?? null,
      dto.idEmpresa ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('gen_eliminar_archivo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  eliminarPorRuta(
    bucket: string,
    ruta: string,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'gen_eliminar_archivo_por_ruta',
      [bucket, ruta, idUsuarioAuditoria ?? null],
    );
  }
}
