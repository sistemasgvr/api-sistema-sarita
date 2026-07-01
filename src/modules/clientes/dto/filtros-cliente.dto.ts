import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsBoolean, IsInt, IsOptional, IsString } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroClienteDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: true, description: 'Filtra solo clientes activos' })
  @IsOptional()
  @IsBoolean()
  @Type(() => Boolean)
  soloActivos?: boolean = true;

  @ApiPropertyOptional({ example: 1, description: 'ID del tipo de cliente' })
  @IsOptional()
  @IsInt()
  @Type(() => Number)
  idTipoCliente?: number;

  @ApiPropertyOptional({ description: 'Búsqueda por razón social, nombres, doc o código' })
  @IsOptional()
  @IsString()
  busqueda?: string;
}