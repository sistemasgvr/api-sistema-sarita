import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { FacturacionCredentialsService } from '../../../integrations/facturacion-electronica/facturacion-credentials.service';
import {
  CreateConfiguracionSunatDto,
  FiltroConfiguracionSunatDto,
  UpdateConfiguracionSunatDto,
} from '../dto/configuracion-sunat.dto';
import {
  ConfiguracionSunatModel,
  ConfiguracionSunatWriteParams,
} from '../models/configuracion-sunat.model';

@Injectable()
export class ConfiguracionSunatLogic {
  constructor(
    private readonly configuracionSunatModel: ConfiguracionSunatModel,
    private readonly facturacionCredentials: FacturacionCredentialsService,
  ) {}

  async listar(filtros: FiltroConfiguracionSunatDto) {
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
      this.toWriteParams(dto),
    );
    this.facturacionCredentials.invalidate();
    return mapSingleResult(result, 'No se pudo crear la configuración SUNAT');
  }

  async actualizar(id: number, dto: UpdateConfiguracionSunatDto) {
    const result = await this.configuracionSunatModel.actualizar(
      id,
      this.toWriteParams(dto, true),
    );
    this.facturacionCredentials.invalidate();
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
    this.facturacionCredentials.invalidate();
    return mapDeleteResult(
      result,
      `Configuración SUNAT ${id} no encontrada`,
    );
  }

  private toWriteParams(
    dto: CreateConfiguracionSunatDto | UpdateConfiguracionSunatDto,
    isUpdate = false,
  ): ConfiguracionSunatWriteParams {
    const create = dto as CreateConfiguracionSunatDto;
    return {
      idEmpresa: isUpdate
        ? ((dto as UpdateConfiguracionSunatDto).idEmpresa ?? null)
        : create.idEmpresa,
      usuarioSol: dto.usuarioSol ?? null,
      claveSol: dto.claveSol ?? null,
      certificadoDigital: dto.certificadoDigital ?? null,
      claveCertificado: dto.claveCertificado ?? null,
      idAmbiente: dto.idAmbiente ?? null,
      proveedorPse: dto.proveedorPse ?? null,
      pseHabilitado:
        dto.pseHabilitado === undefined ? null : dto.pseHabilitado,
      apiBaseUrl: dto.apiBaseUrl ?? null,
      apiToken: dto.apiToken ?? null,
      apiUsuario: dto.apiUsuario ?? null,
      apiClave: dto.apiClave ?? null,
      rucEmisor: dto.rucEmisor ?? null,
      clientId: dto.clientId ?? null,
      clientSecret: dto.clientSecret ?? null,
      timeoutMs: dto.timeoutMs ?? null,
      idUsuarioAuditoria: dto.idUsuarioAuditoria,
    };
  }
}
