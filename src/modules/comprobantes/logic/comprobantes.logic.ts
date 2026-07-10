import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import {
  CreateComprobantesDto,
  FiltroComprobantesDto,
  RegistrarRespuestaSunatDto,
  SiguienteNumeroQueryDto,
  UpdateComprobantesDto,
} from '../dto/comprobantes.dto';
import { ComprobantesModel } from '../models/comprobantes.model';
import type { SiguienteNumeroResult } from '../models/comprobantes.model';

@Injectable()
export class ComprobantesLogic {
  constructor(private readonly model: ComprobantesModel) {}

  async listar(filtros: FiltroComprobantesDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }

  async obtenerSiguienteNumero(query: SiguienteNumeroQueryDto): Promise<SiguienteNumeroResult> {
    const result = await this.model.obtenerSiguienteNumero(query);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    return result;
  }

  async crear(dto: CreateComprobantesDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el comprobante');
  }

  async actualizar(id: number, dto: UpdateComprobantesDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }

  async eliminar(id: number, dto: AuditoriaDto) {
    const result = await this.model.eliminar(id, dto.idUsuarioAuditoria);
    return mapDeleteResult(result, `Comprobante ${id} no encontrado`);
  }

  async registrarRespuestaSunat(id: number, dto: RegistrarRespuestaSunatDto) {
    const result = await this.model.registrarRespuestaSunat(id, dto);
    return mapSingleResult(result, `Comprobante ${id} no encontrado`);
  }
}
