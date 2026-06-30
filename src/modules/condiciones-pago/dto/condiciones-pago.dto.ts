import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
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

  @ApiProperty({ example: 0, default: 0 })
  @Type(() => Number)
  @IsInt()
  @Min(0)
  diasCredito!: number;
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
}
