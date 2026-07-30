import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { DatabaseService } from '../../../database/database.service';
import {
  AuthListResult,
  AuthSessionValidateResult,
} from '../../../common/interfaces/auth-db.interface';
import type { JwtPayload } from '../../../common/strategies/jwt.strategy';

export const NOTIFICACION_NUEVA_EVENT = 'notificacion.nueva';
/** Catch-up: pendientes no leídas al conectar (usuario estuvo offline). */
export const NOTIFICACIONES_SINCRONIZAR_EVENT = 'notificaciones.sincronizar';
export const NOTIFICACIONES_NAMESPACE = '/notificaciones';

@WebSocketGateway({
  namespace: NOTIFICACIONES_NAMESPACE,
  cors: { origin: true, credentials: true },
})
export class NotificacionesGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  private readonly logger = new Logger(NotificacionesGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly db: DatabaseService,
  ) {}

  async handleConnection(client: Socket) {
    try {
      const token = this.extractToken(client);
      if (!token) {
        client.disconnect(true);
        return;
      }

      const payload = await this.jwtService.verifyAsync<JwtPayload>(token, {
        secret: this.configService.getOrThrow<string>('jwt.secret'),
      });

      const sesion = await this.db.callFunctionJson<AuthSessionValidateResult>(
        'auth_validar_sesion',
        [token],
      );

      if (!sesion.valida || !sesion.registro) {
        client.disconnect(true);
        return;
      }

      const userId = payload.sub;
      client.data.userId = userId;
      await client.join(this.userRoom(userId));
      this.logger.debug(`WS conectado user:${userId} sid:${client.id}`);

      // Si estuvo offline, las notificaciones ya están en BD: enviar pendientes ahora.
      await this.emitirPendientesAlConectar(client, userId);
    } catch (error) {
      this.logger.warn(
        `WS rechazo conexión: ${error instanceof Error ? error.message : error}`,
      );
      client.disconnect(true);
    }
  }

  handleDisconnect(client: Socket) {
    const userId = client.data?.userId as number | undefined;
    if (userId) {
      this.logger.debug(`WS desconectado user:${userId} sid:${client.id}`);
    }
  }

  emitToUser(userId: number, payload: unknown) {
    this.server.to(this.userRoom(userId)).emit(NOTIFICACION_NUEVA_EVENT, payload);
  }

  private async emitirPendientesAlConectar(client: Socket, userId: number) {
    try {
      const listado = await this.db.callFunctionJson<AuthListResult>(
        'gen_listar_notificaciones',
        [userId, 1, '', 20, 0],
      );
      const contador = await this.db.callFunctionJson<{ total: number }>(
        'gen_contar_notificaciones_no_leidas',
        [userId],
      );

      const items = Array.isArray(listado.registros) ? listado.registros : [];
      const total = Number(contador.total ?? listado.total ?? 0);

      client.emit(NOTIFICACIONES_SINCRONIZAR_EVENT, {
        totalNoLeidas: total,
        items,
      });
    } catch (error) {
      this.logger.warn(
        `No se pudieron sincronizar pendientes user:${userId}: ${
          error instanceof Error ? error.message : error
        }`,
      );
    }
  }

  private userRoom(userId: number) {
    return `user:${userId}`;
  }

  private extractToken(client: Socket): string | null {
    const fromAuth = client.handshake.auth?.token;
    if (typeof fromAuth === 'string' && fromAuth.trim()) {
      return fromAuth.startsWith('Bearer ') ? fromAuth.slice(7) : fromAuth.trim();
    }

    const fromQuery = client.handshake.query?.token;
    if (typeof fromQuery === 'string' && fromQuery.trim()) {
      return fromQuery.trim();
    }

    const header = client.handshake.headers.authorization;
    if (typeof header === 'string' && header.startsWith('Bearer ')) {
      return header.slice(7);
    }

    return null;
  }
}
