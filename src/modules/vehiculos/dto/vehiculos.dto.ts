import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class CreateVehiculoDto extends AuditoriaDto {
  @ApiProperty({ example: 'ABC-123' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  placa!: string;

  @ApiPropertyOptional({
    example: 1,
    nullable: true,
    description:
      'Cliente/proveedor dueño del vehículo (null si es flota propia de la empresa)',
  })
  @IsOptional()
  @Transform(({ value }) => {
    if (value === null || value === '') return null;
    if (value === undefined) return undefined;
    return Number(value);
  })
  @ValidateIf((_, v) => v != null)
  @IsInt()
  idCliente?: number | null;

  @ApiPropertyOptional({
    example: 1,
    description: 'ID de opción de lista: tipo de vehículo',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoVehiculo?: number;

  @ApiPropertyOptional({ example: 'XYZ-987' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  placa2?: string;

  @ApiPropertyOptional({ example: 'Volvo' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  marca?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(100)
  marca2?: string;

  @ApiPropertyOptional({ example: 'FH 460' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  modelo?: string;

  @ApiPropertyOptional({ example: 2022 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  anio?: number;

  @ApiPropertyOptional({ example: 'Blanco' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  color?: string;

  @ApiPropertyOptional({
    description: 'Número de certificado de inscripción vehicular',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  certificadoInscripcion?: string;

  @ApiPropertyOptional({
    description:
      'Certificado de inscripción del semirremolque/carreta, si aplica',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  certificado2?: string;
}

export class UpdateVehiculoDto extends PartialType(CreateVehiculoDto) {}

export class FiltroVehiculoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  isActivos?: number;

  @ApiPropertyOptional({
    example: 1,
    description:
      'Filtrar por cliente/proveedor dueño. Use -1 para flota propia de la empresa (id_cliente IS NULL).',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}
