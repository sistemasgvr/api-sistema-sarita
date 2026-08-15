import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Matches, Min } from 'class-validator';

export class ClientesKpiQueryDto {
  @ApiPropertyOptional({
    example: 5,
    description: 'Filtrar por un cliente específico',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({
    example: '2026-01-01',
    description: 'Fecha desde (YYYY-MM-DD)',
  })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'fechaDesde debe tener formato YYYY-MM-DD',
  })
  fechaDesde?: string;

  @ApiPropertyOptional({
    example: '2026-12-31',
    description: 'Fecha hasta (YYYY-MM-DD)',
  })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'fechaHasta debe tener formato YYYY-MM-DD',
  })
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

  @ApiPropertyOptional({
    example: 5,
    description: 'Filtrar por un cliente específico (ubicación del balón)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}

export class RangoFechasQueryDto {
  @ApiPropertyOptional({
    example: '2026-01-01',
    description: 'Fecha desde (YYYY-MM-DD)',
  })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'fechaDesde debe tener formato YYYY-MM-DD',
  })
  fechaDesde?: string;

  @ApiPropertyOptional({
    example: '2026-12-31',
    description: 'Fecha hasta (YYYY-MM-DD)',
  })
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'fechaHasta debe tener formato YYYY-MM-DD',
  })
  fechaHasta?: string;
}

export class VentasNetasQueryDto extends RangoFechasQueryDto {
  @ApiPropertyOptional({
    example: 5,
    description: 'Filtrar por un cliente específico',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}

export class ComprasNetasQueryDto extends RangoFechasQueryDto {}

export class DeudaKpiQueryDto extends RangoFechasQueryDto {
  @ApiPropertyOptional({
    example: 5,
    description: 'Filtrar por un cliente/proveedor específico (id_tercero)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}

export class HistoricoQueryDto {
  @ApiPropertyOptional({
    example: 2026,
    description: 'Año a consultar (default: año actual)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  anio?: number;
}

export class TopClientesVentaQueryDto extends RangoFechasQueryDto {
  @ApiPropertyOptional({
    example: 10,
    description: 'Cantidad máxima de clientes a retornar',
    default: 10,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limite?: number;
}

export class VentaGasesComparativoQueryDto {
  @ApiPropertyOptional({
    example: 2026,
    description: 'Año del mes a comparar (default: año actual)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  anio?: number;

  @ApiPropertyOptional({
    example: 8,
    description: 'Mes a comparar, 1-12 (default: mes actual)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  mes?: number;
}

export class ClientesMoraQueryDto extends RangoFechasQueryDto {
  @ApiPropertyOptional({
    example: 30,
    description:
      'Días de retraso a partir de los cuales un caso se considera urgente',
    default: 30,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  diasUrgente?: number;
}

export class IdAlmacenQueryDto {
  @ApiPropertyOptional({
    example: 1,
    description: 'Filtrar por un almacén específico',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;
}

export class VelocidadSalidaQueryDto extends RangoFechasQueryDto {
  @ApiPropertyOptional({
    example: 1,
    description: 'Filtrar por un almacén específico',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({
    example: 20,
    description: 'Cantidad máxima de productos a retornar',
    default: 20,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limite?: number;
}

export class StockCriticoQueryDto {
  @ApiPropertyOptional({
    example: 1,
    description: 'Filtrar por un almacén específico',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({
    example: 10,
    description: 'Cantidad máxima de productos a retornar',
    default: 10,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limite?: number;
}
