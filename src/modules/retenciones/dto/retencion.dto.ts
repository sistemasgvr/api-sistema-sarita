import { Type } from 'class-transformer';
import { IsArray, IsDateString, IsNumber, IsOptional, IsString, Min, ValidateNested } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RetencionDetalleDto {
  @ApiPropertyOptional({ description: 'ID de la compra asociada' })
  @IsNumber()
  @IsOptional()
  idCompra?: number;

  @ApiProperty({ description: 'Tipo de documento SUNAT (01=Factura, 03=Boleta)' })
  @IsString()
  tipoDoc: string;

  @ApiProperty({ description: 'Número del documento' })
  @IsString()
  numDoc: string;

  @ApiProperty({ description: 'Fecha de emisión del documento (YYYY-MM-DD)' })
  @IsDateString()
  fechaEmision: string;

  @ApiProperty({ description: 'Fecha de retención (YYYY-MM-DD)' })
  @IsDateString()
  fechaRetencion: string;

  @ApiPropertyOptional({ description: 'Moneda (PEN, USD)' })
  @IsString()
  @IsOptional()
  moneda?: string;

  @ApiProperty({ description: 'Importe total del documento' })
  @IsNumber()
  @Min(0)
  impTotal: number;

  @ApiProperty({ description: 'Importe retenido sobre este documento' })
  @IsNumber()
  @Min(0)
  impRetenido: number;

  @ApiProperty({ description: 'Importe pendiente de pago' })
  @IsNumber()
  @Min(0)
  impPagar: number;
}

export class CreateRetencionDto {
  @ApiProperty({ description: 'Serie de la retención (ej: R001)' })
  @IsString()
  serie: string;

  @ApiProperty({ description: 'Fecha de emisión (YYYY-MM-DD)' })
  @IsDateString()
  fechaEmision: string;

  @ApiProperty({ description: 'ID de la empresa emisora' })
  @IsNumber()
  idEmpresa: number;

  @ApiProperty({ description: 'ID del proveedor (sujeto retenido)' })
  @IsNumber()
  idProveedor: number;

  @ApiPropertyOptional({ description: 'ID de la sucursal' })
  @IsNumber()
  @IsOptional()
  idSucursal?: number;

  @ApiProperty({ description: 'Código de régimen de retención (01=Honorarios, etc.)' })
  @IsString()
  regimen: string;

  @ApiProperty({ description: 'Tasa de retención (ej: 3 para 3%)' })
  @IsNumber()
  @Min(0)
  tasa: number;

  @ApiProperty({ description: 'Base imponible (monto sobre el que se retiene)' })
  @IsNumber()
  @Min(0)
  baseImponible: number;

  @ApiProperty({ description: 'Monto total retenido' })
  @IsNumber()
  @Min(0)
  montoRetenido: number;

  @ApiProperty({ description: 'Monto total pagado (base - retención)' })
  @IsNumber()
  @Min(0)
  montoPagado: number;

  @ApiPropertyOptional({ description: 'Observaciones' })
  @IsString()
  @IsOptional()
  observacion?: string;

  @ApiPropertyOptional({ description: 'Detalle de documentos asociados', type: [RetencionDetalleDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RetencionDetalleDto)
  @IsOptional()
  detalles?: RetencionDetalleDto[];
}

export class FiltroRetencionDto {
  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  idEmpresa?: number;

  @ApiPropertyOptional()
  @IsDateString()
  @IsOptional()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsDateString()
  @IsOptional()
  fechaHasta?: string;

  @ApiPropertyOptional()
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  idProveedor?: number;

  @ApiPropertyOptional({ default: 1 })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  pagina?: number;

  @ApiPropertyOptional({ default: 20 })
  @IsNumber()
  @IsOptional()
  @Type(() => Number)
  tamano?: number;
}
