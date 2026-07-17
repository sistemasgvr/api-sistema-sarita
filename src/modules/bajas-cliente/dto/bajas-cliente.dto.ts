import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class SolicitarBajaClienteDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idCliente!: number;

  @ApiPropertyOptional({ example: 1, description: 'ID de motivo de baja (MotivoBajaCliente)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMotivoBaja?: number;

  @ApiPropertyOptional({ example: 'Cliente solicitó la baja voluntariamente' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  motivoDetalle?: string;
}

export class AprobarRechazarBajaDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idBaja!: number;
}

export class FiltroBajaClienteDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  isActivos?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por cliente' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID de estado de aprobación (EstadoAprobacion)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstadoAprobacion?: number;
}
