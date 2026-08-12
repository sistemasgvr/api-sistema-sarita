import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, Matches } from 'class-validator';
import { FiltroPaginacionDto } from '../../../common/dto/filtro-paginacion.dto';

export class FiltroSaldosPorTerceroDto extends FiltroPaginacionDto {
  @ApiPropertyOptional({
    example: '2026-08-12',
    description: 'Corte “a la fecha” (YYYY-MM-DD). Default: hoy.',
  })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'fechaCorte debe tener formato YYYY-MM-DD' })
  fechaCorte?: string;

  @ApiPropertyOptional({
    example: 1,
    description: '1 = solo terceros con saldo > 0 (default)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsIn([0, 1])
  soloPendientes?: number;
}
