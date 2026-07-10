import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class FacturacionLoginDto {
  @ApiProperty({ example: 'usuario@empresa.com' })
  @IsString()
  @IsNotEmpty()
  username!: string;

  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  password!: string;
}

export class FacturacionComprobanteStatusDto {
  @ApiProperty({ example: '01', description: '01 Factura, 03 Boleta' })
  @IsString()
  @IsNotEmpty()
  tipo!: string;

  @ApiProperty({ example: 'F001' })
  @IsString()
  @IsNotEmpty()
  serie!: string;

  @ApiProperty({ example: '00000001' })
  @IsString()
  @IsNotEmpty()
  numero!: string;

  @ApiPropertyOptional({ description: 'RUC emisor (multi-empresa)' })
  @IsOptional()
  @IsString()
  ruc?: string;
}

export class FacturacionTicketStatusDto {
  @ApiProperty()
  @IsString()
  @IsNotEmpty()
  ticket!: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  ruc?: string;
}

/** Payload libre según swagger APIsPERU (Invoice, Note, Summary, etc.). */
export type FacturacionDocumentoPayload = Record<string, unknown>;
