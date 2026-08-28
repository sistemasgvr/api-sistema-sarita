import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type, Transform } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class FiltroRecargasPlantaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class RecargaPlantaDetalleDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idBalon!: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProducto?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  capacidad?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class CreateRecargaPlantaDto extends AuditoriaDto {
  @ApiProperty()
  @IsDateString()
  @IsNotEmpty()
  fechaSalida!: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional({ description: 'GRE de salida de vacíos a planta' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idGuiaSalida?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(10)
  serieGuiaSalida?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(15)
  numeroGuiaSalida?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional({
    description: 'true = registra salida (marca vacíos). false = solo borrador.',
    default: true,
  })
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsOptional()
  @IsBoolean()
  confirmarSalida?: boolean;

  @ApiProperty({ type: [RecargaPlantaDetalleDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RecargaPlantaDetalleDto)
  detalles!: RecargaPlantaDetalleDto[];
}

export class UpdateRecargaPlantaDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaSalida?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idGuiaRetorno?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(10)
  serieGuiaIngreso?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(15)
  numeroGuiaIngreso?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteCompra?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(10)
  serieFactura?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(15)
  numeroFactura?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaLlegadaAlmacen?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(50)
  lote?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaVencimientoLote?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class GenerarRecojoRecargaPlantaDto extends AuditoriaDto {
  @ApiPropertyOptional({ description: 'Fecha programada del recojo (default: hoy + 5 días)' })
  @IsOptional()
  @IsDateString()
  fechaProgramada?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUsuarioResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}
