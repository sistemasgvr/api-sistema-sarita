import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroGarantiasDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPrestamo?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlquiler?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstado?: number;
}

export class CreateGarantiaDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idCliente!: number;

  @ApiProperty({ description: 'Monto cobrado (queda como saldo inicial)' })
  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  monto!: number;

  @ApiPropertyOptional({ description: 'Comprobante de cobro (boleta/factura/NV)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobante?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPrestamo?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlquiler?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProducto?: number;

  @ApiPropertyOptional()
  @MaxLength(150)
  @IsOptional()
  @IsString()
  ubicacion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  cantidadVenta?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUnidadMedida?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRegistro?: string;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional({
    description: 'Método con el que se recibe el depósito (efectivo, yape, etc.)',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMedioPago?: number;
}

export class DevolverGarantiaDto extends AuditoriaDto {
  @ApiProperty({ description: 'Monto a devolver (parcial o total del saldo)' })
  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  monto!: number;

  @ApiPropertyOptional({ description: 'Nota de crédito u otro comprobante de devolución' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobante?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;
}
