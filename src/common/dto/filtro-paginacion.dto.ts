import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class FiltroPaginacionDto {
  @ApiPropertyOptional({ example: '' })
  @IsOptional()
  @IsString()
  buscar?: string;

  @ApiPropertyOptional({ example: 1, default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  pagina?: number;

  @ApiPropertyOptional({ example: 10, default: 10 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limite?: number;

  get offset(): number {
    const pagina = this.pagina ?? 1;
    const limite = this.limite ?? 10;
    return (pagina - 1) * limite;
  }
}
