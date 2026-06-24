import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../../database/database.service';
import { CreateEjemploDto } from '../dto/create-ejemplo.dto';
import { FiltroEjemploDto } from '../dto/filtro-ejemplo.dto';
import { UpdateEjemploDto } from '../dto/update-ejemplo.dto';

@Injectable()
export class EjemploModel {
  constructor(private readonly db: DatabaseService) {}

  listar(filtros: FiltroEjemploDto) {
    return this.db.callFunction('fn_ejemplo_listar', [
      filtros.buscar ?? null,
      filtros.soloActivos ?? true,
      filtros.pagina ?? 1,
      filtros.limite ?? 10,
    ]);
  }

  async obtenerPorId(id: number) {
    const rows = await this.db.callFunction('fn_ejemplo_obtener_por_id', [id]);
    return rows[0] ?? null;
  }

  async crear(dto: CreateEjemploDto) {
    const rows = await this.db.callFunction('fn_ejemplo_crear', [
      dto.nombre,
      dto.descripcion ?? null,
    ]);
    return rows[0];
  }

  async actualizar(id: number, dto: UpdateEjemploDto) {
    const rows = await this.db.callFunction('fn_ejemplo_actualizar', [
      id,
      dto.nombre ?? null,
      dto.descripcion ?? null,
    ]);
    return rows[0] ?? null;
  }

  async eliminar(id: number) {
    const rows = await this.db.callFunction('fn_ejemplo_eliminar', [id]);
    return rows[0] ?? null;
  }
}
