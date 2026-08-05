import { Injectable } from '@nestjs/common';
import { mapSingleResult } from '../../../common/helpers/auth-response.helper';
import { ResponseHelper } from '../../../common/helpers/response.helper';
import { CreateListaOpcionDto } from '../dto/catalogos.dto';
import { CatalogosModel } from '../models/catalogos.model';

@Injectable()
export class CatalogosLogic {
  constructor(private readonly catalogosModel: CatalogosModel) {}

  private mapList<T>(data: T[] | null) {
    return ResponseHelper.success(data ?? []);
  }

  async listarListaOpciones(idLista: number) {
    const result = await this.catalogosModel.listarListaOpciones(idLista);
    return this.mapList(result);
  }

  async crearListaOpcion(idLista: number, dto: CreateListaOpcionDto) {
    const result = await this.catalogosModel.crearListaOpcion(
      idLista,
      dto.nombre,
      dto.descripcion ?? null,
      dto.idUsuarioAuditoria,
    );
    return mapSingleResult(result, 'No se pudo crear la opción de lista');
  }

  async listarPaises() {
    const result = await this.catalogosModel.listarPaises();
    return this.mapList(result);
  }

  async listarDepartamentos(idPais?: number) {
    const result = await this.catalogosModel.listarDepartamentos(idPais);
    return this.mapList(result);
  }

  async listarProvincias(idDepartamento?: number) {
    const result = await this.catalogosModel.listarProvincias(idDepartamento);
    return this.mapList(result);
  }

  async listarDistritos(idProvincia?: number) {
    const result = await this.catalogosModel.listarDistritos(idProvincia);
    return this.mapList(result);
  }
}
