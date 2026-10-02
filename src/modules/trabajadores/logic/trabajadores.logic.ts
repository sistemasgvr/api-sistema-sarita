import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  ChoferEmpresaDto,
  CreateTrabajadorDto,
  FiltroTrabajadorDto,
  UpdateTrabajadorDto,
} from '../dto/trabajadores.dto';
import { UsuariosLogic } from '../../usuarios/logic/usuarios.logic';
import { CreateUsuarioDto } from '../../usuarios/dto/usuarios.dto';
import { ChoferesLogic } from '../../choferes/logic/choferes.logic';
import { CreateChoferDto } from '../../choferes/dto/choferes.dto';
import { TrabajadoresModel } from '../models/trabajadores.model';
import { sugerirNombreUsuario } from './nombre-usuario';

type TrabajadorIdentidad = {
  nombres?: string | null;
  apellidoPaterno?: string | null;
  apellidoMaterno?: string | null;
  apellido_paterno?: string | null;
  apellido_materno?: string | null;
  idTipoDocumento?: number | null;
  id_tipo_documento?: number | null;
  numeroDocumento?: string | null;
  numero_documento?: string | null;
};

@Injectable()
export class TrabajadoresLogic {
  constructor(
    private readonly trabajadoresModel: TrabajadoresModel,
    private readonly usuariosLogic: UsuariosLogic,
    private readonly choferesLogic: ChoferesLogic,
    private readonly db: DatabaseService,
  ) {}

  async listar(filtros: FiltroTrabajadorDto) {
    const result = await this.trabajadoresModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.trabajadoresModel.obtenerPorId(id);
    return mapSingleResult(result, `Trabajador ${id} no encontrado`);
  }

  async crear(dto: CreateTrabajadorDto, permisosCaller: string[] = []) {
    this.validarAcceso(dto, permisosCaller);
    return this.db.withTransaction(() => this.crearConAcceso(dto, permisosCaller));
  }

  private async crearConAcceso(dto: CreateTrabajadorDto, permisosCaller: string[]) {
    const result = await this.trabajadoresModel.crear(dto);
    const trabajador = mapSingleResult(result, 'No se pudo crear el trabajador');
    const idTrabajador = (trabajador as { id: number }).id;

    if (dto.crearUsuario) {
      if (!dto.correo || !dto.numeroDocumento) {
        throw new BadRequestException(
          'Para crear el usuario de acceso se requiere el correo y el número de documento del trabajador',
        );
      }
      const usuarioDto: CreateUsuarioDto = {
        nombre: sugerirNombreUsuario(dto.nombres ?? '', dto.apellidoPaterno),
        correo: dto.correo,
        contrasena: dto.numeroDocumento,
        idTrabajador,
        idRol: dto.idRol,
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      };
      await this.usuariosLogic.crear(usuarioDto, permisosCaller);
    }

    if (dto.esChofer && dto.datosChofer) {
      await this.crearChoferEmpresa(
        idTrabajador,
        dto.datosChofer,
        dto,
        dto.idUsuarioAuditoria,
      );
    }

    return this.obtenerPorId(idTrabajador);
  }

  async actualizar(id: number, dto: UpdateTrabajadorDto, permisosCaller: string[] = []) {
    this.validarAcceso(dto, permisosCaller);
    return this.db.withTransaction(() => this.actualizarConAcceso(id, dto, permisosCaller));
  }

  private async actualizarConAcceso(id: number, dto: UpdateTrabajadorDto, permisosCaller: string[]) {
    const result = await this.trabajadoresModel.actualizar(id, dto);
    const trabajador = mapSingleResult(result, `Trabajador ${id} no encontrado`);
    const idTrabajador = (trabajador as { id: number }).id;

    if (dto.crearUsuario) {
      const actual = await this.obtenerPorId(id);
      if (actual.id_usuario || actual.es_usuario) {
        throw new BadRequestException('Este trabajador ya tiene un usuario vinculado');
      }
      await this.usuariosLogic.crear({
        nombre: sugerirNombreUsuario(actual.nombres ?? '', actual.apellido_paterno),
        correo: dto.correo!,
        contrasena: dto.numeroDocumento!,
        idTrabajador,
        idRol: dto.idRol,
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      }, permisosCaller);
    }

    if (dto.esChofer && dto.datosChofer) {
      // SQL devuelve snake_case (id_chofer); no asumir camelCase del mapSingleResult.
      const actual = (await this.obtenerPorId(id)) as TrabajadorIdentidad & {
        idChofer?: number | null;
        id_chofer?: number | null;
      };
      const idChoferExistente = Number(actual.idChofer ?? actual.id_chofer ?? 0) || null;
      const identidad = this.identidadChoferDesdeTrabajador(actual, dto);
      if (idChoferExistente) {
        await this.choferesLogic.actualizar(idChoferExistente, {
          idTrabajador,
          ...identidad,
          ...this.mapearDatosChofer(dto.datosChofer),
          idUsuarioAuditoria: dto.idUsuarioAuditoria,
        });
      } else {
        await this.crearChoferEmpresa(
          idTrabajador,
          dto.datosChofer,
          identidad,
          dto.idUsuarioAuditoria,
        );
      }
    } else if (dto.esChofer === false) {
      // Desmarcar chofer: baja lógica del gen_chofer vinculado (flota propia).
      const actual = (await this.obtenerPorId(id)) as {
        idChofer?: number | null;
        id_chofer?: number | null;
      };
      const idChoferExistente = Number(actual.idChofer ?? actual.id_chofer ?? 0) || null;
      if (idChoferExistente) {
        await this.choferesLogic.eliminar(idChoferExistente, dto.idUsuarioAuditoria);
      }
    }

    return this.obtenerPorId(idTrabajador);
  }

  private validarAcceso(dto: UpdateTrabajadorDto, permisos: string[]) {
    if (!dto.crearUsuario) return;
    if (!permisos.includes(PermisoBanderas.AUTH_TODO) && !permisos.includes(PermisoBanderas.USUARIOS_CREAR)) {
      throw new ForbiddenException('Necesitas permiso para crear usuarios de acceso');
    }
    if (!dto.correo?.trim() || !dto.numeroDocumento?.trim() || !dto.idRol) {
      throw new BadRequestException('Para crear el usuario indica correo, número de documento y rol de acceso');
    }
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.trabajadoresModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Trabajador ${id} no encontrado o ya está inactivo`);
  }

  private mapearDatosChofer(datos: ChoferEmpresaDto): Partial<CreateChoferDto> {
    return {
      telefono: datos.telefono,
      codigoLicencia: datos.codigoLicencia,
      fechaEmision: datos.fechaEmision,
      fechaVencimiento: datos.fechaVencimiento,
      idTipoLicencia: datos.idTipoLicencia,
      idCategoriaLicencia: datos.idCategoriaLicencia,
    };
  }

  private identidadChoferDesdeTrabajador(
    trabajador: TrabajadorIdentidad,
    override?: Partial<TrabajadorIdentidad>,
  ): Pick<
    CreateChoferDto,
    | 'nombres'
    | 'apellidoPaterno'
    | 'apellidoMaterno'
    | 'idTipoDocumento'
    | 'numeroDocumento'
  > {
    return {
      nombres: override?.nombres ?? trabajador.nombres ?? undefined,
      apellidoPaterno:
        override?.apellidoPaterno ??
        trabajador.apellidoPaterno ??
        trabajador.apellido_paterno ??
        undefined,
      apellidoMaterno:
        override?.apellidoMaterno ??
        trabajador.apellidoMaterno ??
        trabajador.apellido_materno ??
        undefined,
      idTipoDocumento:
        override?.idTipoDocumento ??
        trabajador.idTipoDocumento ??
        trabajador.id_tipo_documento ??
        undefined,
      numeroDocumento:
        override?.numeroDocumento ??
        trabajador.numeroDocumento ??
        trabajador.numero_documento ??
        undefined,
    };
  }

  private async crearChoferEmpresa(
    idTrabajador: number,
    datos: ChoferEmpresaDto,
    identidadFuente: TrabajadorIdentidad,
    idUsuarioAuditoria?: number,
  ) {
    const choferDto = {
      idTrabajador,
      idCliente: undefined,
      ...this.identidadChoferDesdeTrabajador(identidadFuente),
      ...this.mapearDatosChofer(datos),
      idUsuarioAuditoria,
    } as CreateChoferDto;
    await this.choferesLogic.crear(choferDto);
  }
}
