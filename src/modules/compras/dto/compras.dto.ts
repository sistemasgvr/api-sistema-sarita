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
  ValidateNested,
} from 'class-validator';
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
  @IsNumber()
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
    description: 'ID de la orden de recarga en planta externa que origina esta compra (bal_recarga_planta)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idRecargaPlanta?: number;

  @ApiPropertyOptional({
    example: false,
    description:
      'Solo aplica junto con idRecargaPlanta. Si es true, ubica los balones de la orden en el almacén de esta compra y genera su movimiento de ingreso. Si es false u omitido, ese ingreso se registra después desde Recargas en planta.',
  })
  @IsOptional()
  @IsBoolean()
  guardarBalonesAlmacen?: boolean;

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
    type: [CreateCompraDetalleDto],
    description:
      'Líneas del detalle de compra (opcional; se puede registrar solo la cabecera y agregar líneas después)',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateCompraDetalleDto)
  detalles?: CreateCompraDetalleDto[];
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
}

export class ActualizarCompraDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional({
    example: 12,
    description: 'Nueva cantidad (si baja y afecta stock, genera SALIDA diferencial)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  cantidad?: number;

  @ApiPropertyOptional({ example: 45.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
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
  @IsNumber()
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
