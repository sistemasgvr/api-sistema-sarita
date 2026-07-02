import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
} from '@nestjs/common';
import { ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
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
