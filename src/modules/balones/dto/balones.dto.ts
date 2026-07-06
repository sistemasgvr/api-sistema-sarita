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

export class FiltroBalonesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteUbicacion?: number;
}

export class CreateBalonesDto extends AuditoriaDto {
  @ApiProperty()
  @MaxLength(50)
  @IsString()
  @IsNotEmpty()
  codigoBalon!: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  libroCilindro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  paginaLibro?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRegistro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteUbicacion?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClientePropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idReferencia?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProductoGas?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoBalon?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaUltimaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  vigenciaPruebaHidrostaticaAnios?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaProximaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFabricacion?: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  numeroRecepcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  presionActual?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class UpdateBalonesDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  codigoBalon?: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  libroCilindro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  paginaLibro?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRegistro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteUbicacion?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClientePropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idReferencia?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProductoGas?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoBalon?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaUltimaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  vigenciaPruebaHidrostaticaAnios?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaProximaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFabricacion?: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  numeroRecepcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  presionActual?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;
}
