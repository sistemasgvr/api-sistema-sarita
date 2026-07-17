import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroMovimientosInventarioDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoMovimiento?: number;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class CreateMovimientoInventarioDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-07-02' })
  @IsDateString()
  fecha!: string;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idProducto!: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idTipoMovimiento!: number;

  @ApiProperty({ example: 5 })
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  cantidad!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocumentoRef?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoDocumentoRef?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  glosa?: string;
}

export class UpdateMovimientoInventarioDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: '2026-07-02' })
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  glosa?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocumentoRef?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoDocumentoRef?: number;
}
