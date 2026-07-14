import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroSubCategoriasProductoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoria?: number;
}

export class CreateSubCategoriaProductoDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idCategoria!: number;

  @ApiProperty({ example: 'Oxígeno', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;
}

export class UpdateSubCategoriaProductoDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoria?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombre?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;
}
