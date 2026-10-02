import { ConfigService } from '@nestjs/config';
import { Pool } from 'pg';
import { DatabaseService } from './database.service';

jest.mock('pg', () => ({ Pool: jest.fn() }));

describe('Transacciones de operaciones compuestas', () => {
  function setup() {
    const client = { query: jest.fn<Promise<{ rows: unknown[] }>, [string, unknown[]?]>(async () => ({ rows: [] })), release: jest.fn() };
    const pool = { on: jest.fn(), connect: jest.fn(async () => client), query: jest.fn<Promise<{ rows: unknown[] }>, [string, unknown[]?]>(async () => ({ rows: [] })) };
    (Pool as unknown as jest.Mock).mockImplementation(() => pool);
    const db = new DatabaseService({ get: jest.fn() } as unknown as ConfigService);
    return { db, client, pool };
  }

  it('usa la misma conexión para los modelos y vuelve al pool al terminar', async () => {
    const { db, client, pool } = setup();
    await db.withTransaction(async () => { await db.query('SELECT 1'); await db.query('SELECT 2'); });
    expect(client.query.mock.calls.map(call => call[0])).toEqual(['BEGIN', 'SELECT 1', 'SELECT 2', 'COMMIT']);
    expect(client.release).toHaveBeenCalledTimes(1);
    await db.query('SELECT 3');
    expect(pool.query).toHaveBeenCalledWith('SELECT 3', undefined);
  });

  it('revierte trabajador y usuario si falla la asignación del rol', async () => {
    const { db, client } = setup();
    await expect(db.withTransaction(async () => {
      await db.query('SELECT 1');
      throw new Error('Rol rechazado');
    })).rejects.toThrow('Rol rechazado');
    expect(client.query).toHaveBeenLastCalledWith('ROLLBACK');
    expect(client.release).toHaveBeenCalledTimes(1);
  });
});
