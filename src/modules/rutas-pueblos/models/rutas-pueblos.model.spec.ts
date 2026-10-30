import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { RutaPuebloDetalleSalidaDto } from '../dto/rutas-pueblos.dto';
import { DatabaseService } from '../../../database/database.service';
import { RutasPueblosModel } from './rutas-pueblos.model';

describe('rutas con libras y m³ manuales', () => {
  it('exige m³ de salida aunque la lectura de libras sea válida', () => {
    const dto = plainToInstance(RutaPuebloDetalleSalidaDto, { idBalon: 101, lbSalida: 1200 });
    expect(validateSync(dto).some(e => e.property === 'm3Salida')).toBe(true);
    dto.m3Salida = 8;
    expect(validateSync(dto)).toHaveLength(0);
  });

  it.each([-1, NaN, Infinity, 2.12345])('rechaza m³ de salida inválidos: %s', m3Salida => {
    const dto = plainToInstance(RutaPuebloDetalleSalidaDto, { idBalon: 101, lbSalida: 1200, m3Salida });
    expect(validateSync(dto).some(e => e.property === 'm3Salida')).toBe(true);
  });

  it('transporta ambos valores manuales hasta la función SQL sin convertirlos', async () => {
    const callFunctionJson = jest.fn().mockResolvedValue({ registro: {} });
    const model = new RutasPueblosModel({ callFunctionJson } as unknown as DatabaseService);
    await model.crear({ idAlmacen: 1, detalles: [{ idBalon: 101, lbSalida: 1300, m3Salida: 10 }] });
    expect(JSON.parse(callFunctionJson.mock.calls[0][1][7])).toEqual([
      expect.objectContaining({ idBalon: 101, lbSalida: 1300, m3Salida: 10 }),
    ]);
    await model.registrarRetorno(42, { detalles: [{ idBalon: 101, lbRetorno: 350, m3Retorno: 2.7 }] });
    expect(JSON.parse(callFunctionJson.mock.calls[1][1][1])).toEqual([
      expect.objectContaining({ idBalon: 101, lbRetorno: 350, m3Retorno: 2.7 }),
    ]);
  });
});
