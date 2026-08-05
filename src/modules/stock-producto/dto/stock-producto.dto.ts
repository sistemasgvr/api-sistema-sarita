import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class FiltroStockDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  soloBajoMinimo?: boolean;

  @ApiPropertyOptional({
    description: '1=activos, 0=inactivos, omitir/null=todos',
    example: 1,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  soloActivos?: number | null;
}

export class CreateStockDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idProducto!: number;

  @ApiPropertyOptional({
    example: 0,
    default: 0,
    description: 'Entero si la U.M. es UNID/piezas; decimal permitido en MT3/KG y gases.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  stock?: number;

  @ApiPropertyOptional({
    example: 0,
    default: 0,
    description: 'Entero si la U.M. es UNID/piezas; decimal permitido en MT3/KG y gases.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  stockMinimo?: number;
}

export class UpdateStockDto extends AuditoriaDto {
  @ApiPropertyOptional({
    example: 2,
    description:
      'Solo stock mínimo de alerta. La cantidad se modifica con movimientos de inventario.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  stockMinimo?: number;
}
