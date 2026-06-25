import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ApiMetaDto {
  @ApiProperty({ example: 1 })
  pagina!: number;

  @ApiProperty({ example: 10 })
  limite!: number;

  @ApiProperty({ example: 100 })
  total!: number;
}

export class ApiResponseDto {
  @ApiProperty({ example: true })
  success!: boolean;

  @ApiProperty({ example: 'Operación exitosa' })
  message!: string;

  @ApiProperty({ type: Object, nullable: true })
  data!: unknown;

  @ApiPropertyOptional({ type: () => ApiMetaDto })
  meta?: ApiMetaDto;
}

export class ApiErrorResponseDto {
  @ApiProperty({ example: false })
  success!: boolean;

  @ApiProperty({ example: 'Error en la operación' })
  message!: string;

  @ApiProperty({
    nullable: true,
    example: null,
    type: Object,
    description: 'Siempre null en respuestas de error',
  })
  data!: unknown;

  @ApiProperty({
    example: ['nombre no debe estar vacío'],
    nullable: true,
    type: [String],
  })
  errors!: string[] | null;

  @ApiProperty({ example: 400 })
  statusCode!: number;
}
