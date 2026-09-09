import { BadRequestException, Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import {
  CreateActividadDto,
  CrearRecojoOrigenDto,
  FiltroActividadesDto,
  UpdateActividadDto,
  CrearRecojoPrestamoDto,
  FiltroRankingActividadesDto,
  FiltroVencidosRecojoDto,
  GenerarRecojosDto,
  VerificarActividadDto,
} from '../dto/actividades.dto';
import { ActividadesModel } from '../models/actividades.model';

@Injectable()
export class ActividadesLogic {
  constructor(private readonly actividadesModel: ActividadesModel) {}

  async listar(filtros: FiltroActividadesDto) {
    const result = await this.actividadesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async listarProximas(minutos = 60) {
    const result = await this.actividadesModel.listarProximas(minutos);
    return result.registros ?? [];
  }

  async listarVencidosRecojo(filtros: FiltroVencidosRecojoDto) {
    const result = await this.actividadesModel.listarVencidosRecojo(filtros);
    return mapListResult(result, filtros);
  }

  async verificar(id: number, dto: VerificarActividadDto) {
    const result = await this.actividadesModel.verificar(id, dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.success({
      momento: result.registro?.momento,
      coincidencias: result.registro?.coincidencias ?? 0,
      noPertenecen: result.registro?.no_pertenecen ?? 0,
      pendientes: result.registro?.pendientes ?? 0,
      observados: result.registro?.observados ?? 0,
      completo: result.registro?.completo ?? false,
    });
  }

  async iniciarEntrega(id: number, idUsuarioAuditoria?: number) {
    const result = await this.actividadesModel.iniciarEntrega(
      id,
      idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async culminarEntrega(id: number, idUsuarioAuditoria?: number) {
    const result = await this.actividadesModel.culminarEntrega(
      id,
      idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async crearRecojoOrigen(dto: CrearRecojoOrigenDto) {
    const result = await this.actividadesModel.crearRecojoOrigen(dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.success({
      id: result.registro?.id,
      creada: result.registro?.creada ?? false,
      items: result.registro?.items ?? 0,
    });
  }

  async crearRecojoPrestamo(dto: CrearRecojoPrestamoDto) {
    const result = await this.actividadesModel.crearRecojoPrestamo(dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.success({
      id: result.registro?.id,
      creada: result.registro?.creada ?? false,
      items: result.registro?.items ?? 0,
    });
  }

  async iniciarVerificacion(id: number, idUsuarioAuditoria?: number) {
    const result = await this.actividadesModel.iniciarVerificacion(
      id,
      idUsuarioAuditoria,
    );
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    if (!result.registro) {
      throw new BadRequestException(`Actividad ${id} no encontrada`);
    }
    return result.registro;
  }

  async generarRecojosPorVencer(dto: GenerarRecojosDto) {
    const result = await this.actividadesModel.generarRecojosPorVencer(dto);
    if (result.error) {
      throw new BadRequestException(result.error);
    }
    return ResponseHelper.success({
      diasAntes: result.registro?.dias_antes,
      creadas: result.registro?.creadas ?? 0,
      yaExistian: result.registro?.ya_existian ?? 0,
      idActividades: result.registro?.id_actividades ?? [],
    });
  }

  async ranking(filtros: FiltroRankingActividadesDto) {
    const result = (await this.actividadesModel.ranking(filtros)) as {
      registros?: unknown[];
      total?: number;
    };
    return ResponseHelper.paginated(result.registros ?? [], {
      pagina: 1,
      limite: filtros.limite ?? 20,
      total: Number(result.total ?? 0),
    });
  }

  async obtenerPorId(id: number) {
    const result = await this.actividadesModel.obtenerPorId(id);
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async crear(dto: CreateActividadDto) {
    const result = await this.actividadesModel.crear(
      dto.titulo?.trim() || null,
      dto.descripcion ?? null,
      dto.fechaProgramada,
      dto.horaInicioEstimada ?? null,
      dto.horaFinEstimada ?? null,
      dto.idTipoActividad,
      dto.idPrioridad,
      dto.idCliente ?? null,
      dto.idTrabajadorResponsable ?? null,
      dto.idEstadoActividad,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria,
      dto.idComprobante ?? null,
      dto.idDocSalida ?? null,
      dto.items ?? null,
    );
    return mapSingleResult(result, 'No se pudo crear la actividad');
  }

  async actualizar(id: number, dto: UpdateActividadDto) {
    const result = await this.actividadesModel.actualizar(
      id,
      dto.titulo ?? null,
      dto.descripcion ?? null,
      dto.fechaProgramada ?? null,
      dto.horaInicioEstimada ?? null,
      dto.horaFinEstimada ?? null,
      dto.idTipoActividad ?? null,
      dto.idPrioridad ?? null,
      dto.idCliente ?? null,
      dto.idTrabajadorResponsable ?? null,
      dto.idEstadoActividad ?? null,
      dto.observaciones ?? null,
      dto.idUsuarioAuditoria,
      dto.idComprobante ?? null,
      dto.idDocSalida ?? null,
      dto.items ?? null,
    );
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.actividadesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Actividad ${id} no encontrada`);
  }

  async marcarComoRealizada(id: number, idUsuarioAuditoria?: number) {
    const result = await this.actividadesModel.marcarComoRealizada(
      id,
      idUsuarioAuditoria,
    );
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async cancelar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.actividadesModel.cancelar(id, idUsuarioAuditoria);
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }

  async asignarResponsable(
    id: number,
    idUsuarioAuditoria?: number,
    idTrabajadorResponsable?: number | null,
    idTrabajadorApoyo?: number | null,
    liberar = false,
  ) {
    const result = await this.actividadesModel.asignarResponsable(
      id,
      idUsuarioAuditoria,
      idTrabajadorResponsable,
      idTrabajadorApoyo,
      liberar,
    );
    return mapSingleResult(result, `Actividad ${id} no encontrada`);
  }
}
