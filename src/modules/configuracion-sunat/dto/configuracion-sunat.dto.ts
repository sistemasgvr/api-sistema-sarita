import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroConfiguracionSunatDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1, description: 'Filtrar por empresa' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEmpresa?: number;
}

/** Campos genéricos de PSE/OSE (facturación electrónica). */
const pseFieldsDocs = {
  proveedorPse: 'Código del proveedor PSE/OSE (ej. APISPERU). Orientativo.',
  pseHabilitado: 'Si la emisión electrónica está habilitada.',
  apiBaseUrl: 'URL base del API de facturación electrónica.',
  apiToken: 'Token Bearer / API key. Vacío en actualización = no cambiar.',
  apiUsuario: 'Usuario del PSE (si usa login en lugar de token).',
  apiClave: 'Clave del PSE. Vacío en actualización = no cambiar.',
  rucEmisor: 'RUC emisor. Si se omite, se usa el RUC de la empresa.',
  clientId: 'OAuth client_id (ej. GRE portal SUNAT CPE).',
  clientSecret: 'OAuth client_secret. Vacío en actualización = no cambiar.',
  timeoutMs: 'Timeout HTTP en milisegundos.',
};

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

  @ApiPropertyOptional({ description: pseFieldsDocs.proveedorPse, example: 'APISPERU' })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  proveedorPse?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.pseHabilitado, default: true })
  @IsOptional()
  @IsBoolean()
  pseHabilitado?: boolean;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiBaseUrl })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  apiBaseUrl?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiToken })
  @IsOptional()
  @IsString()
  apiToken?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiUsuario })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  apiUsuario?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiClave })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  apiClave?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.rucEmisor, example: '20100000000' })
  @IsOptional()
  @IsString()
  @MaxLength(11)
  rucEmisor?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.clientId })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientId?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.clientSecret })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientSecret?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.timeoutMs, example: 60000 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1000)
  @Max(300000)
  timeoutMs?: number;
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

  @ApiPropertyOptional({ description: pseFieldsDocs.proveedorPse })
  @IsOptional()
  @IsString()
  @MaxLength(50)
  proveedorPse?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.pseHabilitado })
  @IsOptional()
  @IsBoolean()
  pseHabilitado?: boolean;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiBaseUrl })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  apiBaseUrl?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiToken })
  @IsOptional()
  @IsString()
  apiToken?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiUsuario })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  apiUsuario?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.apiClave })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  apiClave?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.rucEmisor })
  @IsOptional()
  @IsString()
  @MaxLength(11)
  rucEmisor?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.clientId })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientId?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.clientSecret })
  @IsOptional()
  @IsString()
  @MaxLength(255)
  clientSecret?: string;

  @ApiPropertyOptional({ description: pseFieldsDocs.timeoutMs })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1000)
  @Max(300000)
  timeoutMs?: number;
}
