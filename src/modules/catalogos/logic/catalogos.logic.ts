import { Injectable } from '@nestjs/common';
import { ResponseHelper } from '../../../common/helpers/response.helper';
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
