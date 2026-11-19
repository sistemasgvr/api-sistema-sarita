import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { PermisoBanderas } from '../../../common/constants/permiso-banderas';
import {
  exigirAccesoRuta,
  normalizarRutaStorage,
  puedeAccederRuta,
} from './storage-permisos.helper';

describe('permisos de storage por carpeta', () => {
  const compras = [PermisoBanderas.COMPRAS_CREAR, PermisoBanderas.COMPRAS_VER];

  it('quien registra compras puede adjuntar en compras/', () => {
    expect(puedeAccederRuta(compras, 'compras/12/factura.pdf', 'editar')).toBe(
      true,
    );
    expect(puedeAccederRuta(compras, 'compras/12/factura.pdf', 'ver')).toBe(
      true,
    );
  });

  it('no puede tocar el certificado SUNAT', () => {
    expect(
      puedeAccederRuta(compras, 'certificados/empresa-1/cert.pem', 'editar'),
    ).toBe(false);
    expect(
      puedeAccederRuta(compras, 'certificados/empresa-1/cert.pem', 'ver'),
    ).toBe(false);
  });

  it('no puede escapar de su carpeta con ..', () => {
    expect(
      puedeAccederRuta(compras, 'compras/../certificados/cert.pem', 'editar'),
    ).toBe(false);
    expect(() => normalizarRutaStorage('../certificados/cert.pem')).toThrow(
      BadRequestException,
    );
    expect(() => normalizarRutaStorage('/certificados/cert.pem')).toThrow(
      BadRequestException,
    );
  });

  it('Configuración SUNAT sigue siendo necesaria para el resto', () => {
    expect(
      puedeAccederRuta(
        [PermisoBanderas.CONFIGURACION_SUNAT_EDITAR],
        'certificados/x.pem',
        'editar',
      ),
    ).toBe(true);
  });

  it('auth.todo accede a todo', () => {
    expect(
      puedeAccederRuta(
        [PermisoBanderas.AUTH_TODO],
        'certificados/x.pem',
        'editar',
      ),
    ).toBe(true);
  });

  it('activos y lotes de protocolo usan su propio permiso', () => {
    expect(
      puedeAccederRuta(
        [PermisoBanderas.ACTIVO_EDITAR],
        'activos/1-foto.jpg',
        'editar',
      ),
    ).toBe(true);
    expect(
      puedeAccederRuta(
        [PermisoBanderas.LOTES_PROTOCOLO_CREAR],
        'lotes-protocolo/1-ficha.pdf',
        'editar',
      ),
    ).toBe(true);
  });

  it('exigirAccesoRuta lanza 403 y devuelve la ruta normalizada', () => {
    expect(() => exigirAccesoRuta(compras, 'activos/x.jpg', 'editar')).toThrow(
      ForbiddenException,
    );
    expect(exigirAccesoRuta(compras, 'compras//12/./f.pdf', 'editar')).toBe(
      'compras/12/f.pdf',
    );
  });
});
