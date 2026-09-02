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
  ValidateIf,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroInventarioMovimientosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ enum: ['PRODUCTO', 'BALON'] })
  @IsOptional()
  @IsIn(['PRODUCTO', 'BALON'])
  naturaleza?: 'PRODUCTO' | 'BALON';

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idBalon?: number;

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

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoDocumentoOrigen?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocumentoOrigen?: number;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class CreateInventarioMovimientoDto extends AuditoriaDto {
  @ApiProperty({ enum: ['PRODUCTO', 'BALON'] })
  @IsIn(['PRODUCTO', 'BALON'])
  naturaleza!: 'PRODUCTO' | 'BALON';

  @ApiProperty({ example: 'AJUSTE', description: 'Código en la lista TipoMovInvUnificado' })
  @IsString()
  codigoTipoMovimiento!: string;

  @ApiPropertyOptional({ example: '2026-09-01T10:00:00' })
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional({ example: 1, description: 'Obligatorio si naturaleza = PRODUCTO, u opcional para adjuntar gas a un movimiento de balón' })
  @ValidateIf((o: CreateInventarioMovimientoDto) => o.naturaleza === 'PRODUCTO' || o.idProducto !== undefined)
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional({ example: 1, description: 'Obligatorio si naturaleza = BALON' })
  @ValidateIf((o: CreateInventarioMovimientoDto) => o.naturaleza === 'BALON')
  @Type(() => Number)
  @IsInt()
  idBalon?: number;

  @ApiProperty({ example: 5 })
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  cantidad!: number;

  @ApiPropertyOptional({ example: 1 })
  @ValidateIf(
    (o: CreateInventarioMovimientoDto) =>
      o.codigoTipoMovimiento === 'TRASLADO' || o.idAlmacenOrigen !== undefined,
  )
  @Type(() => Number)
  @IsInt()
  idAlmacenOrigen?: number;

  @ApiPropertyOptional({ example: 2, description: 'Obligatorio si el tipo es TRASLADO' })
  @ValidateIf(
    (o: CreateInventarioMovimientoDto) =>
      o.codigoTipoMovimiento === 'TRASLADO' || o.idAlmacenDestino !== undefined,
  )
  @Type(() => Number)
  @IsInt()
  idAlmacenDestino?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ example: 'VENTA', description: 'Código en la lista TipoDocumentoRef' })
  @IsOptional()
  @IsString()
  codigoTipoDocumentoOrigen?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocumentoOrigen?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Línea de detalle del documento origen (idempotencia por línea)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocumentoDetalle?: number;

  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  glosa?: string;

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

export class CreateTrasladoLoteInventarioDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-09-01' })
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

  @ApiPropertyOptional({ example: 'AJUSTE_MANUAL' })
  @IsOptional()
  @IsString()
  codigoDocumentoRef?: string;
}
