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

export const ESTADOS_VENCIMIENTO = ['VIGENTE', 'POR_VENCER', 'VENCIDO'] as const;
export type EstadoVencimiento = (typeof ESTADOS_VENCIMIENTO)[number];

export class CreateDocumentoVencimientoDto extends AuditoriaDto {
  @ApiPropertyOptional({
    example: 1,
    description:
      'ID de opción de lista: categoría (BPA, SALUBRIDAD, DEFENSA_CIVIL, SANEAMIENTO_AMBIENTAL, EXTINTORES, SOAT, INSPECCION, MUNICIPAL, SEGURIDAD, CERTIFICADO, OTRO...)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoria?: number;

  @ApiProperty({ example: 'BPA - Planta principal' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  descripcion!: string;

  @ApiPropertyOptional({
    example: 1,
    description:
      'Alcance del documento: ID del vehículo (excluyente con idSucursal). Ninguno de los dos = alcance empresa.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idVehiculo?: number;

  @ApiPropertyOptional({
    example: 1,
    description:
      'Alcance del documento: ID de la sucursal/local (excluyente con idVehiculo). Ninguno de los dos = alcance empresa.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiProperty({ example: '2026-12-31' })
  @IsDateString()
  @IsNotEmpty()
  fechaVencimiento!: string;

  @ApiPropertyOptional({ example: '2026-01-15', description: 'Fecha de la última renovación/emisión' })
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

  @ApiPropertyOptional({
    example: 1,
    description:
      'Override manual del estado (ID de opción de lista). No se usa para mostrar el estado: ' +
      'el listado siempre calcula VIGENTE/POR_VENCER/VENCIDO a partir de fechaVencimiento.',
  })
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

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por sucursal/local' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiPropertyOptional({
    enum: ESTADOS_VENCIMIENTO,
    description: 'Filtrar por estado calculado (VIGENTE / POR_VENCER / VENCIDO)',
  })
  @IsOptional()
  @IsIn(ESTADOS_VENCIMIENTO)
  estado?: EstadoVencimiento;

  @ApiPropertyOptional({
    example: 30,
    description: 'Días de anticipación para considerar "POR_VENCER" (por defecto 30)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  diasAlerta?: number;
}
