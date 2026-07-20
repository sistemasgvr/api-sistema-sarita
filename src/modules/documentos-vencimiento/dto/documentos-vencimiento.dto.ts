import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class CreateDocumentoVencimientoDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 1, description: 'ID de opción de lista: categoría (VEHICULO, CERTIFICADO, SEGURIDAD...)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoria?: number;

  @ApiProperty({ example: 'SOAT 2025' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  descripcion!: string;

  @ApiPropertyOptional({ example: 1, description: 'ID del vehículo asociado' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idVehiculo?: number;

  @ApiProperty({ example: '2025-12-31' })
  @IsDateString()
  @IsNotEmpty()
  fechaVencimiento!: string;

  @ApiPropertyOptional({ example: '2025-01-15' })
  @IsOptional()
  @IsDateString()
  fechaRenovacion?: string;

  @ApiPropertyOptional({ example: 'DOC-001' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroDocumento?: string;

  @ApiPropertyOptional({ example: 'Renovar antes de vencer' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  observacion?: string;

  @ApiPropertyOptional({ example: 1, description: 'ID de opción de lista: estado (VIGENTE, POR_VENCER, VENCIDO)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstado?: number;
}

export class UpdateDocumentoVencimientoDto extends PartialType(CreateDocumentoVencimientoDto) {}

export class FiltroDocumentoVencimientoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  isActivos?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por categoría' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoria?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por vehículo' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idVehiculo?: number;
}
