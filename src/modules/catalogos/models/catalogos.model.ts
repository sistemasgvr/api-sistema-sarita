import { Injectable } from '@nestjs/common';
import { AuthSingleResult } from '../../../common/interfaces/auth-db.interface';
import { DatabaseService } from '../../../database/database.service';

@Injectable()
export class CatalogosModel {
  constructor(private readonly db: DatabaseService) {}

  listarListaOpciones(idLista: number) {
    return this.db.callFunctionJson<unknown[]>('gen_listar_lista_opciones', [
      idLista,
    ]);
  }

  crearListaOpcion(
    idLista: number,
    nombre: string,
    descripcion: string | null,
    idUsuarioAuditoria?: number,
  ) {
    return this.db.callFunctionJson<AuthSingleResult>('gen_crear_lista_opcion', [
      idLista,
      nombre,
      descripcion,
      idUsuarioAuditoria ?? null,
    ]);
  }

  listarPaises() {
    return this.db.callFunctionJson<unknown[]>('gen_listar_paises', []);
  }

  listarDepartamentos(idPais?: number) {
    return this.db.callFunctionJson<unknown[]>('gen_listar_departamentos', [
      idPais ?? null,
    ]);
  }

  listarProvincias(idDepartamento?: number) {
    return this.db.callFunctionJson<unknown[]>('gen_listar_provincias', [
      idDepartamento ?? null,
    ]);
  }

  listarDistritos(idProvincia?: number) {
    return this.db.callFunctionJson<unknown[]>('gen_listar_distritos', [
      idProvincia ?? null,
    ]);
  }
}
