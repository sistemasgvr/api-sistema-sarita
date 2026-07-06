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

export class FiltroAlquileresBalonDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;
}

export class CreateAlquileresBalonDto extends AuditoriaDto {
  @ApiProperty()
  @MaxLength(30)
  @IsString()
  @IsNotEmpty()
  numeroAlquiler!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idCliente!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idAlmacen!: number;

  @ApiProperty()
  @IsDateString()
  fechaInicio!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFinPactada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFinReal?: string;

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
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteVenta?: number;
}

export class UpdateAlquileresBalonDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  numeroAlquiler?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaInicio?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFinPactada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFinReal?: string;

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
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteVenta?: number;
}
