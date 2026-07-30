import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateArchivoDto, FiltroArchivosDto } from '../dto/archivos.dto';
import { ArchivosModel } from '../models/archivos.model';

@Injectable()
export class ArchivosLogic {
  constructor(private readonly archivosModel: ArchivosModel) {}

  async listar(filtros: FiltroArchivosDto) {
    const result = await this.archivosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.archivosModel.obtenerPorId(id);
    return mapSingleResult(result, `Archivo ${id} no encontrado`);
  }

  async obtenerPorRuta(bucket: string, ruta: string) {
    const result = await this.archivosModel.obtenerPorRuta(bucket, ruta);
    return mapSingleResult(
      result,
      `Archivo en ruta "${ruta}" no encontrado`,
    );
  }

  async crear(dto: CreateArchivoDto) {
    const result = await this.archivosModel.crear(dto);
    return mapSingleResult(result, 'No se pudo registrar el archivo');
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.archivosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Archivo ${id} no encontrado`);
  }

  async eliminarPorRuta(
    bucket: string,
    ruta: string,
    idUsuarioAuditoria?: number,
  ) {
    await this.archivosModel.eliminarPorRuta(
      bucket,
      ruta,
      idUsuarioAuditoria,
    );
  }
}
