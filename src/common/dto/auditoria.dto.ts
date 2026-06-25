import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional } from 'class-validator';

export class AuditoriaDto {
  @ApiPropertyOptional({ example: 1, description: 'ID del usuario que realiza la acción' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  idUsuarioAuditoria?: number;
}
