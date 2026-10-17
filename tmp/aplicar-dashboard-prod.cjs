const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { Client } = require('pg');
const root = path.join(__dirname, '..');
const env = require('dotenv').parse(fs.readFileSync(path.join(root, '.env')));
const names = ['dash_ventas_netas','dash_historico_ventas_compras','dash_top_clientes_venta','dash_demanda_gases','dash_venta_gases_comparativo','dash_velocidad_salida'];
const migration = fs.readFileSync(path.join(root,'database_sql/migraciones/20261017_dashboard_tipos_comprobante_dinamicos.sql'),'utf8');
const body = migration.replace(/^BEGIN;\s*$/m,'').replace(/^COMMIT;\s*$/m,'');
assert.equal((body.match(/CREATE OR REPLACE FUNCTION/g)||[]).length, 6);
const reference = migration.match(/SELECT COALESCE\(SUM\(total_importe\), 0\)[\s\S]*?;/)[0]
  .replace(/\s+INTO v_total/,'')
  .replace(/\bp_fecha_desde\b/g,'$1::date')
  .replace(/\bp_fecha_hasta\b/g,'$2::date')
  .replace(/\bp_id_cliente\b/g,'$3::integer');
const db = new Client({connectionString:env.DATABASE_URL,ssl:{rejectUnauthorized:false},connectionTimeoutMillis:10000,options:'-c statement_timeout=30000 -c lock_timeout=5000'});
(async()=>{
 let transaction = false;
 try {
  await db.connect();
  await db.query('BEGIN'); transaction = true;
  await db.query('SET LOCAL search_path = public, pg_catalog');
  const previous = (await db.query(`SELECT p.proname,pg_get_functiondef(p.oid) definition
    FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=ANY($1::text[]) ORDER BY p.proname`,[names])).rows;
  assert.equal(previous.length,6,'Debe haber exactamente seis funciones a reemplazar');
  const backup = path.join(root,'tmp','dashboard-prod-before-'+new Date().toISOString().replace(/[:.]/g,'-')+'.sql');
  fs.writeFileSync(backup,'-- Respaldo previo de las seis funciones del dashboard.\nBEGIN;\n'+previous.map(row=>row.definition+';').join('\n')+'\nCOMMIT;\n',{flag:'wx'});
  await db.query(body);
  const params=['2026-10-01','2026-10-17',null];
  const expected=Number((await db.query(reference,params)).rows[0].coalesce);
  const kpi=(await db.query('SELECT dash_ventas_netas($1,$2,$3) ventas,dash_compras_netas($1,$2) compras',params)).rows[0];
  assert.equal(Number(kpi.ventas),Math.round(expected*100)/100);
  const checks = [
   ['SELECT dash_historico_ventas_compras($1)',[2026]],
   ['SELECT dash_top_clientes_venta($1,$2,$3)',['2026-10-01','2026-10-17',10]],
   ['SELECT dash_demanda_gases($1,$2)',['2026-10-01','2026-10-17']],
   ['SELECT dash_venta_gases_comparativo($1,$2)',[2026,10]],
   ['SELECT dash_velocidad_salida($1,$2,$3,$4)',['2026-10-01','2026-10-17',null,20]],
  ];
  for(const [sql,values] of checks) await db.query(sql,values);
  await db.query('COMMIT'); transaction=false;
  console.log(JSON.stringify({aplicado:true,funciones:6,verificadasAntesDeCommit:6,respaldo:backup,periodo:'2026-10-01 / 2026-10-17',ventas:Number(kpi.ventas),compras:Number(kpi.compras),indicadorRentabilidad:Math.round((Number(kpi.ventas)-Number(kpi.compras))*100)/100},null,2));
 }catch(error){if(transaction)await db.query('ROLLBACK');throw error;}
 finally{await db.end();}
})().catch(error=>{console.error(error.code||error.message);process.exitCode=1});
