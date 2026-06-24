import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateEjemploDto {
  @ApiProperty({ example: 'Item de ejemplo', maxLength: 100 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(100)
  nombre: string;

  @ApiPropertyOptional({ example: 'Descripción opcional', maxLength: 255 })
  @IsString()
  @IsOptional()
  @MaxLength(255)
  descripcion?: string;
}
