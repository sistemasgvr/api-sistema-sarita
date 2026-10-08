import { correlativoSunat, fechaCivilSunat, fechaHoraSunat, normalizarDocumentoSunat, receptorSunat, tipoDocumentoSunat } from './sunat-datos.helper';

describe('Datos SUNAT: corregir presentación sin inventar datos', () => {
  it('conserva ceros iniciales y puntuación que necesita revisión', () => {
    expect(normalizarDocumentoSunat(' 00 123456 ')).toBe('00123456');
    expect(normalizarDocumentoSunat(' ab-123 ')).toBe('AB-123');
    expect(() => receptorSunat('DNI', '12-345678')).toThrow('tipo registrado');
  });
  it.each(['CE', 'C.E.', 'Carné de extranjería', '4'])('respeta el tipo %s aunque tenga ocho dígitos', tipo => {
    expect(receptorSunat(tipo, ' 00123456 ')).toEqual({ tipoDoc: '4', numDoc: '00123456' });
  });
  it('respeta pasaporte y bloquea un DNI de longitud incorrecta', () => {
    expect(receptorSunat('Pasaporte', ' ab123456 ')).toEqual({ tipoDoc: '7', numDoc: 'AB123456' });
    expect(() => receptorSunat('DNI', '20123456789')).toThrow('tipo registrado');
    expect(() => tipoDocumentoSunat(null, 'ABC123')).toThrow('tipo de documento');
  });
  it.each(['12abc', '1-2', '1.2', '0', '', '9007199254740992'])('bloquea el correlativo %s sin convertirlo a otro número', numero => {
    expect(() => correlativoSunat(numero)).toThrow('correlativo');
  });
  it('quita ceros de presentación únicamente en el correlativo', () => {
    expect(correlativoSunat(' 000012 ')).toBe('12');
  });
  it.each(['2026-02-30', '2026-13-01', '2026-10-07basura', '07/10/2026', '2026-10-07T99:00:00Z'])('bloquea la fecha %s', fecha => {
    expect(fechaCivilSunat(fecha)).toBeNull();
    expect(() => fechaHoraSunat(fecha)).toThrow('fecha');
  });
  it('acepta años bisiestos y conserva la fecha civil de Lima', () => {
    expect(fechaCivilSunat('2024-02-29')).toBe('2024-02-29');
    expect(fechaHoraSunat(' 2026-10-07T23:30:00-05:00 ')).toBe('2026-10-07T00:00:00-05:00');
  });
});
