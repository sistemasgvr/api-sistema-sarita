// --prepare: respaldo y captura de solo lectura. --test-local: ensayo aislado en Docker.
// --apply: migración + restitución autorizada, atómicas y verificadas antes de COMMIT.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const zlib = require('node:zlib');
const { Client } = require('pg');
const root = path.resolve(__dirname, '..');
const folder = path.resolve(root, '../diagnosticos/rutas-pueblos-historial-20261031');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const unwrapped = s => s.replace(/^BEGIN;\s*$/m, '').replace(/^COMMIT;\s*$/m, '');
const migration = unwrapped(read('database_sql/migraciones/20261031_rutas_pueblos_solo_historial.sql'));
const correction = read('database_sql/correcciones/20261031_ruta_1_solo_historial.sql');
const names = [...migration.matchAll(/FUNCTION public\.(\w+)/g)].map(m => m[1]);
const tables = {
  bal_ruta_pueblo: 'WHERE id=1',
  bal_ruta_pueblo_detalle: 'WHERE id_ruta_pueblo=1',
  bal_ruta_pueblo_detalle_producto: 'WHERE id_ruta_pueblo=1',
  inv_movimiento: 'WHERE id BETWEEN 971 AND 1018',
  pro_stock: 'WHERE estado=1 AND id_almacen=2 AND id_producto IN (SELECT id_producto FROM inv_movimiento WHERE id BETWEEN 971 AND 1018)',
  bal_balon: 'WHERE id IN (SELECT id_balon FROM inv_movimiento WHERE id BETWEEN 971 AND 1018)',
  gen_lista: '', gen_lista_opciones: '',
};
async function snapshot(db) {
  const data = {};
  for (const [table, filter] of Object.entries(tables))
    data[table] = (await db.query(`SELECT * FROM ${table} ${filter} ORDER BY id`)).rows;
  data.functions = (await db.query(`SELECT p.proname, pg_get_functiondef(p.oid) definition
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=ANY($1) ORDER BY p.proname`, [names])).rows;
  return data;
}
async function backupPublic(db) {
  await db.query('BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY');
  await db.query('SET LOCAL statement_timeout=60000');
  try {
    const relations=(await db.query(`SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind IN ('r','p') ORDER BY c.relname`)).rows;
    const quote=s=>'"'+s.replaceAll('"','""')+'"';
    const sql=relations.map(r=>`SELECT '${r.relname.replaceAll("'","''")}' tabla,
      COALESCE(jsonb_agg(to_jsonb(t)),'[]'::jsonb) registros FROM public.${quote(r.relname)} t`).join(' UNION ALL ');
    const data=(await db.query(sql)).rows;
    const definitions=(await db.query(`SELECT p.proname,p.prokind,pg_get_functiondef(p.oid) definicion
      FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind IN ('f','p')`)).rows;
    const columns=(await db.query("SELECT * FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name,ordinal_position")).rows;
    const constraints=(await db.query(`SELECT c.relname tabla,con.conname,con.contype,pg_get_constraintdef(con.oid) definicion
      FROM pg_constraint con JOIN pg_class c ON c.oid=con.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public'`)).rows;
    const indexes=(await db.query("SELECT * FROM pg_indexes WHERE schemaname='public'")).rows;
    const sequences=(await db.query("SELECT * FROM pg_sequences WHERE schemaname='public'")).rows;
    const triggers=(await db.query(`SELECT c.relname tabla,t.tgname,pg_get_triggerdef(t.oid) definicion
      FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND NOT t.tgisinternal`)).rows;
    const grants=(await db.query("SELECT * FROM information_schema.table_privileges WHERE table_schema='public'")).rows;
    const policies=(await db.query("SELECT * FROM pg_policies WHERE schemaname='public'")).rows;
    const raw=Buffer.from(JSON.stringify({schema:'public',data,definitions,columns,constraints,indexes,sequences,triggers,grants,policies}));
    const compressed=zlib.gzipSync(raw);
    assert.deepEqual(zlib.gunzipSync(compressed),raw);
    fs.writeFileSync(path.join(folder,'produccion-public-antes.json.gz'),compressed,{flag:'wx'});
    await db.query('ROLLBACK');
    return {tablas:data.length,funciones:definitions.length,bytes:compressed.length};
  } catch(e) { await db.query('ROLLBACK');throw e; }
}
function verifySql() {
  return `DO $verify$ BEGIN
    IF (SELECT stock FROM pro_stock WHERE id_almacen=2 AND id_producto=4 AND estado=1)<>128
      OR (SELECT stock FROM pro_stock WHERE id_almacen=2 AND id_producto=9 AND estado=1)<>367 THEN
      RAISE EXCEPTION 'Gas no restituido'; END IF;
    IF (SELECT count(*) FROM inv_movimiento WHERE id_movimiento_padre BETWEEN 971 AND 1018
      AND glosa LIKE 'Restitución ruta histórica #1:%' AND estado=1)<>48 THEN
      RAISE EXCEPTION 'Faltan compensaciones'; END IF;
    IF EXISTS (SELECT 1 FROM inv_movimiento m JOIN bal_balon b ON b.id=m.id_balon
      WHERE m.id BETWEEN 971 AND 1018 AND (b.id_almacen IS DISTINCT FROM m.id_almacen_anterior
        OR b.id_estado_balon IS DISTINCT FROM m.id_estado_balon_anterior
        OR b.id_cliente_ubicacion IS DISTINCT FROM m.id_cliente_ubicacion_anterior)) THEN
      RAISE EXCEPTION 'Cilindros no restituidos'; END IF;
    IF NOT EXISTS (SELECT 1 FROM bal_ruta_pueblo r JOIN gen_lista_opciones e ON e.id=r.id_estado
      WHERE r.id=1 AND e.nombre='EN_RUTA') THEN RAISE EXCEPTION 'Se alteró el estado de la ruta'; END IF;
    IF EXISTS (SELECT 1 FROM bal_ruta_pueblo_detalle WHERE id_ruta_pueblo=1 AND lb_retorno IS NOT NULL)
      THEN RAISE EXCEPTION 'Se registró un retorno físico incorrecto'; END IF;
  END $verify$;`;
}
async function main() {
  fs.mkdirSync(folder, { recursive: true });
  if (process.argv.includes('--test-local')) {
    const data = JSON.parse(fs.readFileSync(path.join(folder, 'antes.json')));
    let sql = 'BEGIN; CREATE SCHEMA test_restitucion_ruta; SET LOCAL search_path=test_restitucion_ruta,public;\n';
    for (const table of Object.keys(tables)) {
      const module = table.startsWith('bal_') ? 'balones' : table.startsWith('pro_') ? 'productos' : table.startsWith('inv_') ? 'inventario' : 'general';
      const ddl = read(`database_sql/tablas/${module}/${table}.sql`).match(/CREATE TABLE public\.[\s\S]*?\n\);/)[0];
      sql += ddl.replace('public.', 'test_restitucion_ruta.')
        .replace(/ REFERENCES public\.\w+\(\w+\)/g, '') + '\n';
      sql += `INSERT INTO ${table} SELECT * FROM jsonb_populate_recordset(NULL::${table},'${JSON.stringify(data[table]).replaceAll("'", "''")}'::jsonb);\n`;
    }
    sql += "CREATE SEQUENCE correction_id START 2000; ALTER TABLE inv_movimiento ALTER COLUMN id SET DEFAULT nextval('correction_id');\n";
    sql += correction + '\n' + verifySql();
    sql += '\n' + correction + '\n' + verifySql();
    sql += `\nDO $$ BEGIN IF EXISTS (SELECT 1 FROM pro_stock s WHERE s.stock IS DISTINCT FROM
      ((SELECT (j->>'stock')::numeric FROM jsonb_array_elements('${JSON.stringify(data.pro_stock).replaceAll("'", "''")}'::jsonb) j WHERE (j->>'id')::integer=s.id)
       + COALESCE((SELECT sum(m.stock_anterior-m.stock_nuevo) FROM inv_movimiento m WHERE m.id BETWEEN 971 AND 1018 AND m.id_producto=s.id_producto),0)))
      THEN RAISE EXCEPTION 'Stock de productos incorrecto'; END IF; END $$; ROLLBACK;`;
    const result = spawnSync('docker', ['exec','-i','gvr-postgres-local','psql','-X','-q','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'], {input:sql,encoding:'utf8'});
    if (result.status !== 0) throw new Error(result.stderr || result.error?.message);
    console.log(JSON.stringify({ensayoLocal:true,compensaciones:48,reintentoSinDuplicados:true,productosYCilindrosVerificados:true}));
    return;
  }
  const env = require('dotenv').parse(read('.env'));
  assert.ok(env.DATABASE_URL.includes('ebotjjfdgcuwrfoappsa'), 'La base activa debe ser la producción auditada');
  const apply = process.argv.includes('--apply');
  assert.ok(apply || process.argv.includes('--prepare') || process.argv.includes('--backup-json'), 'Usar --prepare, --backup-json, --test-local o --apply');
  const db = new Client({connectionString:env.DATABASE_URL,ssl:{rejectUnauthorized:false},
    connectionTimeoutMillis:10000,options:'-c statement_timeout=20000 -c lock_timeout=5000'});
  await db.connect();
  try {
    if (process.argv.includes('--backup-json')) {
      console.log(JSON.stringify({respaldoEsquemaAplicacion:await backupPublic(db),carpeta:folder}));
      return;
    }
    if (!apply) {
      await db.query('BEGIN READ ONLY');
      const data = await snapshot(db);
      assert.equal(data.inv_movimiento.length,48);
      const previous=path.join(folder,'antes.json');
      if (fs.existsSync(previous)) assert.deepEqual(JSON.parse(JSON.stringify(data)),JSON.parse(fs.readFileSync(previous)),'La captura previa cambió');
      else fs.writeFileSync(previous,JSON.stringify(data,null,2),{flag:'wx'});
      await db.query('ROLLBACK');
      await backupPublic(db);
      console.log(JSON.stringify({respaldoCompleto:true,carpeta:folder,movimientos:48}));
    } else {
      const backup=JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(folder,'produccion-public-antes.json.gz'))));
      assert.equal(backup.schema,'public');
      assert.ok(backup.data.length>=100 && backup.definitions.length>=515,'Respaldo incompleto');
      const before = JSON.parse(fs.readFileSync(path.join(folder,'antes.json')));
      await db.query('BEGIN');
      await db.query('LOCK TABLE bal_ruta_pueblo,bal_ruta_pueblo_detalle,bal_ruta_pueblo_detalle_producto,inv_movimiento,pro_stock,bal_balon IN SHARE ROW EXCLUSIVE MODE');
      const current = await snapshot(db);
      assert.deepEqual(JSON.parse(JSON.stringify(current)),before,'Los datos cambiaron desde el respaldo: volver a revisar');
      await db.query(migration);
      await db.query(correction);
      await db.query(verifySql());
      // Verificar todos los productos usando el delta real, sin mezclar sus unidades.
      for (const stock of before.pro_stock) {
        const delta=before.inv_movimiento.filter(m=>m.id_producto===stock.id_producto && m.naturaleza==='PRODUCTO')
          .reduce((n,m)=>n+Number(m.stock_anterior)-Number(m.stock_nuevo),0);
        const after=(await db.query('SELECT stock FROM pro_stock WHERE id=$1',[stock.id])).rows[0];
        assert.equal(Number(after.stock),Number(stock.stock)+delta);
      }
      const after=JSON.parse(JSON.stringify(await snapshot(db)));
      assert.deepEqual(after.inv_movimiento,before.inv_movimiento,'Conservar movimientos originales');
      assert.deepEqual(after.bal_ruta_pueblo,before.bal_ruta_pueblo,'Conservar ruta en curso');
      assert.deepEqual(after.bal_ruta_pueblo_detalle,before.bal_ruta_pueblo_detalle);
      assert.deepEqual(after.bal_ruta_pueblo_detalle_producto,before.bal_ruta_pueblo_detalle_producto);
      for (const f of names) {
        const body=(await db.query(`SELECT prosrc FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND proname=$1`,[f])).rows[0].prosrc;
        assert.equal(body,read(`database_sql/funciones/balones/${f}.sql`).split('$function$')[1]);
      }
      const movements=(await db.query("SELECT * FROM inv_movimiento WHERE id_movimiento_padre BETWEEN 971 AND 1018 AND glosa LIKE 'Restitución ruta histórica #1:%' ORDER BY id")).rows;
      fs.writeFileSync(path.join(folder,'despues.json'),JSON.stringify({ ...after,compensaciones:movements },null,2),{flag:'wx'});
      await db.query('COMMIT');
      console.log(JSON.stringify({aplicado:true,base:'PROD',funciones:names.length,compensaciones:movements.length,argon:128,oxigenoIndustrial:367,cilindros:14,rutaConservada:'EN_RUTA',respaldo:folder}));
    }
  } catch(e) { await db.query('ROLLBACK'); throw e; }
  finally { await db.end(); }
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
