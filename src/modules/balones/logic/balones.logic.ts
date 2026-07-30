import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateBalonesDto,
  AprobarBajaBalonDto,
  DarBajaBalonDto,
  FiltroBalonesDto,
  FiltroEstadoHistorialDto,
  FiltroPhHistorialDto,
  RechazarBajaBalonDto,
  RegistrarPhHistorialDto,
  RestaurarBalonDto,
  UpdateBalonesDto,
} from '../dto/balones.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';
import { BalonesModel } from '../models/balones.model';

@Injectable()
export class BalonesLogic {
  constructor(private readonly model: BalonesModel) {}

  async listar(filtros: FiltroBalonesDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Balón ${id} no encontrado`);
  }

  async crear(dto: CreateBalonesDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateBalonesDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Balón ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Balón ${id} no encontrado`);
  }

  async listarPhHistorial(idBalon: number, filtros: FiltroPhHistorialDto) {
    const result = await this.model.listarPhHistorial(idBalon, filtros);
    return mapListResult(result, filtros);
  }

  async registrarPhHistorial(idBalon: number, dto: RegistrarPhHistorialDto) {
    const result = await this.model.registrarPhHistorial(idBalon, dto);
    return mapSingleResult(result, 'No se pudo registrar la prueba hidrostática');
  }

  async obtenerBajaPorBalon(idBalon: number) {
    const result = await this.model.obtenerBajaPorBalon(idBalon);

    if (result.error) {
      throw new BadRequestException(result.error);
    }

    return result.registro ?? null;
  }

  async darBaja(idBalon: number, dto: DarBajaBalonDto) {
    const result = await this.model.darBaja(idBalon, dto);
    return mapSingleResult(result, 'No se pudo registrar la solicitud de baja');
  }

  async listarSolicitudesBaja(filtros: FiltroPaginacionDto) {
    const result = await this.model.listarSolicitudesBaja(filtros);
    return mapListResult(result, filtros);
  }

  async aprobarBaja(idBaja: number, dto: AprobarBajaBalonDto) {
    const result = await this.model.aprobarBaja(idBaja, dto);
    return mapSingleResult(result, 'No se pudo aprobar la solicitud de baja');
  }

  async rechazarBaja(idBaja: number, dto: RechazarBajaBalonDto) {
    const result = await this.model.rechazarBaja(idBaja, dto);
    return mapSingleResult(result, 'No se pudo rechazar la solicitud de baja');
  }

  async listarEstadoHistorial(idBalon: number, filtros: FiltroEstadoHistorialDto) {
    const result = await this.model.listarEstadoHistorial(idBalon, filtros);
    return mapListResult(result, filtros);
  }

  async restaurar(idBalon: number, dto: RestaurarBalonDto) {
    const result = await this.model.restaurar(idBalon, dto);
    return mapSingleResult(result, 'No se pudo reactivar el cilindro');
  }
}
