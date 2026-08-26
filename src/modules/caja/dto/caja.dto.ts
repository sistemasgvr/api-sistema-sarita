import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class AbrirCajaDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-08-11' })
  @IsDateString()
  fecha!: string;

  @ApiProperty({ example: 100 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  montoInicial!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional({
    description: 'ID de sesión CERRADA a reabrir (flujo Reabrir caja)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSesion?: number;
}

export class CerrarCajaDto extends AuditoriaDto {
  @ApiProperty({ example: 450.5, description: 'Efectivo físico contado en el arqueo' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  montoEfectivoContado!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class FiltroCajaDiaDto {
  @ApiProperty({ example: '2026-08-11' })
  @IsDateString()
  fecha!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;
}

export class FiltroCajaSesionesDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiPropertyOptional({ description: 'ABIERTA / CERRADA' })
  @IsOptional()
  @IsString()
  estadoCaja?: string;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  pagina?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limite?: number = 20;

  get offset(): number {
    return ((this.pagina ?? 1) - 1) * (this.limite ?? 20);
  }
}

export class CrearCajaGastoDto extends AuditoriaDto {
  @ApiProperty()
  @IsDateString()
  fecha!: string;

  @ApiProperty({ example: 'Combustible' })
  @IsString()
  @MaxLength(200)
  concepto!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  monto!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaGasto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  numeroOperacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSesion?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;
}

export class CrearCajaDepositoDto extends AuditoriaDto {
  @ApiProperty()
  @IsDateString()
  fecha!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  monto!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCuentaBancaria?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  numeroOperacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSesion?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;
}

export class CrearCajaObservacionDto extends AuditoriaDto {
  @ApiProperty()
  @IsDateString()
  fecha!: string;

  @ApiProperty()
  @IsString()
  @MaxLength(1000)
  texto!: string;
}

export class ActualizarCajaGastoDto extends AuditoriaDto {
  @ApiProperty({ example: 'Combustible' })
  @IsString()
  @MaxLength(200)
  concepto!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  monto!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaGasto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(80)
  numeroOperacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class FiltroCajaGastosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaGasto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSesion?: number;

  @ApiPropertyOptional({ default: 1, description: '1 = activos (default), NULL/omitir vía query no soportado; usar 0 para ver de baja' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  estado?: number;
}

export class FiltroLibroDiarioDto {
  @ApiProperty({ example: '2026-08-11' })
  @IsDateString()
  fechaDesde!: string;

  @ApiPropertyOptional({ description: 'Si se omite, usa fechaDesde (día único)' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;
}
