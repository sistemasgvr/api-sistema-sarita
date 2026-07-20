import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class CreateCuentaBancariaDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: null, description: 'NULL = cuenta empresa, valor = cliente/proveedor' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID de opción de lista: banco' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idBanco?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID de opción de lista: tipo cuenta (AHORROS, CCI, YAPE, PLIN)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoCuenta?: number;

  @ApiPropertyOptional({ example: 'Juan Pérez' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  titular?: string;

  @ApiPropertyOptional({ example: '1234567890123456' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  numeroCuenta?: string;

  @ApiPropertyOptional({ example: '12345678901234567890' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  numeroCuentaInterbancaria?: string;

  @ApiPropertyOptional({ example: '987654321', description: 'YAPE / PLIN' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  telefonoBilletera?: string;

  @ApiPropertyOptional({ example: false })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  esPrincipal?: boolean;
}

export class UpdateCuentaBancariaDto extends PartialType(CreateCuentaBancariaDto) {}

export class FiltroCuentaBancariaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  isActivos?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por cliente. -1 para cuentas de empresa' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}
