import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
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

  @ApiProperty({
    example: 5,
    description: 'Entera si la U.M. es UNID/piezas; decimal permitido en MT3/KG y gases.',
  })
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

  @ApiPropertyOptional({ example: 2, description: 'Almacén destino (obligatorio si el tipo es TRASLADO)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacenDestino?: number;

  @ApiPropertyOptional({
    enum: ['MAS', 'MENOS'],
    description: 'Sentido del AJUSTE: MAS suma stock (default), MENOS resta',
  })
  @IsOptional()
  @IsIn(['MAS', 'MENOS'])
  sentidoAjuste?: 'MAS' | 'MENOS';
}

export class TrasladoLoteDetalleDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idProducto!: number;

  @ApiProperty({ example: 2 })
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  cantidad!: number;
}

export class CreateTrasladoLoteDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-07-02' })
  @IsDateString()
  fecha!: string;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiProperty({ example: 2 })
  @Type(() => Number)
  @IsInt()
  idAlmacenDestino!: number;

  @ApiProperty({ example: 1, description: 'Debe ser tipo TRASLADO' })
  @Type(() => Number)
  @IsInt()
  idTipoMovimiento!: number;

  @ApiProperty({ type: [TrasladoLoteDetalleDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => TrasladoLoteDetalleDto)
  detalles!: TrasladoLoteDetalleDto[];

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
