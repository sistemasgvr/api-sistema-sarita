import { FiltroInventarioMovimientosDto } from '../dto/inventario-movimientos.dto';
import { InventarioMovimientosModel } from './inventario-movimientos.model';

describe('InventarioMovimientosModel.listar', () => {
  it('envía los 13 argumentos posicionales en el orden de inv_listar_movimientos', async () => {
    const db = {
      callFunctionJson: jest
        .fn()
        .mockResolvedValue({ registros: [], total: 0, resumen: {} }),
    };
    const filtros = new FiltroInventarioMovimientosDto();
    filtros.buscar = 'acme';
    filtros.pagina = 1;
    filtros.limite = 5;
    filtros.naturaleza = 'PRODUCTO';
    filtros.idProducto = 1;
    filtros.idBalon = 2;
    filtros.idAlmacen = 3;
    filtros.idTipoMovimiento = 4;
    filtros.idTipoDocumentoOrigen = 5;
    filtros.idDocumentoOrigen = 6;
    filtros.fechaDesde = '2026-01-01';
    filtros.fechaHasta = '2026-12-31';
    filtros.idCliente = 7;

    await new InventarioMovimientosModel(db as never).listar(filtros);

    expect(db.callFunctionJson).toHaveBeenCalledWith('inv_listar_movimientos', [
      'acme',
      5,
      0,
      'PRODUCTO',
      1,
      2,
      3,
      4,
      5,
      6,
      '2026-01-01',
      '2026-12-31',
      7,
    ]);
  });

  it('usa los valores por defecto y deja el cliente en null cuando no se filtra', async () => {
    const db = {
      callFunctionJson: jest
        .fn()
        .mockResolvedValue({ registros: [], total: 0, resumen: {} }),
    };

    await new InventarioMovimientosModel(db as never).listar(
      new FiltroInventarioMovimientosDto(),
    );

    expect(db.callFunctionJson).toHaveBeenCalledWith('inv_listar_movimientos', [
      '',
      10,
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
    ]);
  });

  it('propaga -1 para listar los movimientos sin cliente', async () => {
    const db = {
      callFunctionJson: jest
        .fn()
        .mockResolvedValue({ registros: [], total: 0, resumen: {} }),
    };
    const filtros = new FiltroInventarioMovimientosDto();
    filtros.idCliente = -1;

    await new InventarioMovimientosModel(db as never).listar(filtros);

    expect(db.callFunctionJson).toHaveBeenCalledWith('inv_listar_movimientos', [
      '',
      10,
      0,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      -1,
    ]);
  });
});
