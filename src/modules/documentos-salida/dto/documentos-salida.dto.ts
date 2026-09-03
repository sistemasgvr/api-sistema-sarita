import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class CreateDocSalidaDto extends AuditoriaDto {
  @ApiProperty({
    example: 'ORDEN_SALIDA_INTERNA',
    description:
      'Código TipoOrdenSalida: ORDEN_SALIDA_VENTA, ORDEN_SALIDA_INTERNA, RECARGA_PLANTA_EXTERNA, RETORNO_PLANTA_EXTERNA, TRASLADO',
  })
  @IsString()
  @IsNotEmpty()
  codigoTipoOrden!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idSucursal!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiPropertyOptional({
    description: 'Solo para ORDEN_SALIDA_VENTA armada a mano; usar POST /crear-desde-venta en el caso normal',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idVenta?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({ description: 'A quién se entrega (si difiere del cliente)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDestinatario?: number;

  @ApiPropertyOptional({ description: 'Proveedor (recarga en planta externa)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional({ description: 'Documento de salida del que este nace (p.ej. retorno de una recarga)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocSalidaOrigen?: number;

  @ApiPropertyOptional({ example: '2026-09-03' })
  @IsOptional()
  @IsDateString()
  fecha?: string;

  @ApiPropertyOptional({ example: '2026-09-03' })
  @IsOptional()
  @IsDateString()
  fechaTraslado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}

export class CreateDocSalidaDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional({ description: 'Obligatorio si no se indica idBalon' })
  @ValidateIf((o: CreateDocSalidaDetalleDto) => !o.idBalon)
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idProducto?: number;

  @ApiPropertyOptional({ description: 'Obligatorio si no se indica idProducto' })
  @ValidateIf((o: CreateDocSalidaDetalleDto) => !o.idProducto)
  @Type(() => Number)
  @IsInt()
  @IsNotEmpty()
  idBalon?: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  cantidad!: number;

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

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(255)
  glosa?: string;
}

export class CrearDesdeVentaDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idVenta!: number;

  @ApiPropertyOptional({ description: 'Por defecto, el cliente de la venta' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDestinatario?: number;

  @ApiPropertyOptional({ example: '2026-09-03' })
  @IsOptional()
  @IsDateString()
  fechaTraslado?: string;
}

export class ConvertirGreDto extends AuditoriaDto {
  @ApiProperty({ description: 'ID opción TipoGuiaRemision (09/31)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoGuiaRemision?: number;

  @ApiProperty({ example: 'T001' })
  @IsString()
  @MaxLength(10)
  serie!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idMotivoTraslado?: number;

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
  idUnidadMedida?: number;

  @ApiPropertyOptional({ example: 12.5 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
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
  @IsString()
  @MaxLength(255)
  direccionLlegada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDistritoLlegada?: number;

  @ApiPropertyOptional({ example: '2026-09-03' })
  @IsOptional()
  @IsDateString()
  fechaTraslado?: string;
}

export class FinalizarRecargaDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idComprobanteCompra?: number;

  @ApiProperty({ example: '2026-09-03' })
  @IsDateString()
  fechaLlegadaAlmacen!: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idAlmacen!: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(50)
  lote?: string;

  @ApiPropertyOptional({ example: '2027-08-01' })
  @IsOptional()
  @IsDateString()
  fechaVencimientoLote?: string;

  @ApiPropertyOptional({ example: '2026-06-01' })
  @IsOptional()
  @IsDateString()
  fechaPruebaHidrostatica?: string;

  @ApiPropertyOptional({
    default: false,
    description: 'Si true, además actualiza la custodia de cada balón (EN_ALMACEN) y registra su entrada de gas',
  })
  @IsOptional()
  @IsBoolean()
  guardarBalonesAlmacen?: boolean;
}

export class RegistrarDireccionEntregaDto extends AuditoriaDto {
  @ApiPropertyOptional({
    description: 'Dirección guardada del cliente (cli_direcciones); si se indica, se copia su snapshot y se ignoran los campos manuales',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDireccionCliente?: number;

  @ApiPropertyOptional({ description: 'Obligatorio si no se indica idDireccionCliente' })
  @ValidateIf((o: RegistrarDireccionEntregaDto) => !o.idDireccionCliente)
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  direccionEntrega?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  referenciaEntrega?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  latitud?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  longitud?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDistritoEntrega?: number;
}

export class GenerarRecojoDocSalidaDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: '2026-09-05' })
  @IsOptional()
  @IsDateString()
  fechaProgramada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUsuarioResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class AnularDocSalidaDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  motivo?: string;
}

export class FiltroDocSalidaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoOrden?: number;

  @ApiPropertyOptional({ description: 'Alternativa a idTipoOrden por código' })
  @IsOptional()
  @IsString()
  codigoTipoOrden?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstadoCiclo?: number;

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
  @Type(() => Boolean)
  @IsBoolean()
  emitidoSunat?: boolean;

  @ApiPropertyOptional({ example: '2026-09-01' })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({ example: '2026-09-30' })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class SiguienteNumeroDocSalidaQueryDto {
  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idSucursal!: number;

  @ApiPropertyOptional({ example: '2026-09-03' })
  @IsOptional()
  @IsDateString()
  fecha?: string;
}
