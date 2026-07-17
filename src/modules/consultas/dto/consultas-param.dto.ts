import { ApiProperty } from '@nestjs/swagger';
import { IsString, Length, Matches } from 'class-validator';

export class DniParamDto {
  @ApiProperty({ example: '12345678', description: 'Número de DNI (8 dígitos)' })
  @IsString()
  @Length(8, 8, { message: 'El DNI debe tener exactamente 8 dígitos' })
  @Matches(/^[0-9]+$/, { message: 'El DNI solo debe contener números' })
  dni!: string;
}

export class RucParamDto {
  @ApiProperty({ example: '20131312955', description: 'Número de RUC (11 dígitos)' })
  @IsString()
  @Length(11, 11, { message: 'El RUC debe tener exactamente 11 dígitos' })
  @Matches(/^[0-9]+$/, { message: 'El RUC solo debe contener números' })
  ruc!: string;
}