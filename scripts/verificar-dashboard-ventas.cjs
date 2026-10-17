// Solo lectura: valida la consulta corregida sin instalar funciones ni migraciones.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { Client } = require('pg');

const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'database_sql/funciones/dashboard/ventas/dash_ventas_netas.sql'), 'utf8');
const query = source.match(/SELECT COALESCE\(SUM\(total_importe\), 0\)[\s\S]*?;/)[0]
  .replace(/\s+INTO v_total/, '')
  .replace(/\bp_fecha_desde\b/g, '$1::date')
  .replace(/\bp_fecha_hasta\b/g, '$2::date')
  .replace(/\bp_id_cliente\b/g, '$3::integer');

const fixture = `WITH
  gen_lista(id,nombre) AS (
    VALUES (33,'TipoComprobante'),(44,'EstadoDocumento'),(45,'EstadoSunat'),(99,'OtraLista')
  ),
  gen_lista_opciones(id,id_lista,descripcion,nombre) AS (
    VALUES (71,33,'01','FACTURA'),(69,33,'03','BOLETA'),(183,33,'VSD','NOTA_VENTA'),
           (70,33,'07','NOTA_CREDITO'),(102,99,'01','FACTURA'),
           (500,44,NULL,'PENDIENTE'),(501,44,NULL,'PAGADO'),(502,44,NULL,'ANULADO'),
           (600,45,NULL,'ACEPTADO'),(601,45,NULL,'PENDIENTE'),(602,45,NULL,'RECHAZADO'),
           (603,45,NULL,'BAJA'),(604,45,NULL,'NO_APLICA'),
           (605,99,NULL,'ACEPTADO')
  ),
  ven_comprobante(id_tipo_comprobante,estado,fecha,id_cliente,total_importe,id_estado,id_estado_sunat) AS (
    VALUES (71,1,DATE '2026-10-01',1,100.00,501,600),
           (69,1,DATE '2026-10-17',2,30.00,500,600),
           (183,1,DATE '2026-10-17',1,20.00,500,604),
           (70,1,DATE '2026-10-17',1,999.00,501,600),
           (69,0,DATE '2026-10-17',1,500.00,501,600),
           (102,1,DATE '2026-10-17',1,700.00,501,600),
           (71,1,DATE '2026-09-30',1,333.00,501,600),
           (71,1,DATE '2026-10-17',1,400.00,500,601),
           (71,1,DATE '2026-10-17',1,400.00,500,602),
           (69,1,DATE '2026-10-17',1,400.00,501,603),
           (71,1,DATE '2026-10-17',1,400.00,502,600),
           (183,1,DATE '2026-10-17',1,400.00,502,604),
           (183,1,DATE '2026-10-17',1,400.00,500,601),
           (71,1,DATE '2026-10-17',1,400.00,501,NULL),
           (71,1,DATE '2026-10-17',1,400.00,NULL,600),
           (71,1,DATE '2026-10-17',1,400.00,501,605)
  ) `;

async function main() {
  const env = require('dotenv').parse(fs.readFileSync(path.join(root, '.env')));
  const db = new Client({
    connectionString: env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 10000,
    options: '-c default_transaction_read_only=on -c statement_timeout=15000',
  });
  try {
    await db.connect();
    await db.query('BEGIN READ ONLY');
    const cases = [
      [['2026-10-01','2026-10-17',null],150],
      [['2026-10-01','2026-10-17',1],120],
      [['2026-10-17','2026-10-17',2],30],
      [['2026-11-01','2026-11-30',null],0],
      [[null,null,null],483],
    ];
    for (const [params, expected] of cases) {
      const result = await db.query(fixture + query, params);
      assert.equal(Number(result.rows[0].coalesce), expected);
    }
    const params = ['2026-10-01','2026-10-17',null];
    const corregido = Number((await db.query(query, params)).rows[0].coalesce);
    const actual = (await db.query('SELECT dash_ventas_netas($1,$2,$3) ventas, dash_compras_netas($1,$2) compras', params)).rows[0];
    // Ejecutar también los SELECT reales de las otras cinco funciones, sin DDL.
    const indicadores = [
      ['ventas/dash_historico_ventas_compras.sql','WITH meses AS'],
      ['ventas/dash_top_clientes_venta.sql','SELECT COALESCE(json_agg(t)'],
      ['ventas/dash_demanda_gases.sql','WITH detalle_gas AS'],
      ['ventas/dash_venta_gases_comparativo.sql','WITH ventas_gas AS'],
      ['productos/dash_velocidad_salida.sql','WITH stock_prod AS'],
    ];
    const valores = {
      p_fecha_desde: "DATE '2026-10-01'", p_fecha_hasta: "DATE '2026-10-17'",
      v_desde: "DATE '2026-10-01'", v_hasta: "DATE '2026-10-17'", v_anio: '2026',
      v_inicio_actual: "DATE '2026-10-01'", v_fin_actual: "DATE '2026-10-31'",
      v_inicio_ant: "DATE '2026-09-01'", v_fin_ant: "DATE '2026-09-30'",
      p_id_almacen: 'NULL::integer', p_limite: '20',
    };
    for (const [file, inicio] of indicadores) {
      const sql = fs.readFileSync(path.join(root,'database_sql/funciones/dashboard',file),'utf8');
      assert.ok(sql.includes(inicio), file);
      let consulta = sql.slice(sql.indexOf(inicio)).split(';')[0].replace(/\bINTO v_result\b/g,'');
      for (const [variable, valor] of Object.entries(valores)) consulta = consulta.replace(new RegExp(`\\b${variable}\\b`,'g'),valor);
      await db.query(consulta);
    }
    console.log(JSON.stringify({
      soloLectura: true, pruebasRegresion: cases.length,
      indicadoresValidados: indicadores.length + 1,
      periodo: '2026-10-01 / 2026-10-17',
      ventasFuncionInstalada: Number(actual.ventas),
      ventasConsultaCorregida: corregido,
      compras: Number(actual.compras),
      indicadorRentabilidadCorregido: Math.round((corregido - Number(actual.compras))*100)/100,
    }, null, 2));
    await db.query('ROLLBACK');
  } finally { await db.end(); }
}
main().catch(error => { console.error(error.code || error.message); process.exitCode = 1; });
