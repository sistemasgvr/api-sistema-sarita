import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  ApiBody,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import { StorageLogic } from '../logic/storage.logic';

@ApiTags('Storage')
@Controller('storage')
export class StorageController {
  constructor(private readonly storageLogic: StorageLogic) {}

  @Get('status')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Estado de configuración de Supabase Storage' })
  status() {
    return this.storageLogic.status();
  }

  @Get('ping')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Probar conexión al bucket de Supabase Storage' })
  ping() {
    return this.storageLogic.ping();
  }

  @Get('archivos')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Listar archivos de una carpeta del bucket' })
  listar(@Query('folder') folder?: string) {
    return this.storageLogic.listar(folder);
  }

  @Post('upload')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({
    summary: 'Subir archivo al bucket y registrar metadatos en gen_archivo',
  })
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      required: ['file', 'path'],
      properties: {
        path: {
          type: 'string',
          example: 'certificados/empresa-1/cert.pem',
        },
        upsert: { type: 'boolean', example: true },
        idEmpresa: { type: 'integer', example: 1 },
        idUsuarioAuditoria: { type: 'integer', example: 1 },
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  @UseInterceptors(FileInterceptor('file'))
  subir(
    @UploadedFile() file: Express.Multer.File,
    @Body('path') path: string,
    @Body('upsert') upsert?: string,
    @Body('idEmpresa') idEmpresa?: string,
    @Body('idUsuarioAuditoria') idUsuarioAuditoria?: string,
  ) {
    return this.storageLogic.subir(
      path,
      file,
      upsert === undefined ? true : upsert === 'true' || upsert === '1',
      idEmpresa ? Number(idEmpresa) : undefined,
      idUsuarioAuditoria ? Number(idUsuarioAuditoria) : undefined,
    );
  }

  @Post('signed-url')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_VER)
  @ApiOperation({ summary: 'Generar URL firmada temporal para un archivo' })
  firmarUrl(
    @Body('path') path?: string,
    @Body('idArchivo') idArchivo?: number,
    @Body('expiresIn') expiresIn?: number,
  ) {
    if (idArchivo != null) {
      return this.storageLogic.firmarUrlPorId(Number(idArchivo), expiresIn);
    }
    return this.storageLogic.firmarUrl(path ?? '', expiresIn);
  }

  @Delete('archivos')
  @Permisos(PermisoBanderas.CONFIGURACION_SUNAT_EDITAR)
  @ApiOperation({
    summary: 'Eliminar archivos del bucket y marcar gen_archivo como inactivo',
  })
  eliminar(
    @Body('paths') paths: string[],
    @Body('idUsuarioAuditoria') idUsuarioAuditoria?: number,
  ) {
    return this.storageLogic.eliminar(paths ?? [], idUsuarioAuditoria);
  }
}
