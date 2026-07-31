import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroCategoriasProductoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    description: '1=activos, 0=inactivos, omitir/null=todos',
    example: 1,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  soloActivos?: number | null;
}

export class CreateCategoriaProductoDto extends AuditoriaDto {
  @ApiProperty({ example: 'Gases', maxLength: 100 })
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

export class UpdateCategoriaProductoDto extends AuditoriaDto {
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
