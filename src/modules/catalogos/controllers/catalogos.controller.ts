import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { CreateListaOpcionDto } from '../dto/catalogos.dto';
import { CatalogosLogic } from '../logic/catalogos.logic';

@ApiTags('Catálogos')
@Controller('catalogos')
export class CatalogosController {
  constructor(private readonly catalogosLogic: CatalogosLogic) {}

  @Get('listas/:idLista/opciones')
  @ApiOperation({ summary: 'Listar opciones de una lista maestra por id_lista' })
  listarListaOpciones(@Param('idLista', ParseIntPipe) idLista: number) {
    return this.catalogosLogic.listarListaOpciones(idLista);
  }

  @Post('listas/:idLista/opciones')
  @ApiOperation({ summary: 'Crear opción en una lista maestra (ej. unidad de medida)' })
  crearListaOpcion(
    @Param('idLista', ParseIntPipe) idLista: number,
    @Body() dto: CreateListaOpcionDto,
  ) {
    return this.catalogosLogic.crearListaOpcion(idLista, dto);
  }

  @Get('ubigeo/paises')
  @ApiOperation({ summary: 'Listar países' })
  listarPaises() {
    return this.catalogosLogic.listarPaises();
  }

  @Get('ubigeo/departamentos')
  @ApiOperation({ summary: 'Listar departamentos' })
  @ApiQuery({ name: 'idPais', required: false, type: Number })
  listarDepartamentos(@Query('idPais', new ParseIntPipe({ optional: true })) idPais?: number) {
    return this.catalogosLogic.listarDepartamentos(idPais);
  }

  @Get('ubigeo/provincias')
  @ApiOperation({ summary: 'Listar provincias' })
  @ApiQuery({ name: 'idDepartamento', required: false, type: Number })
  listarProvincias(
    @Query('idDepartamento', new ParseIntPipe({ optional: true })) idDepartamento?: number,
  ) {
    return this.catalogosLogic.listarProvincias(idDepartamento);
  }

  @Get('ubigeo/distritos')
  @ApiOperation({ summary: 'Listar distritos' })
  @ApiQuery({ name: 'idProvincia', required: false, type: Number })
  listarDistritos(
    @Query('idProvincia', new ParseIntPipe({ optional: true })) idProvincia?: number,
  ) {
    return this.catalogosLogic.listarDistritos(idProvincia);
  }
}
