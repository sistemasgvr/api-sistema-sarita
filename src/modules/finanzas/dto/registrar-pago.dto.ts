import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Matches,
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

  @ApiPropertyOptional({ example: 'OP-000123', description: 'Referencia / N° de operación' })
  @IsOptional()
  @IsString()
  referencia?: string;

  @ApiPropertyOptional({ example: 'Pago parcial acordado' })
  @IsOptional()
  @IsString()
  observacion?: string;
}
