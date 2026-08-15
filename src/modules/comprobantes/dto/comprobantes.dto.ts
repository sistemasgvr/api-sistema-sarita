import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsPositive,
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

export class EfectoPosGarantiaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsPositive()
  monto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  cantidadVenta?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRegistro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class EfectoPosRecargaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idProducto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidad?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idBalonOrigen?: number;
}

export class EfectoPosPrestamoDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idTipoPrestamo!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaSalida?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRetornoPactada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  titulo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idEstado?: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaEntregado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaPrestamo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacionDetalle?: string;

  @ApiPropertyOptional({ type: EfectoPosGarantiaDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectoPosGarantiaDto)
  garantia?: EfectoPosGarantiaDto;
}

export class EfectoPosAlquilerPeriodoDto {
  @ApiProperty()
  @IsDateString()
  fechaInicio!: string;

  @ApiProperty()
  @IsDateString()
  fechaFin!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  monto!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class EfectoPosAlquilerDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiProperty()
  @IsDateString()
  fechaInicio!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFinPactada?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  tarifaDiaria?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  totalCobrado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProductoRegulador?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idProductoStock?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional({ type: EfectoPosAlquilerPeriodoDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectoPosAlquilerPeriodoDto)
  periodo?: EfectoPosAlquilerPeriodoDto;

  @ApiPropertyOptional({ type: EfectoPosGarantiaDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectoPosGarantiaDto)
  garantia?: EfectoPosGarantiaDto;
}

export class EfectoPosMantenimientoDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiProperty()
  @IsDateString()
  fechaIngreso!: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idTipoMantenimiento?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  costo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class EfectoPosBajaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idBalon!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idMotivoBaja!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  montoVenta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaBaja?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  aprobar?: boolean;
}

export class EfectosPosDto {
  @ApiPropertyOptional({ type: [EfectoPosRecargaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosRecargaDto)
  recargas?: EfectoPosRecargaDto[];

  @ApiPropertyOptional({ type: [EfectoPosPrestamoDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosPrestamoDto)
  prestamos?: EfectoPosPrestamoDto[];

  @ApiPropertyOptional({ type: [EfectoPosAlquilerDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosAlquilerDto)
  alquileres?: EfectoPosAlquilerDto[];

  @ApiPropertyOptional({ type: [EfectoPosMantenimientoDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosMantenimientoDto)
  mantenimientos?: EfectoPosMantenimientoDto[];

  @ApiPropertyOptional({ type: [EfectoPosBajaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => EfectoPosBajaDto)
  bajas?: EfectoPosBajaDto[];
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

  @ApiPropertyOptional({
    description:
      'Pestaña POS de emisión: accesorios|recarga|medicinal|industrial|mantenimiento',
    example: 'accesorios',
  })
  @MaxLength(30)
  @IsOptional()
  @IsString()
  origenPos?: string;

  @ApiPropertyOptional({
    type: EfectosPosDto,
    description:
      'Efectos POS (recarga, préstamo, alquiler, garantía, mantenimiento, baja) en la misma transacción del CPE',
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => EfectosPosDto)
  efectosPos?: EfectosPosDto;

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

  @ApiPropertyOptional({
    description:
      'Pestaña POS de emisión: accesorios|recarga|medicinal|industrial|mantenimiento',
    example: 'accesorios',
  })
  @MaxLength(30)
  @IsOptional()
  @IsString()
  origenPos?: string;

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

export class PreviewResumenDiarioQueryDto {
  @ApiProperty({ example: '2026-07-13' })
  @IsDateString()
  @IsNotEmpty()
  fecha!: string;
}

export class FiltroResumenDiarioDto extends FiltroPaginacionDto {
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
}

export class EstadoResumenDiarioQueryDto {
  @ApiProperty({ example: '20260713123456' })
  @IsString()
  @IsNotEmpty()
  ticket!: string;
}

export class EnviarResumenDiarioDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-07-13' })
  @IsDateString()
  @IsNotEmpty()
  fecha!: string;

  @ApiPropertyOptional({
    example: '001',
    description: 'Correlativo del resumen del día (3 dígitos). Por defecto el siguiente disponible.',
  })
  @MaxLength(10)
  @IsOptional()
  @IsString()
  correlativo?: string;

  @ApiPropertyOptional({
    type: [Number],
    description: 'Si se omite, incluye todas las boletas/NC familia B de la fecha',
  })
  @IsOptional()
  @IsArray()
  @Type(() => Number)
  @IsNumber({}, { each: true })
  idsComprobante?: number[];
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
