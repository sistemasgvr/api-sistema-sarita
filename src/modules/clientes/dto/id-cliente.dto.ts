import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, Min } from 'class-validator';

export class ClienteIdDto {
  @ApiProperty({ example: 1, description: 'ID del cliente' })
  @IsInt({ message: 'El ID debe ser un número entero' })
  @Min(1, { message: 'El ID debe ser mayor a 0' })
  @Type(() => Number)
  id!: number;
}