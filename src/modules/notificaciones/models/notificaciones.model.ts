import { Injectable } from '@nestjs/common';
import {
  AuthListResult,
  AuthSingleResult,
} from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';
import { FiltroNotificacionesDto } from '../dto/notificaciones.dto';

@Injectable()
export class NotificacionesModel {
  constructor(private readonly db: DatabaseService) {}

  listar(idUsuario: number, filtros: FiltroNotificacionesDto) {
    return this.db.callFunctionJson<AuthListResult>('gen_listar_notificaciones', [
      idUsuario,
      filtros.soloNoLeidas ?? 0,
      filtros.buscar ?? '',
      filtros.limite ?? 20,
      filtros.offset,
    ]);
  }

  obtenerPorId(id: number, idUsuario: number) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_obtener_notificacion', [
      id,
      idUsuario,
    ]);
  }

  crear(params: {
    idUsuario: number;
    codigoTipo: string;
    titulo: string;
    mensaje?: string | null;
    payload?: Record<string, unknown> | null;
    idReferencia?: number | null;
    tipoReferencia?: string | null;
    claveDedupe?: string | null;
    idUsuarioAuditoria?: number | null;
  }) {
    return this.db.callFunctionJson<AuthSingleResult & { creada?: boolean }>(
      'gen_crear_notificacion',
      [
        params.idUsuario,
        params.codigoTipo,
        params.titulo,
        params.mensaje ?? null,
        JSON.stringify(params.payload ?? {}),
        params.idReferencia ?? null,
        params.tipoReferencia ?? null,
        params.claveDedupe ?? null,
        params.idUsuarioAuditoria ?? null,
      ],
    );
  }

  marcarLeida(id: number, idUsuario: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<AuthSingleResult>(
      'gen_marcar_notificacion_leida',
      [id, idUsuario, idUsuarioAuditoria ?? null],
    );
  }

  marcarTodasLeidas(idUsuario: number, idUsuarioAuditoria?: number) {
    return this.db.callFunctionJson<{ actualizadas?: number; error?: string }>(
      'gen_marcar_todas_notificaciones_leidas',
      [idUsuario, idUsuarioAuditoria ?? null],
    );
  }

  contarNoLeidas(idUsuario: number) {
    return this.db.callFunctionJson<{ total: number }>(
      'gen_contar_notificaciones_no_leidas',
      [idUsuario],
    );
  }

  listarIdsPorPermiso(permiso: string) {
    return this.db.callFunctionJson<{ ids: number[] }>(
      'auth_listar_ids_usuarios_por_permiso',
      [permiso],
    );
  }

  listarIdsAdminConPermiso(permiso: string) {
    return this.db.callFunctionJson<{ ids: number[] }>(
      'auth_listar_ids_usuarios_admin_con_permiso',
      [permiso],
    );
  }

  listarIdsPorRoles(idsRoles: number[]) {
    return this.db.callFunctionJson<{ ids: number[] }>(
      'auth_listar_ids_usuarios_por_roles',
      [JSON.stringify(idsRoles)],
    );
  }

  listarAlquileresVencidos(fecha?: string | null) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'bal_listar_alquileres_vencidos_notificar',
      [fecha ?? null],
    );
  }

  listarAlquileresPorVencer(
    diasMin = 3,
    diasMax = 7,
    fecha?: string | null,
  ) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'bal_listar_alquileres_por_vencer_notificar',
      [diasMin, diasMax, fecha ?? null],
    );
  }

  listarPrestamosVencidos(fecha?: string | null) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'bal_listar_prestamos_vencidos_notificar',
      [fecha ?? null],
    );
  }

  listarPrestamosPorVencer(
    diasMin = 3,
    diasMax = 7,
    fecha?: string | null,
  ) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'bal_listar_prestamos_por_vencer_notificar',
      [diasMin, diasMax, fecha ?? null],
    );
  }

  listarStockBajo() {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'pro_listar_stock_bajo_notificar',
      [],
    );
  }

  listarDocumentosPorVencer(
    diasMin = 3,
    diasMax = 7,
    fecha?: string | null,
  ) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'gen_listar_documentos_por_vencer_notificar',
      [diasMin, diasMax, fecha ?? null],
    );
  }

  listarDocumentosVencidos(fecha?: string | null) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'gen_listar_documentos_vencidos_notificar',
      [fecha ?? null],
    );
  }

  listarLicenciasPorVencer(
    diasMin = 3,
    diasMax = 7,
    fecha?: string | null,
  ) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'gen_listar_licencias_por_vencer_notificar',
      [diasMin, diasMax, fecha ?? null],
    );
  }

  listarLicenciasVencidas(fecha?: string | null) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'gen_listar_licencias_vencidas_notificar',
      [fecha ?? null],
    );
  }

  listarComprobantesPendientesSunat(
    diasMin = 1,
    fecha?: string | null,
  ) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'ven_listar_comprobantes_pendientes_notificar',
      [diasMin, fecha ?? null],
    );
  }

  listarGuiasPendientesSunat(diasMin = 1, fecha?: string | null) {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'gre_listar_guias_pendientes_notificar',
      [diasMin, fecha ?? null],
    );
  }

  listarCajaPendienteCierre() {
    return this.db.callFunctionJson<{ registros: unknown[] }>(
      'fin_listar_caja_pendiente_cierre',
      [null],
    );
  }
}
