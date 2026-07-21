import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type, Transform } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
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

export class FiltroBalonesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteUbicacion?: number;

  @ApiPropertyOptional({
    description:
      'Cilindros vinculados al cliente por ubicación (p. ej. prestado) o por propiedad (balón propio)',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteRelacionado?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMarcaCilindro?: number;

  @ApiPropertyOptional({ description: 'true = solo PH vencida, false = solo vigente o sin fecha' })
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsOptional()
  @IsBoolean()
  phVencida?: boolean;

  @ApiPropertyOptional({ description: 'Cilindros con PH por vencer en N días' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  phPorVencerDias?: number;

  @ApiPropertyOptional({
    description:
      'true = solo dados de baja/robados (historial); false = excluir bajas; omitir = todos',
  })
  @Transform(({ value }) => toOptionalBoolean(value))
  @IsOptional()
  @IsBoolean()
  soloBajas?: boolean;
}

export class CreateBalonesDto extends AuditoriaDto {
  @ApiProperty()
  @MaxLength(50)
  @IsString()
  @IsNotEmpty()
  codigoBalon!: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  libroCilindro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  paginaLibro?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRegistro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteUbicacion?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClientePropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idReferencia?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProductoGas?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoBalon?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaUltimaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  vigenciaPruebaHidrostaticaAnios?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaProximaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFabricacion?: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  numeroRecepcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  presionActual?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  numeroSerie?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMarcaCilindro?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idOrganoInspector?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  organoInspectorNoAplica?: boolean;

  @ApiPropertyOptional({ description: 'Año de fabricación (pH del lomo)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  anioFabricacion?: number;

  @ApiPropertyOptional({ description: 'Mes de fabricación 1-12 (pH del lomo)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  mesFabricacion?: number;

  @ApiPropertyOptional({ description: 'Planta proveedora asociada al cilindro' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPlanta?: number;
}

export class UpdateBalonesDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  codigoBalon?: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  libroCilindro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  paginaLibro?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaRegistro?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacen?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteUbicacion?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClientePropietario?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idReferencia?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTipoBalon?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idProductoGas?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idEstadoBalon?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaUltimaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  vigenciaPruebaHidrostaticaAnios?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaProximaPruebaHidrostatica?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaFabricacion?: string;

  @ApiPropertyOptional()
  @MaxLength(30)
  @IsOptional()
  @IsString()
  numeroRecepcion?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  presionActual?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  numeroSerie?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMarcaCilindro?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idOrganoInspector?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  organoInspectorNoAplica?: boolean;

  @ApiPropertyOptional({ description: 'Año de fabricación (pH del lomo)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  anioFabricacion?: number;

  @ApiPropertyOptional({ description: 'Mes de fabricación 1-12 (pH del lomo)' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  mesFabricacion?: number;

  @ApiPropertyOptional({ description: 'Planta proveedora asociada al cilindro' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPlanta?: number;
}

export class FiltroPhHistorialDto extends FiltroPaginacionDto {}

export class RegistrarPhHistorialDto extends AuditoriaDto {
  @ApiProperty()
  @IsDateString()
  @IsNotEmpty()
  fechaPrueba!: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  vigenciaAnios?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idOrganoInspector?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsBoolean()
  organoInspectorNoAplica?: boolean;

  @ApiPropertyOptional()
  @MaxLength(50)
  @IsOptional()
  @IsString()
  numeroCertificado?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMantenimiento?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMovimientoRecarga?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;
}

export class DarBajaBalonDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idMotivoBaja!: number;

  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idUsuarioSolicita!: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  motivoDetalle?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idClienteComprador?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idComprobanteVenta?: number;

  @ApiPropertyOptional()
  @MaxLength(10)
  @IsOptional()
  @IsString()
  serieComprobante?: string;

  @ApiPropertyOptional()
  @MaxLength(15)
  @IsOptional()
  @IsString()
  numeroComprobante?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  montoVenta?: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  observacion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaBaja?: string;
}

export class AprobarBajaBalonDto extends AuditoriaDto {
  @ApiProperty({ description: 'Administrador que aprueba la solicitud' })
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idUsuarioAutoriza!: number;
}

export class RechazarBajaBalonDto extends AuditoriaDto {
  @ApiProperty({ description: 'Administrador que rechaza la solicitud' })
  @Type(() => Number)
  @IsNumber()
  @IsNotEmpty()
  idUsuarioAutoriza!: number;

  @ApiPropertyOptional()
  @MaxLength(500)
  @IsOptional()
  @IsString()
  motivoRechazo?: string;
}
