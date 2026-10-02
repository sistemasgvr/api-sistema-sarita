import { sugerirNombreUsuario } from './nombre-usuario';

describe('Sugerencia de nombre de usuario', () => {
  it.each([
    ['Billy', 'Reaño', 'breano'],
    [' José Luis ', 'Pérez', 'jperez'],
    ['Ana', undefined, 'ana'],
  ])('sugiere un alias para %s %s', (nombre, apellido, alias) => {
    expect(sugerirNombreUsuario(nombre!, apellido)).toBe(alias);
  });
});
