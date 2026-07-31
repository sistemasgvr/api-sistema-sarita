import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroNotificacionesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 0, description: '1 = solo no leídas' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  soloNoLeidas?: number;
}

export class CrearNotificacionDto {
  @ApiProperty({ example: 'ALQUILER_VENCIDO' })
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  codigoTipo!: string;

  @ApiProperty({ example: 'Alquiler vencido' })
  @IsString()
  @MinLength(2)
  @MaxLength(200)
  titulo!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  mensaje?: string;

  @ApiPropertyOptional({ type: Object })
  @IsOptional()
  @IsObject()
  payload?: Record<string, unknown>;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idReferencia?: number;

  @ApiPropertyOptional({ example: 'ALQUILER' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  tipoReferencia?: string;

  @ApiPropertyOptional({
    description: 'Clave para evitar duplicados (usuario+clave)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(160)
  claveDedupe?: string;

  @ApiPropertyOptional({
    description: 'Destinatario único. Si se omite, usar idsUsuarios/idsRoles/permiso.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUsuario?: number;

  @ApiPropertyOptional({ type: [Number] })
  @IsOptional()
  @IsArray()
  @Type(() => Number)
  @IsInt({ each: true })
  idsUsuarios?: number[];

  @ApiPropertyOptional({ type: [Number] })
  @IsOptional()
  @IsArray()
  @Type(() => Number)
  @IsInt({ each: true })
  idsRoles?: number[];

  @ApiPropertyOptional({
    example: 'alquileres_balon.listar',
    description: 'Notifica a todos los usuarios con este permiso (o auth.todo)',
  })
  @IsOptional()
  @IsString()
  permiso?: string;
}
