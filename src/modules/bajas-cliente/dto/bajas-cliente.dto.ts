import { ApiProperty, ApiPropertyOptional, OmitType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class SolicitarBajaClienteDto extends OmitType(AuditoriaDto, [
  'idUsuarioAuditoria',
] as const) {
  @ApiProperty({ example: 1, description: 'ID del usuario que solicita la baja' })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idUsuarioAuditoria!: number;

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

  @ApiPropertyOptional({ example: 233, description: 'ID de tipo de solicitud (TipoSolicitud: BAJA)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoSolicitud?: number;
}

export class AprobarRechazarBajaDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idBaja!: number;
}

export class SolicitarReactivacionClienteDto extends OmitType(AuditoriaDto, [
  'idUsuarioAuditoria',
] as const) {
  @ApiProperty({
    example: 1,
    description: 'ID del usuario que solicita la reactivación',
  })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idUsuarioAuditoria!: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idCliente!: number;

  @ApiPropertyOptional({ example: 'El cliente regularizó sus documentos' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  motivoDetalle?: string;

  @ApiPropertyOptional({ example: 234, description: 'ID de tipo de solicitud (TipoSolicitud: REACTIVACION)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoSolicitud?: number;
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

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por tipo de solicitud (ID gen_lista_opciones: BAJA/REACTIVACION)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoSolicitud?: number;
}
