import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class CreateLicenciaDto extends AuditoriaDto {
  @ApiProperty({ example: 'Q12345678' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(30)
  codigo!: string;

  @ApiProperty({ example: 1, description: 'ID del chofer al que pertenece la licencia' })
  @Type(() => Number)
  @IsInt()
  idChofer!: number;

  @ApiProperty({ example: '2023-01-15' })
  @IsDateString()
  fechaEmision!: string;

  @ApiProperty({ example: '2028-01-15' })
  @IsDateString()
  fechaVencimiento!: string;

  @ApiPropertyOptional({ example: 1, description: 'ID de opción de lista: tipo de licencia' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoLicencia?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID de opción de lista: categoría de licencia (A-I, A-IIa, etc.)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaLicencia?: number;
}

export class UpdateLicenciaDto extends PartialType(CreateLicenciaDto) {}

export class FiltroLicenciaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    required: false,
    example: 1,
    nullable: true,
    description: 'Estado de la licencia: 1 = activas, 0 = inactivas, null = todas',
  })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  soloActivos?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por chofer dueño de la licencia' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idChofer?: number;
}
