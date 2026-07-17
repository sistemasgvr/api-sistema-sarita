import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
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

export class FiltroActividadesDto extends FiltroPaginacionDto { 
  @ApiPropertyOptional({ description: 'Filtrar desde la fecha programada (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ description: 'Filtrar hasta la fecha programada (YYYY-MM-DD)' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstado?: number;
}

export class CreateActividadDto extends AuditoriaDto { 
  @ApiProperty({ example: 'Reunión de coordinación', maxLength: 150 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  titulo!: string; 

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiProperty({ example: '2026-07-17' })
  @IsDateString()
  @IsNotEmpty()
  fechaProgramada!: string; 

  @ApiPropertyOptional({ example: '09:00:00' })
  @IsOptional()
  @IsString()
  horaInicioEstimada?: string;

  @ApiPropertyOptional({ example: '10:30:00' })
  @IsOptional()
  @IsString()
  horaFinEstimada?: string;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idTipoActividad!: number; 

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idPrioridad!: number; 

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUsuarioResponsable?: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idEstadoActividad!: number; 

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}

export class UpdateActividadDto extends AuditoriaDto { 
  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  titulo?: string; 

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaProgramada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  horaInicioEstimada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  horaFinEstimada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoActividad?: number; 

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idPrioridad?: number; 

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUsuarioResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstadoActividad?: number; 

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}