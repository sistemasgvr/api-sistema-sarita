import { HttpService } from '@nestjs/axios';
import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class ConsultasLogic {
  private readonly baseUrl = 'https://dniruc.apisperu.com/api/v1';
  private readonly token = process.env.APIS_PERU_TOKEN;

  constructor(private readonly httpService: HttpService) {}

  async consultarDni(dni: string) {
    try {
      const url = `${this.baseUrl}/dni/${dni}?token=${this.token}`;
      const response = await firstValueFrom(this.httpService.get(url));

      if (!response.data || response.data.error) {
        throw new NotFoundException(`DNI ${dni} no encontrado en RENIEC`);
      }
      return response.data;
    } catch (error: any) {
      if (error instanceof NotFoundException) throw error;
      throw new BadRequestException(
        'Error al comunicarse con el servicio de RENIEC',
      );
    }
  }

  async consultarRuc(ruc: string) {
    try {
      const url = `${this.baseUrl}/ruc/${ruc}?token=${this.token}`;
      const response = await firstValueFrom(this.httpService.get(url));

      if (!response.data || response.data.error) {
        throw new NotFoundException(`RUC ${ruc} no encontrado en SUNAT`);
      }
      return response.data;
    } catch (error: any) {
      if (error instanceof NotFoundException) throw error;
      throw new BadRequestException(
        'Error al comunicarse con el servicio de SUNAT',
      );
    }
  }
}
