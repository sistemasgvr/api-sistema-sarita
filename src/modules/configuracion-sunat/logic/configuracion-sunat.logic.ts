import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { DatabaseService } from '../../../database/database.service';
import { FacturacionApisperuClient } from '../../../integrations/facturacion-apisperu/facturacion-apisperu.client';
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
    private readonly facturacionClient: FacturacionApisperuClient,
    private readonly db: DatabaseService,
  ) {}

  /**
   * «Verificar conexión y empresa»: solo lecturas al PSE con las credenciales
   * de esa empresa. No modifica nada ni en el PSE ni en la base.
   */
  async verificarGre(idEmpresa: number) {
    const ruc = await this.rucDeEmpresa(idEmpresa);
    this.facturacionCredentials.invalidate();
    return this.facturacionCredentials.withEmpresa(idEmpresa, () =>
      this.facturacionClient.verificarEmpresaGre(ruc),
    );
  }

  /**
   * «Sincronizar configuración GRE»: la única acción que escribe credenciales
   * en la empresa del PSE. Requiere permiso de edición y queda en el log.
   */
  async sincronizarGre(idEmpresa: number, idUsuarioAuditoria?: number) {
    const ruc = await this.rucDeEmpresa(idEmpresa);
    this.facturacionCredentials.invalidate();
    const resultado = await this.facturacionCredentials.withEmpresa(idEmpresa, () =>
      this.facturacionClient.sincronizarCredencialesGre(ruc),
    );
    await this.db.query(
      `UPDATE gen_configuracion_sunat SET id_usuario_modificacion = $2, fecha_modificacion = now()
       WHERE id_empresa = $1 AND estado = 1`,
      [idEmpresa, idUsuarioAuditoria ?? null],
    );
    return resultado;
  }

  private async rucDeEmpresa(idEmpresa: number): Promise<string> {
    const result = await this.db.query<{ ruc: string }>(
      'SELECT ruc FROM gen_empresa WHERE id = $1 AND estado = 1',
      [idEmpresa],
    );
    const ruc = result.rows[0]?.ruc?.trim();
    if (!ruc) throw new NotFoundException(`Empresa ${idEmpresa} no encontrada`);
    if (!/^\d{11}$/.test(ruc)) throw new BadRequestException('El RUC de la empresa debe tener 11 dígitos');
    return ruc;
  }

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
