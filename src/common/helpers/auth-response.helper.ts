import { BadRequestException, NotFoundException } from '@nestjs/common';
import { FiltroPaginacionDto } from '../dto/filtro-paginacion.dto';
import {
  AuthActivateResult,
  AuthDeleteResult,
  AuthListResult,
  AuthSingleResult,
} from '../interfaces/auth-db.interface';
import { ResponseHelper } from './response.helper';

export function mapListResult<T>(result: AuthListResult<T>, filtros: FiltroPaginacionDto) {
  const pagina = filtros.pagina ?? 1;
  const limite = filtros.limite ?? 10;

  return ResponseHelper.paginated(result.registros ?? [], {
    pagina,
    limite,
    total: Number(result.total ?? 0),
  });
}

export function mapSingleResult<T>(
  result: AuthSingleResult<T>,
  notFoundMessage = 'Registro no encontrado',
) {
  if (result.error) {
    throw new BadRequestException(result.error);
  }

  if (!result.registro) {
    throw new NotFoundException(notFoundMessage);
  }

  return result.registro;
}

export function mapDeleteResult(result: AuthDeleteResult, notFoundMessage: string) {
  if (result.error) {
    throw new BadRequestException(result.error);
  }

  if (!result.eliminado) {
    throw new NotFoundException(notFoundMessage);
  }

  return result;
}

export function mapActivateResult(result: AuthActivateResult, notFoundMessage: string) {
  if (result.error) {
    throw new BadRequestException(result.error);
  }

  if (!result.activado) {
    throw new NotFoundException(notFoundMessage);
  }

  return result;
}
