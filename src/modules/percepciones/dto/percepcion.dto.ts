import { Type } from 'class-transformer';
import { IsArray, IsDateString, IsNumber, IsOptional, IsString, Min, ValidateNested } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class PercepcionDetalleDto {
  @ApiPropertyOptional({ description: 'ID del comprobante de venta asociado' })
  @IsNumber()
  @IsOptional()
  idComprobante?: number;

  @ApiProperty({ description: 'Tipo de documento SUNAT (01=Factura, 03=Boleta)' })
  @IsString()
  tipoDoc: string;

  @ApiProperty({ description: 'Número del documento' })
  @IsString()
  numDoc: string;

  @ApiProperty({ description: 'Fecha de emisión del documento (YYYY-MM-DD)' })
  @IsDateString()
  fechaEmision: string;

  @ApiProperty({ description: 'Fecha de percepción (YYYY-MM-DD)' })
  @IsDateString()
  fechaPercepcion: string;

  @ApiPropertyOptional({ description: 'Moneda (PEN, USD)' })
  @IsString()
  @IsOptional()
  moneda?: string;

  @ApiProperty({ description: 'Importe total del documento' })
  @IsNumber()
  @Min(0)
  impTotal: number;

  @ApiProperty({ description: 'Importe percibido sobre este documento' })
  @IsNumber()
  @Min(0)
  impPercibido: number;

  @ApiProperty({ description: 'Importe pendiente de cobrar' })
  @IsNumber()
  @Min(0)
  impCobrar: number;
}

export class CreatePercepcionDto {
  @ApiProperty({ description: 'Serie de la percepción (ej: P001)' })
  @IsString()
  serie: string;

  @ApiProperty({ description: 'Fecha de emisión (YYYY-MM-DD)' })
  @IsDateString()
  fechaEmision: string;

  @ApiProperty({ description: 'ID de la empresa emisora' })
  @IsNumber()
  idEmpresa: number;

  @ApiProperty({ description: 'ID del cliente (sujeto percibido)' })
  @IsNumber()
  idCliente: number;

  @ApiPropertyOptional({ description: 'ID de la sucursal' })
  @IsNumber()
  @IsOptional()
  idSucursal?: number;

  @ApiProperty({ description: 'Código de régimen de percepción (01=Venta Interna, etc.)' })
  @IsString()
  regimen: string;

  @ApiProperty({ description: 'Tasa de percepción (ej: 2 para 2%)' })
  @IsNumber()
  @Min(0)
  tasa: number;

  @ApiProperty({ description: 'Base imponible (monto sobre el que se percibe)' })
  @IsNumber()
  @Min(0)
  baseImponible: number;

  @ApiProperty({ description: 'Monto total percibido' })
  @IsNumber()
  @Min(0)
  montoPercibido: number;

  @ApiProperty({ description: 'Monto total cobrado (base + percepción)' })
  @IsNumber()
  @Min(0)
  montoCobrado: number;

  @ApiPropertyOptional({ description: 'Observaciones' })
  @IsString()
  @IsOptional()
  observacion?: string;

  @ApiPropertyOptional({ description: 'Detalle de documentos asociados', type: [PercepcionDetalleDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PercepcionDetalleDto)
  @IsOptional()
  detalles?: PercepcionDetalleDto[];
}

export class FiltroPercepcionDto {
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
  idCliente?: number;

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
