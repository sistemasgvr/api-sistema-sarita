import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class CreateArchivoDto extends AuditoriaDto {
  @ApiProperty({ example: 'certificado.pem' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  nombreOriginal!: string;

  @ApiProperty({ example: 'certificado.pem' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  nombreAlmacenado!: string;

  @ApiProperty({ example: 'certificados/empresa-1/certificado.pem' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  ruta!: string;

  @ApiProperty({ example: 'storage-sarita' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  bucket!: string;

  @ApiPropertyOptional({ example: 'application/x-pem-file' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  mimeType?: string;

  @ApiPropertyOptional({ example: 'pem' })
  @IsOptional()
  @IsString()
  @MaxLength(20)
  extension?: string;

  @ApiPropertyOptional({ example: 2048 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  tamanioBytes?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEmpresa?: number;
}

export class FiltroArchivosDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1, description: 'Filtrar por empresa' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idEmpresa?: number;
}
