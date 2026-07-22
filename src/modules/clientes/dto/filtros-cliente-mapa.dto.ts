import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export const FILTROS_BALONES_MAPA = [
  'CON_BALONES',
  'PRESTADO_CLIENTE',
  'ALQUILADO',
  'EN_PODER_CLIENTE',
] as const;

export type FiltroBalonesMapa = (typeof FILTROS_BALONES_MAPA)[number];

export class FiltroClienteMapaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    required: false,
    example: 1,
    nullable: true,
    description: 'Estado del cliente: 1 = activos, 0 = inactivos, null = todos',
  })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  soloActivos?: number;

  @ApiPropertyOptional({
    required: false,
    example: 'CON_BALONES',
    description:
      'Filtrar por balones en campo: CON_BALONES | PRESTADO_CLIENTE | ALQUILADO | EN_PODER_CLIENTE',
  })
  @IsOptional()
  @IsString()
  @IsIn([...FILTROS_BALONES_MAPA])
  filtroBalones?: FiltroBalonesMapa;
}
