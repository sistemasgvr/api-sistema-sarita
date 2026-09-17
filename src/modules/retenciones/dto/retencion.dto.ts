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

/** Compra registrada (factura del proveedor) cuyo pago genera la retención. */
export class RetencionCompraDto {
  @ApiProperty({ description: 'ID de com_comprobante_compra (factura del proveedor, con RUC)' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  idCompra!: number;

  @ApiPropertyOptional({ description: 'Fecha del pago (YYYY-MM-DD); por defecto la fecha de emisión de la retención' })
  @IsOptional()
  @IsDateString({ strict: true })
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  fechaPago?: string;
}

/**
 * La retención se arma sobre compras registradas (facturas del proveedor):
 * proveedor, sucursal, importes y detalle salen de la compra, no del formulario.
 */
export class CreateRetencionDto {
  @ApiProperty({ description: 'Empresa emisora (agente de retención)' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  idEmpresa!: number;

  @ApiProperty({ example: 'R001' })
  @IsString()
  @Matches(/^R\d{3}$/, { message: 'La serie de retención es R001–R999' })
  serie!: string;

  @ApiProperty({ example: '2026-09-17' })
  @IsDateString({ strict: true })
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  fechaEmision!: string;

  @ApiProperty({ description: 'Régimen SUNAT (catálogo 23): 01 (3%) o 02 (6%)' })
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

  @ApiProperty({ type: [RetencionCompraDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => RetencionCompraDto)
  compras!: RetencionCompraDto[];
}

export class FiltroRetencionDto {
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
  idProveedor?: number;

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

/** Compras con factura de proveedor (RUC), en soles, sin retención. */
export class ComprasElegiblesQueryDto {
  @ApiPropertyOptional({ description: 'Proveedor (sujeto retenido)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional({ description: 'Serie-número o nombre del proveedor' })
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
