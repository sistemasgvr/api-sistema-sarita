import { BadRequestException, Injectable } from '@nestjs/common';
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
  ) {}

  async listar(filtros: FiltroTrabajadorDto) {
    const result = await this.trabajadoresModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.trabajadoresModel.obtenerPorId(id);
    return mapSingleResult(result, `Trabajador ${id} no encontrado`);
  }

  async crear(dto: CreateTrabajadorDto) {
    const result = await this.trabajadoresModel.crear(dto);
    const trabajador = mapSingleResult(result, 'No se pudo crear el trabajador');
    const idTrabajador = (trabajador as { id: number }).id;

    if (dto.crearUsuario) {
      if (!dto.correo || !dto.numeroDocumento) {
        throw new BadRequestException(
          'Para crear el usuario de acceso se requiere el correo y el número de documento del trabajador',
        );
      }
      const nombre = [dto.nombres, dto.apellidoPaterno, dto.apellidoMaterno]
        .filter((v): v is string => Boolean(v))
        .join(' ')
        .trim();
      const usuarioDto: CreateUsuarioDto = {
        nombre: nombre || dto.nombres || 'Trabajador',
        correo: dto.correo,
        contrasena: dto.numeroDocumento,
        idTrabajador,
        idRol: dto.idRol,
        idUsuarioAuditoria: dto.idUsuarioAuditoria,
      };
      await this.usuariosLogic.crear(usuarioDto);
    }

    if (dto.esChofer && dto.datosChofer) {
      await this.crearChoferEmpresa(
        idTrabajador,
        dto.datosChofer,
        dto,
        dto.idUsuarioAuditoria,
      );
    }

    return trabajador;
  }

  async actualizar(id: number, dto: UpdateTrabajadorDto) {
    const result = await this.trabajadoresModel.actualizar(id, dto);
    const trabajador = mapSingleResult(result, `Trabajador ${id} no encontrado`);
    const idTrabajador = (trabajador as { id: number }).id;

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

    return trabajador;
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
