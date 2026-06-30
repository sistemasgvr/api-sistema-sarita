import { Injectable } from '@nestjs/common';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateConfiguracionSunatDto,
  UpdateConfiguracionSunatDto,
} from '../dto/configuracion-sunat.dto';
import { ConfiguracionSunatModel } from '../models/configuracion-sunat.model';

@Injectable()
export class ConfiguracionSunatLogic {
  constructor(
    private readonly configuracionSunatModel: ConfiguracionSunatModel,
  ) {}

  async listar(filtros: FiltroPaginacionDto) {
    const result = await this.configuracionSunatModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.configuracionSunatModel.obtenerPorId(id);
    return mapSingleResult(
      result,
      `Configuración SUNAT ${id} no encontrada`,
    );
  }

  async crear(dto: CreateConfiguracionSunatDto) {
    const result = await this.configuracionSunatModel.crear(
      dto.idEmpresa,
      dto.usuarioSol,
      dto.claveSol,
      dto.certificadoDigital ?? null,
      dto.claveCertificado ?? null,
      dto.idAmbiente ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la configuración SUNAT');
  }

  async actualizar(id: number, dto: UpdateConfiguracionSunatDto) {
    const result = await this.configuracionSunatModel.actualizar(
      id,
      dto.idEmpresa ?? null,
      dto.usuarioSol ?? null,
      dto.claveSol ?? null,
      dto.certificadoDigital ?? null,
      dto.claveCertificado ?? null,
      dto.idAmbiente ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(
      result,
      `Configuración SUNAT ${id} no encontrada`,
    );
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.configuracionSunatModel.eliminar(
      id,
      idUsuarioAuditoria,
    );
    return mapDeleteResult(
      result,
      `Configuración SUNAT ${id} no encontrada`,
    );
  }
}
