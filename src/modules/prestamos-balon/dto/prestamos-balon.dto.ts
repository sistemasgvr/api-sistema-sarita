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

export class FiltroPrestamosBalonDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoPrestamo?: number;

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
}

export class CreatePrestamosBalonDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idTipoPrestamo!: number;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  numeroPrestamo?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
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
  @IsDateString()
  fechaRetornoReal?: string;

  @ApiPropertyOptional()
  @MaxLength(200)
  @IsOptional()
  @IsString()
  titulo?: string;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteVenta?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteCompra?: number;
}

export class UpdatePrestamosBalonDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoPrestamo?: number;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  numeroPrestamo?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
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
  @IsDateString()
  fechaRetornoReal?: string;

  @ApiPropertyOptional()
  @MaxLength(200)
  @IsOptional()
  @IsString()
  titulo?: string;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteVenta?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteCompra?: number;
}
