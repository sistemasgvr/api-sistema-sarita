import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroContactoDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    required: false,
    example: 1,
    nullable: true,
    description: 'Estado del contacto: 1 = activos, 0 = inactivos, null = todos',
  })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  soloActivos?: number;

  @ApiPropertyOptional({ example: 1, description: 'ID del cliente/proveedor' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idCliente?: number;
}
