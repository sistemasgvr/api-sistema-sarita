import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateEjemploDto, UpdateEjemploDto } from '../dto/ejemplos.dto';
import { EjemploModel } from '../models/ejemplo.model';

@Injectable()
export class EjemploLogic {
  constructor(private readonly ejemploModel: EjemploModel) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.ejemploModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.ejemploModel.obtenerPorId(id);
    return mapSingleResult(result, `Ejemplo ${id} no encontrado`);
  }

  async crear(dto: CreateEjemploDto) {
    const result = await this.ejemploModel.crear(
      dto.nombre,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear el ejemplo');
  }

  async actualizar(id: number, dto: UpdateEjemploDto) {
    const result = await this.ejemploModel.actualizar(
      id,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Ejemplo ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.ejemploModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Ejemplo ${id} no encontrado`);
  }
}
