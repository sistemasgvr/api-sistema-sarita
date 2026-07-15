import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, MaxLength, IsDateString } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroActividadesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: '2026-07-01' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ example: '2026-07-31' })
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
  @ApiProperty({ example: 'Entrega de Oxígeno Medicinal' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  titulo!: string;

  @ApiPropertyOptional({ example: 'Descripción de prueba de la actividad' })
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiProperty({ example: '2026-07-13' })
  @IsDateString()
  fechaProgramada!: string;

  @ApiPropertyOptional({ example: '08:00:00' })
  @IsOptional()
  @IsString()
  horaInicioEstimada?: string;

  @ApiPropertyOptional({ example: '10:00:00' })
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

  @ApiPropertyOptional({ maxLength: 500, example: 'Ninguna observación' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}

export class UpdateActividadDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 'Entrega de Oxígeno Medicinal' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  titulo?: string;

  @ApiPropertyOptional({ example: 'Descripción actualizada' })
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional({ example: '2026-07-13' })
  @IsOptional()
  @IsString()
  fechaProgramada?: string;

  @ApiPropertyOptional({ example: '08:00:00' })
  @IsOptional()
  @IsString()
  horaInicioEstimada?: string;

  @ApiPropertyOptional({ example: '10:00:00' })
  @IsOptional()
  @IsString()
  horaFinEstimada?: string;

  @ApiPropertyOptional({ example: '2026-07-13 11:00:00' })
  @IsOptional()
  @IsString() 
  fechaHoraCierre?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoActividad?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idPrioridad?: number;

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

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstadoActividad?: number;

  @ApiPropertyOptional({ maxLength: 500, example: 'Observaciones actualizadas' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}