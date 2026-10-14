// Solo consultas a la base, SUNAT y GET /invoice/status. Ningún envío.
require('ts-node/register/transpile-only');
const fs=require('node:fs'); const path=require('node:path'); const axios=require('axios');
const {Client}=require('pg');
const env=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
const db=new Client({connectionString:env.DATABASE_URL,connectionTimeoutMillis:10000});
const {SunatValidezClient}=require('../src/integrations/facturacion-electronica/sunat-validez.client');
const validez=new SunatValidezClient(db);
function compact(p) {
  const root=p?.sunatResponse??p??{};
  return {claves:Object.keys(p??{}),clavesSunat:Object.keys(root),success:root.success,error:root.error,
    cdr:root.cdrResponse??null,zip:typeof root.cdrZip==='string'?root.cdrZip.length:0};
}
async function main(){
  await db.connect();
  const cfg=(await db.query('SELECT cs.*,e.ruc FROM gen_configuracion_sunat cs JOIN gen_empresa e ON e.id=cs.id_empresa WHERE cs.estado=1')).rows[0];
  if(cfg.api_base_url!=='https://facturacion.apisperu.com/api/v1') throw new Error('Proveedor inesperado');
  const docs=(await db.query(`SELECT c.id,c.serie,c.numero,c.fecha::text,c.fecha_emision_cpe::text,c.total_importe,c.cdr_respuesta,c.hash_documento,
    c.cpe_verificacion,s.nombre AS estado,t.descripcion AS tipo FROM ven_comprobante c JOIN gen_lista_opciones s ON s.id=c.id_estado_sunat
    JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante WHERE c.estado=1 AND ((c.serie='F002' AND c.numero::numeric IN (1,2,3,21)) OR (c.serie='B002' AND c.numero::numeric IN (1,2))) ORDER BY c.id DESC`)).rows;
  const resultados=[];
  for(const doc of docs){
    let saved={}; try {saved=JSON.parse(doc.cdr_respuesta??'{}');}catch{}
    const item={id:doc.id,referencia:`${doc.serie}-${Number(doc.numero)}`,estado:doc.estado,hash:!!doc.hash_documento,guardado:compact(saved),marca:saved.tipo??null,fase:saved.fase??null,verificacion:doc.cpe_verificacion};
    try{const live=await validez.consultar(cfg.id_empresa,{tipo:doc.tipo,serie:doc.serie,numero:doc.numero,fecha:doc.fecha_emision_cpe??doc.fecha,total:Number(doc.total_importe)});item.validez={codigo:live.codigo,estado:live.estado,consulta:live.consulta};}catch(e){item.validez={error:e.message};}
    try{const live=await axios.get(`${cfg.api_base_url}/invoice/status`,{params:{ruc:cfg.ruc,tipo:doc.tipo,serie:doc.serie,numero:String(Number(doc.numero))},headers:{Authorization:`Bearer ${cfg.api_token}`},timeout:30000,maxRedirects:0,validateStatus:()=>true});item.proveedor={http:live.status,...compact(live.data)};}catch(e){item.proveedor={error:e.code??'red'};}
    resultados.push(item);console.log(JSON.stringify(item));
  }
  fs.writeFileSync(path.join(__dirname,'../../diagnosticos/envios-actuales-20261012.json'),JSON.stringify({consultadoEn:new Date().toISOString(),envios:0,resultados},null,2));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;}).finally(()=>db.end());
