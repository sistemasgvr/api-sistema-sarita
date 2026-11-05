import { GLOSA_SUNAT_MAX, glosaParaSunat } from './comprobante-glosa.util';

describe('glosaParaSunat', () => {
  it('recorta la glosa a 200 caracteres', () => {
    const glosa = 'G'.repeat(221);

    expect(glosaParaSunat(glosa)).toBe('G'.repeat(GLOSA_SUNAT_MAX));
    expect(glosaParaSunat(glosa)).toHaveLength(200);
  });

  it('convierte saltos de línea y tabuladores en espacios simples', () => {
    expect(glosaParaSunat('Linea 1\nLinea 2\tfin   de   glosa')).toBe(
      'Linea 1 Linea 2 fin de glosa',
    );
  });

  it('recorta sin dejar espacios al final', () => {
    expect(glosaParaSunat(`${'A'.repeat(199)}   `)).toBe('A'.repeat(199));
  });

  it('devuelve null cuando no hay texto', () => {
    expect(glosaParaSunat(null)).toBeNull();
    expect(glosaParaSunat(undefined)).toBeNull();
    expect(glosaParaSunat('   \n\t ')).toBeNull();
  });
});
