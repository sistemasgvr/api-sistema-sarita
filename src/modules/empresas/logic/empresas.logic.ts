import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { CreateEmpresaDto, UpdateEmpresaDto } from '../dto/empresas.dto';
import { EmpresasModel } from '../models/empresas.model';

@Injectable()
export class EmpresasLogic {
  constructor(private readonly empresasModel: EmpresasModel) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.empresasModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.empresasModel.obtenerPorId(id);
    return mapSingleResult(result, `Empresa ${id} no encontrada`);
  }

  async crear(dto: CreateEmpresaDto) {
    const result = await this.empresasModel.crear(
      dto.ruc,
      dto.razonSocial ?? null,
      dto.nombreComercial ?? null,
      dto.direccion ?? null,
      dto.telefono ?? null,
      dto.email ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la empresa');
  }

  async actualizar(id: number, dto: UpdateEmpresaDto) {
    const result = await this.empresasModel.actualizar(
      id,
      dto.ruc ?? null,
      dto.razonSocial ?? null,
      dto.nombreComercial ?? null,
      dto.direccion ?? null,
      dto.telefono ?? null,
      dto.email ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Empresa ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.empresasModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Empresa ${id} no encontrada`);
  }
}
