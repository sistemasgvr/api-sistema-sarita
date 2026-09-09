import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  ArrayNotEmpty,
  Min,
  IsArray,
  IsIn,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Validate,
  ValidateIf,
  ValidateNested,
  ValidationArguments,
  ValidatorConstraint,
  ValidatorConstraintInterface,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

type BooleanLike = string | boolean | null | undefined;

function parseBooleanLike(value: BooleanLike): boolean | undefined {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value === 'boolean') return value;
  const v = String(value).toLowerCase().trim();
  if (v === 'true' || v === '1' || v === 'si' || v === 's') return true;
  if (v === 'false' || v === '0' || v === 'no' || v === 'n') return false;
  return undefined;
}

function horaAMinutos(value?: string | null): number | null {
  if (!value) return null;
  const match = String(value)
    .trim()
    .match(/^(\d{1,2}):(\d{2})/);
  if (!match) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

@ValidatorConstraint({ name: 'horaFinPosteriorInicio', async: false })
class HoraFinPosteriorInicioConstraint implements ValidatorConstraintInterface {
  validate(_: unknown, args: ValidationArguments) {
    const dto = args.object as {
      horaInicioEstimada?: string;
      horaFinEstimada?: string;
    };
    const inicio = horaAMinutos(dto.horaInicioEstimada);
    const fin = horaAMinutos(dto.horaFinEstimada);
    if (inicio == null || fin == null) return true;
    return fin > inicio;
  }

  defaultMessage() {
    return 'La hora de fin debe ser posterior a la hora de inicio';
  }
}

export class FiltroActividadesDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    description: 'Filtrar desde la fecha programada (YYYY-MM-DD)',
  })
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional({
    description: 'Filtrar hasta la fecha programada (YYYY-MM-DD)',
  })
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstado?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipo?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idPrioridad?: number;

  @ApiPropertyOptional({
    description:
      'Filtrar por asignación: true = sin responsable (usuario y chofer nulos), false = con responsable, undefined = todas',
  })
  @IsOptional()
  @Transform(({ value }: { value: unknown }) =>
    parseBooleanLike(value as BooleanLike),
  )
  sinResponsable?: boolean;
}

export class FiltroActividadesProximasDto {
  @ApiPropertyOptional({
    example: 60,
    description: 'Minutos hacia adelante (mín. 5)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  minutos?: number;
}

export class ActividadItemDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  item?: number;

  @ApiPropertyOptional({ example: 12 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProducto?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(300)
  descripcion?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  cantidad?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idBalon?: number;
}

export class CreateActividadDto extends AuditoriaDto {
  @ApiProperty({ example: 'Visita de seguimiento', maxLength: 150 })
  @ValidateIf((o: CreateActividadDto) => !o.idComprobante && !o.idDocSalida)
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  titulo?: string;

  @ApiPropertyOptional({ example: 'Coordinar entrega y recambio de cilindros' })
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiProperty({ example: '2026-07-17' })
  @IsDateString()
  @IsNotEmpty()
  fechaProgramada!: string;

  @ApiPropertyOptional({ example: '09:00:00' })
  @IsOptional()
  @IsString()
  horaInicioEstimada?: string;

  @ApiPropertyOptional({ example: '10:30:00' })
  @IsOptional()
  @IsString()
  @Validate(HoraFinPosteriorInicioConstraint)
  horaFinEstimada?: string;

  @ApiProperty({ example: 221, description: 'Id de opción en TipoActividad' })
  @Type(() => Number)
  @IsInt()
  idTipoActividad!: number;

  @ApiProperty({
    example: 230,
    description: 'Id de opción en PrioridadActividad',
  })
  @Type(() => Number)
  @IsInt()
  idPrioridad!: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Trabajador responsable (tra_trabajadores)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTrabajadorResponsable?: number;

  @ApiPropertyOptional({
    example: 10,
    description: 'Comprobante de venta origen del reparto',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idComprobante?: number;

  @ApiPropertyOptional({
    example: 5,
    description: 'Orden de salida (doc_salida) origen del reparto',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocSalida?: number;

  @ApiPropertyOptional({ type: [ActividadItemDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ActividadItemDto)
  items?: ActividadItemDto[];

  @ApiProperty({ example: 227, description: 'Id de opción en EstadoActividad' })
  @Type(() => Number)
  @IsInt()
  idEstadoActividad!: number;

  @ApiPropertyOptional({
    example: 'Confirmar asistencia con el cliente',
    maxLength: 500,
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}

export class UpdateActividadDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  titulo?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  descripcion?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaProgramada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  horaInicioEstimada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @Validate(HoraFinPosteriorInicioConstraint)
  horaFinEstimada?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoActividad?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idPrioridad?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTrabajadorResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idComprobante?: number;

  @ApiPropertyOptional({
    description: 'Orden de salida (doc_salida) origen del reparto',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDocSalida?: number;

  @ApiPropertyOptional({ type: [ActividadItemDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ActividadItemDto)
  items?: ActividadItemDto[];

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEstadoActividad?: number;

  @ApiPropertyOptional({ maxLength: 500 })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}

export class AsignarResponsableActividadDto extends AuditoriaDto {
  @ApiPropertyOptional({
    example: 12,
    description: 'Trabajador responsable (tra_trabajadores). null lo libera.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTrabajadorResponsable?: number | null;
}

export class VerificarActividadDto extends AuditoriaDto {
  @ApiProperty({ enum: ['SALIDA', 'LLEGADA'], example: 'SALIDA' })
  @IsString()
  @IsIn(['SALIDA', 'LLEGADA'])
  momento!: 'SALIDA' | 'LLEGADA';

  @ApiProperty({
    type: [String],
    example: ['BAL-OXM10-001'],
    description:
      'Códigos leídos con la pistola: de cilindro, número de serie o código de producto',
  })
  @IsArray()
  @ArrayNotEmpty()
  @IsString({ each: true })
  codigos!: string[];

  @ApiPropertyOptional({
    description:
      'Si viene, los ítems escaneados quedan CON_OBSERVACION en vez de OK',
  })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacion?: string;
}

export class FiltroVencidosRecojoDto extends FiltroPaginacionDto {}

export class CrearRecojoOrigenDto extends AuditoriaDto {
  @ApiProperty({ enum: ['PRESTAMO', 'ALQUILER'], example: 'PRESTAMO' })
  @IsString()
  @IsIn(['PRESTAMO', 'ALQUILER'])
  tipoOrigen!: 'PRESTAMO' | 'ALQUILER';

  @ApiProperty({ example: 12, description: 'Id del préstamo o alquiler' })
  @Type(() => Number)
  @IsInt()
  idOrigen!: number;

  @ApiPropertyOptional({
    description: 'Por defecto, la fecha pactada del origen',
  })
  @IsOptional()
  @IsDateString()
  fechaProgramada?: string;

  @ApiProperty({
    example: '09:00',
    description: 'Hora de inicio estimada del recojo (obligatoria)',
  })
  @IsString()
  @IsNotEmpty()
  horaInicioEstimada!: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  idTrabajadorResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}

/** @deprecated Preferir CrearRecojoOrigenDto / POST recojo */
export class CrearRecojoPrestamoDto extends AuditoriaDto {
  @ApiProperty()
  @Type(() => Number)
  @IsNumber()
  idPrestamo!: number;

  @ApiPropertyOptional({
    description: 'Por defecto, la fecha de retorno pactada del préstamo',
  })
  @IsOptional()
  @IsDateString()
  fechaProgramada?: string;

  @ApiPropertyOptional({
    example: '09:00',
    description: 'Hora de inicio estimada del recojo',
  })
  @IsOptional()
  @IsString()
  horaInicioEstimada?: string;

  @ApiPropertyOptional()
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTrabajadorResponsable?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  observaciones?: string;
}

export class IniciarVerificacionDto extends AuditoriaDto {}

export class GenerarRecojosDto extends AuditoriaDto {
  @ApiPropertyOptional({
    default: 3,
    description:
      'Ventana hacia adelante en días. 0 = solo préstamos ya vencidos',
  })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(0)
  diasAntes?: number;

  @ApiPropertyOptional({
    description: 'A quién se asignan. Sin valor, quedan sin asignar',
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  idTrabajadorResponsable?: number;
}

export class FiltroRankingActividadesDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaDesde?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsDateString()
  fechaHasta?: string;

  @ApiPropertyOptional({ default: 20 })
  @Type(() => Number)
  @IsOptional()
  @IsInt()
  @Min(1)
  limite?: number;
}
