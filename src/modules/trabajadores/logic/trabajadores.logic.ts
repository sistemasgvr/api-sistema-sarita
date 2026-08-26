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
      await this.crearChoferEmpresa(idTrabajador, dto.datosChofer, dto.idUsuarioAuditoria);
    }

    return trabajador;
  }

  async actualizar(id: number, dto: UpdateTrabajadorDto) {
    const result = await this.trabajadoresModel.actualizar(id, dto);
    const trabajador = mapSingleResult(result, `Trabajador ${id} no encontrado`);
    const idTrabajador = (trabajador as { id: number }).id;

    if (dto.esChofer && dto.datosChofer) {
      const actual = (await this.obtenerPorId(id)) as { idChofer?: number };
      if (actual.idChofer) {
        await this.choferesLogic.actualizar(actual.idChofer, {
          idTrabajador,
          ...this.mapearDatosChofer(dto.datosChofer),
          idUsuarioAuditoria: dto.idUsuarioAuditoria,
        });
      } else {
        await this.crearChoferEmpresa(idTrabajador, dto.datosChofer, dto.idUsuarioAuditoria);
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

  private async crearChoferEmpresa(
    idTrabajador: number,
    datos: ChoferEmpresaDto,
    idUsuarioAuditoria?: number,
  ) {
    const choferDto = {
      idTrabajador,
      idCliente: undefined,
      ...this.mapearDatosChofer(datos),
      idUsuarioAuditoria,
    } as CreateChoferDto;
    await this.choferesLogic.crear(choferDto);
  }
}
