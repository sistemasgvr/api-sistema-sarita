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

  @ApiPropertyOptional({ example: 1, description: 'ID tipo de comprobante (Factura, Boleta...)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoComprobante?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID tipo de registro (Compra, Gasto)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoRegistro?: number;
}

export class CreateCompraDetalleDto {
  @ApiPropertyOptional({ example: 1, description: 'ID de clasificación de gasto en 3 niveles' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idClasificacionGasto?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID del producto si afecta stock' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

  @ApiProperty({ example: 'Recarga de gas oxígeno 10m3' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  descripcion!: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiProperty({ example: 10 })
  @Type(() => Number)
  @IsNumber()
  cantidad!: number;

  @ApiPropertyOptional({ example: 45.50 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  precioUnitario?: number;

  @ApiProperty({ example: 455.00 })
  @Type(() => Number)
  @IsNumber()
  importe!: number;

  @ApiPropertyOptional({ example: 1, description: 'Medio de pago si la línea se pagó' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional({ example: '2026-07-22' })
  @IsOptional()
  @IsDateString()
  fechaPago?: string;

  @ApiPropertyOptional({ example: 'OP-987654' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroOperacion?: string;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  afectaStock?: boolean;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
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

  @ApiPropertyOptional({ example: 1, description: 'ID del proveedor (cli_clientes)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID tipo de registro (COMPRA/GASTO)' })
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
  idAlmacen?: number;

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

  @ApiPropertyOptional({ example: 100.00 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  subTotal?: number;

  @ApiPropertyOptional({ example: 18.00 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  igv?: number;

  @ApiProperty({ example: 118.00 })
  @Type(() => Number)
  @IsNumber()
  totalImporte!: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  afectaInventario?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  declararSunat?: boolean;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  glosa?: string;

  @ApiProperty({ type: [CreateCompraDetalleDto], description: 'Líneas del detalle de compra' })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateCompraDetalleDto)
  detalles!: CreateCompraDetalleDto[];
}

export class UpdateCompraDetalleDto {
  @ApiPropertyOptional({ example: 1, description: 'ID de la línea si ya existe en la BD' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  id?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID de clasificación de gasto' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idClasificacionGasto?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID del producto si afecta stock' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

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

  @ApiPropertyOptional({ example: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  cantidad?: number;

  @ApiPropertyOptional({ example: 45.50 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  precioUnitario?: number;

  @ApiPropertyOptional({ example: 455.00 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  importe?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional({ example: '2026-07-22' })
  @IsOptional()
  @IsDateString()
  fechaPago?: string;

  @ApiPropertyOptional({ example: 'OP-987654' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroOperacion?: string;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  afectaStock?: boolean;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class UpdateCompraDto extends AuditoriaDto {
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

  @ApiPropertyOptional({ example: '2026-07-22' })
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional({ example: 1, description: 'ID del proveedor (cli_clientes)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID tipo de registro (COMPRA/GASTO)' })
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
  idAlmacen?: number;

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

  @ApiPropertyOptional({ example: 100.00 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  subTotal?: number;

  @ApiPropertyOptional({ example: 18.00 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  igv?: number;

  @ApiPropertyOptional({ example: 118.00 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  totalImporte?: number;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @IsBoolean()
  afectaInventario?: boolean;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @IsBoolean()
  declararSunat?: boolean;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  glosa?: string;

  @ApiPropertyOptional({ type: [UpdateCompraDetalleDto], description: 'Detalle de líneas a actualizar' })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => UpdateCompraDetalleDto)
  detalles?: UpdateCompraDetalleDto[];
}