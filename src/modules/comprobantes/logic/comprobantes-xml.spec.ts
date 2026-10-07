import { NotFoundException } from '@nestjs/common';
import { ComprobantesLogic } from './comprobantes.logic';

describe('Descarga del XML original del comprobante', () => {
  const xml = '<?xml version="1.0" encoding="UTF-8"?><Invoice>Oxígeno</Invoice>';

  function logic(original: string | null) {
    const instance = Object.create(ComprobantesLogic.prototype) as ComprobantesLogic;
    instance.obtenerPorId = jest.fn().mockResolvedValue({
      serie: 'F001', numero: '00000001', xml_firmado: original,
    });
    return instance;
  }

  it.each([xml, Buffer.from(xml).toString('base64')])('conserva el XML firmado en texto o base64', async (original) => {
    const result = await logic(original).obtenerXml(1);
    expect(result.buffer.equals(Buffer.from(xml))).toBe(true);
    expect(result.filename).toBe('F001-00000001.xml');
  });

  it('informa que falta el archivo sin regenerarlo', async () => {
    await expect(logic(null).obtenerXml(1)).rejects.toBeInstanceOf(NotFoundException);
  });
});
