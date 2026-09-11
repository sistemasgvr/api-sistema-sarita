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
  Matches,
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
      'Código TipoOrdenSalida: ORDEN_SALIDA_VENTA, ORDEN_SALIDA_INTERNA, RECARGA_PLANTA_EXTERNA, TRASLADO',
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
    description: 'Obligatorio en TRASLADO: almacén al que va la carga. Debe ser distinto al origen',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAlmacenDestino?: number;

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

  @ApiPropertyOptional({
    example: 82.5,
    description: 'Peso bruto total. Se pide al crear y lo reutiliza la guía de remisión',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  pesoBruto?: number;

  @ApiPropertyOptional({ example: 3, description: 'N° de bultos. Lo reutiliza la guía de remisión' })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(0)
  numeroBultos?: number;
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

export class ActualizarDocSalidaDetalleDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 5, description: 'Omitir para no cambiarla' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.0001)
  cantidad?: number;

  @ApiPropertyOptional({ description: 'Cadena vacía para borrarla; omitir para no cambiarla' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  glosa?: string;
}

export class ActualizarDocSalidaDto extends AuditoriaDto {
  @ApiPropertyOptional({ description: 'Cadena vacía para borrarlas; omitir para no cambiarlas' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
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

  @ApiProperty({
    example: '2026-09-03',
    description:
      'Solo se guarda si el retorno es físico (guardarBalonesAlmacen) o si los cilindros ya habían entrado: una fecha sin entrada de inventario daba la recarga por retornada',
  })
  @IsDateString()
  fechaLlegadaAlmacen!: string;

  @ApiProperty({ description: 'Almacén al que llegan los cilindros; no reemplaza el almacén de origen de la orden' })
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

  @ApiPropertyOptional({
    example: '2026-06-01',
    description:
      'Con retorno físico se registra además en el libro de P.H. de cada cilindro (bal_balon_ph_historial)',
  })
  @IsOptional()
  @IsDateString()
  fechaPruebaHidrostatica?: string;

  @ApiPropertyOptional({
    description:
      'Ficha ICP (lote y protocolo) con la que volvieron los cilindros. Queda como ficha vigente de cada balón del documento',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idLoteProtocolo?: number;

  @ApiPropertyOptional({
    default: false,
    description:
      'Retorno físico: ingresa los envases al almacén (custodia DISPONIBLE) y registra la entrada de gas. En false la llamada solo actualiza metadata (factura, guía, lote, ficha ICP) y NO marca la orden como retornada',
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

  @ApiPropertyOptional({
    description:
      'Solo dirección manual: guardarla también en cli_direcciones del cliente/proveedor destinatario (aparece en su ficha y en el mapa). Default true',
    default: true,
  })
  @IsOptional()
  @IsBoolean()
  guardarEnCliente?: boolean;
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

  @ApiPropertyOptional({
    description: 'Proveedor de la orden (órdenes de recarga en planta externa)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProveedor?: number;

  @ApiPropertyOptional({
    description:
      'Uno o varios códigos de EstadoCicloSalida separados por coma (p. ej. GENERADA,EMITIDA_SUNAT)',
    example: 'GENERADA,EMITIDA_SUNAT',
  })
  @IsOptional()
  @IsString()
  @Matches(/^[A-Za-z_]+(,[A-Za-z_]+)*$/, {
    message:
      'codigoEstadoCiclo debe ser una lista de códigos separados por coma',
  })
  codigoEstadoCiclo?: string;

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

  @ApiPropertyOptional({
    description:
      'Si true, solo órdenes sin actividad vigente (excluye BORRADOR/ANULADA)',
  })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  sinActividadVigente?: boolean;
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

export class SeriesGreQueryDto {
  @ApiPropertyOptional({
    description: 'Tipo de guía (gen_lista_opciones TipoGuiaRemision): 09 remitente → series T###, 31 transportista → V###',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoGuiaRemision?: number;
}

export class ActualizarTrasladoDto extends AuditoriaDto {
  @ApiPropertyOptional({ description: 'Motivo de traslado (catálogo SUNAT)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMotivoTraslado?: number;

  @ApiPropertyOptional({ description: 'Modalidad de traslado (público / privado)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idModalidadTraslado?: number;

  @ApiPropertyOptional({ example: 25.5, description: 'Peso bruto total de la carga' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  pesoBruto?: number;

  @ApiPropertyOptional({ example: 3 })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(0)
  numeroBultos?: number;

  @ApiPropertyOptional({ description: 'Unidad del peso bruto (kg por defecto)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUnidadMedida?: number;
}
