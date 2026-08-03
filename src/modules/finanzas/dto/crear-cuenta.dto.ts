import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

/**
 * Crear una cuenta financiera manual/externa
 * (préstamos bancarios, cobros no derivados de ventas, etc.).
 * NO se debe usar para cuentas que ya nacen de un comprobante de venta o compra.
 *
 * Tercero: debe venir `idTercero` (cliente/proveedor de cli_clientes) O
 * `terceroNombre` (texto libre) — al menos uno.
 */
export class CrearCuentaDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 3, description: 'ID del tercero (cli_clientes.id)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTercero?: number;

  @ApiPropertyOptional({
    example: 'Banco de Crédito del Perú',
    description: 'Nombre libre del tercero cuando no está registrado en cli_clientes',
  })
  @ValidateIf((o: CrearCuentaDto) => !o.idTercero)
  @IsString()
  @MaxLength(255)
  terceroNombre?: string;

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
    example: 'Alquiler de local julio 2026',
    description: 'Título breve para identificar la cuenta',
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiPropertyOptional({
    example: 'Depositar en cuenta corriente BCP soles',
    description: 'Observación / notas internas',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional({
    example: 12,
    description: 'ID del banco (gen_lista_opciones — lista Banco). Solo para préstamos bancarios.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idBanco?: number;

  @ApiPropertyOptional({ example: 15.5, description: 'Tasa de interés % anual (opcional)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  tasaInteres?: number;

  @ApiPropertyOptional({
    example: 'F001-000123',
    description: 'N° de comprobante/documento libre (opcional)',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroComprobante?: string;
}

/**
 * Crear una cuenta financiera CON PLAN DE CUOTAS
 * (préstamos bancarios, ventas/compras a plazos, servicios pagados en N cuotas...).
 *
 * Genera 1 cabecera en fin_cuenta + N cuotas hijas equidistantes.
 */
export class CrearCuentaCuotasDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 3, description: 'ID del tercero (cli_clientes.id)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTercero?: number;

  @ApiPropertyOptional({ example: 'Interbank', description: 'Nombre libre del tercero' })
  @ValidateIf((o: CrearCuentaCuotasDto) => !o.idTercero)
  @IsString()
  @MaxLength(255)
  terceroNombre?: string;

  @ApiProperty({ example: '2026-07-24' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaEmision debe tener formato YYYY-MM-DD' })
  fechaEmision: string;

  @ApiProperty({ example: 12000, description: 'Monto total del plan (se distribuye entre las cuotas)' })
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @IsPositive()
  montoTotal: number;

  @ApiProperty({ example: 12, description: 'Número de cuotas del plan' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  numeroCuotas: number;

  @ApiProperty({ example: '2026-08-24', description: 'Fecha exacta de la primera cuota (YYYY-MM-DD)' })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaPrimeraCuota debe tener formato YYYY-MM-DD' })
  fechaPrimeraCuota: string;

  @ApiProperty({
    example: 30,
    description:
      'Día del mes en que se pagan las cuotas siguientes (1–31). Si el mes no tiene ese día, se usa el último del mes.',
  })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(31)
  diaMesPago: number;

  @ApiPropertyOptional({ example: 'Préstamo capital de trabajo BCP' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiPropertyOptional({ example: 'Cuenta corriente 194-…' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional({ example: 12, description: 'ID del banco (para préstamos bancarios)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idBanco?: number;

  @ApiPropertyOptional({ example: 18.0, description: 'Tasa de interés % anual' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  tasaInteres?: number;

  @ApiPropertyOptional({ example: 'F001-000123', description: 'N° de comprobante libre' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  numeroComprobante?: string;
}
