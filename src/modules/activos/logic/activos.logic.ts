import { Injectable, Logger } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { StorageLogic } from '../../storage/logic/storage.logic';
import {
  CreateActivoDto,
  FiltroActivoDto,
  UpdateActivoDto,
} from '../dto/activos.dto';
import { ActivosModel } from '../models/activos.model';

type ActivoRegistro = {
  imagen_principal_ruta?: string | null;
  url_imagen_principal?: string | null;
  [key: string]: unknown;
};

@Injectable()
export class ActivosLogic {
  private readonly logger = new Logger(ActivosLogic.name);

  constructor(
    private readonly activosModel: ActivosModel,
    private readonly storageLogic: StorageLogic,
  ) {}

  async listar(filtros: FiltroActivoDto) {
    const result = await this.activosModel.listar(filtros);
    const mapped = mapListResult(result, filtros);
    const registros = (mapped.data ?? []) as ActivoRegistro[];

    if (filtros.incluirImagenes === true) {
      mapped.data = await Promise.all(registros.map((r) => this.conUrlImagen(r)));
      return mapped;
    }

    mapped.data = registros.map(({ imagen_principal_ruta: _ruta, ...rest }) => ({
      ...rest,
      url_imagen_principal: null,
    }));
    return mapped;
  }

  async obtenerPorId(id: number) {
    const result = await this.activosModel.obtenerPorId(id);
    const registro = mapSingleResult(result, `Activo ${id} no encontrado`);
    return this.conUrlImagen(registro);
  }

  async crear(dto: CreateActivoDto) {
    const result = await this.activosModel.crear(dto);
    const registro = mapSingleResult(result, 'No se pudo crear el activo');
    return this.conUrlImagen(registro);
  }

  async actualizar(id: number, dto: UpdateActivoDto) {
    const result = await this.activosModel.actualizar(id, dto);
    const registro = mapSingleResult(result, `Activo ${id} no encontrado`);
    return this.conUrlImagen(registro);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.activosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Activo ${id} no encontrado o ya está inactivo`);
  }

  private async conUrlImagen(registro: ActivoRegistro): Promise<ActivoRegistro> {
    if (!registro) return registro;
    const ruta = registro.imagen_principal_ruta?.trim() || null;
    let url: string | null = null;
    if (ruta) {
      try {
        const signed = await this.storageLogic.firmarUrl(ruta);
        url = signed.signedUrl;
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.warn(`No se pudo firmar imagen principal [${ruta}]: ${message}`);
      }
    }
    const { imagen_principal_ruta: _ruta, ...rest } = registro;
    return { ...rest, url_imagen_principal: url };
  }
}
