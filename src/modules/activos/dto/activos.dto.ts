import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class CreateActivoDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 69, description: 'Catálogo ACTIVOS_TIPO' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipo?: number;

  @ApiPropertyOptional({ example: 'Laptop Dell Latitude 5420' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  descripcion?: string;

  @ApiPropertyOptional({ example: '2023-01-15', description: 'Fecha de compra' })
  @IsOptional()
  @IsDateString()
  fechaCompra?: string;

  @ApiPropertyOptional({ example: 3500.0, description: 'Importe de adquisición' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  importe?: number;

  @ApiPropertyOptional({ example: 1, description: 'Sucursal (gen_sucursal)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiPropertyOptional({ example: 'Dell' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  marca?: string;

  @ApiPropertyOptional({ example: 'Latitude 5420' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  modelo?: string;

  @ApiPropertyOptional({ example: 'SN-ABC123' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  numeroSerie?: string;

  @ApiPropertyOptional({ example: 1, description: 'Trabajador responsable (tra_trabajadores)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTrabajadorResponsable?: number;

  @ApiPropertyOptional({ example: 'activos/laptop-123.jpg', description: 'Ruta de la imagen en storage' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  imagenPrincipalRuta?: string;
}

export class UpdateActivoDto extends PartialType(CreateActivoDto) {}

export class FiltroActivoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1, description: '1 activos, 0 inactivos, omitir = todos' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  estado?: number;

  @ApiPropertyOptional({ example: 69, description: 'Filtrar por tipo (catálogo ACTIVOS_TIPO)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipo?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por sucursal' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiPropertyOptional({ example: '2023-01-01', description: 'Fecha de compra desde' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ example: '2023-12-31', description: 'Fecha de compra hasta' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional({ example: 1000, description: 'Importe mínimo' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  importeMin?: number;

  @ApiPropertyOptional({ example: 5000, description: 'Importe máximo' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  importeMax?: number;

  @ApiPropertyOptional({
    description:
      'Si es true, firma la URL de la imagen principal. Default: false (listados sin esperar storage).',
    example: true,
  })
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  incluirImagenes?: boolean;
}
