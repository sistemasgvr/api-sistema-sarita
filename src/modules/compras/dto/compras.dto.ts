import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { MONEY_NUMBER_OPTIONS } from '../../../common/constants/money';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroComprasDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ description: 'Filtrar desde la fecha (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ description: 'Filtrar hasta la fecha (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional({ example: 1, description: 'ID del proveedor' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID del almacén' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Estado (1=activo, 0=anulado)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  estado?: number;

  @ApiPropertyOptional({ description: 'ID de gen_lista_opciones (lista TipoRegistroCompra)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoRegistro?: number;

  @ApiPropertyOptional({ description: 'ID de gen_lista_opciones (lista CategoriaGasto)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaGasto?: number;
}

export class CompraCuotaDto {
  @ApiProperty({
    example: '2026-08-15',
    description: 'Fecha de vencimiento de la cuota',
  })
  @IsDateString()
  fechaPago!: string;

  @ApiPropertyOptional({ example: 150.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  monto?: number;
}

export class CreateCompraDetalleDto {
  @ApiPropertyOptional({
    example: 1,
    description: 'ID de clasificación de gasto en 3 niveles',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idClasificacionGasto?: number;

  @ApiProperty({ example: 1, description: 'ID del producto' })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idProducto!: number;

  @ApiPropertyOptional({ example: 'Recarga de gas oxígeno 10m3' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  descripcion?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiProperty({ example: 10 })
  @Type(() => Number)
  @IsNumber()
  cantidad!: number;

  @ApiPropertyOptional({ example: 45.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precioUnitario?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Almacén de la línea (por defecto el de la cabecera)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;
}

export class CreateCompraDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoComprobante?: number;

  @ApiPropertyOptional({ example: 'F001', maxLength: 10 })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  serie?: string;

  @ApiPropertyOptional({ example: '00001234', maxLength: 15 })
  @IsOptional()
  @IsString()
  @MaxLength(15)
  numero?: string;

  @ApiProperty({ example: '2026-07-22' })
  @IsDateString()
  @IsNotEmpty()
  fecha!: string;

  @ApiPropertyOptional({
    example: 1,
    description: 'ID del proveedor (cli_clientes)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional({ example: 1, description: 'Almacén por defecto' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'ID de la compra anulada que se corrige',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idComprobanteReferencia?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'ID de la orden de recarga en planta externa vinculada',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idRecargaPlanta?: number;

  @ApiPropertyOptional({
    example: false,
    description:
      'Si true y hay idRecargaPlanta: registra retorno de balones al almacén (genera ENTRADA_PLANTA_EXTERNA)',
  })
  @IsOptional()
  @IsBoolean()
  guardarBalonesAlmacen?: boolean;

  @ApiPropertyOptional({
    example: '2026-08-12',
    description:
      'Fecha de llegada al almacén (retorno físico). Si viene informada, registra el ingreso.',
  })
  @IsOptional()
  @IsDateString()
  fechaLlegadaAlmacen?: string;

  @ApiPropertyOptional({
    example: 'LOTE-2026-01',
    description: 'Lote del protocolo de planta',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  lote?: string;

  @ApiPropertyOptional({ example: '2027-08-12' })
  @IsOptional()
  @IsDateString()
  fechaVencimientoLote?: string;

  @ApiPropertyOptional({ example: '2026-08-12' })
  @IsOptional()
  @IsDateString()
  fechaPruebaHidrostatica?: string;

  @ApiPropertyOptional({ example: 1, description: 'GRE de retorno / ingreso' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idGuiaRetorno?: number;

  @ApiPropertyOptional({ example: 'T001' })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  serieGuiaIngreso?: string;

  @ApiPropertyOptional({ example: '00000002' })
  @IsOptional()
  @IsString()
  @MaxLength(15)
  numeroGuiaIngreso?: string;

  @ApiPropertyOptional({
    example: 1,
    description: 'ID tipo de registro (COMPRA/GASTO)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoRegistro?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaGasto?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMoneda?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCondicionPago?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  declararSunat?: boolean;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  glosa?: string;

  @ApiPropertyOptional({
    example: '2026-10-12',
    description: 'Vencimiento CxP si la condición es crédito (un solo pago)',
  })
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional({
    type: [CompraCuotaDto],
    description: 'Plan de cuotas personalizado (fechas/montos) para la CxP',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CompraCuotaDto)
  cuotas?: CompraCuotaDto[];

  @ApiProperty({
    type: [CreateCompraDetalleDto],
    description: 'Líneas del detalle de compra',
  })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateCompraDetalleDto)
  @IsNotEmpty()
  detalles!: CreateCompraDetalleDto[];
}

export class ActualizarCompraCabeceraDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  glosa?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCondicionPago?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaGasto?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  declararSunat?: boolean;

  @ApiPropertyOptional({ example: '2026-10-12' })
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional({ type: [CompraCuotaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CompraCuotaDto)
  cuotas?: CompraCuotaDto[];
}

export class ActualizarCompraDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional({
    example: 12,
    description:
      'Nueva cantidad (si baja y afecta stock, genera SALIDA diferencial)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  cantidad?: number;

  @ApiPropertyOptional({ example: 45.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precioUnitario?: number;
}

export class CreateCompraDetalleLineaDto extends AuditoriaDto {
  @ApiProperty({ example: 1, description: 'ID del producto' })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idProducto!: number;

  @ApiProperty({ example: 10 })
  @Type(() => Number)
  @IsNumber()
  cantidad!: number;

  @ApiPropertyOptional({ example: 45.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precioUnitario?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'ID de clasificación de gasto',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idClasificacionGasto?: number;

  @ApiPropertyOptional({
    example: 'Recarga de gas oxígeno 10m3',
    maxLength: 300,
  })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  descripcion?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Almacén de la línea (por defecto el de la cabecera)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;
}
