import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateConfiguracionServicioDto,
  UpdateConfiguracionServicioDto,
} from '../dto/configuracion-servicios.dto';
import { ConfiguracionServiciosModel } from '../models/configuracion-servicios.model';

@Injectable()
export class ConfiguracionServiciosLogic {
  constructor(
    private readonly configuracionServiciosModel: ConfiguracionServiciosModel,
  ) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.configuracionServiciosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.configuracionServiciosModel.obtenerPorId(id);
    return mapSingleResult(
      result,
      `Configuración de servicio ${id} no encontrada`,
    );
  }

  async crear(dto: CreateConfiguracionServicioDto) {
    const result = await this.configuracionServiciosModel.crear(
      dto.codigo,
      dto.nombre,
      dto.usuario ?? null,
      dto.contrasena ?? null,
      dto.email ?? null,
      dto.url ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(
      result,
      'No se pudo crear la configuración de servicio',
    );
  }

  async actualizar(id: number, dto: UpdateConfiguracionServicioDto) {
    const result = await this.configuracionServiciosModel.actualizar(
      id,
      dto.codigo ?? null,
      dto.nombre ?? null,
      dto.usuario ?? null,
      dto.contrasena ?? null,
      dto.email ?? null,
      dto.url ?? null,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(
      result,
      `Configuración de servicio ${id} no encontrada`,
    );
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.configuracionServiciosModel.eliminar(
      id,
      idUsuarioAuditoria,
    );
    return mapDeleteResult(
      result,
      `Configuración de servicio ${id} no encontrada`,
    );
  }
}
