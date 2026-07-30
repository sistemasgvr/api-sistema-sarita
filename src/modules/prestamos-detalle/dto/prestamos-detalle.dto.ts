import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type, Transform } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class FiltroPrestamosDetalleDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPrestamo?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;
}

export class CreatePrestamosDetalleDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idPrestamo!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProducto?: number;

  @ApiPropertyOptional()
  @MaxLength(255)
  @IsOptional()
  @IsString()
  motivoEspecifico?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaEntregado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaPrestamo?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  diasPrestamo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDevolucion?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaEntrega?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaEntrega?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaDevolucion?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaDevolucion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class UpdatePrestamosDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProducto?: number;

  @ApiPropertyOptional()
  @MaxLength(255)
  @IsOptional()
  @IsString()
  motivoEspecifico?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaEntregado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaPrestamo?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  diasPrestamo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDevolucion?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaEntrega?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaEntrega?: string;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieGuiaDevolucion?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroGuiaDevolucion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class DevolverPrestamosDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional({ description: 'Fecha de devolución (default: hoy)' })
  @IsOptional()
  @IsDateString()
  fechaDevolucion?: string;

  @ApiPropertyOptional({
    description: 'Almacén destino del reingreso (default: almacén del préstamo)',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacenDestino?: number;
}
