import { Injectable, BadRequestException } from '@nestjs/common';
import {
  mapDeleteResult,
  mapListResult,
  mapSingleResult,
} from '../../../common/helpers/auth-response.helper';
import {
  CreateDireccionDto,
  FiltroDireccionesDto,
  UpdateDireccionDto,
} from '../dto/filtros-direcciones.dto';
import { DireccionesModel } from '../models/direcciones.model';

export interface CoordenadasResult {
  latitud: number;
  longitud: number;
}
@Injectable()
export class DireccionesLogic {
  constructor(private readonly direccionesModel: DireccionesModel) {}

  async listar(filtros: FiltroDireccionesDto) {
    const result = await this.direccionesModel.listar(filtros);
    return mapListResult(result, filtros);
  }

  async obtenerPorId(id: number) {
    const result = await this.direccionesModel.obtenerPorId(id);
    return mapSingleResult(result, `Dirección ${id} no encontrada`);
  }

  async crear(dto: CreateDireccionDto) {
    const result = await this.direccionesModel.crear(dto);
    return mapSingleResult(result, 'No se pudo crear la dirección');
  }

  async actualizar(id: number, dto: UpdateDireccionDto) {
  const result = await this.direccionesModel.actualizar(id,dto);
  return mapSingleResult(result, `Dirección ${id} no encontrada`);
}

  async eliminar(id: number, idUsuarioAuditoria?: number) {
    const result = await this.direccionesModel.eliminar(id, idUsuarioAuditoria);
    return mapDeleteResult(result, `Dirección ${id} no encontrada`);
  }

  async obtenerCoordenadasDesdeLink(link: string): Promise<CoordenadasResult> {
    const urlFinal = await this.resolverUrlSiEsAcortada(link);
    const coords = this.extraerCoordenadas(urlFinal);

    if (!coords) {
      throw new BadRequestException(
        'No se pudieron extraer las coordenadas del link proporcionado',
      );
    }

    return coords;
  }

  private async resolverUrlSiEsAcortada(link: string): Promise<string> {
    const esAcortada =
      link.includes('maps.app.goo.gl') || link.includes('goo.gl/maps');

    if (!esAcortada) return link;

    try {
      // Seguimos el redirect sin descargar el body completo
      const response = await fetch(link, {
        method: 'GET',
        redirect: 'follow',
      });
      return response.url; // URL final después del/los redirects
    } catch (error) {
      throw new BadRequestException(
        'No se pudo resolver el link acortado de Google Maps',
      );
    }
  }

  private extraerCoordenadas(url: string): CoordenadasResult | null {
    // Normalizamos: Google a veces codifica el espacio como "+" o "%20"
    // antes de la coordenada negativa (ej: "-8.12,+-79.02")
    const urlDecodificada = decodeURIComponent(url).replace(/\+/g, '');

    // Formato 1 (prioridad más alta): !3d-8.111!4d-79.028
    // Es la ubicación exacta del pin, más precisa que el centro del mapa.
    let match = urlDecodificada.match(/!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/);
    if (match) {
      return { latitud: parseFloat(match[1]), longitud: parseFloat(match[2]) };
    }

    // Formato 2: /@-8.111,-79.028,17z (centro del mapa, puede diferir del pin)
    match = urlDecodificada.match(/@(-?\d+\.\d+),(-?\d+\.\d+)/);
    if (match) {
      return { latitud: parseFloat(match[1]), longitud: parseFloat(match[2]) };
    }

    // Formato 3: ?q=-8.111,-79.028 o &q=-8.111,-79.028
    match = urlDecodificada.match(/[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)/);
    if (match) {
      return { latitud: parseFloat(match[1]), longitud: parseFloat(match[2]) };
    }

    // Formato 4: /maps/search/-8.125283,-79.028792
    // Aparece cuando el link acortado resuelve a una búsqueda por coordenadas.
    match = urlDecodificada.match(/\/search\/(-?\d+\.\d+),(-?\d+\.\d+)/);
    if (match) {
      return { latitud: parseFloat(match[1]), longitud: parseFloat(match[2]) };
    }

    // Formato 5 (fallback genérico): cualquier par "lat,lng" suelto en la URL.
    // Cubre variantes futuras de Google que no hayamos mapeado explícitamente.
    match = urlDecodificada.match(/(-?\d{1,2}\.\d{4,}),\s*(-?\d{1,3}\.\d{4,})/);
    if (match) {
      const lat = parseFloat(match[1]);
      const lng = parseFloat(match[2]);
      // Validación básica de rango para evitar falsos positivos
      // (ej. IDs numéricos largos que casualmente tengan un punto y una coma cerca)
      if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
        return { latitud: lat, longitud: lng };
      }
    }

    return null;
  }
}