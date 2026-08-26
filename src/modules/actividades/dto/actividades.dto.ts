import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import {
  IsArray,
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
  @ValidateIf((o: CreateActividadDto) => !o.idComprobante)
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
    description: 'Guía de remisión origen del reparto',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idGuiaRemision?: number;

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

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idGuiaRemision?: number;

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
