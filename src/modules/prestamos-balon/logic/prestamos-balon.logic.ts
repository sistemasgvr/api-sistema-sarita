import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import {
  CreatePrestamosBalonDto,
  FiltroPrestamosAntiguedadDto,
  FiltroPrestamosBalonDto,
  UpdatePrestamosBalonDto,
} from '../dto/prestamos-balon.dto';
import { PrestamosBalonModel } from '../models/prestamos-balon.model';

@Injectable()
export class PrestamosBalonLogic {
  constructor(private readonly model: PrestamosBalonModel) {}

  async listar(filtros: FiltroPrestamosBalonDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async reporteAntiguedad(filtros: FiltroPrestamosAntiguedadDto) {
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
    return mapSingleResult(result, `Préstamo ${id} no encontrado`);
  }

  async crear(dto: CreatePrestamosBalonDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el registro');
  }

  async actualizar(id: number, dto: UpdatePrestamosBalonDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, `Préstamo ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Préstamo ${id} no encontrado`);
  }
}
