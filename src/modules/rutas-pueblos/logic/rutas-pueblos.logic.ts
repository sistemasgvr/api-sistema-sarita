import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CerrarRutaPuebloDto,
  CreateRutaPuebloDto,
  FiltroRutasPueblosDto,
  RegistrarRetornoRutaPuebloDto,
  UpdateRutaPuebloDto,
} from '../dto/rutas-pueblos.dto';
import { RutasPueblosModel } from '../models/rutas-pueblos.model';

@Injectable()
export class RutasPueblosLogic {
  constructor(private readonly model: RutasPueblosModel) {}

  async listar(filtros: FiltroRutasPueblosDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Ruta ${id} no encontrada`);
  }

  async crear(dto: CreateRutaPuebloDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear la ruta');
  }

  async actualizar(id: number, dto: UpdateRutaPuebloDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Ruta ${id} no encontrada`);
  }

  async iniciar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.iniciar(id, idUsuarioAuditoria);
    return mapSingleResult(result, `Ruta ${id} no encontrada`);
  }

  async registrarRetorno(id: number, dto: RegistrarRetornoRutaPuebloDto) {
    const result = await this.model.registrarRetorno(id, dto);
    return mapSingleResult(result, `Ruta ${id} no encontrada`);
  }

  async cerrar(id: number, dto: CerrarRutaPuebloDto) {
    const result = await this.model.cerrar(id, dto);
    return mapSingleResult(result, `Ruta ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Ruta ${id} no encontrada`);
  }
}
