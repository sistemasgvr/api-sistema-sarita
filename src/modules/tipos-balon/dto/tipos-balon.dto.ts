import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroTiposBalonDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idGas?: number;
}

export class CreateTiposBalonDto extends AuditoriaDto {
  @ApiProperty()
  @MaxLength(150)
  @IsString()
  @IsNotEmpty()
  nombre!: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idGas?: number;

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
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  peso?: number;

  @ApiPropertyOptional({ description: 'Vigencia PH en años según normativa del gas (5 o 10)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  vigenciaPhAnios?: number;
}

export class UpdateTiposBalonDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @MaxLength(150)
  @IsOptional()
  @IsString()
  nombre?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idGas?: number;

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
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  peso?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  vigenciaPhAnios?: number;
}
