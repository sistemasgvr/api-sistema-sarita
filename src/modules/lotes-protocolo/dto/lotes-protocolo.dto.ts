import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

function toOptionalBoolean(value: unknown) {
  if (value === 'true' || value === true) return true;
  if (value === 'false' || value === false) return false;
  return undefined;
}

export class LoteProtocoloPruebaDto {
  @ApiPropertyOptional({
    description: 'Orden de la fila en la tabla de análisis',
  })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  orden?: number;

  @ApiProperty({ example: 'Valoración' })
  @IsString()
  @MaxLength(120)
  prueba!: string;

  @ApiPropertyOptional({ example: 'No menos de 99,5% por volumen de O2' })
  @IsOptional()
  @IsString()
  @MaxLength(300)
  especificacion?: string;

  @ApiPropertyOptional({ example: '99.90%' })
  @IsOptional()
  @IsString()
  @MaxLength(120)
  resultado?: string;
}

export class LoteProtocoloEnvaseDto {
  @ApiProperty({
    example: 'J25642171',
    description: 'Serie del envase aprobado',
  })
  @IsString()
  @MaxLength(60)
  serieEnvase!: string;
}

export class FiltroLotesProtocoloDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProductoGas?: number;

  @ApiPropertyOptional({
    description: 'true = solo fichas vencidas; false = solo vigentes',
  })
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsOptional()
  @IsBoolean()
  vencidos?: boolean;

  @ApiPropertyOptional({
    description: 'Filtra por fecha de emisión de la ficha',
  })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class CreateLoteProtocoloDto extends AuditoriaDto {
  @ApiProperty({ example: 'GOXM1260827-01' })
  @IsString()
  @MaxLength(60)
  numeroLote!: string;

  @ApiPropertyOptional({ example: '060' })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  numeroProtocolo?: string;

  @ApiPropertyOptional({ description: 'Proveedor / planta que emite la ficha' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProveedor?: number;

  @ApiPropertyOptional({
    description: 'Producto gas al que corresponde el lote',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProductoGas?: number;

  @ApiPropertyOptional({
    example: 'OXÍGENO MEDICINAL 99,5% V/V GAS COMPRIMIDO MEDICINAL',
  })
  @IsOptional()
  @IsString()
  @MaxLength(250)
  descripcionProducto?: string;

  @ApiPropertyOptional({ example: 'GAS COMPRIMIDO' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  formaFarmaceutica?: string;

  @ApiPropertyOptional({ example: 'Cilindro de Acero al Carbono x 10 m³' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  presentacion?: string;

  @ApiPropertyOptional({ example: 'USP VIGENTE' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  normaTecnica?: string;

  @ApiPropertyOptional({ example: 'Licuefacción del Aire' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  metodoFabricacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaAnalisis?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaEmision?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFabricacion?: string;

  @ApiPropertyOptional({
    description:
      'La ficha trae mes/año ("08/2027"); se guarda como el día 1 de ese mes (2027-08-01)',
  })
  @IsOptional()
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional({ example: 600, description: 'Tamaño del lote en m³' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  tamanoLoteM3?: number;

  @ApiPropertyOptional({ example: 60 })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  cantidadEnvases?: number;

  @ApiPropertyOptional({ example: 99.9 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  valoracionO2Pct?: number;

  @ApiPropertyOptional({
    example: 300,
    description:
      'Omitir cuando la ficha dice N.A. (O2 por licuefacción está exento)',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  limiteCo2Ppm?: number;

  @ApiPropertyOptional({
    example: 10,
    description: 'Omitir cuando la ficha dice N.A.',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  limiteCoPpm?: number;

  @ApiPropertyOptional({ example: 'J25642171' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  cilindroMuestreadoSerie?: string;

  @ApiPropertyOptional({ example: 21 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  temperaturaMuestreoC?: number;

  @ApiPropertyOptional({ example: 2900 })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  presionMuestreoPsi?: number;

  @ApiPropertyOptional({ example: 'Q.F. Ana María Ventura Ponce' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  analista?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  conclusion?: string;

  @ApiPropertyOptional({ example: 'ICP-INS-011' })
  @IsOptional()
  @IsString()
  @MaxLength(40)
  codigoDocumento?: string;

  @ApiPropertyOptional({ example: '05' })
  @IsOptional()
  @IsString()
  @MaxLength(10)
  versionDocumento?: string;

  @ApiPropertyOptional({
    description: 'gen_archivo del PDF escaneado de la ficha',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idArchivoPdf?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiPropertyOptional({ type: () => [LoteProtocoloPruebaDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LoteProtocoloPruebaDto)
  pruebas?: LoteProtocoloPruebaDto[];

  @ApiPropertyOptional({
    type: () => [LoteProtocoloEnvaseDto],
    description:
      'Relación de envases aprobados. Cada serie se empareja con bal_balon.numero_serie si el envase existe en el sistema',
  })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LoteProtocoloEnvaseDto)
  envases?: LoteProtocoloEnvaseDto[];
}

export class UpdateLoteProtocoloDto extends CreateLoteProtocoloDto {
  @ApiPropertyOptional({ example: 'GOXM1260827-01' })
  @IsOptional()
  @IsString()
  @MaxLength(60)
  declare numeroLote: string;
}

export class AplicarLoteProtocoloDto extends AuditoriaDto {
  @ApiPropertyOptional({
    type: [Number],
    description:
      'Cilindros a los que se aplica la ficha. Si se omite, se aplica a los que la relación de envases ya emparejó por número de serie',
  })
  @IsOptional()
  @IsArray()
  @Type(() => Number)
  @IsNumber({}, { each: true })
  idBalones?: number[];

  @ApiPropertyOptional({
    description:
      'Orden de salida (doc_salida) a la que se engancha la ficha: escribe doc_salida.id_lote_protocolo',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocSalida?: number;
}

export class FiltroHistorialLoteProtocoloDto {
  @ApiPropertyOptional({ default: 50 })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  limite?: number;

  @ApiPropertyOptional({ default: 0 })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  offset?: number;
}
