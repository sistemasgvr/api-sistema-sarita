import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateRecojosBalonDto,
  FiltroPendientesRecojoDto,
  FiltroRecojosBalonDto,
  RegistrarResultadoRecojoDto,
  UpdateRecojosBalonDto,
  ValidarCodigosRecojoDto,
} from '../dto/recojos-balon.dto';
import { RecojosBalonModel } from '../models/recojos-balon.model';

@Injectable()
export class RecojosBalonLogic {
  constructor(private readonly model: RecojosBalonModel) {}

  async listar(filtros: FiltroRecojosBalonDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async listarPendientes(filtros: FiltroPendientesRecojoDto) {
    const result = await this.model.listarPendientes(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Recojo ${id} no encontrado`);
  }

  async crear(dto: CreateRecojosBalonDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el recojo');
  }

  async actualizar(id: number, dto: UpdateRecojosBalonDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Recojo ${id} no encontrado`);
  }

  async registrarResultado(id: number, dto: RegistrarResultadoRecojoDto) {
    const result = await this.model.registrarResultado(id, dto);
    return mapSingleResult(result, `Recojo ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Recojo ${id} no encontrado`);
  }

  async validarCodigos(id: number, dto: ValidarCodigosRecojoDto) {
    const result = await this.model.validarCodigos(id, dto.codigos ?? []);
    return mapSingleResult(result, `Recojo ${id} no encontrado`);
  }
}
