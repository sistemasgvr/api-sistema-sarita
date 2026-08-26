import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateIf,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class ChoferEmpresaDto {
  @ApiPropertyOptional({ example: '987654321' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  telefono?: string;

  @ApiPropertyOptional({ example: 'Q12345678' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  codigoLicencia?: string;

  @ApiPropertyOptional({ example: '2024-01-15' })
  @ValidateIf((o) => !!o.codigoLicencia)
  @IsDateString()
  fechaEmision?: string;

  @ApiPropertyOptional({ example: '2029-01-15' })
  @ValidateIf((o) => !!o.codigoLicencia)
  @IsDateString()
  fechaVencimiento?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoLicencia?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCategoriaLicencia?: number;
}

export class CreateTrabajadorDto extends AuditoriaDto {
  @ApiProperty({ example: 'Juan' })
  @IsString()
  @MaxLength(150)
  nombres?: string;

  @ApiPropertyOptional({ example: 'Pérez' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellidoPaterno?: string;

  @ApiPropertyOptional({ example: 'Lopez' })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  apellidoMaterno?: string;

  @ApiPropertyOptional({ example: 1, description: 'Catálogo TipoDocumento (DNI/CE/Pasaporte)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTipoDocumento?: number;

  @ApiPropertyOptional({ example: '45678912' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  numeroDocumento?: string;

  @ApiPropertyOptional({ example: 'Av. Principal 123' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccion?: string;

  @ApiPropertyOptional({ example: 'Frente al parque' })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  referencia?: string;

  @ApiPropertyOptional({ example: -12.0463 })
  @IsOptional()
  latitud?: number;

  @ApiPropertyOptional({ example: -77.0427 })
  @IsOptional()
  longitud?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idPais?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDepartamento?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idProvincia?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idDistrito?: number;

  @ApiPropertyOptional({ example: '1990-05-15' })
  @IsOptional()
  @IsDateString()
  fechaNacimiento?: string;

  @ApiPropertyOptional({ example: '2023-01-01' })
  @IsOptional()
  @IsDateString()
  fechaInicio?: string;

  @ApiPropertyOptional({ example: '2024-12-31', description: 'Null = activo' })
  @IsOptional()
  @IsDateString()
  fechaCese?: string;

  @ApiPropertyOptional({ example: 1, description: 'Catálogo AREAS_TRABAJADOR' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idArea?: number;

  @ApiPropertyOptional({ example: 1, description: 'Catálogo CARGOS_TRABAJADOR' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCargo?: number;

  @ApiPropertyOptional({ description: 'Correo para las credenciales del usuario de acceso' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  correo?: string;

  @ApiPropertyOptional({ description: 'Crear usuario de acceso (correo + n° documento como contraseña)' })
  @IsOptional()
  @IsBoolean()
  crearUsuario?: boolean;

  @ApiPropertyOptional({ example: 1, description: 'Rol a asignar si se crea el usuario de acceso' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idRol?: number;

  @ApiPropertyOptional({ description: 'El trabajador es chofer de flota propia de la empresa' })
  @IsOptional()
  @IsBoolean()
  esChofer?: boolean;

  @ApiPropertyOptional({ type: () => ChoferEmpresaDto })
  @IsOptional()
  datosChofer?: ChoferEmpresaDto;
}

export class UpdateTrabajadorDto extends PartialType(CreateTrabajadorDto) {}

export class FiltroTrabajadorDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1, description: '1 activos, 0 cesados, omitir = todos' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  estado?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por área (catálogo)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idArea?: number;

  @ApiPropertyOptional({ example: 1, description: 'Filtrar por cargo (catálogo)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCargo?: number;

  @ApiPropertyOptional({ description: 'Solo trabajadores sin usuario de acceso vinculado' })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  soloSinUsuario?: boolean;
}
