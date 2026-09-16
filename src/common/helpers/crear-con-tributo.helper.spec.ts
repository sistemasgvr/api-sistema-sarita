import { autorizarTributo, crearConTributo } from './crear-con-tributo.helper';
import { PermisoBanderas } from '../constants/permiso-banderas';
import type { TributoOrigenDto } from '../dto/tributo-origen.dto';

function fixture(tipo: 'percepcion' | 'retencion') {
  const venta = tipo === 'percepcion';
  const registro = venta ? { id: 10 } : { cabecera: { id: 10 } };
  const source = { id: 10, id_tercero: 20, id_sucursal: 2, serie: 'F001', numero: '00000321', fecha: '2026-09-16', total: '100.00', tipo_doc: '01', moneda: 'PEN' };
  const child: { id?: number; serie: string; numero: string; error?: string } = { id: 30, serie: venta ? 'P001' : 'R001', numero: '00000001' };
  const client = {
    query: jest.fn(async (sql: string, _params?: unknown[]) => {
      if (sql.includes(' AS empresa,')) return { rows: [{ empresa: true, regimen: true }] };
      if (sql.includes(venta ? 'ven_crear_comprobante' : 'com_crear_compra')) return { rows: [{ result: { registro } }] };
      if (sql.includes(' AS id_tercero')) return { rows: [source] };
      if (sql.includes(venta ? 'ven_crear_percepcion' : 'com_crear_retencion')) return { rows: [{ result: child }] };
      return { rows: [] };
    }),
    release: jest.fn(),
  };
  const db = { getClient: jest.fn(async () => client), callFunctionJson: jest.fn(async () => ({ registro })) };
  const dto: TributoOrigenDto = { idEmpresa: 18, serie: child.serie, fechaEmision: '2026-09-16', regimen: '01', tasa: venta ? 2 : 3, baseImponible: 100 };
  return { client, db, dto, source, child };
}

describe.each(['percepcion', 'retencion'] as const)('Creación asociada: %s', tipo => {
  it('guarda juntos y toma contraparte, correlativo y total del origen', async () => {
    const { db, client, dto } = fixture(tipo);
    const result = await crearConTributo(db as never, tipo, [1], dto, 5);
    expect(result.registro).toHaveProperty(tipo, expect.objectContaining({ id: 30 }));
    const child = client.query.mock.calls.find(([sql]) => sql.includes(tipo === 'percepcion' ? 'ven_crear_percepcion' : 'com_crear_retencion'))!;
    expect(child[1]![3]).toBe(20);
    const detalle = JSON.parse(child[1]![11] as string)[0];
    expect(detalle.num_doc).toBe('F001-00000321');
    expect(detalle[tipo === 'percepcion' ? 'id_comprobante' : 'id_compra']).toBe(10);
    expect(child[1]![8]).toBe(tipo === 'percepcion' ? 2 : 3);
    expect(child[1]![9]).toBe(tipo === 'percepcion' ? 102 : 97);
    expect(client.query).toHaveBeenCalledWith('COMMIT');
    expect(client.query).not.toHaveBeenCalledWith('ROLLBACK');
    expect(client.release).toHaveBeenCalled();
  });
  it('revierte la operación completa si falla el documento asociado', async () => {
    const { db, client, dto, child } = fixture(tipo);
    child.error = 'Serie no disponible';
    await expect(crearConTributo(db as never, tipo, [], dto)).rejects.toThrow('Serie no disponible');
    expect(client.query).toHaveBeenCalledWith('ROLLBACK');
    expect(client.query).not.toHaveBeenCalledWith('COMMIT');
  });
  it('no admite una base superior al total guardado', async () => {
    const { db, client, dto } = fixture(tipo);
    dto.baseImponible = 101;
    await expect(crearConTributo(db as never, tipo, [], dto)).rejects.toThrow('superar');
    expect(client.query).toHaveBeenCalledWith('ROLLBACK');
  });
  it('rechaza moneda sin conversión definida', async () => {
    const { db, dto, source } = fixture(tipo);
    source.moneda = 'USD';
    await expect(crearConTributo(db as never, tipo, [], dto)).rejects.toThrow('PEN');
  });
  it('conserva el flujo existente cuando la sección no está activada', async () => {
    const { db } = fixture(tipo);
    await crearConTributo(db as never, tipo, [1]);
    expect(db.getClient).not.toHaveBeenCalled();
    expect(db.callFunctionJson).toHaveBeenCalled();
  });
});

describe('Permisos de creación asociada', () => {
  it('crear venta no concede permiso de crear percepción', () => {
    expect(() => autorizarTributo({ permisos: [PermisoBanderas.COMPROBANTES_CREAR] } as never, 'percepcion')).toThrow('percepciones.crear');
  });
  it('permite el permiso explícito o administrador', () => {
    expect(() => autorizarTributo({ permisos: [PermisoBanderas.RETENCIONES_CREAR] } as never, 'retencion')).not.toThrow();
    expect(() => autorizarTributo({ permisos: [PermisoBanderas.AUTH_TODO] } as never, 'percepcion')).not.toThrow();
  });
});
