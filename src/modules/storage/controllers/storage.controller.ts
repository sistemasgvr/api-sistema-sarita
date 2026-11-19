import {
  Body,
  Controller,
  Delete,
  Get,
  Post,
  Query,
  Req,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import { Permisos } from '../../../common/decorators/permisos.decorator';
import type { AuthRequest } from '../../../common/interfaces/auth-request.interface';
import { exigirAccesoRuta } from '../helpers/storage-permisos.helper';
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

  // Los endpoints de archivos se autorizan por carpeta (storage-permisos.helper):
  // compras/, activos/ y lotes-protocolo/ piden el permiso de su módulo; el resto
  // (incluido certificados/) sigue exigiendo Configuración SUNAT.

  @Get('archivos')
  @ApiOperation({ summary: 'Listar archivos de una carpeta del bucket' })
  listar(@Req() req: AuthRequest, @Query('folder') folder?: string) {
    // Sin carpeta se lista la raíz: solo Configuración SUNAT.
    const pedida = folder?.trim().replace(/\/+$/, '') ?? '';
    const carpeta = exigirAccesoRuta(
      req.user?.permisos,
      pedida ? `${pedida}/` : 'raiz',
      'ver',
    ).replace(/\/+$/, '');
    return this.storageLogic.listar(pedida ? carpeta : undefined);
  }

  @Post('upload')
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
    @Req() req: AuthRequest,
    @UploadedFile() file: Express.Multer.File,
    @Body('path') path: string,
    @Body('upsert') upsert?: string,
    @Body('idEmpresa') idEmpresa?: string,
    @Body('idUsuarioAuditoria') idUsuarioAuditoria?: string,
  ) {
    const ruta = exigirAccesoRuta(req.user?.permisos, path, 'editar');
    return this.storageLogic.subir(
      ruta,
      file,
      upsert === undefined ? true : upsert === 'true' || upsert === '1',
      idEmpresa ? Number(idEmpresa) : undefined,
      idUsuarioAuditoria ? Number(idUsuarioAuditoria) : undefined,
    );
  }

  @Post('signed-url')
  @ApiOperation({ summary: 'Generar URL firmada temporal para un archivo' })
  async firmarUrl(
    @Req() req: AuthRequest,
    @Body('path') path?: string,
    @Body('idArchivo') idArchivo?: number,
    @Body('expiresIn') expiresIn?: number,
  ) {
    // Por id también se valida la carpeta real del archivo, no la que diga el cliente.
    const rutaOriginal =
      idArchivo != null
        ? await this.storageLogic.obtenerRutaArchivo(Number(idArchivo))
        : (path ?? '');
    const ruta = exigirAccesoRuta(req.user?.permisos, rutaOriginal, 'ver');
    return this.storageLogic.firmarUrl(ruta, expiresIn);
  }

  @Delete('archivos')
  @ApiOperation({
    summary: 'Eliminar archivos del bucket y marcar gen_archivo como inactivo',
  })
  eliminar(
    @Req() req: AuthRequest,
    @Body('paths') paths: string[],
    @Body('idUsuarioAuditoria') idUsuarioAuditoria?: number,
  ) {
    const rutas = (paths ?? []).map((p) =>
      exigirAccesoRuta(req.user?.permisos, p, 'editar'),
    );
    return this.storageLogic.eliminar(rutas, idUsuarioAuditoria);
  }
}
