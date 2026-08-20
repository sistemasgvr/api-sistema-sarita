import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayNotEmpty, IsArray, IsInt } from 'class-validator';

export class ExportarRelacionadosClienteDto {
  @ApiProperty({
    type: [Number],
    example: [1, 2, 3],
    description:
      'IDs de los clientes a exportar. Se resuelven en una sola consulta agregada ' +
      '(direcciones, vehículos, choferes y cuentas bancarias) en vez de 4 llamadas por cliente.',
  })
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(1000)
  @Type(() => Number)
  @IsInt({ each: true })
  ids!: number[];
}
