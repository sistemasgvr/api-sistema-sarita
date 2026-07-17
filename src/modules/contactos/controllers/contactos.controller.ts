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
import { ApiNotFoundResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { ApiErrorResponseDto } from '../../../common/dto/api-response.dto';
import { AuditoriaDto } from '../../../common/dto/auditoria.dto';
import { FiltroContactoDto } from '../dto/filtros-contacto.dto';
import { ContactosLogic } from '../logic/contactos.logic';
import {
  CreateContactoDto,
  UpdateContactoDto,
} from '../dto/crear-contacto.dto';

@ApiTags('Contactos')
@Controller('contactos')
export class ContactosController {
  constructor(private readonly contactosLogic: ContactosLogic) {}

  @Get()
  @Permisos(PermisoBanderas.CONTACTOS_LISTAR)
  @ApiOperation({ summary: 'Listar contactos de clientes/proveedores' })
  listar(@Query() filtros: FiltroContactoDto) {
    return this.contactosLogic.listar(filtros);
  }

  @Get(':id')
  @Permisos(PermisoBanderas.CONTACTOS_VER)
  @ApiOperation({ summary: 'Obtener contacto por ID' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  obtenerPorId(@Param('id', ParseIntPipe) id: number) {
    return this.contactosLogic.obtenerPorId(id);
  }

  @Post()
  @Permisos(PermisoBanderas.CONTACTOS_CREAR)
  @ApiOperation({ summary: 'Crear contacto para un cliente/proveedor' })
  crear(@Body() dto: CreateContactoDto) {
    return this.contactosLogic.crear(dto);
  }

  @Patch(':id')
  @Permisos(PermisoBanderas.CONTACTOS_EDITAR)
  @ApiOperation({ summary: 'Actualizar contacto' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  actualizar(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateContactoDto,
  ) {
    return this.contactosLogic.actualizar(id, dto);
  }

  @Delete(':id')
  @Permisos(PermisoBanderas.CONTACTOS_ELIMINAR)
  @ApiOperation({ summary: 'Eliminar contacto (baja lógica)' })
  @ApiNotFoundResponse({ type: () => ApiErrorResponseDto })
  eliminar(@Param('id', ParseIntPipe) id: number, @Body() dto: AuditoriaDto) {
    return this.contactosLogic.eliminar(id, dto.idUsuarioAuditoria);
  }
}
