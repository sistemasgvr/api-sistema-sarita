import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
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

export class CreateChoferDto extends AuditoriaDto {
  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;

  @ApiProperty({ example: 'Carlos' })
  @IsString()
  @MaxLength(150)
  nombres?: string;

  @ApiPropertyOptional({ example: 'Ramírez' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  apellidoPaterno?: string;

  @ApiPropertyOptional({ example: 'Soto' })
  @IsOptional()
  @IsString()
  @MaxLength(150)
  apellidoMaterno?: string;

  @ApiProperty()
  @Type(() => Number)
  @IsInt()
  idTipoDocumento?: number;

  @ApiProperty({ example: '45678912' })
  @IsString()
  @MaxLength(20)
  numeroDocumento?: string;

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

export class UpdateChoferDto extends PartialType(CreateChoferDto) {}

export class FiltroChoferDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  isActivos?: number;

  @ApiPropertyOptional({
    example: 1,
    description: 'Filtrar por ID del cliente',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}
