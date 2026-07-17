import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class GuiaRemisionDetalleDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  item?: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idProducto!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  descripcion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  cantidad!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idBalon?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  glosa?: string;
}

export class GuiaRemisionReferenciaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idTipoComprobante!: number;

  @ApiPropertyOptional({ example: 'F001' })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  serie?: string;

  @ApiPropertyOptional({ example: '00000123' })
  @IsOptional()
  @IsString()
  @MaxLength(15)
  numero?: string;

  @ApiPropertyOptional({ example: '2026-07-16' })
  @IsOptional()
  @IsDateString()
  fecha?: string;
}

export class CreateGuiaRemisionDto extends AuditoriaDto {
  @ApiProperty({ description: 'ID opción TipoGuiaRemision (09/31)' })
  @Type(() => Number)
  @IsInt()
  idTipoGuiaRemision!: number;

  @ApiProperty({ example: 'T001' })
  @IsString()
  @MaxLength(10)
  serie!: string;

  @ApiPropertyOptional({ example: '00000001' })
  @IsOptional()
  @IsString()
  @MaxLength(15)
  numero?: string;

  @ApiPropertyOptional({ example: '2026-07-16' })
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional({ example: '2026-07-16' })
  @IsOptional()
  @IsDateString()
  fechaTraslado?: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idSucursal!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiPropertyOptional({ description: 'Cliente relacionado (opcional)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idMotivoTraslado!: number;

  @ApiPropertyOptional({ description: 'Unidad de peso (preferible KGM)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiProperty({ example: 12.5 })
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  pesoBruto!: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  numeroBultos?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccionOrigen?: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idDistritoOrigen!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idDestinatario!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccionLlegada?: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idDistritoLlegada!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idModalidadTraslado!: number;

  @ApiPropertyOptional({ description: 'Obligatorio si modalidad pública (01)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTransportista?: number;

  @ApiPropertyOptional({ description: 'Obligatorio si modalidad privada (02)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idChofer?: number;

  @ApiPropertyOptional({ description: 'Obligatorio si modalidad privada (02)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idVehiculo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;

  @ApiProperty({ type: [GuiaRemisionDetalleDto] })
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => GuiaRemisionDetalleDto)
  detalles!: GuiaRemisionDetalleDto[];

  @ApiPropertyOptional({ type: [GuiaRemisionReferenciaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GuiaRemisionReferenciaDto)
  referencias?: GuiaRemisionReferenciaDto[];
}

export class UpdateGuiaRemisionDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: '2026-07-16' })
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional({ example: '2026-07-16' })
  @IsOptional()
  @IsDateString()
  fechaTraslado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idSucursal?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMotivoTraslado?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUnidadMedida?: number;

  @ApiPropertyOptional({ example: 12.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  pesoBruto?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  numeroBultos?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccionOrigen?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDistritoOrigen?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDestinatario?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccionLlegada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDistritoLlegada?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idModalidadTraslado?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTransportista?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idChofer?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idVehiculo?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;

  @ApiPropertyOptional({ type: [GuiaRemisionDetalleDto] })
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => GuiaRemisionDetalleDto)
  detalles?: GuiaRemisionDetalleDto[];

  @ApiPropertyOptional({ type: [GuiaRemisionReferenciaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => GuiaRemisionReferenciaDto)
  referencias?: GuiaRemisionReferenciaDto[];
}

export class FiltroGuiaRemisionDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoGuia?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDestinatario?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstado?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstadoSunat?: number;

  @ApiPropertyOptional({ example: '2026-07-01' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ example: '2026-07-31' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional({ example: 'T001' })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  serie?: string;
}

export class SiguienteNumeroGuiaQueryDto {
  @ApiProperty({ example: 'T001' })
  @IsString()
  @MaxLength(10)
  serie!: string;
}
