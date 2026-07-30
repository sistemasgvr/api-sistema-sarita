import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  TipoNotificacion,
  TipoReferenciaNotificacion,
} from '../constants/tipo-notificacion';
import {
  CrearNotificacionDto,
  FiltroNotificacionesDto,
} from '../dto/notificaciones.dto';
import { NotificacionesGateway } from '../gateways/notificaciones.gateway';
import { NotificacionesModel } from '../models/notificaciones.model';

export interface NotificacionRegistro {
  id: number;
  id_usuario: number;
  codigo_tipo: string;
  titulo: string;
  mensaje?: string | null;
  payload?: Record<string, unknown>;
  id_referencia?: number | null;
  tipo_referencia?: string | null;
  clave_dedupe?: string | null;
  leida: boolean;
  fecha_lectura?: string | null;
  fecha_creacion?: string;
}

interface AlquilerRow {
  id: number;
  nombre_cliente?: string | null;
  fecha_vencimiento?: string;
  dias_vencido?: number;
  dias_para_vencer?: number;
  id_periodo?: number | null;
  numero_periodo?: number | null;
}

interface PrestamoRow {
  id_detalle: number;
  id_prestamo: number;
  numero_prestamo?: string | null;
  nombre_cliente?: string | null;
  codigo_balon?: string | null;
  fecha_vencimiento?: string;
  dias_vencido?: number;
  dias_para_vencer?: number;
}

interface StockBajoRow {
  id: number;
  id_almacen?: number;
  nombre_almacen?: string | null;
  id_producto?: number;
  codigo_producto?: string | null;
  nombre_producto?: string | null;
  stock?: number;
  stock_minimo?: number;
  es_cero?: boolean;
}

interface DocumentoVencimientoRow {
  id: number;
  descripcion?: string | null;
  numero_documento?: string | null;
  fecha_vencimiento?: string;
  dias_vencido?: number;
  dias_para_vencer?: number;
  nombre_categoria?: string | null;
  id_vehiculo?: number | null;
  vehiculo_placa?: string | null;
}

interface LicenciaRow {
  id: number;
  codigo?: string | null;
  fecha_vencimiento?: string;
  dias_vencido?: number;
  dias_para_vencer?: number;
  nombre_tipo_licencia?: string | null;
  chofer_nombre?: string | null;
  id_chofer?: number | null;
}

interface ComprobantePendienteRow {
  id: number;
  serie?: string | null;
  numero?: string | null;
  fecha?: string;
  dias_pendiente?: number;
  ticket_sunat?: string | null;
  codigo_tipo_comprobante?: string | null;
}

interface GuiaPendienteRow {
  id: number;
  serie?: string | null;
  numero?: string | null;
  fecha?: string;
  dias_pendiente?: number;
  ticket_sunat?: string | null;
}

@Injectable()
export class NotificacionesLogic {
  private readonly logger = new Logger(NotificacionesLogic.name);

  constructor(
    private readonly model: NotificacionesModel,
    private readonly gateway: NotificacionesGateway,
  ) {}

  async listar(idUsuario: number, filtros: FiltroNotificacionesDto) {
    const result = await this.model.listar(idUsuario, filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number, idUsuario: number) {
    const result = await this.model.obtenerPorId(id, idUsuario);
    return mapSingleResult(result, `Notificación ${id} no encontrada`);
  }

  async contarNoLeidas(idUsuario: number) {
    const result = await this.model.contarNoLeidas(idUsuario);
    return { total: result.total ?? 0 };
  }

  async marcarLeida(id: number, idUsuario: number) {
    const result = await this.model.marcarLeida(id, idUsuario, idUsuario);
    return mapSingleResult(result, `Notificación ${id} no encontrada`);
  }

  async marcarTodasLeidas(idUsuario: number) {
    const result = await this.model.marcarTodasLeidas(idUsuario, idUsuario);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return { actualizadas: result.actualizadas ?? 0 };
  }

  async enviar(dto: CrearNotificacionDto, idUsuarioAuditoria?: number) {
    const destinatarios = await this.resolverDestinatarios(dto);
    if (destinatarios.length === 0) {
      throw new BadRequestException('No se encontraron destinatarios');
    }

    const creadas: NotificacionRegistro[] = [];
    for (const idUsuario of destinatarios) {
      const registro = await this.crearYEmitir({
        idUsuario,
        codigoTipo: dto.codigoTipo,
        titulo: dto.titulo,
        mensaje: dto.mensaje,
        payload: dto.payload,
        idReferencia: dto.idReferencia,
        tipoReferencia: dto.tipoReferencia,
        claveDedupe: dto.claveDedupe,
        idUsuarioAuditoria,
      });
      if (registro) creadas.push(registro);
    }

    return {
      destinatarios: destinatarios.length,
      creadas: creadas.length,
      registros: creadas,
    };
  }

  async crearYEmitir(params: {
    idUsuario: number;
    codigoTipo: string;
    titulo: string;
    mensaje?: string;
    payload?: Record<string, unknown>;
    idReferencia?: number;
    tipoReferencia?: string;
    claveDedupe?: string;
    idUsuarioAuditoria?: number;
  }): Promise<NotificacionRegistro | null> {
    const result = await this.model.crear({
      idUsuario: params.idUsuario,
      codigoTipo: params.codigoTipo,
      titulo: params.titulo,
      mensaje: params.mensaje ?? null,
      payload: params.payload ?? {},
      idReferencia: params.idReferencia ?? null,
      tipoReferencia: params.tipoReferencia ?? null,
      claveDedupe: params.claveDedupe ?? null,
      idUsuarioAuditoria: params.idUsuarioAuditoria ?? null,
    });

    if (result.error || !result.registro) {
      this.logger.warn(
        `No se creó notificación para user ${params.idUsuario}: ${result.error ?? 'sin registro'}`,
      );
      return null;
    }

    const registro = result.registro as NotificacionRegistro;
    if (result.creada !== false) {
      this.gateway.emitToUser(params.idUsuario, registro);
    }
    return result.creada === false ? null : registro;
  }

  async notificarPorPermiso(params: {
    permiso: string;
    codigoTipo: string;
    titulo: string;
    mensaje?: string;
    payload?: Record<string, unknown>;
    idReferencia?: number;
    tipoReferencia?: string;
    claveDedupePrefix?: string;
    excluirUsuarioId?: number;
    idUsuarioAuditoria?: number;
    soloAdmins?: boolean;
  }) {
    const byPermiso = params.soloAdmins
      ? await this.model.listarIdsAdminConPermiso(params.permiso)
      : await this.model.listarIdsPorPermiso(params.permiso);
    let destinatarios = this.normalizeIds(byPermiso.ids);
    if (params.excluirUsuarioId) {
      destinatarios = destinatarios.filter((id) => id !== params.excluirUsuarioId);
    }

    if (destinatarios.length === 0) {
      this.logger.warn(
        `Sin destinatarios para permiso ${params.permiso} (${params.codigoTipo})`,
      );
      return { destinatarios: 0, creadas: 0 };
    }

    let creadas = 0;
    for (const idUsuario of destinatarios) {
      const claveDedupe = params.claveDedupePrefix
        ? `${params.claveDedupePrefix}:${idUsuario}`
        : undefined;
      const registro = await this.crearYEmitir({
        idUsuario,
        codigoTipo: params.codigoTipo,
        titulo: params.titulo,
        mensaje: params.mensaje,
        payload: params.payload,
        idReferencia: params.idReferencia,
        tipoReferencia: params.tipoReferencia,
        claveDedupe,
        idUsuarioAuditoria: params.idUsuarioAuditoria,
      });
      if (registro) creadas += 1;
    }

    return { destinatarios: destinatarios.length, creadas };
  }

  async detectarYNotificarAlquileresVencidos(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarAlquileresVencidos();
    const alquileres = (raw.registros ?? []) as AlquilerRow[];
    return this.notificarAlquileres({
      alquileres,
      codigoTipo: TipoNotificacion.ALQUILER_VENCIDO,
      titulo: 'Alquiler vencido',
      mensajeFn: (a) => {
        const nombre = a.nombre_cliente?.trim() || `Alquiler #${a.id}`;
        const dias = Number(a.dias_vencido ?? 0);
        return dias > 0
          ? `${nombre} venció hace ${dias} día(s) (${a.fecha_vencimiento}).`
          : `${nombre} tiene la fecha de vencimiento ${a.fecha_vencimiento}.`;
      },
      clavePrefix: 'ALQUILER_VENCIDO',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarAlquileresPorVencer(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarAlquileresPorVencer(3, 7);
    const alquileres = (raw.registros ?? []) as AlquilerRow[];
    return this.notificarAlquileres({
      alquileres,
      codigoTipo: TipoNotificacion.ALQUILER_POR_VENCER,
      titulo: 'Alquiler por vencer',
      mensajeFn: (a) => {
        const nombre = a.nombre_cliente?.trim() || `Alquiler #${a.id}`;
        const dias = Number(a.dias_para_vencer ?? 0);
        return `${nombre} vence en ${dias} día(s) (${a.fecha_vencimiento}).`;
      },
      clavePrefix: 'ALQUILER_POR_VENCER',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarPrestamosVencidos(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarPrestamosVencidos();
    const prestamos = (raw.registros ?? []) as PrestamoRow[];
    return this.notificarPrestamos({
      prestamos,
      codigoTipo: TipoNotificacion.PRESTAMO_VENCIDO,
      titulo: 'Préstamo vencido',
      mensajeFn: (p) => {
        const cliente = p.nombre_cliente?.trim() || 'Cliente';
        const cilindro = p.codigo_balon || `detalle #${p.id_detalle}`;
        const dias = Number(p.dias_vencido ?? 0);
        return `${cliente} · ${p.numero_prestamo ?? 'Préstamo'} · cilindro ${cilindro} venció hace ${dias} día(s) (${p.fecha_vencimiento}).`;
      },
      clavePrefix: 'PRESTAMO_VENCIDO',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarPrestamosPorVencer(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarPrestamosPorVencer(3, 7);
    const prestamos = (raw.registros ?? []) as PrestamoRow[];
    return this.notificarPrestamos({
      prestamos,
      codigoTipo: TipoNotificacion.PRESTAMO_POR_VENCER,
      titulo: 'Préstamo por vencer',
      mensajeFn: (p) => {
        const cliente = p.nombre_cliente?.trim() || 'Cliente';
        const cilindro = p.codigo_balon || `detalle #${p.id_detalle}`;
        const dias = Number(p.dias_para_vencer ?? 0);
        return `${cliente} · ${p.numero_prestamo ?? 'Préstamo'} · cilindro ${cilindro} vence en ${dias} día(s) (${p.fecha_vencimiento}).`;
      },
      clavePrefix: 'PRESTAMO_POR_VENCER',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarStockBajo(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarStockBajo();
    const items = (raw.registros ?? []) as StockBajoRow[];
    const destinatarios = this.normalizeIds(
      (await this.model.listarIdsPorPermiso(PermisoBanderas.STOCK_LISTAR)).ids,
    );

    if (destinatarios.length === 0) {
      return { items: items.length, destinatarios: 0, notificaciones: 0 };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const item of items) {
      const esCero = Boolean(item.es_cero) || Number(item.stock ?? 0) <= 0;
      const codigoTipo = esCero
        ? TipoNotificacion.STOCK_CERO
        : TipoNotificacion.STOCK_BAJO;
      const titulo = esCero ? 'Stock en cero' : 'Stock bajo';
      const producto =
        [item.codigo_producto, item.nombre_producto].filter(Boolean).join(' — ') ||
        `Producto #${item.id_producto}`;
      const mensaje = esCero
        ? `${producto} sin stock en ${item.nombre_almacen ?? 'almacén'} (mín. ${item.stock_minimo ?? 0}).`
        : `${producto} bajo mínimo en ${item.nombre_almacen ?? 'almacén'}: ${item.stock} / mín. ${item.stock_minimo}.`;

      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo,
          titulo,
          mensaje,
          payload: {
            idStock: item.id,
            idAlmacen: item.id_almacen,
            idProducto: item.id_producto,
            stock: item.stock,
            stockMinimo: item.stock_minimo,
            esCero,
          },
          idReferencia: item.id,
          tipoReferencia: TipoReferenciaNotificacion.STOCK,
          claveDedupe: `${codigoTipo}:${item.id}:${hoy}`,
          idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `Stock bajo/cero: ${items.length} | destinatarios: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      items: items.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  async detectarYNotificarDocumentosPorVencer(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarDocumentosPorVencer(3, 7);
    const docs = (raw.registros ?? []) as DocumentoVencimientoRow[];
    return this.notificarDocumentos({
      docs,
      codigoTipo: TipoNotificacion.DOCUMENTO_POR_VENCER,
      titulo: 'Documento por vencer',
      mensajeFn: (d) => {
        const label =
          [d.nombre_categoria, d.descripcion || d.numero_documento]
            .filter(Boolean)
            .join(' · ') || `Documento #${d.id}`;
        const placa = d.vehiculo_placa ? ` (${d.vehiculo_placa})` : '';
        return `${label}${placa} vence en ${Number(d.dias_para_vencer ?? 0)} día(s) (${d.fecha_vencimiento}).`;
      },
      clavePrefix: 'DOCUMENTO_POR_VENCER',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarDocumentosVencidos(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarDocumentosVencidos();
    const docs = (raw.registros ?? []) as DocumentoVencimientoRow[];
    return this.notificarDocumentos({
      docs,
      codigoTipo: TipoNotificacion.DOCUMENTO_VENCIDO,
      titulo: 'Documento vencido',
      mensajeFn: (d) => {
        const label =
          [d.nombre_categoria, d.descripcion || d.numero_documento]
            .filter(Boolean)
            .join(' · ') || `Documento #${d.id}`;
        const placa = d.vehiculo_placa ? ` (${d.vehiculo_placa})` : '';
        return `${label}${placa} venció hace ${Number(d.dias_vencido ?? 0)} día(s) (${d.fecha_vencimiento}).`;
      },
      clavePrefix: 'DOCUMENTO_VENCIDO',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarLicenciasPorVencer(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarLicenciasPorVencer(3, 7);
    const licencias = (raw.registros ?? []) as LicenciaRow[];
    return this.notificarLicencias({
      licencias,
      codigoTipo: TipoNotificacion.LICENCIA_POR_VENCER,
      titulo: 'Licencia por vencer',
      mensajeFn: (l) => {
        const chofer = l.chofer_nombre?.trim() || 'Chofer';
        const codigo = l.codigo || `#${l.id}`;
        return `${chofer} · licencia ${codigo} vence en ${Number(l.dias_para_vencer ?? 0)} día(s) (${l.fecha_vencimiento}).`;
      },
      clavePrefix: 'LICENCIA_POR_VENCER',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarLicenciasVencidas(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarLicenciasVencidas();
    const licencias = (raw.registros ?? []) as LicenciaRow[];
    return this.notificarLicencias({
      licencias,
      codigoTipo: TipoNotificacion.LICENCIA_VENCIDA,
      titulo: 'Licencia vencida',
      mensajeFn: (l) => {
        const chofer = l.chofer_nombre?.trim() || 'Chofer';
        const codigo = l.codigo || `#${l.id}`;
        return `${chofer} · licencia ${codigo} venció hace ${Number(l.dias_vencido ?? 0)} día(s) (${l.fecha_vencimiento}).`;
      },
      clavePrefix: 'LICENCIA_VENCIDA',
      idUsuarioAuditoria,
    });
  }

  async detectarYNotificarComprobantesPendientesSunat(
    idUsuarioAuditoria?: number,
  ) {
    const raw = await this.model.listarComprobantesPendientesSunat(1);
    const items = (raw.registros ?? []) as ComprobantePendienteRow[];
    const destinatarios = this.normalizeIds(
      (await this.model.listarIdsPorPermiso(PermisoBanderas.COMPROBANTES_EMITIR))
        .ids,
    );

    if (destinatarios.length === 0) {
      return { items: items.length, destinatarios: 0, notificaciones: 0 };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const item of items) {
      const doc =
        [item.serie, item.numero].filter(Boolean).join('-') ||
        `Comprobante #${item.id}`;
      const mensaje = `${doc} lleva ${Number(item.dias_pendiente ?? 0)} día(s) pendiente en SUNAT (ticket ${item.ticket_sunat ?? '—'}). Consulta el CDR.`;

      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo: TipoNotificacion.COMPROBANTE_SUNAT_PENDIENTE,
          titulo: 'Comprobante pendiente en SUNAT',
          mensaje,
          payload: {
            idComprobante: item.id,
            serie: item.serie,
            numero: item.numero,
            fecha: item.fecha,
            diasPendiente: item.dias_pendiente,
            ticketSunat: item.ticket_sunat,
          },
          idReferencia: item.id,
          tipoReferencia: TipoReferenciaNotificacion.COMPROBANTE,
          claveDedupe: `COMPROBANTE_SUNAT_PENDIENTE:${item.id}:${hoy}`,
          idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `Comprobantes PENDIENTE: ${items.length} | dest: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      items: items.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  async detectarYNotificarGuiasPendientesSunat(idUsuarioAuditoria?: number) {
    const raw = await this.model.listarGuiasPendientesSunat(1);
    const items = (raw.registros ?? []) as GuiaPendienteRow[];
    const destinatarios = this.normalizeIds(
      (
        await this.model.listarIdsPorPermiso(PermisoBanderas.GUIAS_REMISION_EMITIR)
      ).ids,
    );

    if (destinatarios.length === 0) {
      return { items: items.length, destinatarios: 0, notificaciones: 0 };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const item of items) {
      const doc =
        [item.serie, item.numero].filter(Boolean).join('-') ||
        `Guía #${item.id}`;
      const mensaje = `${doc} lleva ${Number(item.dias_pendiente ?? 0)} día(s) pendiente en SUNAT (ticket ${item.ticket_sunat ?? '—'}). Consulta el estado.`;

      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo: TipoNotificacion.GUIA_SUNAT_PENDIENTE,
          titulo: 'Guía de remisión pendiente en SUNAT',
          mensaje,
          payload: {
            idGuia: item.id,
            serie: item.serie,
            numero: item.numero,
            fecha: item.fecha,
            diasPendiente: item.dias_pendiente,
            ticketSunat: item.ticket_sunat,
          },
          idReferencia: item.id,
          tipoReferencia: TipoReferenciaNotificacion.GUIA_REMISION,
          claveDedupe: `GUIA_SUNAT_PENDIENTE:${item.id}:${hoy}`,
          idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `Guías PENDIENTE: ${items.length} | dest: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      items: items.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  private async notificarDocumentos(params: {
    docs: DocumentoVencimientoRow[];
    codigoTipo: string;
    titulo: string;
    mensajeFn: (d: DocumentoVencimientoRow) => string;
    clavePrefix: string;
    idUsuarioAuditoria?: number;
  }) {
    const destinatarios = this.normalizeIds(
      (
        await this.model.listarIdsPorPermiso(
          PermisoBanderas.DOCUMENTOS_VENCIMIENTO_LISTAR,
        )
      ).ids,
    );

    if (destinatarios.length === 0) {
      return {
        documentos: params.docs.length,
        destinatarios: 0,
        notificaciones: 0,
      };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const doc of params.docs) {
      const mensaje = params.mensajeFn(doc);
      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo: params.codigoTipo,
          titulo: params.titulo,
          mensaje,
          payload: {
            idDocumento: doc.id,
            descripcion: doc.descripcion,
            numeroDocumento: doc.numero_documento,
            fechaVencimiento: doc.fecha_vencimiento,
            idVehiculo: doc.id_vehiculo,
            vehiculoPlaca: doc.vehiculo_placa,
            nombreCategoria: doc.nombre_categoria,
          },
          idReferencia: doc.id,
          tipoReferencia: TipoReferenciaNotificacion.DOCUMENTO_VENCIMIENTO,
          claveDedupe: `${params.clavePrefix}:${doc.id}:${hoy}`,
          idUsuarioAuditoria: params.idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `${params.clavePrefix}: ${params.docs.length} | dest: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      documentos: params.docs.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  private async notificarLicencias(params: {
    licencias: LicenciaRow[];
    codigoTipo: string;
    titulo: string;
    mensajeFn: (l: LicenciaRow) => string;
    clavePrefix: string;
    idUsuarioAuditoria?: number;
  }) {
    const destinatarios = this.normalizeIds(
      (await this.model.listarIdsPorPermiso(PermisoBanderas.LICENCIAS_LISTAR))
        .ids,
    );

    if (destinatarios.length === 0) {
      return {
        licencias: params.licencias.length,
        destinatarios: 0,
        notificaciones: 0,
      };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const licencia of params.licencias) {
      const mensaje = params.mensajeFn(licencia);
      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo: params.codigoTipo,
          titulo: params.titulo,
          mensaje,
          payload: {
            idLicencia: licencia.id,
            codigo: licencia.codigo,
            fechaVencimiento: licencia.fecha_vencimiento,
            idChofer: licencia.id_chofer,
            choferNombre: licencia.chofer_nombre,
            nombreTipo: licencia.nombre_tipo_licencia,
          },
          idReferencia: licencia.id,
          tipoReferencia: TipoReferenciaNotificacion.LICENCIA,
          claveDedupe: `${params.clavePrefix}:${licencia.id}:${hoy}`,
          idUsuarioAuditoria: params.idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `${params.clavePrefix}: ${params.licencias.length} | dest: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      licencias: params.licencias.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  private async notificarAlquileres(params: {
    alquileres: AlquilerRow[];
    codigoTipo: string;
    titulo: string;
    mensajeFn: (a: AlquilerRow) => string;
    clavePrefix: string;
    idUsuarioAuditoria?: number;
  }) {
    const destinatarios = this.normalizeIds(
      (
        await this.model.listarIdsPorPermiso(PermisoBanderas.ALQUILERES_BALON_LISTAR)
      ).ids,
    );

    if (destinatarios.length === 0) {
      return {
        alquileres: params.alquileres.length,
        destinatarios: 0,
        notificaciones: 0,
      };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const alquiler of params.alquileres) {
      const mensaje = params.mensajeFn(alquiler);
      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo: params.codigoTipo,
          titulo: params.titulo,
          mensaje,
          payload: {
            idAlquiler: alquiler.id,
            idPeriodo: alquiler.id_periodo,
            numeroPeriodo: alquiler.numero_periodo,
            fechaVencimiento: alquiler.fecha_vencimiento,
            diasVencido: alquiler.dias_vencido,
            diasParaVencer: alquiler.dias_para_vencer,
            nombreCliente: alquiler.nombre_cliente,
          },
          idReferencia: alquiler.id,
          tipoReferencia: TipoReferenciaNotificacion.ALQUILER,
          claveDedupe: `${params.clavePrefix}:${alquiler.id}:${hoy}`,
          idUsuarioAuditoria: params.idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `${params.clavePrefix}: ${params.alquileres.length} | dest: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      alquileres: params.alquileres.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  private async notificarPrestamos(params: {
    prestamos: PrestamoRow[];
    codigoTipo: string;
    titulo: string;
    mensajeFn: (p: PrestamoRow) => string;
    clavePrefix: string;
    idUsuarioAuditoria?: number;
  }) {
    const destinatarios = this.normalizeIds(
      (
        await this.model.listarIdsPorPermiso(PermisoBanderas.PRESTAMOS_BALON_LISTAR)
      ).ids,
    );

    if (destinatarios.length === 0) {
      return {
        prestamos: params.prestamos.length,
        destinatarios: 0,
        notificaciones: 0,
      };
    }

    const hoy = new Date().toISOString().slice(0, 10);
    let notificaciones = 0;

    for (const prestamo of params.prestamos) {
      const mensaje = params.mensajeFn(prestamo);
      for (const idUsuario of destinatarios) {
        const creado = await this.crearYEmitir({
          idUsuario,
          codigoTipo: params.codigoTipo,
          titulo: params.titulo,
          mensaje,
          payload: {
            idDetalle: prestamo.id_detalle,
            idPrestamo: prestamo.id_prestamo,
            numeroPrestamo: prestamo.numero_prestamo,
            codigoBalon: prestamo.codigo_balon,
            fechaVencimiento: prestamo.fecha_vencimiento,
            diasVencido: prestamo.dias_vencido,
            diasParaVencer: prestamo.dias_para_vencer,
            nombreCliente: prestamo.nombre_cliente,
          },
          idReferencia: prestamo.id_detalle,
          tipoReferencia: TipoReferenciaNotificacion.PRESTAMO,
          claveDedupe: `${params.clavePrefix}:${prestamo.id_detalle}:${hoy}`,
          idUsuarioAuditoria: params.idUsuarioAuditoria,
        });
        if (creado) notificaciones += 1;
      }
    }

    this.logger.log(
      `${params.clavePrefix}: ${params.prestamos.length} | dest: ${destinatarios.length} | notifs: ${notificaciones}`,
    );

    return {
      prestamos: params.prestamos.length,
      destinatarios: destinatarios.length,
      notificaciones,
    };
  }

  private async resolverDestinatarios(dto: CrearNotificacionDto): Promise<number[]> {
    const ids = new Set<number>();

    if (dto.idUsuario) ids.add(dto.idUsuario);
    for (const id of dto.idsUsuarios ?? []) {
      if (id) ids.add(id);
    }

    if (dto.idsRoles?.length) {
      const byRoles = await this.model.listarIdsPorRoles(dto.idsRoles);
      for (const id of this.normalizeIds(byRoles.ids)) ids.add(id);
    }

    if (dto.permiso?.trim()) {
      const byPermiso = await this.model.listarIdsPorPermiso(dto.permiso.trim());
      for (const id of this.normalizeIds(byPermiso.ids)) ids.add(id);
    }

    return [...ids];
  }

  private normalizeIds(ids: unknown): number[] {
    if (!Array.isArray(ids)) return [];
    return ids
      .map((id) => Number(id))
      .filter((id) => Number.isInteger(id) && id > 0);
  }
}
