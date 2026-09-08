import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import {
  AplicarLoteProtocoloDto,
  CreateLoteProtocoloDto,
  FiltroHistorialLoteProtocoloDto,
  FiltroLotesProtocoloDto,
  UpdateLoteProtocoloDto,
} from '../dto/lotes-protocolo.dto';
import { LotesProtocoloModel } from '../models/lotes-protocolo.model';

@Injectable()
export class LotesProtocoloLogic {
  constructor(private readonly model: LotesProtocoloModel) {}

  async listar(filtros: FiltroLotesProtocoloDto) {
    const result = await this.model.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.model.obtenerPorId(id);
    return mapSingleResult(result, 'Ficha de lote y protocolo no encontrada');
  }

  async crear(dto: CreateLoteProtocoloDto) {
    const result = await this.model.crear(dto);
    return mapSingleResult(
      result,
      'No se pudo registrar la ficha de lote y protocolo',
    );
  }

  async actualizar(id: number, dto: UpdateLoteProtocoloDto) {
    const result = await this.model.actualizar(id, dto);
    return mapSingleResult(result, 'Ficha de lote y protocolo no encontrada');
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.model.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, 'Ficha de lote y protocolo no encontrada');
  }

  async aplicarABalones(id: number, dto: AplicarLoteProtocoloDto) {
    if (dto.idBalones && dto.idBalones.length === 0) {
      throw new BadRequestException(
        'Envía al menos un cilindro, u omite idBalones para aplicar a los envases ya emparejados',
      );
    }
    const result = await this.model.aplicarABalones(id, dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.success({
      idLoteProtocolo: result.registro?.id_lote_protocolo ?? id,
      balonesAplicados: result.registro?.balones_aplicados ?? 0,
      envasesVinculados: result.registro?.envases_vinculados ?? 0,
    });
  }

  async historialPorBalon(
    idBalon: number,
    filtros: FiltroHistorialLoteProtocoloDto,
  ) {
    const result = await this.model.historialPorBalon(idBalon, filtros);
    if (result.error) {
      throw new NotFoundException(result.error);
    }
    const limite = filtros.limite ?? 50;
    // La ficha vigente viaja en meta.resumen: es contexto del cilindro, no una
    // fila más del historial (puede estar vigente sin recarga que la registre).
    return ResponseHelper.paginated(result.registros ?? [], {
      pagina: Math.floor((filtros.offset ?? 0) / limite) + 1,
      limite,
      total: Number(result.total ?? 0),
      resumen: { vigente: result.vigente ?? null },
    });
  }
}
