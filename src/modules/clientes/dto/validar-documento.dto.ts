import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, MinLength, Min } from 'class-validator';

export class ValidarDocumentoClienteDto {
  @ApiProperty({ example: '12345678' })
  @IsString()
  @MinLength(1)
  numeroDocumento!: string;

  @ApiPropertyOptional({
    example: 5,
    description: 'ID a excluir (uso al editar)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  idExcluir?: number;
}
