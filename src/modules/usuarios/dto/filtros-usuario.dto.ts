import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsIn, IsOptional } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export type UsuarioEstadoFiltro = 'todos' | 'activos' | 'inactivos';

export class FiltroUsuarioDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    enum: ['todos', 'activos', 'inactivos'],
    default: 'activos',
    description: 'Filtrar por estado del usuario',
  })
  @IsOptional()
  @IsIn(['todos', 'activos', 'inactivos'])
  estado?: UsuarioEstadoFiltro = 'activos';
}
