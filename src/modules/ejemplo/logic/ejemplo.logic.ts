import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateEjemploDto } from '../dto/create-ejemplo.dto';
import { FiltroEjemploDto } from '../dto/filtro-ejemplo.dto';
import { UpdateEjemploDto } from '../dto/update-ejemplo.dto';
import { EjemploModel } from '../models/ejemplo.model';

@Injectable()
export class EjemploLogic {
  constructor(private readonly ejemploModel: EjemploModel) {}

  listar(filtros: FiltroEjemploDto) {
    return this.ejemploModel.listar(filtros);
  }

  async obtenerPorId(id: number) {
    const registro = await this.ejemploModel.obtenerPorId(id);

    if (!registro) {
      throw new NotFoundException(`Registro ${id} no encontrado`);
    }

    return registro;
  }

  crear(dto: CreateEjemploDto) {
    return this.ejemploModel.crear(dto);
  }

  async actualizar(id: number, dto: UpdateEjemploDto) {
    await this.obtenerPorId(id);

    const actualizado = await this.ejemploModel.actualizar(id, dto);

    if (!actualizado) {
      throw new NotFoundException(`No se pudo actualizar el registro ${id}`);
    }

    return actualizado;
  }

  async eliminar(id: number) {
    await this.obtenerPorId(id);

    const eliminado = await this.ejemploModel.eliminar(id);

    if (!eliminado) {
      throw new NotFoundException(`No se pudo eliminar el registro ${id}`);
    }

    return eliminado;
  }
}
