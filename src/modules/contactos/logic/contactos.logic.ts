import { Injectable } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import { FiltroContactoDto } from '../dto/filtros-contacto.dto';
import { ContactosModel } from '../models/contactos.model';
import {
  CreateContactoDto,
  UpdateContactoDto,
} from '../dto/crear-contacto.dto';

@Injectable()
export class ContactosLogic {
  constructor(private readonly contactosModel: ContactosModel) {}

  async listar(filtros: FiltroContactoDto) {
    const result = await this.contactosModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.contactosModel.obtenerPorId(id);
    return mapSingleResult(result, `Contacto ${id} no encontrado`);
  }

  async crear(dto: CreateContactoDto) {
    const result = await this.contactosModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear el contacto');
  }

  async actualizar(id: number, dto: UpdateContactoDto) {
    const result = await this.contactosModel.actualizar(id, dto);
    return mapSingleResult(result, `Contacto ${id} no encontrado`);
  }

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.contactosModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(
      result,
      `Contacto ${id} no encontrado o ya está inactivo`,
    );
  }
}
