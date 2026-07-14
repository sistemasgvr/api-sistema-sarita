import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroDireccionesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  soloActivos?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Filtrar por ID del cliente',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}

export class CreateDireccionDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idCliente!: number;

  @ApiProperty({ example: 'Av. Los Álamos 123', maxLength: 255 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  direccion!: string;

  @ApiPropertyOptional({ example: 'Almacén secundario', maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  descripcion?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDepartamento?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProvincia?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDistrito?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  referencia?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  esPrincipal?: boolean;
}

export class UpdateDireccionDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccion?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  descripcion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDepartamento?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProvincia?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDistrito?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  referencia?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esPrincipal?: boolean;
}

export class ObtenerCoordenadasDto {
  @ApiProperty({
    example: 'https://maps.app.goo.gl/xxxxxxxxx',
    description:
      'Link de Google Maps a procesar. Acepta links completos (con @lat,lng o !3d!4d), links con ?q=lat,lng, o links acortados (maps.app.goo.gl / goo.gl/maps).',
  })
  @IsNotEmpty({ message: 'El link de Google Maps es obligatorio' })
  @IsString()
  link!: string;
}