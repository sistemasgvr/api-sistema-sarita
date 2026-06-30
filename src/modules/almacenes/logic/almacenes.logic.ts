import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateAlmacenDto,
  FiltroAlmacenesDto,
  UpdateAlmacenDto,
} from '../dto/almacenes.dto';
import { AlmacenesModel } from '../models/almacenes.model';

@Injectable()
export class AlmacenesLogic {
  constructor(private readonly almacenesModel: AlmacenesModel) {}

  async listar(filtros: FiltroAlmacenesDto) {
    const result = await this.almacenesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.almacenesModel.obtenerPorId(id);
    return mapSingleResult(result, `Almacén ${id} no encontrado`);
  }

  async crear(dto: CreateAlmacenDto) {
    const result = await this.almacenesModel.crear(
      dto.idSucursal,
      dto.nombre,
      dto.ubicacion ?? null,
      dto.descripcion ?? null,
      dto.idDepartamento ?? null,
      dto.idProvincia ?? null,
      dto.idDistrito ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el almacén');
  }

  async actualizar(id: number, dto: UpdateAlmacenDto) {
    const result = await this.almacenesModel.actualizar(
      id,
      dto.idSucursal ?? null,
      dto.nombre ?? null,
      dto.ubicacion ?? null,
      dto.descripcion ?? null,
      dto.idDepartamento ?? null,
      dto.idProvincia ?? null,
      dto.idDistrito ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Almacén ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.almacenesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Almacén ${id} no encontrado`);
  }
}
