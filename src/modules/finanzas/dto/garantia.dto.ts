import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class CrearGarantiaDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-08-04', description: 'Fecha de recepción de la garantía' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fecha debe tener formato YYYY-MM-DD' })
  fecha: string;

  @ApiProperty({ example: 3, description: 'ID del cliente (cli_clientes.id)' })
  @Type(() => Number)
  @IsInt()
  idCliente: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Método con el que el cliente PAGÓ la garantía (efectivo, yape, etc.)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiProperty({ example: 50.0, description: 'Importe de la garantía' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @IsPositive()
  importe: number;

  @ApiPropertyOptional({ example: 'Balón de 10kg, se compromete a devolver en 15 días' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class ActualizarGarantiaDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: '2026-08-04' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fecha debe tener formato YYYY-MM-DD' })
  fecha?: string;

  @ApiPropertyOptional({ example: 3 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ example: 1, description: 'Método de pago (recepción)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMedioPago?: number;

  @ApiPropertyOptional({ example: 50.0 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @IsPositive()
  importe?: number;

  @ApiPropertyOptional({ example: '...' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class ReembolsarGarantiaDto extends AuditoriaDto {
  @ApiProperty({ example: '2026-09-04', description: 'Fecha en que se devolvió el dinero' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaReembolso debe tener formato YYYY-MM-DD' })
  fechaReembolso: string;

  @ApiProperty({ example: 2, description: 'Método usado para reembolsar (efectivo, transferencia, etc.)' })
  @Type(() => Number)
  @IsInt()
  idMedioReembolso: number;

  @ApiPropertyOptional({ example: 'Entregado en tienda con voucher #123' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacionReembolso?: string;
}

export class FiltroGarantiaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 3 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ example: '2026-01-01' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'desde debe tener formato YYYY-MM-DD' })
  desde?: string;

  @ApiPropertyOptional({ example: '2026-12-31' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'hasta debe tener formato YYYY-MM-DD' })
  hasta?: string;

  @ApiPropertyOptional({ enum: ['ACTIVA', 'DEVUELTA'], example: 'ACTIVA' })
  @IsOptional()
  @IsString()
  @IsIn(['ACTIVA', 'DEVUELTA'])
  estado?: string;
}
