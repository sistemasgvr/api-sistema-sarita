import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class CreateConfiguracionSunatDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idEmpresa!: number;

  @ApiProperty({ example: 'MODDATOS', maxLength: 50 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(50)
  usuarioSol!: string;

  @ApiProperty({ maxLength: 255 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  claveSol!: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  certificadoDigital?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  claveCertificado?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAmbiente?: number;

  @ApiPropertyOptional({
    description: 'Client ID OAuth GRE (portal SUNAT CPE). Requerido para emitir guías.',
    maxLength: 255,
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientIdGre?: string;

  @ApiPropertyOptional({
    description: 'Client Secret OAuth GRE (portal SUNAT CPE).',
    maxLength: 255,
  })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientSecretGre?: string;
}

export class UpdateConfiguracionSunatDto extends AuditoriaDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEmpresa?: number;

  @ApiPropertyOptional({ maxLength: 50 })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  usuarioSol?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  claveSol?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  certificadoDigital?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  claveCertificado?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idAmbiente?: number;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientIdGre?: string;

  @ApiPropertyOptional({ maxLength: 255 })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientSecretGre?: string;
}
