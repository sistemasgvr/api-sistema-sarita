import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class PdfComprobanteQueryDto {
  @ApiPropertyOptional({
    enum: ['a4', 'ticket'],
    default: 'a4',
    description: 'Formato de representación impresa: A4 o ticketera 80mm',
  })
  @IsOptional()
  @IsIn(['a4', 'ticket'])
  formato?: 'a4' | 'ticket';
}

export class FiltroComprobantesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoComprobante?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoSunat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serie?: string;
}

export class SiguienteNumeroQueryDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idTipoComprobante!: number;

  @ApiProperty()
  @MaxLength(10)
  @IsString()
  @IsNotEmpty()
  serie!: string;
}

export class ComprobanteDetalleDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idProducto!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  cantidad!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  precioUnitario!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  descuento?: number;

  @ApiPropertyOptional({ default: 18 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  porcentajeIgv?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAfectacionIgv?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  item?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidadCilindro?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoCilindro?: number;
}

export class ComprobanteCuotaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  numeroCuota!: number;

  @ApiProperty()
  @IsDateString()
  @IsNotEmpty()
  fechaVencimiento!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  monto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  montoPagado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;
}

export class CreateComprobantesDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idTipoComprobante!: number;

  @ApiProperty()
  @MaxLength(10)
  @IsString()
  @IsNotEmpty()
  serie!: string;

  @ApiPropertyOptional({ description: 'Si se omite, se asigna automáticamente' })
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numero?: string;

  @ApiProperty()
  @IsDateString()
  @IsNotEmpty()
  fecha!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idCliente!: number;

  @ApiProperty({ type: [ComprobanteDetalleDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ComprobanteDetalleDto)
  detalles!: ComprobanteDetalleDto[];

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoOperacionSunat?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteOrigen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMotivoNota?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoMovimiento?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoVenta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional({ default: 3.5 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  tipoCambio?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idSucursal?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCondicionPago?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMoneda?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  glosa?: string;

  @ApiPropertyOptional()
  @MaxLength(1000)
  @IsOptional()
  @IsString()
  observaciones?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  periodoContable?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  operacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional({ type: [ComprobanteCuotaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ComprobanteCuotaDto)
  cuotas?: ComprobanteCuotaDto[];
}

export class UpdateComprobantesDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional({ type: [ComprobanteDetalleDto] })
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => ComprobanteDetalleDto)
  detalles?: ComprobanteDetalleDto[];

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoOperacionSunat?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteOrigen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMotivoNota?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoMovimiento?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoVenta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  tipoCambio?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idSucursal?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCondicionPago?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMoneda?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  glosa?: string;

  @ApiPropertyOptional()
  @MaxLength(1000)
  @IsOptional()
  @IsString()
  observaciones?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  periodoContable?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  operacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional({ type: [ComprobanteCuotaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ComprobanteCuotaDto)
  cuotas?: ComprobanteCuotaDto[];
}

export class AnularComprobanteDto extends AuditoriaDto {
  @ApiProperty({
    example: 'ERROR EN EL CLIENTE / CANTIDAD',
    description: 'Motivo de la comunicación de baja ante SUNAT',
  })
  @MaxLength(250)
  @IsString()
  @IsNotEmpty()
  motivo!: string;
}

export class RegistrarRespuestaSunatDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoSunat?: number;

  @ApiPropertyOptional()
  @MaxLength(100)
  @IsOptional()
  @IsString()
  ticketSunat?: string;

  @ApiPropertyOptional()
  @MaxLength(200)
  @IsOptional()
  @IsString()
  hashDocumento?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  xmlFirmado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  cdrRespuesta?: string;
}
