import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsDateString, IsNumber, IsOptional } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroAlquileresDetalleDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlquiler?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;
}

export class CreateAlquileresDetalleDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idAlquiler!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idBalon!: number;
}

export class UpdateAlquileresDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idBalon?: number;
}

export class DevolverAlquileresDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional({ description: 'Fecha de devolución (default: hoy)' })
  @IsOptional()
  @IsDateString()
  fechaDevolucion?: string;

  @ApiPropertyOptional({
    description: 'Almacén destino (default: almacén del alquiler)',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacenDestino?: number;
}
