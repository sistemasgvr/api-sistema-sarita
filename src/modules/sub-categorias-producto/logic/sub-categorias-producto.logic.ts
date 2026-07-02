import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateSubCategoriaProductoDto,
  FiltroSubCategoriasProductoDto,
  UpdateSubCategoriaProductoDto,
} from '../dto/sub-categorias-producto.dto';
import { SubCategoriasProductoModel } from '../models/sub-categorias-producto.model';

@Injectable()
export class SubCategoriasProductoLogic {
  constructor(private readonly subCategoriasProductoModel: SubCategoriasProductoModel) {}

  async listar(filtros: FiltroSubCategoriasProductoDto) {
    const result = await this.subCategoriasProductoModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.subCategoriasProductoModel.obtenerPorId(id);
    return mapSingleResult(result, `Subcategoría ${id} no encontrada`);
  }

  async crear(dto: CreateSubCategoriaProductoDto) {
    const result = await this.subCategoriasProductoModel.crear(
      dto.idCategoria,
      dto.nombre,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la subcategoría');
  }

  async actualizar(id: number, dto: UpdateSubCategoriaProductoDto) {
    const result = await this.subCategoriasProductoModel.actualizar(
      id,
      dto.idCategoria ?? null,
      dto.nombre ?? null,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Subcategoría ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.subCategoriasProductoModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Subcategoría ${id} no encontrada`);
  }
}
