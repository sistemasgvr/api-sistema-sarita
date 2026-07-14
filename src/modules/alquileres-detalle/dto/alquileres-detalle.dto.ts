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

export class FiltroAlquileresDetalleDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlquiler?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;
}

export class CreateAlquileresDetalleDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idAlquiler!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idBalon!: number;
}

export class UpdateAlquileresDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;
}
