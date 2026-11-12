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
    expect(args).toHaveLength(31);
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
    await model.actualizarCabecera(7, {
      porcentajeIgv: 0,
    } as ActualizarCompraCabeceraDto);
    const [fn, args] = db.callFunctionJson.mock.calls[0];
    expect(fn).toBe('com_actualizar_compra_cabecera');
    expect(args).toHaveLength(18);
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

describe('Compras: fecha de gasto y fecha de emisión', () => {
  function setup() {
    const db = {
      callFunctionJson: jest.fn().mockResolvedValue({ registro: { id: 1 } }),
    };
    return { db, model: new ComprasModel(db as unknown as DatabaseService) };
  }

  const baseCrear = {
    fecha: '2026-11-12',
    idProveedor: 1,
    idAlmacen: 1,
  } as CreateCompraDto;

  it('crear pasa fechaEmision como p_fecha_emision (último parámetro)', async () => {
    const { db, model } = setup();
    await model.crear({
      ...baseCrear,
      fechaEmision: '2026-11-10',
    } as CreateCompraDto);
    const args = db.callFunctionJson.mock.calls[0][1];
    expect(args).toHaveLength(31);
    expect(args[30]).toBe('2026-11-10');
  });

  it('crear sin fechaEmision envía NULL (pendiente de comprobante)', async () => {
    const { db, model } = setup();
    await model.crear(baseCrear);
    expect(db.callFunctionJson.mock.calls[0][1][30]).toBeNull();
  });

  it('actualizarCabecera pasa fecha de gasto y comprobante en orden', async () => {
    const { db, model } = setup();
    await model.actualizarCabecera(7, {
      fecha: '2026-11-11',
      fechaEmision: '2026-11-10',
      idTipoComprobante: 2,
      serie: 'F001',
      numero: '99',
    } as ActualizarCompraCabeceraDto);
    const args = db.callFunctionJson.mock.calls[0][1];
    expect(args).toHaveLength(18);
    expect(args.slice(12)).toEqual([
      '2026-11-11',
      '2026-11-10',
      2,
      'F001',
      '99',
      false,
    ]);
  });

  it('actualizarCabecera sin esos campos envía NULL (conserva)', async () => {
    const { db, model } = setup();
    await model.actualizarCabecera(7, {} as ActualizarCompraCabeceraDto);
    expect(db.callFunctionJson.mock.calls[0][1].slice(12)).toEqual([
      null,
      null,
      null,
      null,
      null,
      false,
    ]);
  });

  it("actualizarCabecera conserva serie '' para vaciarla", async () => {
    const { db, model } = setup();
    await model.actualizarCabecera(7, {
      serie: '',
    } as ActualizarCompraCabeceraDto);
    expect(db.callFunctionJson.mock.calls[0][1][15]).toBe('');
  });

  it('CreateCompraDto exige idProveedor', async () => {
    const errores = await validate(
      plainToInstance(CreateCompraDto, { fecha: '2026-11-12', idAlmacen: 1 }),
    );
    expect(errores.some((e) => e.property === 'idProveedor')).toBe(true);
  });

  it('CreateCompraDto acepta compra sin serie, número ni fechaEmision', async () => {
    const errores = await validate(
      plainToInstance(CreateCompraDto, { ...baseCrear }),
    );
    expect(
      errores.filter((e) =>
        ['serie', 'numero', 'fechaEmision', 'idProveedor'].includes(e.property),
      ),
    ).toHaveLength(0);
  });
});

describe('Compras: vaciar fecha de emisión y tipo de comprobante', () => {
  function setup() {
    const db = {
      callFunctionJson: jest.fn().mockResolvedValue({ registro: { id: 1 } }),
    };
    return { db, model: new ComprasModel(db as unknown as DatabaseService) };
  }

  it('fechaEmision null envía p_quitar_fecha_emision = true', async () => {
    const { db, model } = setup();
    await model.actualizarCabecera(7, {
      fechaEmision: null,
    } as ActualizarCompraCabeceraDto);
    const args = db.callFunctionJson.mock.calls[0][1] as unknown[];
    expect(args[13]).toBeNull();
    expect(args[17]).toBe(true);
  });

  it('idTipoComprobante null envía 0 (vaciar)', async () => {
    const { db, model } = setup();
    await model.actualizarCabecera(7, {
      idTipoComprobante: null,
    } as ActualizarCompraCabeceraDto);
    expect((db.callFunctionJson.mock.calls[0][1] as unknown[])[14]).toBe(0);
  });

  it('el DTO acepta null para vaciar fechaEmision e idTipoComprobante', async () => {
    const errores = await validate(
      plainToInstance(ActualizarCompraCabeceraDto, {
        fechaEmision: null,
        idTipoComprobante: null,
      }),
    );
    expect(errores).toHaveLength(0);
  });
});
