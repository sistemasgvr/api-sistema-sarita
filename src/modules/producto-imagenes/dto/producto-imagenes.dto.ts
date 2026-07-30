import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroProductoImagenesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 50, default: 50 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  override limite?: number = 50;
}

export class UpdateProductoImagenDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 0 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  orden?: number;

  @ApiPropertyOptional({ example: true })
  @IsOptional()
  @Transform(({ value }) => {
    if (value === undefined || value === null || value === '') return undefined;
    if (typeof value === 'boolean') return value;
    if (value === 'true' || value === '1') return true;
    if (value === 'false' || value === '0') return false;
    return value;
  })
  @IsBoolean()
  esPrincipal?: boolean;
}

export class ProductoImagenAuditoriaDto extends AuditoriaDto {}
