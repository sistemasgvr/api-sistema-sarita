import { DocSalidaPdfGenerator } from './doc-salida-pdf.generator';
import PDFDocument from 'pdfkit';
import type { DocumentoSalidaCompletoResult } from '../interfaces/documento-salida.interface';

const orden = (cambios = {}): DocumentoSalidaCompletoResult => ({ registro: {
  numero: 'OS-PRUEBA', fecha: '2026-09-22', fecha_traslado: '2026-09-22',
  nombre_estado_ciclo: 'GENERADA', id_tipo_guia_remision: 1, codigo_tipo_guia: '09',
  id_motivo_traslado: 2, nombre_motivo_traslado: 'VENTA', id_modalidad_traslado: 3,
  codigo_modalidad_traslado: '02', nombre_modalidad_traslado: 'PRIVADO',
  peso_bruto: 12, numero_bultos: 1, id_chofer: 4, nombre_chofer: 'Chofer de prueba',
  id_vehiculo: 5, placa_vehiculo: 'ABC-123', detalle: [], ...cambios,
} } as unknown as DocumentoSalidaCompletoResult);

describe('PDF local de salida', () => {
  it('separa un cilindro de sus cinco unidades de gas y muestra el transporte local', async () => {
    const text = jest.spyOn(PDFDocument.prototype, 'text');
    try {
      await new DocSalidaPdfGenerator().generarA4(orden({ detalle: [{
        id_balon: 14, codigo_balon: 'BAL-ACE5-014', id_producto: 1,
        nombre_producto: 'Acetileno', codigo_producto_gas_balon: 'GAS-ACE', cantidad: 5, unidad_capacidad_balon: 'KG', origen_detalle: 'VENTA',
      }] }), null);
      const textos = text.mock.calls.map(call => String(call[0]));
      const cilindros = textos.indexOf('Cilindros (1)');
      const productos = textos.indexOf('Productos / gas despachado');
      expect(textos.slice(cilindros, productos)).toContain('1');
      expect(textos.slice(cilindros, productos)).not.toContain('5');
      expect(textos.slice(productos)).toEqual(expect.arrayContaining(['GAS-ACE', 'Acetileno', '5', 'KG']));
      expect(textos).toContain('Vehículo: ABC-123');
    } finally { text.mockRestore(); }
  });
  it('rechaza el PDF cuando faltan datos de traslado', async () => {
    await expect(new DocSalidaPdfGenerator().generarA4(orden({ peso_bruto: null, id_chofer: null }), null))
      .rejects.toThrow('peso bruto mayor a cero, chofer');
  });
  it('exige transportista en público y chofer en una guía 31', async () => {
    await expect(new DocSalidaPdfGenerator().generarA4(orden({ codigo_modalidad_traslado: '01' }), null))
      .rejects.toThrow('transportista');
    await expect(new DocSalidaPdfGenerator().generarA4(orden({ codigo_tipo_guia: '31', codigo_modalidad_traslado: '01', id_chofer: null }), null))
      .rejects.toThrow('chofer');
  });
  it('genera una orden completa sin emitir a SUNAT', async () => {
    const pdf = await new DocSalidaPdfGenerator().generarA4(orden(), null);
    expect(pdf.subarray(0, 5).toString()).toBe('%PDF-');
  });
});
