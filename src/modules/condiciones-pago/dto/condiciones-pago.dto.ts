import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateCondicionPagoDto extends AuditoriaDto {
  @ApiProperty({ example: 'CONTADO', maxLength: 10 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(10)
  codigo!: string;

  @ApiProperty({ example: 'Contado', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre!: string;

  @ApiProperty({
    example: 0,
    default: 0,
    description: 'Días hasta vencimiento (crédito) o hasta la 1ª cuota',
  })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  diasCredito!: number;

  @ApiPropertyOptional({
    example: 3,
    nullable: true,
    description: 'Cantidad de cuotas (>1 = plan mensual). Null = sin plan.',
  })
  @ValidateIf((_, v) => v !== null && v !== undefined)
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  numeroCuotas?: number | null;

  @ApiPropertyOptional({
    example: 15,
    nullable: true,
    description: 'Día del mes (1..31) a cobrar cada cuota',
  })
  @ValidateIf((_, v) => v !== null && v !== undefined)
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  diaMesPago?: number | null;
}

export class UpdateCondicionPagoDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 10 })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  codigo?: string;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  nombre?: string;

  @ApiPropertyOptional({ example: 30 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  diasCredito?: number;

  @ApiPropertyOptional({ example: 3, nullable: true })
  @ValidateIf((_, v) => v !== null && v !== undefined)
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  numeroCuotas?: number | null;

  @ApiPropertyOptional({ example: 15, nullable: true })
  @ValidateIf((_, v) => v !== null && v !== undefined)
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  diaMesPago?: number | null;
}
