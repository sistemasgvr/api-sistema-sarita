import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroRutasPueblosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ description: 'ABIERTA | EN_RUTA | CERRADA | CANCELADA' })
  @IsOptional()
  @IsString()
  estadoNombre?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class RutaPuebloDetalleSalidaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idBalon: number;

  @ApiProperty({ description: 'Libras al salir (sellado o con residual)' })
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  lbSalida: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  sellado?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class CreateRutaPuebloDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idAlmacen: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUsuarioResponsable?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idChofer?: number;

  @ApiPropertyOptional({
    description:
      'Opcional. Si se omite, se calcula como capacidad_m3 / capacidad_lb del tipo de cada cilindro',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0.000001)
  factorLbM3?: number;

  @ApiPropertyOptional({
    description:
      'Opcional. Si se omite, usa tolerancia_m3_ruta_pueblo de la empresa (default 0.5)',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  toleranciaM3?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiProperty({ type: [RutaPuebloDetalleSalidaDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RutaPuebloDetalleSalidaDto)
  detalles: RutaPuebloDetalleSalidaDto[];
}

export class UpdateRutaPuebloDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUsuarioResponsable?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idChofer?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0.000001)
  factorLbM3?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  toleranciaM3?: number;

  @ApiPropertyOptional({ description: 'Solo CANCELADA' })
  @IsOptional()
  @IsString()
  estadoNombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RutaPuebloDetalleRetornoDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idBalon: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  lbRetorno: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RegistrarRetornoRutaPuebloDto extends AuditoriaDto {
  @ApiProperty({ type: [RutaPuebloDetalleRetornoDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RutaPuebloDetalleRetornoDto)
  @IsNotEmpty()
  detalles: RutaPuebloDetalleRetornoDto[];
}

export class CerrarRutaPuebloDto extends AuditoriaDto {
  @ApiProperty({ description: 'm³ de ventas reportados por el repartidor' })
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  m3ReportadoVentas: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}
