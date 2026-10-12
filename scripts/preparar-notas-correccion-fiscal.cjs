// Preparación exclusivamente: consulta SUNAT/CDR y genera XML de revisión.
// No llama /note/send, no crea NC operativas y no modifica ventas ni stock.
require('ts-node/register/transpile-only');
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const {ConfigService}=require('@nestjs/config'); const {HttpService}=require('@nestjs/axios');
const env=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
const {DatabaseService}=require('../src/database/database.service');
const {ComprobantesModel}=require('../src/modules/comprobantes/models/comprobantes.model');
const {ClientesModel}=require('../src/modules/clientes/models/clientes.model');
const {ComprobanteInvoiceMapper}=require('../src/modules/comprobantes/mappers/comprobante-invoice.mapper');
const {FacturacionCredentialsService}=require('../src/integrations/facturacion-electronica/facturacion-credentials.service');
const {FacturacionApisperuClient}=require('../src/integrations/facturacion-apisperu/facturacion-apisperu.client');
const {SunatValidezClient}=require('../src/integrations/facturacion-electronica/sunat-validez.client');
const {estadoDesdeCdr,cdrCorrespondeAlDocumento}=require('../src/common/helpers/cpe-estado.helper');
const config=new ConfigService({database:{url:env.DATABASE_URL}});
const db=new DatabaseService(config), model=new ComprobantesModel(db,config),clientes=new ClientesModel(db),mapper=new ComprobanteInvoiceMapper();
const provider=new FacturacionApisperuClient(new HttpService(),new FacturacionCredentialsService(db,config)),sunat=new SunatValidezClient(db);
const folder=path.join(__dirname,'../../diagnosticos/notas-correccion-fiscal-20261012');
fs.mkdirSync(folder,{recursive:true});
async function main(){
 const emisor=await model.obtenerEmpresaEmisora();assert.equal(emisor.ruc,'10175332796');
 const lock=await model.reclamarOperacionCpe(emisor.id);if(!lock)throw new Error('Hay otra operación activa; preparación no iniciada');
 const review={preparadoEn:new Date().toISOString(),soloPreparacion:true,notasEnviadas:0,ventasModificadas:0,documentos:[]};
 try {
  const refs=['F002-1','F002-2','F002-3','B002-1','B002-24','B002-25'];
  const ids=(await db.query("SELECT id,serie,numero FROM ven_comprobante WHERE estado=1 AND serie IN ('F002','B002') ORDER BY serie,numero::numeric")).rows;
  const counters={FC02:0,BC02:0};
  for(const ref of refs){
   await db.query("UPDATE ven_cpe_operacion_control SET vencimiento=NOW()+INTERVAL '10 minutes' WHERE id_empresa=$1 AND token=$2",[emisor.id,lock]);
   const id=ids.find(r=>`${r.serie}-${Number(r.numero)}`===ref)?.id;if(!id)throw new Error('No existe '+ref);
   const original=await model.obtenerCompleto(id),doc=original.registro;
   const valid=await sunat.consultar(emisor.id,{tipo:doc.codigo_tipo_comprobante,serie:doc.serie,numero:doc.numero,fecha:doc.fecha_emision_cpe??doc.fecha,total:Number(doc.total_importe)});
   assert.equal(valid.codigo,'1','SUNAT no confirma '+ref);
   const cdr=await provider.consultarEstadoFacturaBoleta({ruc:emisor.ruc,tipo:doc.codigo_tipo_comprobante,serie:doc.serie,numero:String(Number(doc.numero))});
   assert.equal(estadoDesdeCdr(cdr),'ACEPTADO');
   assert.ok(cdrCorrespondeAlDocumento(cdr,doc.serie,doc.numero,doc.fecha_emision_cpe??doc.fecha,'0'));
   const serie=doc.codigo_tipo_comprobante==='01'?'FC02':'BC02';
   const local=(await db.query('SELECT COALESCE(MAX(numero::numeric),0)::int AS ultimo FROM ven_comprobante c JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante WHERE t.descripcion=$1 AND c.serie=$2',['07',serie])).rows[0].ultimo;
   counters[serie]=Math.max(counters[serie],local);
   let num,status;
   do{num=++counters[serie]; status=await provider.consultarEstadoFacturaBoleta({ruc:emisor.ruc,tipo:'07',serie,numero:String(num)});}
   while(estadoDesdeCdr(status)==='ACEPTADO');
   const st=status.sunatResponse??status;
   assert.equal(String(st.error?.code??''),'0127','No se puede comprobar disponibilidad de la referencia NC');
   const cliente=(await clientes.obtenerPorId(doc.id_cliente)).registro;
   const ubigeo=cliente.id_distrito?await model.obtenerCodigoUbigeoDistrito(cliente.id_distrito):'';
   const nota=structuredClone(original);
   Object.assign(nota.registro,{codigo_tipo_comprobante:'07',serie,numero:String(num),fecha_emision_cpe:'2026-10-12',
     serie_comprobante_origen:doc.serie,numero_comprobante_origen:doc.numero,codigo_tipo_comprobante_origen:doc.codigo_tipo_comprobante,
     codigo_motivo_nota:'01',nombre_motivo_nota:'ANULACION DEL COMPROBANTE POR CORRECCION DEL ORDEN DE CORRELATIVOS Y EMISION DE REEMPLAZO. LA VENTA SE MANTIENE VIGENTE.'});
   const payload=mapper.mapComprobanteToInvoicePayload(nota,emisor,cliente,ubigeo);
   delete payload.formaPago;
   delete payload.cuotas;
   assert.equal(Number(payload.mtoImpVenta),Number(doc.total_importe));
   assert.equal(payload.numDocfectado,ref);
   const xml=await provider.generarXmlNota(payload);
   assert.ok(xml.includes(`${serie}-${num}`));
   fs.writeFileSync(path.join(folder,`${serie}-${num}.json`),JSON.stringify(payload,null,2));
   fs.writeFileSync(path.join(folder,`${serie}-${num}.xml`),xml);
   review.documentos.push({idVenta:id,original:ref,notaPropuesta:`${serie}-${num}`,fechaVenta:doc.fecha,fechaFiscalOriginal:doc.fecha_emision_cpe??doc.fecha,
     importe:Number(doc.total_importe),motivoCodigo:'01',estado:'XML_GENERADO_NO_EMITIDO',validezOriginal:valid,cdrOriginal:cdr,payload});
   fs.writeFileSync(path.join(folder,'revision.json'),JSON.stringify(review,null,2));
   console.log(JSON.stringify({original:ref,notaPropuesta:`${serie}-${num}`,importe:Number(doc.total_importe),xmlGenerado:true,notasEnviadas:0}));
  }
 }finally{await model.liberarOperacionCpe(emisor.id,lock);}
}
main().catch(e=>{console.error(e.message);process.exitCode=1;}).finally(()=>db.onModuleDestroy());
