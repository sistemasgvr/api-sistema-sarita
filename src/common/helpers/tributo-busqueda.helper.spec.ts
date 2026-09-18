import {
  asociarTasasARegimenes,
  leerTasaCatalogo,
} from './comprobante-sunat.helper';
import {
  normalizarBusqueda,
  sqlCoincideBusqueda,
} from './tributo-busqueda.helper';

/**
 * Lo que el usuario escribe y lo que guarda la BD deben reducirse a la misma
 * forma: es lo que antes hacía que «F001-123» no encontrara «F001-00000123».
 */
describe('Normalización del término de búsqueda', () => {
  it.each([
    ['F001-123', 'f001123'],
    ['f001 123', 'f001123'],
    ['  F001 - 00000123  ', 'f00100000123'],
    ['MUÑOZ', 'munoz'],
    ['Muñoz S.A.C.', 'munozsac'],
    ['García', 'garcia'],
    ['20100000141', '20100000141'],
    ['', ''],
  ])('%s → %s', (escrito, esperado) => {
    expect(normalizarBusqueda(escrito)).toBe(esperado);
  });

  it('trata null y undefined como búsqueda vacía', () => {
    expect(normalizarBusqueda(null)).toBe('');
    expect(normalizarBusqueda(undefined)).toBe('');
  });
});

describe('Condición SQL de coincidencia', () => {
  const sql = sqlCoincideBusqueda('c', 'cl');

  it('compara el correlativo con y sin ceros a la izquierda', () => {
    expect(sql).toContain("COALESCE(c.serie, '') || COALESCE(c.numero, '')");
    expect(sql).toContain("LTRIM(COALESCE(c.numero, ''), '0')");
  });

  it('también busca por nombre y por documento de la contraparte', () => {
    expect(sql).toContain('cl.razon_social');
    expect(sql).toContain('cl.numero_documento');
  });

  it('reduce cada columna a la misma forma canónica que el término', () => {
    // Tantos TRANSLATE/REGEXP_REPLACE como columnas comparadas.
    expect(sql.match(/REGEXP_REPLACE\(TRANSLATE\(LOWER\(/g)).toHaveLength(4);
    expect(sql).toContain("'[^a-z0-9]', '', 'g'");
  });

  it('usa el marcador que se le indique', () => {
    expect(sqlCoincideBusqueda('c', 'pr', '$5')).toContain("'%' || $5 || '%'");
  });
});

describe('Tasas asociadas al régimen', () => {
  const regimenes = [
    { id: 1, nombre: 'Percepción venta interna', descripcion: '01' },
    {
      id: 2,
      nombre: 'Percepción a la adquisición de combustible',
      descripcion: '02',
    },
    { id: 3, nombre: 'Régimen sin tasas', descripcion: '09' },
  ];
  const tasas = [
    { id: 10, nombre: '2%', descripcion: '01' },
    { id: 11, nombre: '3.5%', descripcion: '01' },
    { id: 12, nombre: '1%', descripcion: '02' },
    { id: 13, nombre: 'sin número', descripcion: '02' },
  ];

  it('cruza por código de régimen y propone la menor', () => {
    const [venta, combustible, sinTasas] = asociarTasasARegimenes(
      regimenes,
      tasas,
    );
    expect(venta.tasas).toEqual([
      { id: 10, tasa: 2, etiqueta: '2%' },
      { id: 11, tasa: 3.5, etiqueta: '3.5%' },
    ]);
    expect(venta.tasa).toBe(2);
    expect(combustible.tasas).toEqual([{ id: 12, tasa: 1, etiqueta: '1%' }]);
    expect(sinTasas.tasas).toEqual([]);
    expect(sinTasas.tasa).toBeNull();
  });

  it('ignora opciones sin porcentaje usable', () => {
    expect(leerTasaCatalogo('0.5%')).toBe(0.5);
    expect(leerTasaCatalogo('0,5%')).toBe(0.5);
    expect(leerTasaCatalogo('sin número')).toBeNull();
    expect(leerTasaCatalogo('0%')).toBeNull();
    expect(leerTasaCatalogo('120%')).toBeNull();
    expect(leerTasaCatalogo(null)).toBeNull();
  });
});
