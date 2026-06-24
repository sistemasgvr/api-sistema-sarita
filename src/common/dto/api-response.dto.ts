import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ApiMetaDto {
  @ApiProperty({ example: 1 })
  pagina: number;

  @ApiProperty({ example: 10 })
  limite: number;

  @ApiProperty({ example: 100 })
  total: number;
}

export class ApiResponseDto<T = unknown> {
  @ApiProperty({ example: true })
  success: boolean;

  @ApiProperty({ example: 'Operación exitosa' })
  message: string;

  @ApiProperty()
  data: T;

  @ApiPropertyOptional({ type: ApiMetaDto })
  meta?: ApiMetaDto;
}

export class ApiErrorResponseDto {
  @ApiProperty({ example: false })
  success: boolean;

  @ApiProperty({ example: 'Error en la operación' })
  message: string;

  @ApiProperty({ example: null, nullable: true })
  data: null;

  @ApiProperty({
    example: ['nombre no debe estar vacío'],
    nullable: true,
    type: [String],
  })
  errors: string[] | null;

  @ApiProperty({ example: 400 })
  statusCode: number;
}
