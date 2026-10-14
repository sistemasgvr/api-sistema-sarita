import axios from 'axios';
import { DatabaseService } from '../../database/database.service';
import { SunatValidezClient } from './sunat-validez.client';

jest.mock('axios');
const http = axios as jest.Mocked<typeof axios>;
describe('Consulta integrada SUNAT independiente de GRE', () => {
  const doc = { tipo: '01', serie: 'F001', numero: '00000023', fecha: '2026-10-12', total: 330 };
  const cfg = { ruc: '10175332796', validez_client_id: 'consulta-id', validez_client_secret: 'consulta-clave', client_id: 'gre-id', client_secret: 'gre-clave' };
  beforeEach(() => jest.clearAllMocks());

  it('usa credenciales de validez y fecha/importe exactos sin actualizar la base', async () => {
    const db = { query: jest.fn().mockResolvedValue({ rows: [cfg] }) };
    http.post.mockResolvedValueOnce({ status: 200, data: { access_token: 'token-consulta' } });
    http.post.mockResolvedValueOnce({ status: 200, data: { success: true, data: { estadoCp: '0' } } });
    const result = await new SunatValidezClient(db as unknown as DatabaseService).consultar(1, doc);
    expect(result.estado).toBe('NO INFORMADO');
    expect(result.soloLectura).toBe(true);
    expect(String(http.post.mock.calls[0][1])).toContain('client_id=consulta-id');
    expect(String(http.post.mock.calls[0][1])).not.toContain('gre-clave');
    expect(http.post.mock.calls[1][1]).toEqual({ numRuc: cfg.ruc, codComp: '01', numeroSerie: 'F001', numero: 23, fechaEmision: '12/10/2026', monto: 330 });
    expect(db.query).toHaveBeenCalledTimes(1);
    expect(db.query.mock.calls[0][0]).toMatch(/^SELECT/);
    expect(JSON.stringify(result)).not.toContain('consulta-clave');
    expect(JSON.stringify(result)).not.toContain('token-consulta');
  });

  it('no reutiliza GRE si faltan credenciales de validez', async () => {
    const db = { query: jest.fn().mockResolvedValue({ rows: [{ ...cfg, validez_client_secret: null }] }) };
    await expect(new SunatValidezClient(db as unknown as DatabaseService).consultar(1, doc)).rejects.toThrow('Configura');
    expect(http.post).not.toHaveBeenCalled();
  });

  it('no interpreta fallos de acceso o respuestas incompletas como rechazo o aceptación', async () => {
    const db = { query: jest.fn().mockResolvedValue({ rows: [cfg] }) };
    const client = new SunatValidezClient(db as unknown as DatabaseService);
    http.post.mockResolvedValueOnce({ status: 400, data: { error: 'unauthorized_client' } });
    await expect(client.consultar(1, doc)).rejects.toThrow('no autorizó');
    http.post.mockResolvedValueOnce({ status: 200, data: { access_token: 'token' } });
    http.post.mockResolvedValueOnce({ status: 200, data: { success: true, data: {} } });
    await expect(client.consultar(1, doc)).rejects.toThrow('no pudo confirmar');
  });
});
