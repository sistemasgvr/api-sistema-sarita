import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  ValidateIf,
  ValidateNested,
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

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipo?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idPrioridad?: number;
}

export class FiltroActividadesProximasDto {
  @ApiPropertyOptional({ example: 60, description: 'Minutos hacia adelante (mín. 5)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  minutos?: number;
}

export class ActividadItemDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  item?: number;

  @ApiPropertyOptional({ example: 12 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  descripcion?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  cantidad?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idBalon?: number;
}

export class CreateActividadDto extends AuditoriaDto {
  @ApiProperty({ example: 'Reunión de coordinación', maxLength: 150 })
  @ValidateIf((o: CreateActividadDto) => !o.idComprobante)
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  titulo?: string;

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

  @ApiPropertyOptional({ example: 1, description: 'Chofer / repartidor de flota propia' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idChoferResponsable?: number;

  @ApiPropertyOptional({ example: 10, description: 'Comprobante de venta origen del reparto' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idComprobante?: number;

  @ApiPropertyOptional({ type: [ActividadItemDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ActividadItemDto)
  items?: ActividadItemDto[];

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
  idChoferResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idComprobante?: number;

  @ApiPropertyOptional({ type: [ActividadItemDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ActividadItemDto)
  items?: ActividadItemDto[];

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
