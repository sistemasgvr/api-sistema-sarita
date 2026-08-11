import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsNumber, IsOptional, IsPositive, IsString, Matches, MaxLength } from 'class-validator';

export class VerificarDuplicadoPagoDto {
  @ApiProperty({ example: 12 })
  @Type(() => Number)
  @IsInt()
  idCuenta: number;

  @ApiProperty({ example: '2026-08-04', description: 'Fecha del pago propuesto' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaPago debe tener formato YYYY-MM-DD' })
  fechaPago: string;

  @ApiProperty({ example: 150.5 })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @IsPositive()
  monto: number;

  @ApiPropertyOptional({ example: 7, description: 'Días de ventana para "duplicado probable"', default: 7 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  diasVentana?: number;

  @ApiPropertyOptional({ example: 'F001-000123' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroComprobante?: string;
}
