import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
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
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

/**
 * Crear una cuenta financiera manual/externa
 * (préstamos bancarios, cobros no derivados de ventas, etc.).
 * NO se debe usar para cuentas que ya nacen de un comprobante de venta o compra.
 */
export class CrearCuentaDto extends AuditoriaDto {
  @ApiProperty({ example: 3, description: 'ID del tercero (cli_clientes.id)' })
  @Type(() => Number)
  @IsInt()
  idTercero: number;

  @ApiProperty({ example: '2026-07-24', description: 'Fecha de emisión (YYYY-MM-DD)' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaEmision debe tener formato YYYY-MM-DD' })
  fechaEmision: string;

  @ApiPropertyOptional({ example: '2026-08-24', description: 'Fecha de vencimiento (YYYY-MM-DD)' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaVencimiento debe tener formato YYYY-MM-DD' })
  fechaVencimiento?: string;

  @ApiProperty({ example: 1500.5, description: 'Monto total pendiente inicial' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @IsPositive()
  monto: number;

  @ApiPropertyOptional({
    example: 'Préstamo bancario BCP - cuota 3/12',
    description: 'Descripción de la cuenta (obligatoria recomendada para cuentas manuales)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}
