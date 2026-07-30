import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroCuentaDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({ example: 5, description: 'ID del tercero (cliente/proveedor)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idTercero?: number;

  @ApiPropertyOptional({
    example: 'VENCIDO',
    description: 'Estado calculado: PENDIENTE, PARCIAL, VENCIDO o PAGADO',
  })
  @IsOptional()
  @IsString()
  @IsIn(['PENDIENTE', 'PARCIAL', 'VENCIDO', 'PAGADO'])
  estado?: string;

  @ApiPropertyOptional({
    example: 1,
    description: '1 = solo cuentas con saldo pendiente (> 0)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  soloPendientes?: number;
}
