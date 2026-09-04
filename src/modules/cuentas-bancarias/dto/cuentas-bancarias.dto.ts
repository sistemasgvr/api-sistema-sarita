import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

/** Medio de pago asociado a una cuenta de la empresa (Fase 3, relación N:M). */
export class MedioPagoCuentaDto {
  @ApiProperty({ example: 267, description: 'ID de opción de lista MedioPago' })
  @Type(() => Number)
  @IsInt()
  idMedioPago: number;

  @ApiPropertyOptional({
    example: true,
    description: 'Cuenta que se propone por defecto al elegir este medio de pago',
  })
  @IsOptional()
  @IsBoolean()
  esPredeterminada?: boolean;
}

export class CreateCuentaBancariaDto extends AuditoriaDto {
  @ApiPropertyOptional({
    example: 'EMPRESA',
    enum: ['CLIENTE', 'EMPRESA'],
    description:
      'CLIENTE = cuenta del cliente (devoluciones). EMPRESA = cuenta propia que recibe los cobros. Si se omite se deduce de idCliente.',
  })
  @IsOptional()
  @IsString()
  @IsIn(['CLIENTE', 'EMPRESA'])
  ambito?: 'CLIENTE' | 'EMPRESA';

  @ApiPropertyOptional({ example: 'BCP Principal', description: 'Nombre corto para elegirla en los cobros' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  alias?: string;

  @ApiPropertyOptional({
    type: [MedioPagoCuentaDto],
    description:
      'Medios de pago que recibe esta cuenta (solo ámbito EMPRESA). Omitir para no tocarlos; [] para quitarlos todos.',
  })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => MedioPagoCuentaDto)
  mediosPago?: MedioPagoCuentaDto[];

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

  @ApiPropertyOptional({
    example: 'EMPRESA',
    enum: ['CLIENTE', 'EMPRESA'],
    description: 'Filtrar por ámbito. Reemplaza al truco de idCliente = -1.',
  })
  @IsOptional()
  @IsString()
  @IsIn(['CLIENTE', 'EMPRESA'])
  ambito?: 'CLIENTE' | 'EMPRESA';

  @ApiPropertyOptional({
    example: 267,
    description: 'Solo cuentas que aceptan este medio de pago (para el selector del cobro)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;
}
