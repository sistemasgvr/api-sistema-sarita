import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type, Transform } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class FiltroMovimientosRecargaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class CreateMovimientosRecargaDto extends AuditoriaDto {
  @ApiProperty()
  @IsDateString()
  fechaSalidaAlmacen!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idBalon!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProducto?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidad?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaSalida?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaSalida?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaIngreso?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaIngreso?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieFactura?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroFactura?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobante?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaLlegadaAlmacen?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  lote?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimientoLote?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;
}

export class CreateRecargaClienteDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idCliente!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idBalon!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idProducto!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  precioUnitario!: number;

  @ApiPropertyOptional({ default: 1 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  cantidad?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoComprobante?: number;

  @ApiPropertyOptional({ default: 'B001' })
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serie?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidad?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class UpdateMovimientosRecargaDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaSalidaAlmacen?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProducto?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidad?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaSalida?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaSalida?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaIngreso?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaIngreso?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieFactura?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroFactura?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobante?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaLlegadaAlmacen?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  lote?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimientoLote?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;
}
