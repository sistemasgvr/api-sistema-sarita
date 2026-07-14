import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class FiltroProductosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSubCategoria?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoria?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  esGas?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  esServicio?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  esAlquilable?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  afectaStock?: boolean;
}

export class CreateProductoDto extends AuditoriaDto {
  @ApiProperty({ example: 'GAS-OX-001', maxLength: 30 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(30)
  codigo!: string;

  @ApiProperty({ example: 'Oxígeno Industrial', maxLength: 300 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  nombre!: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSubCategoria?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  codigoBarra?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  marca?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  presentacion?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  esGas?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  esServicio?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  esAlquilable?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  afectaStock?: boolean;

  @ApiPropertyOptional({ example: 0, default: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  precio?: number;
}

export class UpdateProductoDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 30 })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  codigo?: string;

  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSubCategoria?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  codigoBarra?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  marca?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  presentacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esGas?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esServicio?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esAlquilable?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  afectaStock?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  precio?: number;
}
