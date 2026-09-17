import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** Comprobante de venta ya emitido cuyo cobro genera la percepción. */
export class PercepcionComprobanteDto {
  @ApiProperty({ description: 'ID de ven_comprobante (factura/boleta aceptada por SUNAT)' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  idComprobante!: number;

  @ApiPropertyOptional({ description: 'Fecha del cobro (YYYY-MM-DD); por defecto la fecha de emisión de la percepción' })
  @IsOptional()
  @IsDateString({ strict: true })
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  fechaCobro?: string;
}

/**
 * La percepción se arma sobre comprobantes de venta emitidos: cliente,
 * sucursal, importes y detalle salen del comprobante, no del formulario.
 */
export class CreatePercepcionDto {
  @ApiProperty({ description: 'Empresa emisora (agente de percepción)' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  idEmpresa!: number;

  @ApiProperty({ example: 'P001' })
  @IsString()
  @Matches(/^P\d{3}$/, { message: 'La serie de percepción es P001–P999' })
  serie!: string;

  @ApiProperty({ example: '2026-09-17' })
  @IsDateString({ strict: true })
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  fechaEmision!: string;

  @ApiProperty({ description: 'Régimen SUNAT (catálogo 22): 01, 02 o 03' })
  @IsString()
  @Matches(/^\d{2}$/)
  regimen!: string;

  @ApiPropertyOptional({ description: 'Tasa %; por defecto la del régimen' })
  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0.01)
  @Max(100)
  tasa?: number;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiProperty({ type: [PercepcionComprobanteDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => PercepcionComprobanteDto)
  comprobantes!: PercepcionComprobanteDto[];
}

export class FiltroPercepcionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  buscar?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEmpresa?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  pagina?: number;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  tamano?: number;
}

/** Comprobantes de venta aceptados por SUNAT que aún no tienen percepción. */
export class ComprobantesElegiblesQueryDto {
  @ApiPropertyOptional({ description: 'Cliente (sujeto percibido)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ description: 'Serie-número o nombre del cliente' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  buscar?: string;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  limite?: number;
}
