import { Injectable } from '@nestjs/common';
import {
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import {
  CerrarRutaPuebloDto,
  CreateRutaPuebloDto,
  FiltroRutasPueblosDto,
  RegistrarRetornoRutaPuebloDto,
  UpdateRutaPuebloDto,
} from '../dto/rutas-pueblos.dto';

@Injectable()
export class RutasPueblosModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroRutasPueblosDto) {
    return this.db.callFunctionJson<AuthListResult>('bal_listar_rutas_pueblo', [
      filtros.buscar ?? '',
      filtros.limite ?? 10,
      filtros.offset,
      filtros.estadoNombre ?? null,
      filtros.idAlmacen ?? null,
      filtros.fechaDesde ?? null,
      filtros.fechaHasta ?? null,
    ]);
  }

  obtenerPorId(id: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_obtener_ruta_pueblo', [
      id,
    ]);
  }

  crear(dto: CreateRutaPuebloDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_crear_ruta_pueblo', [
      dto.fecha ?? null,
      dto.idAlmacen,
      dto.idUsuarioResponsable ?? null,
      dto.idChofer ?? null,
      dto.factorLbM3 ?? null,
      dto.toleranciaM3 ?? null,
      dto.observacion ?? null,
      JSON.stringify(
        (dto.detalles ?? []).map((d) => ({
          idBalon: d.idBalon,
          lbSalida: d.lbSalida,
          sellado: d.sellado ?? false,
          observacion: d.observacion ?? null,
        })),
      ),
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  actualizar(id: number, dto: UpdateRutaPuebloDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'bal_actualizar_ruta_pueblo',
      [
        id,
        dto.fecha ?? null,
        dto.idAlmacen ?? null,
        dto.idUsuarioResponsable ?? null,
        dto.idChofer ?? null,
        dto.factorLbM3 ?? null,
        dto.toleranciaM3 ?? null,
        dto.observacion ?? null,
        dto.estadoNombre ?? null,
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  iniciar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_iniciar_ruta_pueblo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }

  registrarRetorno(id: number, dto: RegistrarRetornoRutaPuebloDto) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'bal_registrar_retorno_ruta_pueblo',
      [
        id,
        JSON.stringify(
          (dto.detalles ?? []).map((d) => ({
            idBalon: d.idBalon,
            lbRetorno: d.lbRetorno,
            observacion: d.observacion ?? null,
          })),
        ),
        dto.idUsuarioAuditoria ?? null,
      ],
    );
  }

  cerrar(id: number, dto: CerrarRutaPuebloDto) {
    return this.db.callFunctionJson<AuthSingleResult>('bal_cerrar_ruta_pueblo', [
      id,
      dto.m3ReportadoVentas,
      dto.observacion ?? null,
      dto.idUsuarioAuditoria ?? null,
    ]);
  }

  eliminar(id: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthDeleteResult>('bal_eliminar_ruta_pueblo', [
      id,
      idUsuarioAuditoria ?? null,
    ]);
  }
}
