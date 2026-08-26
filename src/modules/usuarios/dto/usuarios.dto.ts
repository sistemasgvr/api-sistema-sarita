import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateUsuarioDto extends AuditoriaDto {
  @ApiProperty({ example: 'Juan Pérez', maxLength: 150 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(150)
  nombre!: string;

  @ApiProperty({ example: 'juan@empresa.com' })
  @IsEmail()
  @MaxLength(150)
  correo!: string;

  @ApiProperty({ example: 'MiClave123', minLength: 6 })
  @IsString()
  @MinLength(6)
  @MaxLength(100)
  contrasena!: string;

  @ApiPropertyOptional({
    example: 1,
    description: 'Trabajador de la empresa al que pertenece este usuario de acceso',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTrabajador?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Rol a asignar al crear el usuario',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idRol?: number;
}

export class UpdateUsuarioDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombre?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsEmail()
  @MaxLength(150)
  correo?: string;

  @ApiPropertyOptional({ minLength: 6 })
  @IsOptional()
  @IsString()
  @MinLength(6)
  @MaxLength(100)
  contrasena?: string;

  @ApiPropertyOptional({
    example: 1,
    description: 'Trabajador de la empresa al que pertenece este usuario de acceso',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTrabajador?: number;
}
