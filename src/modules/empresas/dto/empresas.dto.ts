import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsEmail,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateEmpresaDto extends AuditoriaDto {
  @ApiProperty({ example: '20123456789', maxLength: 11 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(11)
  ruc!: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  razonSocial?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombreComercial?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccion?: string;

  @ApiPropertyOptional({ maxLength: 30 })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  telefono?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsEmail()
  @MaxLength(150)
  email?: string;

  @ApiPropertyOptional({
    description: 'Descuadre permitido (m³) al cerrar ruta pueblos',
    example: 0.5,
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  toleranciaM3RutaPueblo?: number;

  @ApiPropertyOptional({
    description: 'PSI bajo este umbral = cilindro vacío / enviar a planta',
    example: 100,
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  psiMinimoUtil?: number;
}

export class UpdateEmpresaDto extends AuditoriaDto {
  @ApiPropertyOptional({ maxLength: 11 })
  @IsOptional()
  @IsString()
  @MaxLength(11)
  ruc?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  razonSocial?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  nombreComercial?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  direccion?: string;

  @ApiPropertyOptional({ maxLength: 30 })
  @IsOptional()
  @IsString()
  @MaxLength(30)
  telefono?: string;

  @ApiPropertyOptional({ maxLength: 150 })
  @IsOptional()
  @IsEmail()
  @MaxLength(150)
  email?: string;

  @ApiPropertyOptional({
    description: 'Descuadre permitido (m³) al cerrar ruta pueblos',
    example: 0.5,
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  toleranciaM3RutaPueblo?: number;

  @ApiPropertyOptional({
    description: 'PSI bajo este umbral = cilindro vacío / enviar a planta',
    example: 100,
  })
  @Type(() => Number)
  @IsOptional()
  @IsNumber()
  @Min(0)
  psiMinimoUtil?: number;
}
