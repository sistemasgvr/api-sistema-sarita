// Proceso fiscal de corrección autorizado. Preparación no emite ni cambia ventas.
// Las fases explícitas posteriores deben comprobar CDR y conservar datos económicos.
require('ts-node/register/transpile-only');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {randomUUID,createHash}=require('node:crypto');
const {ConfigService}=require('@nestjs/config'),{HttpService}=require('@nestjs/axios');
const env=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
const {DatabaseService}=require('../src/database/database.service');
const {ComprobantesModel}=require('../src/modules/comprobantes/models/comprobantes.model');
const {FacturacionCredentialsService}=require('../src/integrations/facturacion-electronica/facturacion-credentials.service');
const {FacturacionApisperuClient}=require('../src/integrations/facturacion-apisperu/facturacion-apisperu.client');
const {SunatValidezClient}=require('../src/integrations/facturacion-electronica/sunat-validez.client');
const {estadoDesdeCdr,cdrCorrespondeAlDocumento,mensajeErrorCpe}=require('../src/common/helpers/cpe-estado.helper');
const config=new ConfigService({database:{url:env.DATABASE_URL}}),db=new DatabaseService(config),model=new ComprobantesModel(db,config);
const provider=new FacturacionApisperuClient(new HttpService(),new FacturacionCredentialsService(db,config)),sunat=new SunatValidezClient(db);
const folder=path.join(__dirname,'../../diagnosticos/reordenamiento-fiscal-20261012');fs.mkdirSync(folder,{recursive:true});
const hash=value=>createHash('sha256').update(JSON.stringify(value)).digest('hex');
let lease=null,empresa=null;
async function heartbeat(){
 const result=await db.query("UPDATE ven_cpe_operacion_control SET vencimiento=NOW()+INTERVAL '10 minutes' WHERE id_empresa=$1 AND token=$2 RETURNING token",[empresa.id,lease]);
 assert.equal(result.rowCount,1,'Se perdió el control exclusivo de emisión');
}
async function docsActuales(){
 return (await db.query(`SELECT c.*,t.descripcion AS tipo,s.nombre AS estado_sunat,
   COALESCE(c.fecha_emision_cpe,c.fecha::date)::text AS fecha_fiscal,c.fecha::text AS fecha_venta
   FROM ven_comprobante c JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante
   JOIN gen_lista_opciones s ON s.id=c.id_estado_sunat
   WHERE c.estado=1 AND c.serie IN ('F002','B002') AND t.descripcion IN ('01','03')
   ORDER BY c.fecha::date,c.id`)).rows;
}
async function validarDependencias(docs){
 const ids=docs.map(d=>d.id);
 const gre=(await db.query(`SELECT DISTINCT c.id,c.serie,c.numero FROM ven_comprobante c
  JOIN doc_salida d ON d.estado=1 AND (d.id_venta=c.id OR EXISTS(SELECT 1 FROM doc_salida_referencia r WHERE r.id_doc_salida=d.id AND r.id_comprobante=c.id AND r.estado=1))
  WHERE c.id=ANY($1::int[]) AND (d.emitido_sunat OR NULLIF(TRIM(COALESCE(d.ticket_sunat,'')),'') IS NOT NULL
    OR EXISTS(SELECT 1 FROM doc_gre_intento i WHERE i.id_doc_salida=d.id AND i.estado<>'RECHAZADO'))`,[ids])).rows;
 assert.equal(gre.length,0,'Hay GRE enviadas que citan una referencia del lote: '+JSON.stringify(gre));
 const nc=(await db.query(`SELECT c.id,c.serie,c.numero FROM ven_comprobante c JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante
  WHERE c.estado=1 AND t.descripcion IN ('07','08') AND c.id_comprobante_origen=ANY($1::int[])`,[ids])).rows;
 assert.equal(nc.length,0,'Hay notas operativas existentes: '+JSON.stringify(nc));
}
async function preparar(){
 const notes=JSON.parse(fs.readFileSync(path.join(__dirname,'../../diagnosticos/notas-correccion-fiscal-20261012/revision.json'),'utf8')).documentos;
 assert.equal(notes.length,6);
 const docs=await docsActuales();assert.equal(docs.length,48,'Cambió el conjunto de comprobantes');
 await validarDependencias(docs);
 const loteId=randomUUID(),plan=[];
 const next={F002:Math.max(...docs.filter(d=>d.serie==='F002').map(d=>Number(d.numero)))+1,
             B002:Math.max(...docs.filter(d=>d.serie==='B002').map(d=>Number(d.numero)))+1};
 for(const doc of docs){
  await heartbeat();
  const original=`${doc.serie}-${Number(doc.numero)}`;
  const valid=await sunat.consultar(empresa.id,{tipo:doc.tipo,serie:doc.serie,numero:doc.numero,fecha:doc.fecha_fiscal,total:Number(doc.total_importe)});
  const status=await provider.consultarEstadoFacturaBoleta({ruc:empresa.ruc,tipo:doc.tipo,serie:doc.serie,numero:String(Number(doc.numero))});
  const data=status.sunatResponse??status;
  const note=notes.find(n=>n.idVenta===doc.id);
  if(note){
   assert.equal(note.original,original);assert.equal(valid.codigo,'1');assert.equal(Number(note.importe),Number(doc.total_importe));
   assert.equal(estadoDesdeCdr(status),'ACEPTADO');assert.ok(cdrCorrespondeAlDocumento(status,doc.serie,doc.numero,doc.fecha_fiscal,'0'));
  }else{
   assert.equal(valid.codigo,'0','El documento requiere tratamiento fiscal adicional: '+original);
   assert.equal(String(data.error?.code??''),'0127','El proveedor tiene un resultado que requiere revisión: '+original);
   assert.ok(!data.cdrResponse&&!data.ticket);
  }
  let numero,nuevoStatus;
  do{numero=next[doc.serie]++;nuevoStatus=await provider.consultarEstadoFacturaBoleta({ruc:empresa.ruc,tipo:doc.tipo,serie:doc.serie,numero:String(numero)});}
  while(estadoDesdeCdr(nuevoStatus)==='ACEPTADO');
  assert.equal(String((nuevoStatus.sunatResponse??nuevoStatus).error?.code??''),'0127');
  plan.push({id:doc.id,serie:doc.serie,numeroOriginal:doc.numero,numeroNuevo:String(numero).padStart(8,'0'),fechaVenta:doc.fecha_venta.slice(0,10),fechaFiscal:doc.fecha_fiscal,
    total:Number(doc.total_importe),original,propuesto:`${doc.serie}-${numero}`,requiereNota:!!note,verificacion:valid,estadoProveedor:status,snapshot:doc});
  console.log(JSON.stringify({fase:'PREPARACION',original,propuesto:`${doc.serie}-${numero}`,fechaVenta:doc.fecha_venta.slice(0,10),requiereNota:!!note,envios:0}));
 }
 await db.withTransaction(async()=>{
  for(const p of plan){
   const current=(await db.query('SELECT serie,numero,total_importe,cdr_respuesta,xml_firmado FROM ven_comprobante WHERE id=$1 FOR UPDATE',[p.id])).rows[0];
   assert.equal(current.serie,p.serie);assert.equal(current.numero,p.numeroOriginal);assert.equal(Number(current.total_importe),p.total);
   assert.equal(current.cdr_respuesta,p.snapshot.cdr_respuesta);assert.equal(current.xml_firmado,p.snapshot.xml_firmado);
  }
  await db.query("INSERT INTO ven_cpe_correccion_lote(id,motivo,fecha_fiscal,plan) VALUES($1,$2,$3,$4::jsonb)",[loteId,'Corrección cronológica de correlativos conservando la venta','2026-10-12',JSON.stringify(plan)]);
  for(const n of notes){
   const doc=plan.find(p=>p.id===n.idVenta);
   const [serie,numero]=n.notaPropuesta.split('-');
   const xml=fs.readFileSync(path.join(__dirname,`../../diagnosticos/notas-correccion-fiscal-20261012/${n.notaPropuesta}.xml`),'utf8');
   await db.query(`INSERT INTO ven_cpe_correccion_nota(id_lote,id_empresa,id_comprobante_original,serie_original,numero_original,serie,numero,importe,payload,xml_firmado,verificacion_original,datos_originales)
    VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10,$11::jsonb,$12::jsonb)`,
    [loteId,empresa.id,n.idVenta,doc.serie,doc.numeroOriginal,serie,Number(numero),n.importe,JSON.stringify(n.payload),xml,JSON.stringify(doc.verificacion),JSON.stringify(doc.snapshot)]);
  }
 });
 fs.writeFileSync(path.join(folder,'lote.json'),JSON.stringify({loteId,estado:'PREPARADO',plan,notasEnviadas:0,ventasModificadas:0},null,2));
 console.log(JSON.stringify({loteId,preparados:plan.length,notasPreparadas:notes.length,notasEnviadas:0,ventasModificadas:0}));
}
async function main(){
 empresa=await model.obtenerEmpresaEmisora();assert.equal(empresa.ruc,'10175332796');
 lease=await model.reclamarOperacionCpe(empresa.id);if(!lease)throw new Error('Hay otra operación de esta empresa activa');
 await db.query(fs.readFileSync(path.join(__dirname,'../database_sql/migraciones/20261012_correccion_fiscal_cronologica.sql'),'utf8'));
 if(process.argv.includes('--preparar')) await preparar();
 else throw new Error('Selecciona una fase explícita');
}
main().catch(e=>{console.error(e.message);process.exitCode=1;}).finally(async()=>{if(lease)await model.liberarOperacionCpe(empresa.id,lease);await db.onModuleDestroy();});
