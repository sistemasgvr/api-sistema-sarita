import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class RegistrarPagoDto extends AuditoriaDto {
  @ApiProperty({ example: 12, description: 'ID de la cuenta financiera a abonar' })
  @Type(() => Number)
  @IsInt()
  idCuenta: number;

  @ApiProperty({ example: 150.5, description: 'Monto del pago/cobranza' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @IsPositive()
  monto: number;

  @ApiPropertyOptional({ example: '2026-07-24', description: 'Fecha del pago (YYYY-MM-DD)' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaPago debe tener formato YYYY-MM-DD' })
  fechaPago?: string;

  @ApiPropertyOptional({ example: 1, description: 'ID del medio de pago' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional({
    example: 7,
    description: 'ID de la cuenta bancaria de la empresa afectada (gen_cuenta_bancaria.id)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCuentaBancaria?: number;

  @ApiPropertyOptional({ example: 'OP-000123', description: 'N° de operación / N° cheque' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroOperacion?: string;

  @ApiPropertyOptional({ example: 'Depósito ventanilla', description: 'Referencia adicional' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  referencia?: string;

  @ApiPropertyOptional({ example: 'Pago parcial acordado' })
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional({
    example: false,
    description:
      'Si es true, se registra aunque el backend detecte un posible pago duplicado (mismo tercero/monto/fecha).',
  })
  @IsOptional()
  @IsBoolean()
  forzarDuplicado?: boolean;
}
