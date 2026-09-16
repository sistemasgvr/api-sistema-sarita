import { pdfGreBuffer, xmlGreBuffer } from './gre-archivos';

describe('Archivos GRE', () => {
  const xml = '<?xml version="1.0"?><DespatchAdvice xmlns="urn:oasis:names:specification:ubl:schema:xsd:DespatchAdvice-2">á</DespatchAdvice>';
  it('conserva exactamente el XML firmado en texto y base64', () => {
    expect(xmlGreBuffer(xml)?.toString('utf8')).toBe(xml);
    expect(xmlGreBuffer(Buffer.from(xml).toString('base64'))?.toString('utf8')).toBe(xml);
  });
  it('no convierte respuesta JSON o HTML en XML descargable', () => {
    expect(() => xmlGreBuffer('{"error":"falló"}')).toThrow();
    expect(() => xmlGreBuffer('<html>Error</html>')).toThrow();
    expect(xmlGreBuffer(null)).toBeNull();
  });
  it('verifica el encabezado PDF antes de almacenar', () => {
    expect(pdfGreBuffer(Buffer.from('%PDF-1.7\ntest').toString('base64')).toString()).toContain('%PDF-');
    expect(() => pdfGreBuffer(Buffer.from('{"error":"falló"}').toString('base64'))).toThrow();
  });
});
