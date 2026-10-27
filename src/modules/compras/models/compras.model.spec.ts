import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { DatabaseService } from '../../../database/database.service';
import {
  ActualizarCompraCabeceraDto,
  CreateCompraDto,
} from '../dto/compras.dto';
import { ComprasModel } from './compras.model';

describe('Compras: porcentaje de IGV editable', () => {
  function setup() {
    const db = {
      callFunctionJson: jest.fn().mockResolvedValue({ registro: { id: 1 } }),
    };
    return { db, model: new ComprasModel(db as unknown as DatabaseService) };
  }

  const baseCrear = {
    fecha: '2026-10-27',
    idProveedor: 1,
    idAlmacen: 1,
  } as CreateCompraDto;

  it('pasa porcentajeIgv como último parámetro de com_crear_compra (p_porcentaje_igv)', async () => {
    const { db, model } = setup();
    await model.crear({ ...baseCrear, porcentajeIgv: 10.5 } as CreateCompraDto);
    const [fn, args] = db.callFunctionJson.mock.calls[0];
    expect(fn).toBe('com_crear_compra');
    expect(args).toHaveLength(30);
    expect(args[29]).toBe(10.5);
  });

  it('sin porcentajeIgv envía NULL (la función usa 18)', async () => {
    const { db, model } = setup();
    await model.crear(baseCrear);
    const [, args] = db.callFunctionJson.mock.calls[0];
    expect(args[29]).toBeNull();
  });

  it('acepta 0 % (no se confunde con "sin valor")', async () => {
    const { db, model } = setup();
    await model.crear({ ...baseCrear, porcentajeIgv: 0 } as CreateCompraDto);
    expect(db.callFunctionJson.mock.calls[0][1][29]).toBe(0);
  });

  it('pasa porcentajeIgv como p_porcentaje_igv de com_actualizar_compra_cabecera', async () => {
    const { db, model } = setup();
    await model.actualizarCabecera(7, { porcentajeIgv: 0 } as ActualizarCompraCabeceraDto);
    const [fn, args] = db.callFunctionJson.mock.calls[0];
    expect(fn).toBe('com_actualizar_compra_cabecera');
    expect(args).toHaveLength(12);
    expect(args[0]).toBe(7);
    expect(args[11]).toBe(0);
  });

  it('en la cabecera, sin porcentajeIgv envía NULL (conserva el actual)', async () => {
    const { db, model } = setup();
    await model.actualizarCabecera(7, {} as ActualizarCompraCabeceraDto);
    expect(db.callFunctionJson.mock.calls[0][1][11]).toBeNull();
  });

  it.each([
    [CreateCompraDto, { ...baseCrear }],
    [ActualizarCompraCabeceraDto, {}],
  ])('valida porcentajeIgv entre 0 y 100 (%p)', async (Dto, base) => {
    const errores = async (porcentajeIgv: unknown) =>
      (
        await validate(
          plainToInstance(Dto as new () => object, { ...base, porcentajeIgv }),
        )
      ).filter((e) => e.property === 'porcentajeIgv');

    expect(await errores(18)).toHaveLength(0);
    expect(await errores(0)).toHaveLength(0);
    expect(await errores(100)).toHaveLength(0);
    expect(await errores(10.5)).toHaveLength(0);
    expect(await errores(undefined)).toHaveLength(0);
    expect(await errores(-1)).toHaveLength(1);
    expect(await errores(100.01)).toHaveLength(1);
    expect(await errores(18.123)).toHaveLength(1);
  });
});
