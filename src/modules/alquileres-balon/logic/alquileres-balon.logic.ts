import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import {
  CreateAlquileresBalonDto,
  FiltroAlquileresAntiguedadDto,
  FiltroAlquileresBalonDto,
  RegistrarAlquilerPeriodoDto,
  RenovarAlquilerDto,
  UpdateAlquileresBalonDto,
} from '../dto/alquileres-balon.dto';
import { AlquileresBalonModel } from '../models/alquileres-balon.model';

@Injectable()
export class AlquileresBalonLogic {
  constructor(private readonly model: AlquileresBalonModel) {}

  async listar(filtros: FiltroAlquileresBalonDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async reporteAntiguedad(filtros: FiltroAlquileresAntiguedadDto) {
    const result = await this.model.reporteAntiguedad(filtros);
    const pagina = filtros.pagina ?? 1;
    const limite = filtros.limite ?? 50;

    return ResponseHelper.paginated(result.registros ?? [], {
      pagina,
      limite,
      total: Number(result.total ?? 0),
      resumen: (result.resumen ?? null) as Record<string, unknown> | null,
    });
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, `Alquiler ${id} no encontrado`);
  }

  async obtenerSiguienteNumero(anio?: number) {
    const result = await this.model.obtenerSiguienteNumero(anio);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return {
      anio: result.anio ?? null,
      ultimo: result.ultimo ?? null,
      numero: result.numero ?? null,
    };
  }

  async crear(dto: CreateAlquileresBalonDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdateAlquileresBalonDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Alquiler ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Alquiler ${id} no encontrado`);
  }

  async listarPeriodos(idAlquiler: number, pagina = 1, limite = 100) {
    const offset = (pagina - 1) * limite;
    const result = await this.model.listarPeriodos(idAlquiler, limite, offset);
    return ResponseHelper.paginated(result.registros ?? [], {
      pagina,
      limite,
      total: Number(result.total ?? 0),
    });
  }

  async registrarPeriodo(idAlquiler: number, dto: RegistrarAlquilerPeriodoDto) {
    const result = await this.model.registrarPeriodo(idAlquiler, dto);
    return mapSingleResult(result, 'No se pudo registrar el periodo');
  }

  async renovar(idAlquiler: number, dto: RenovarAlquilerDto) {
    const result = await this.model.renovar(idAlquiler, dto);
    return mapSingleResult(result, `No se pudo renovar el alquiler ${idAlquiler}`);
  }
}
