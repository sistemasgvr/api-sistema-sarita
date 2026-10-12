import { cdrCorrespondeAlDocumento, estadoDesdeCdr, mensajeErrorCpe } from './cpe-estado.helper';

function zipXml(xml: string): string {
  const name = Buffer.from('cdr.xml');
  const data = Buffer.from(xml);
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0);
  local.writeUInt16LE(name.length, 26);
  const central = Buffer.alloc(46);
  central.writeUInt32LE(0x02014b50, 0);
  central.writeUInt32LE(data.length, 20);
  central.writeUInt16LE(name.length, 28);
  return Buffer.concat([local, name, data, central, name]).toString('base64');
}

describe('CDR y errores de emisión CPE', () => {
  it.each([
    [{ success: true, cdrResponse: { code: '2325', accepted: true } }, 'RECHAZADO'],
    [{ success: true, cdrResponse: { code: '0', notes: ['observación'] } }, 'ACEPTADO'],
    [{ success: true }, 'PENDIENTE'],
    [{ success: false, error: { code: '0127' } }, 'PENDIENTE'],
    [{ success: false, error: { code: '2325' } }, 'RECHAZADO'],
    [{ success: true, ticket: '123' }, 'PENDIENTE'],
    [{ success: true, cdrResponse: { code: '98' } }, 'PENDIENTE'],
  ])('interpreta el CDR antes del éxito HTTP: %j', (payload, expected) => {
    expect(estadoDesdeCdr(payload)).toBe(expected);
  });

  it('rechaza el CDR histórico de F001-23 para la factura de 2026', () => {
    const payload = { cdrZip: zipXml('<cbc:ReferenceID>F001-0000023</cbc:ReferenceID><cbc:ResponseDate>2023-11-13</cbc:ResponseDate>') };
    expect(cdrCorrespondeAlDocumento(payload, 'F001', '00000023', '2026-10-12')).toBe(false);
  });

  it('admite una constancia posterior de la misma referencia y rechaza otra referencia', () => {
    const payload = { cdrZip: zipXml('<cbc:ReferenceID>F001-23</cbc:ReferenceID><cbc:ResponseDate>2026-10-13</cbc:ResponseDate>') };
    expect(cdrCorrespondeAlDocumento(payload, 'F001', '00000023', '2026-10-12')).toBe(true);
    expect(cdrCorrespondeAlDocumento(payload, 'F001', '24', '2026-10-12')).toBe(false);
    expect(cdrCorrespondeAlDocumento({ cdrZip: 'invalid' }, 'F001', '23', '2026-10-12')).toBe(false);
  });

  it('muestra el resultado incierto del timeout sin exponer el token interno', () => {
    const message = mensajeErrorCpe('cURL error 28: Operation timed out after 45000 milliseconds http://cf:8000/api/v1/invoice/send?token=secret-example');
    expect(message).toContain('por confirmar');
    expect(message).not.toContain('secret-example');
    expect(message).not.toContain('cf:8000');
    expect(mensajeErrorCpe('Fallo en /invoice/send?token=secret-example&x=1')).not.toContain('secret-example');
  });
});
