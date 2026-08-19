import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';
import { MONEY_NUMBER_OPTIONS } from '../../../common/constants/money';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

/**
 * Edita una cuenta financiera. Todos los campos son opcionales:
 * los que llegan como `undefined` se preservan.
 *
 * Las reglas de negocio (qué se puede editar según el estado de la cuenta)
 * se aplican en la función SQL fin_actualizar_cuenta.
 */
export class ActualizarCuentaDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 3, description: 'ID del tercero (cli_clientes.id)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTercero?: number;

  @ApiPropertyOptional({ example: 'Banco de Crédito del Perú' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  terceroNombre?: string;

  @ApiPropertyOptional({ example: '2026-07-24' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaEmision debe tener formato YYYY-MM-DD' })
  fechaEmision?: string;

  @ApiPropertyOptional({ example: '2026-08-24' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaVencimiento debe tener formato YYYY-MM-DD' })
  fechaVencimiento?: string;

  @ApiPropertyOptional({ example: 1500.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @IsPositive()
  monto?: number;

  @ApiPropertyOptional({ example: 'Alquiler de local julio 2026' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiPropertyOptional({ example: 'Depositar en cuenta corriente BCP soles' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional({ example: 'F001-000123' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroComprobante?: string;
}
