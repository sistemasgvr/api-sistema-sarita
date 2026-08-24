import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { MONEY_NUMBER_OPTIONS } from '../../../common/constants/money';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class FiltroProductosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSubCategoria?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoria?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  esGas?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  esServicio?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  esAlquilable?: boolean;

  @ApiPropertyOptional({
    description: 'Servicio de taller (cilindro). false = solo cobro (flete, etc.)',
  })
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  esMantenimiento?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  afectaStock?: boolean;

  @ApiPropertyOptional({
    description: '1=activos, 0=inactivos, omitir/null=todos',
    example: 1,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  soloActivos?: number | null;

  @ApiPropertyOptional({
    description: 'Si se envía, incluye stock_actual del almacén',
    example: 1,
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional({
    description:
      'Si es true, firma URLs de imagen principal. Default: false (selects/POS/filtros sin esperar storage).',
    example: true,
  })
  @IsOptional()
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsBoolean()
  incluirImagenes?: boolean;
}

export class ImprimirUbicacionesProductoDto {
  @ApiProperty({
    type: [Number],
    example: [1, 2, 3],
    description: 'IDs de productos con código de ubicación único',
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ArrayUnique()
  @Type(() => Number)
  @IsInt({ each: true })
  ids!: number[];
}

export class GenerarCodigoUbicacionDto {
  @ApiProperty({
    example: 'Adaptador Rosca Oxígeno CGA540',
    description: 'Nombre del producto para construir iniciales',
  })
  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  nombre!: string;

  @ApiPropertyOptional({
    example: 'Generico',
    description: 'Marca opcional para el prefijo',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  marca?: string;

  @ApiPropertyOptional({
    example: 12,
    description:
      'Si se envía, genera y asigna el código al producto (actualiza BD)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;
}

export class GenerarCodigoProductoDto {
  @ApiPropertyOptional({
    example: 'PRO',
    description: 'Prefijo del código (PRO, SER, GAS). Por defecto PRO.',
    maxLength: 10,
  })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  prefijo?: string;

  @ApiPropertyOptional({
    example: false,
    description: 'Si es true, usa prefijo SER (salvo que envíe prefijo explícito).',
  })
  @IsOptional()
  @IsBoolean()
  esServicio?: boolean;

  @ApiPropertyOptional({
    example: false,
    description: 'Si es true, usa prefijo GAS (salvo que envíe prefijo explícito).',
  })
  @IsOptional()
  @IsBoolean()
  esGas?: boolean;
}

export class CreateProductoDto extends AuditoriaDto {
  @ApiProperty({ example: 'GAS-OX-001', maxLength: 30 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(30)
  codigo!: string;

  @ApiProperty({ example: 'Oxígeno Industrial', maxLength: 300 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(300)
  nombre!: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSubCategoria?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  codigoBarra?: string;

  @ApiPropertyOptional({
    example: '0103',
    maxLength: 20,
    description: 'Código digitable de ubicación/cajón',
  })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  codigoUbicacion?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  marca?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  presentacion?: string;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  esGas?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  esServicio?: boolean;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  esAlquilable?: boolean;

  @ApiPropertyOptional({
    default: false,
    description: 'Si es servicio: entra a taller. El resto de servicios solo se cobra.',
  })
  @IsOptional()
  @IsBoolean()
  esMantenimiento?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  afectaStock?: boolean;

  @ApiPropertyOptional({ example: 0, default: 0, description: 'Precio de venta base' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precio?: number;

  @ApiPropertyOptional({ example: 0, default: 0, description: 'Precio de compra / costo' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precioCompra?: number;

  @ApiPropertyOptional({
    example: 0,
    default: 0,
    description: 'Depósito/garantía (solo si es alquilable)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precioGarantia?: number;

  @ApiPropertyOptional({ description: 'm³ por 1 kg (solo gases)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.000001)
  factorKgM3?: number;

  @ApiPropertyOptional({ description: 'm³ por 1 lb (solo gases)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.000001)
  factorLbM3?: number;
}

export class UpdateProductoDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 30 })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  codigo?: string;

  @ApiPropertyOptional({ maxLength: 300 })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSubCategoria?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  codigoBarra?: string;

  @ApiPropertyOptional({ maxLength: 20 })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  codigoUbicacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional({ maxLength: 100 })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  marca?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  presentacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esGas?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esServicio?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esAlquilable?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  esMantenimiento?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  afectaStock?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precio?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precioCompra?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber(MONEY_NUMBER_OPTIONS)
  @Min(0)
  precioGarantia?: number;

  @ApiPropertyOptional({ description: 'm³ por 1 kg (solo gases)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.000001)
  factorKgM3?: number;

  @ApiPropertyOptional({ description: 'm³ por 1 lb (solo gases)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.000001)
  factorLbM3?: number;
}
