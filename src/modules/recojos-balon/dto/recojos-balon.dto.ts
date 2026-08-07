import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Validate,
  ValidateNested,
} from 'class-validator';
import {
  ValidationArguments,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

const RESULTADOS_RECOJO = ['RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO'] as const;

@ValidatorConstraint({ name: 'exactlyOneRecojoDetalle', async: false })
class ExactlyOneRecojoDetalleConstraint implements ValidatorConstraintInterface {
  validate(_: unknown, args: ValidationArguments) {
    const value = args.object as {
      idPrestamoDetalle?: number;
      idAlquilerDetalle?: number;
    };
    return Boolean(value.idPrestamoDetalle) !== Boolean(value.idAlquilerDetalle);
  }

  defaultMessage() {
    return 'Debe indicar exactamente un detalle de préstamo o alquiler';
  }
}

/** Resultado de recojo: un origen, o ninguno (alquiler solo regulador). */
@ValidatorConstraint({ name: 'atMostOneRecojoDetalle', async: false })
class AtMostOneRecojoDetalleConstraint implements ValidatorConstraintInterface {
  validate(_: unknown, args: ValidationArguments) {
    const value = args.object as {
      idPrestamoDetalle?: number;
      idAlquilerDetalle?: number;
    };
    return !(Boolean(value.idPrestamoDetalle) && Boolean(value.idAlquilerDetalle));
  }

  defaultMessage() {
    return 'No puede indicar detalle de préstamo y alquiler a la vez';
  }
}

export class FiltroRecojosBalonDto extends FiltroPaginacionDto {
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

  @ApiPropertyOptional({
    description:
      'PROGRAMADO | EN_RUTA | EXITOSO | FALLIDO | REPROGRAMADO | CANCELADO',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  estadoNombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class FiltroPendientesRecojoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idCliente?: number;

  @ApiPropertyOptional({ enum: ['PRESTAMO', 'ALQUILER'] })
  @IsOptional()
  @IsIn(['PRESTAMO', 'ALQUILER'])
  tipoOrigen?: 'PRESTAMO' | 'ALQUILER';

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;
}

export class RecojoDetalleCreateDto {
  @ApiPropertyOptional({ description: 'ID de bal_prestamo_detalle pendiente de devolución' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Validate(ExactlyOneRecojoDetalleConstraint)
  idPrestamoDetalle?: number;

  @ApiPropertyOptional({ description: 'ID de bal_alquiler_detalle pendiente de devolución' })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlquilerDetalle?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class CreateRecojosBalonDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idCliente!: number;

  @ApiPropertyOptional({
    description: 'Opcional; null si la visita cubre varios préstamos del cliente',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idPrestamo?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlquiler?: number;

  @ApiProperty()
  @IsDateString()
  @IsNotEmpty()
  fechaProgramada!: string;

  @ApiPropertyOptional({ example: '09:30:00', description: 'HH:mm o HH:mm:ss' })
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/, {
    message: 'horaEstimada debe tener formato HH:mm o HH:mm:ss',
  })
  horaEstimada?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUsuarioResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiProperty({ type: [RecojoDetalleCreateDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RecojoDetalleCreateDto)
  detalles!: RecojoDetalleCreateDto[];
}

export class UpdateRecojosBalonDto extends AuditoriaDto {
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
  @IsOptional()
  @IsDateString()
  fechaProgramada?: string;

  @ApiPropertyOptional({ example: '09:30:00' })
  @IsOptional()
  @IsString()
  @Matches(/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/, {
    message: 'horaEstimada debe tener formato HH:mm o HH:mm:ss',
  })
  horaEstimada?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idUsuarioResponsable?: number;

  @ApiPropertyOptional({
    description: 'PROGRAMADO | EN_RUTA | CANCELADO',
  })
  @IsOptional()
  @IsString()
  @IsIn(['PROGRAMADO', 'EN_RUTA', 'CANCELADO'])
  estadoNombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RecojoDetalleResultadoDto {
  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Validate(AtMostOneRecojoDetalleConstraint)
  idPrestamoDetalle?: number;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlquilerDetalle?: number;

  @ApiProperty({ enum: RESULTADOS_RECOJO })
  @IsString()
  @IsIn([...RESULTADOS_RECOJO])
  resultado!: (typeof RESULTADOS_RECOJO)[number];

  @ApiPropertyOptional({
    description: 'EstadoContenidoBalon: VACIO | LLENO | DESCONOCIDO',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  nombreEstadoContenido?: string;

  @ApiPropertyOptional({
    description:
      'Cantidad de gas restante en la unidad del producto/tipo (m³, kg, etc.). Si se omite: VACIO→0, LLENO→capacidad.',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  cantidadRestante?: number;

  @ApiPropertyOptional({
    description: 'Requerido/útil para EXTENDIDO (default: visita + 1 día)',
  })
  @IsOptional()
  @IsDateString()
  nuevaFechaRetorno?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idAlmacenDestino?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RecojoReguladorResultadoDto {
  @ApiProperty({ enum: RESULTADOS_RECOJO })
  @IsString()
  @IsIn([...RESULTADOS_RECOJO])
  resultado!: (typeof RESULTADOS_RECOJO)[number];

  @ApiPropertyOptional({
    enum: ['BUENO', 'PARA_REPARAR'],
    description: 'Obligatorio si resultado = RECOGIDO',
  })
  @IsOptional()
  @IsString()
  @IsIn(['BUENO', 'PARA_REPARAR'])
  condicion?: 'BUENO' | 'PARA_REPARAR';

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  nuevaFechaRetorno?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class RegistrarResultadoRecojoDto extends AuditoriaDto {
  @ApiPropertyOptional({ description: 'Fecha real de la visita (default: hoy)' })
  @IsOptional()
  @IsDateString()
  fechaVisita?: string;

  @ApiPropertyOptional({
    description: 'Obligatorio si el recojo resulta FALLIDO (MotivoFalloRecojo)',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idMotivoFallo?: number;

  @ApiPropertyOptional({
    description:
      'Alternativa a idMotivoFallo: CLIENTE_AUSENTE | SIN_ACCESO | CILINDRO_NO_DISPONIBLE | GAS_NO_USADO | OTRO',
  })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  motivoFalloNombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;

  @ApiProperty({ type: [RecojoDetalleResultadoDto] })
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RecojoDetalleResultadoDto)
  detalles!: RecojoDetalleResultadoDto[];

  @ApiPropertyOptional({
    type: RecojoReguladorResultadoDto,
    description: 'Resultado del regulador/accesorio (independiente de cilindros)',
  })
  @IsOptional()
  @ValidateNested()
  @Type(() => RecojoReguladorResultadoDto)
  regulador?: RecojoReguladorResultadoDto;
}
