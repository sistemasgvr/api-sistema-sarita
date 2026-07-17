import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateDocumentoVencimientoDto,
  FiltroDocumentoVencimientoDto,
  UpdateDocumentoVencimientoDto,
} from '../dto/documentos-vencimiento.dto';
import { DocumentosVencimientoModel } from '../models/documentos-vencimiento.model';

@Injectable()
export class DocumentosVencimientoLogic {
  constructor(private readonly documentosVencimientoModel: DocumentosVencimientoModel) {}

  async listar(filtros: FiltroDocumentoVencimientoDto) {
    const result = await this.documentosVencimientoModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.documentosVencimientoModel.obtenerPorId(id);
    return mapSingleResult(result, `Documento de vencimiento ${id} no encontrado`);
  }

  async crear(dto: CreateDocumentoVencimientoDto) {
    const result = await this.documentosVencimientoModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el documento de vencimiento');
  }

  async actualizar(id: number, dto: UpdateDocumentoVencimientoDto) {
    const result = await this.documentosVencimientoModel.actualizar(id, dto);
    return mapSingleResult(result, `Documento de vencimiento ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.documentosVencimientoModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Documento de vencimiento ${id} no encontrado o ya está inactivo`);
  }
}
