import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Matches, Min, IsDateString, IsString } from 'class-validator';

export class GeneralKpiQueryDto {
  @ApiPropertyOptional({ description: 'ID de almacén específico para stock crítico' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({ description: 'Límite de registros para listas' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  limite?: number;

  @ApiPropertyOptional({ description: 'Offset para paginación' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  offset?: number;
}

export class ClientesKpiQueryDto {
  @ApiPropertyOptional({ example: 5, description: 'Filtrar por un cliente específico' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ example: '2026-01-01', description: 'Fecha desde (YYYY-MM-DD)' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaDesde debe tener formato YYYY-MM-DD' })
  fechaDesde?: string;

  @ApiPropertyOptional({ example: '2026-12-31', description: 'Fecha hasta (YYYY-MM-DD)' })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaHasta debe tener formato YYYY-MM-DD' })
  fechaHasta?: string;
}

export class BalonesKpiQueryDto {
  @ApiPropertyOptional({
    example: 30,
    description: 'Días de anticipación para considerar un balón "por vencer"',
    default: 30,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  diasAlerta?: number;

  @ApiPropertyOptional({ example: 5, description: 'Filtrar por un cliente específico (ubicación del balón)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}

export class ProductosKpiQueryDto {
  @ApiPropertyOptional({ description: 'ID de almacén específico' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({ description: 'Término de búsqueda por nombre/código' })
  @IsOptional()
  @IsString()
  busqueda?: string;

  @ApiPropertyOptional({ description: 'Límite de registros para listas' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  limite?: number;

  @ApiPropertyOptional({ description: 'Offset para paginación' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  offset?: number;
}

export class VentasKpiQueryDto {
  @ApiPropertyOptional({ description: 'Fecha de consulta (YYYY-MM-DD)', example: '2026-07-30' })
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional({ description: 'Límite de registros para listas' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  limite?: number;

  @ApiPropertyOptional({ description: 'Offset para paginación' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  offset?: number;
}