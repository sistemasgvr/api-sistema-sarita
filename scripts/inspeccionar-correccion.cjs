require('ts-node/register/transpile-only');
const fs=require('node:fs'),path=require('node:path');
const {ConfigService}=require('@nestjs/config');
const {DatabaseService}=require('../src/database/database.service');
const env=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
const db=new DatabaseService(new ConfigService({database:{url:env.DATABASE_URL}}));
async function main(){
 const tables=['ven_comprobante','ven_comprobante_detalle','fin_cuenta','fin_pago','fin_cobro','ven_cobro','inv_movimiento','bal_baja_balon','bal_movimiento_recarga','doc_salida_referencia','doc_salida','ven_resumen_diario_detalle'];
 const cols=await db.query(`SELECT table_name,column_name,data_type FROM information_schema.columns WHERE table_schema='public' AND table_name=ANY($1::text[]) ORDER BY table_name,ordinal_position`,[tables]);
 console.log(JSON.stringify(cols.rows));
 const current=await db.query(`SELECT c.id,c.serie,c.numero,c.fecha::text,COALESCE(c.fecha_emision_cpe,c.fecha::date)::text AS fecha_fiscal,s.nombre AS estado_sunat,c.total_importe FROM ven_comprobante c JOIN gen_lista_opciones s ON s.id=c.id_estado_sunat WHERE c.estado=1 AND c.serie IN ('F002','B002') ORDER BY c.fecha::date,c.id`);
 console.log(JSON.stringify(current.rows));
 const functions=await db.query("SELECT pg_get_functiondef(oid) AS definition FROM pg_proc WHERE proname='ven_obtener_siguiente_numero'");
 fs.writeFileSync(path.join(__dirname,'../../diagnosticos/reordenamiento-fiscal-20261012/contador-previo.sql'),functions.rows[0].definition);
}
main().catch(e=>{console.error(e.message);process.exitCode=1;}).finally(()=>db.onModuleDestroy());
