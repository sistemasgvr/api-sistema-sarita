import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class EjemploResponseDto {
  @ApiProperty({ example: 1 })
  id: number;

  @ApiProperty({ example: 'Item de ejemplo' })
  nombre: string;

  @ApiPropertyOptional({ example: 'Descripción del item' })
  descripcion?: string;

  @ApiProperty({ example: true })
  activo: boolean;
}
