import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  AplicarLoteProtocoloDto,
  CreateLoteProtocoloDto,
  FiltroHistorialLoteProtocoloDto,
  FiltroLotesProtocoloDto,
  UpdateLoteProtocoloDto,
} from '../dto/lotes-protocolo.dto';
import {
  AplicarLoteProtocoloResult,
  LoteProtocoloHistorialResult,
} from '../interfaces/lote-protocolo.interface';

@Injectable()
export class LotesProtocoloModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroLotesProtocoloDto) {
    return this.db.callFunctionJson<AuthListResult>(
      'bal_listar_lotes_protocolo',
      [
        filtros.buscar ?? '',
        filtros.limite ?? 10,
        filtros.offset,
        filtros.idProveedor ?? null,
        filtros.idProductoGas ?? null,
        filtros.vencidos ?? null,
        filtros.fechaDesde ?? null,
        filtros.fechaHasta ?? null,
      ],
    );
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'bal_obtener_lote_protocolo',
      [id],
    );
  }

  crear(dto: CreateLoteProtocoloDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'bal_crear_lote_protocolo',
      [
        dto.numeroLote,
        dto.numeroProtocolo ?? null,
        dto.idProveedor ?? null,
        dto.idProductoGas ?? null,
        dto.descripcionProducto ?? null,
        dto.formaFarmaceutica ?? null,
        dto.presentacion ?? null,
        dto.normaTecnica ?? null,
        dto.metodoFabricacion ?? null,
        dto.fechaAnalisis ?? null,
        dto.fechaEmision ?? null,
        dto.fechaFabricacion ?? null,
        dto.fechaVencimiento ?? null,
        dto.tamanoLoteM3 ?? null,
        dto.cantidadEnvases ?? null,
        dto.valoracionO2Pct ?? null,
        dto.limiteCo2Ppm ?? null,
        dto.limiteCoPpm ?? null,
        dto.cilindroMuestreadoSerie ?? null,
        dto.temperaturaMuestreoC ?? null,
        dto.presionMuestreoPsi ?? null,
        dto.analista ?? null,
        dto.conclusion ?? null,
        dto.codigoDocumento ?? null,
        dto.versionDocumento ?? null,
        dto.idArchivoPdf ?? null,
        dto.observacion ?? null,
        dto.pruebas ? JSON.stringify(dto.pruebas) : null,
        dto.envases ? JSON.stringify(dto.envases) : null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  actualizar(id: number, dto: UpdateLoteProtocoloDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'bal_actualizar_lote_protocolo',
      [
        id,
        dto.numeroLote ?? null,
        dto.numeroProtocolo ?? null,
        dto.idProveedor ?? null,
        dto.idProductoGas ?? null,
        dto.descripcionProducto ?? null,
        dto.formaFarmaceutica ?? null,
        dto.presentacion ?? null,
        dto.normaTecnica ?? null,
        dto.metodoFabricacion ?? null,
        dto.fechaAnalisis ?? null,
        dto.fechaEmision ?? null,
        dto.fechaFabricacion ?? null,
        dto.fechaVencimiento ?? null,
        dto.tamanoLoteM3 ?? null,
        dto.cantidadEnvases ?? null,
        dto.valoracionO2Pct ?? null,
        dto.limiteCo2Ppm ?? null,
        dto.limiteCoPpm ?? null,
        dto.cilindroMuestreadoSerie ?? null,
        dto.temperaturaMuestreoC ?? null,
        dto.presionMuestreoPsi ?? null,
        dto.analista ?? null,
        dto.conclusion ?? null,
        dto.codigoDocumento ?? null,
        dto.versionDocumento ?? null,
        dto.idArchivoPdf ?? null,
        dto.observacion ?? null,
        dto.pruebas ? JSON.stringify(dto.pruebas) : null,
        dto.envases ? JSON.stringify(dto.envases) : null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>(
      'bal_eliminar_lote_protocolo',
      [id, idUsuarioAuditoria ?? null],
    );
  }

  aplicarABalones(id: number, dto: AplicarLoteProtocoloDto) {
    return this.db.callFunctionJson<AplicarLoteProtocoloResult>(
      'bal_aplicar_lote_protocolo_balones',
      [
        id,
        dto.idBalones ? JSON.stringify(dto.idBalones) : null,
        dto.idUsuarioAuditoria ?? null,
        dto.idDocSalida ?? null,
      ],
    );
  }

  historialPorBalon(idBalon: number, filtros: FiltroHistorialLoteProtocoloDto) {
    return this.db.callFunctionJson<LoteProtocoloHistorialResult>(
      'bal_historial_lote_protocolo_balon',
      [idBalon, filtros.limite ?? 50, filtros.offset ?? 0],
    );
  }
}
