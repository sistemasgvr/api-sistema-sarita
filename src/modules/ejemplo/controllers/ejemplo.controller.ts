import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  ApiCreatedResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
  getSchemaPath,
} from '@nestjs/swagger';
import {
  ApiErrorResponseDto,
  ApiResponseDto,
} from '../../../common/dto/api-response.dto';
import {
  CreateEjemploDto,
  EjemploResponseDto,
  FiltroEjemploDto,
  UpdateEjemploDto,
} from '../dto';
import { EjemploLogic } from '../logic/ejemplo.logic';

@ApiTags('Ejemplo')
@Controller('ejemplo')
export class EjemploController {
  constructor(private readonly ejemploLogic: EjemploLogic) {}

  @Get()
  @ApiOperation({ summary: 'Listar registros con filtros opcionales' })
  @ApiOkResponse({
    description: 'Lista de registros',
    schema: {
      allOf: [
        { $ref: getSchemaPath(ApiResponseDto) },
        {
          properties: {
            data: {
              type: 'array',
              items: { $ref: getSchemaPath(EjemploResponseDto) },
            },
          },
        },
      ],
    },
  })
  listar(@Query() filtros: FiltroEjemploDto) {
    return this.ejemploLogic.listar(filtros);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Obtener un registro por ID' })
  @ApiOkResponse({
    description: 'Registro encontrado',
    schema: {
      allOf: [
        { $ref: getSchemaPath(ApiResponseDto) },
        {
          properties: {
            data: { $ref: getSchemaPath(EjemploResponseDto) },
          },
        },
      ],
    },
  })
  @ApiNotFoundResponse({ type: ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.ejemploLogic.obtenerPorId(id);
  }

  @Post()
  @ApiOperation({ summary: 'Crear un nuevo registro' })
  @ApiCreatedResponse({
    description: 'Registro creado',
    schema: {
      allOf: [
        { $ref: getSchemaPath(ApiResponseDto) },
        {
          properties: {
            data: { $ref: getSchemaPath(EjemploResponseDto) },
          },
        },
      ],
    },
  })
  crear(@Body() dto: CreateEjemploDto) {
    return this.ejemploLogic.crear(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Actualizar un registro existente' })
  @ApiOkResponse({
    description: 'Registro actualizado',
    schema: {
      allOf: [
        { $ref: getSchemaPath(ApiResponseDto) },
        {
          properties: {
            data: { $ref: getSchemaPath(EjemploResponseDto) },
          },
        },
      ],
    },
  })
  @ApiNotFoundResponse({ type: ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateEjemploDto,
  ) {
    return this.ejemploLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Eliminar un registro' })
  @ApiOkResponse({
    description: 'Registro eliminado',
    type: ApiResponseDto,
  })
  @ApiNotFoundResponse({ type: ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number) {
    return this.ejemploLogic.eliminar(id);
  }
}
