import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt } from 'class-validator';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';

export class AsignarRolPermisoDto extends AuditoriaDto {
  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idRol!: number;

  @ApiProperty({ example: 1 })
  @Type(() => Number)
  @IsInt()
  idPermiso!: number;
}
