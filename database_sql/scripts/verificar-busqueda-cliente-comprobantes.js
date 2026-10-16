// Prueba SQL con datos ficticios en tablas y función temporales.
// No modifica funciones públicas ni registros de negocio; termina con ROLLBACK.
const { Client } = require('pg')
const fs = require('node:fs')
const path = require('node:path')
const assert = require('node:assert/strict')

async function main() {
  const root = path.resolve(__dirname, '../..')
  const envLine = process.env.DATABASE_URL ? null : fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/).find(line => line.startsWith('DATABASE_URL='))
  const connectionString = process.env.DATABASE_URL || envLine?.slice('DATABASE_URL='.length).trim().replace(/^['"]|['"]$/g, '')
  if (!connectionString) throw new Error('DATABASE_URL no configurada')
  const client = new Client({ connectionString, ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 10000 })
  await client.connect()
  try {
    await client.query('BEGIN')
    for (const table of ['ven_comprobante', 'cli_clientes', 'gen_lista_opciones', 'ven_comprobante_detalle', 'age_actividad', 'doc_salida']) {
      await client.query(`CREATE TEMP TABLE ${table} AS SELECT * FROM public.${table} WITH NO DATA`)
    }
    await client.query(`
      INSERT INTO gen_lista_opciones (id, nombre, descripcion) VALUES (1, 'FACTURA', '01'), (2, 'BOLETA', '03');
      INSERT INTO cli_clientes (id, razon_social, nombres, apellido_paterno, apellido_materno, numero_documento) VALUES
        (901, 'OXÍGENO DEL SUR S.A.C.', NULL, NULL, NULL, '20123456789'),
        (902, NULL, 'María Elena', 'García', 'López', '00123456'),
        (903, '', 'José', NULL, NULL, '00234567');
      INSERT INTO ven_comprobante (id, id_tipo_comprobante, serie, numero, fecha, id_cliente, estado, total_importe, glosa) VALUES
        (101, 1, 'F001', '00000101', '2026-10-16', 901, 1, 118, 'Oxígeno medicinal'),
        (102, 2, 'B001', '00000102', '2026-10-16', 902, 1, 59, 'Entrega'),
        (103, 1, 'F001', '00000103', '2026-10-15', 902, 1, 80, 'Entrega'),
        (104, 2, 'B001', '00000104', '2026-10-16', 903, 1, 20, 'Entrega'),
        (105, 2, 'B001', '00000105', '2026-10-16', 902, 0, 50, 'Anulado');
    `)
    const namePredicate = "OR gen_texto_coincide(TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno)), v_busqueda)"
    let definition = fs.readFileSync(path.join(root, 'database_sql/funciones/comprobantes/ven_listar_comprobantes.sql'), 'utf8')
      .replace(/^DROP FUNCTION[^\r\n]+\r?\n/gm, '')
      .replace('CREATE OR REPLACE FUNCTION ven_listar_comprobantes(', 'CREATE OR REPLACE FUNCTION pg_temp.ven_listar_comprobantes(')
    assert.equal(definition.split(namePredicate).length - 1, 2, 'Conteo y listado deben buscar el nombre completo')
    // Reproduce primero el fallo original en la función temporal.
    await client.query(definition.replaceAll(namePredicate, '').replace(/\n[ \t]+\n/g, '\n'))
    const listar = async (buscar, limite = 20, offset = 0, tipo = null) => {
      const { rows } = await client.query('SELECT pg_temp.ven_listar_comprobantes($1::varchar, $2::int, $3::int, $4::int) AS resultado', [buscar, limite, offset, tipo])
      return rows[0].resultado
    }
    assert.equal((await listar('maria')).total, 0, 'El caso reproduce la omisión de nombres en el buscador anterior')
    let migration = fs.readFileSync(path.join(root, 'database_sql/migraciones/20261016_comprobantes_busqueda_nombre_cliente.sql'), 'utf8')
      .replace(/^(BEGIN|COMMIT);\s*$/gm, '')
      .replace("n.nspname = 'public'", 'n.oid = pg_my_temp_schema()')
    await client.query(migration)
    await client.query(migration) // Idempotencia.
    for (const term of ['maria', 'MARÍA', 'garcia', 'García López', 'María Elena García López', '00123456']) {
      const result = await listar(term)
      assert.equal(Number(result.total), 2, `Conteo incorrecto para ${term}`)
      assert.deepEqual(result.registros.map(r => r.id).sort(), [102, 103], `Deben aparecer boleta y factura para ${term}`)
    }
    assert.equal(Number((await listar('jose')).total), 1, 'Nombres sin apellidos y razón social vacía')
    assert.equal(Number((await listar('oxigeno del sur')).total), 1, 'Se conserva la búsqueda por razón social')
    assert.equal(Number((await listar('medicinal')).total), 1, 'Se conserva la búsqueda por glosa')
    assert.equal(Number((await listar('B001-00000102')).total), 1, 'Se conserva la búsqueda por serie y número')
    assert.equal((await listar('maria', 1, 0)).registros[0].id, 102)
    assert.equal((await listar('maria', 1, 1)).registros[0].id, 103)
    assert.equal(Number((await listar('maria', 1, 1)).total), 2, 'Conteo consistente en la segunda página')
    assert.deepEqual((await listar('maria', 20, 0, 2)).registros.map(r => r.id), [102], 'Filtro explícito de boletas')
    assert.deepEqual((await listar('maria', 20, 0, 1)).registros.map(r => r.id), [103], 'Filtro explícito de facturas')
    assert.equal(Number((await listar('cliente inexistente')).total), 0)
    console.log('PASS: nombres, apellidos, tildes, DNI, razón social, glosa, serie, boletas/facturas, paginación y migración idempotente. Datos ficticios; cambios revertidos.')
  } finally {
    await client.query('ROLLBACK').catch(() => {})
    await client.end()
  }
}
main().catch(error => { console.error(error.message); process.exitCode = 1 })
