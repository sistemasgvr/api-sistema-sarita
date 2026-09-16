import { Type } from 'class-transformer';
import { IsDateString, IsInt, IsNumber, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

/** Datos adicionales. El servidor toma la contraparte y el comprobante del origen. */
export class TributoOrigenDto {
  @ApiProperty() @Type(() => Number) @IsInt() @Min(1)
  idEmpresa!: number;

  @ApiProperty() @IsString() @Matches(/^[PR][A-Z0-9]{3}$/)
  serie!: string;

  @ApiProperty() @IsDateString({ strict: true }) @Matches(/^\d{4}-\d{2}-\d{2}$/)
  fechaEmision!: string;

  @ApiProperty() @IsString() @Matches(/^\d{2}$/)
  regimen!: string;

  @ApiProperty() @IsNumber({ maxDecimalPlaces: 2 }) @Min(0.01) @Max(100)
  tasa!: number;

  @ApiProperty({ description: 'Importe de la operación al que se aplica la tasa' })
  @IsNumber({ maxDecimalPlaces: 2 }) @Min(0.01)
  baseImponible!: number;

  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(500)
  observacion?: string;
}
