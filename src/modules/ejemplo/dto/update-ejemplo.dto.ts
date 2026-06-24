import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateEjemploDto {
  @ApiPropertyOptional({ example: 'Item actualizado', maxLength: 100 })
  @IsString()
  @IsOptional()
  @MaxLength(100)
  nombre?: string;

  @ApiPropertyOptional({ example: 'Nueva descripción', maxLength: 255 })
  @IsString()
  @IsOptional()
  @MaxLength(255)
  descripcion?: string;
}
