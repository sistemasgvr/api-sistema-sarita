// Fases explícitas y reanudables del lote autorizado. Ninguna llamada a las
// funciones operativas de NC/anulación: no revierte stock, pagos ni saldos.
require('ts-node/register/transpile-only');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {ConfigService}=require('@nestjs/config'),{HttpService}=require('@nestjs/axios');
const {DatabaseService}=require('../src/database/database.service');
const {ComprobantesModel}=require('../src/modules/comprobantes/models/comprobantes.model');
const {ClientesModel}=require('../src/modules/clientes/models/clientes.model');
const {ComprobanteInvoiceMapper}=require('../src/modules/comprobantes/mappers/comprobante-invoice.mapper');
const {FacturacionCredentialsService}=require('../src/integrations/facturacion-electronica/facturacion-credentials.service');
const {FacturacionApisperuClient}=require('../src/integrations/facturacion-apisperu/facturacion-apisperu.client');
const {SunatValidezClient}=require('../src/integrations/facturacion-electronica/sunat-validez.client');
const {estadoDesdeCdr,cdrCorrespondeAlDocumento,mensajeErrorCpe}=require('../src/common/helpers/cpe-estado.helper');
const {hash,validarOrden,validarOriginal,validarPayload,validarNota,sinCdr}=require('./correccion-fiscal-guards.cjs');
const env=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
const config=new ConfigService({database:{url:env.DATABASE_URL}}),db=new DatabaseService(config);
const model=new ComprobantesModel(db,config),clientes=new ClientesModel(db),mapper=new ComprobanteInvoiceMapper();
const provider=new FacturacionApisperuClient(new HttpService(),new FacturacionCredentialsService(db,config)),sunat=new SunatValidezClient(db);
const loteId='6e066593-30f9-4730-ace0-47f40ede5227';
const folder=path.join(__dirname,'../../diagnosticos/reordenamiento-fiscal-20261012');
let empresa,lease,plan;
const log=value=>console.log(JSON.stringify(value));
const nombre=p=>`${p.serie}-${Number(p.numeroNuevo)}`;
const accepted=(data,serie,numero,fecha)=>estadoDesdeCdr(data)==='ACEPTADO'&&cdrCorrespondeAlDocumento(data,serie,String(numero),fecha,'0');
async function consultarStatus(query){
 for(let intento=1;intento<=3;intento++){
  try{return await provider.consultarEstadoFacturaBoleta(query);}
  catch(error){
   if(intento===3||!/servidor interno|tiempo de espera|502|503|504|timeout/i.test(error.message))throw error;
   log({fase:'REPETIR_CONSULTA_SOLO_LECTURA',documento:`${query.serie}-${query.numero}`,intento});
   await new Promise(resolve=>setTimeout(resolve,intento*1500));await heartbeat();
  }
 }
}
async function heartbeat(){
 const result=await db.query("UPDATE ven_cpe_operacion_control SET vencimiento=now()+interval '10 minutes' WHERE id_empresa=$1 AND token=$2 RETURNING token",[empresa.id,lease]);
 assert.equal(result.rowCount,1,'Se perdió el control exclusivo de emisión');
}
async function lote(){return (await db.query('SELECT * FROM ven_cpe_correccion_lote WHERE id=$1',[loteId])).rows[0];}
async function notas(){return (await db.query('SELECT * FROM ven_cpe_correccion_nota WHERE id_lote=$1 ORDER BY id',[loteId])).rows;}
async function actual(p){return (await db.query(`SELECT c.*,t.descripcion AS tipo,c.fecha::text AS fecha_venta,COALESCE(c.fecha_emision_cpe,c.fecha::date)::text AS fecha_fiscal
 FROM ven_comprobante c JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante WHERE c.id=$1`,[p.id])).rows[0];}
async function deps(){
 const ids=plan.map(p=>p.id);
 const rows=(await db.query(`SELECT DISTINCT c.id FROM ven_comprobante c JOIN doc_salida d ON d.estado=1
 AND (d.id_venta=c.id OR EXISTS(SELECT 1 FROM doc_salida_referencia r WHERE r.estado=1 AND r.id_doc_salida=d.id AND r.id_comprobante=c.id))
 WHERE c.id=ANY($1::int[]) AND (d.emitido_sunat OR NULLIF(TRIM(COALESCE(d.ticket_sunat,'')),'') IS NOT NULL
 OR EXISTS(SELECT 1 FROM doc_gre_intento i WHERE i.id_doc_salida=d.id AND i.estado<>'RECHAZADO'))`,[ids])).rows;
 assert.equal(rows.length,0,'Una GRE enviada referencia documentos del lote');
 const notes=(await db.query('SELECT id FROM ven_comprobante WHERE estado=1 AND id_comprobante_origen=ANY($1::int[])',[ids])).rows;
 assert.equal(notes.length,0,'Hay documentos derivados operativos; se requiere revisión');
 const summaries=(await db.query(`SELECT rd.id_comprobante FROM ven_resumen_diario_detalle rd JOIN ven_resumen_diario r ON r.id=rd.id_resumen
 LEFT JOIN gen_lista_opciones s ON s.id=r.id_estado_sunat
 WHERE rd.estado=1 AND r.estado=1 AND rd.id_comprobante=ANY($1::int[]) AND COALESCE(s.nombre,'')<>'RECHAZADO'`,[ids])).rows;
 assert.equal(summaries.length,0,'Hay un resumen diario no rechazado relacionado');
}
async function verificarOriginal(p){
 await heartbeat();const doc=await actual(p);validarOriginal(doc,p);
 const valid=await sunat.consultar(empresa.id,{tipo:doc.tipo,serie:p.serie,numero:p.numeroOriginal,fecha:p.fechaFiscal,total:p.total});
 const status=await consultarStatus({ruc:empresa.ruc,tipo:doc.tipo,serie:p.serie,numero:String(Number(p.numeroOriginal))});
 if(p.requiereNota){assert.equal(valid.codigo,'1',p.original+' no está aceptado');assert.ok(accepted(status,p.serie,p.numeroOriginal,p.fechaFiscal),'CDR original no corresponde: '+p.original);}
 else {assert.equal(valid.codigo,'0',p.original+' ahora tiene otro estado SUNAT');assert.ok(sinCdr(status),'Existe un resultado fiscal para '+p.original);}
 return {doc,valid,status};
}
async function payloadNuevo(p){
 const doc=await model.obtenerCompleto(p.id);assert.ok(doc.registro&&!doc.error);
 doc.registro.numero=p.numeroNuevo;doc.registro.fecha_emision_cpe=p.fechaFiscal;
 const cliente=(await clientes.obtenerPorId(doc.registro.id_cliente)).registro;assert.ok(cliente);
 const ubigeo=cliente.id_distrito?await model.obtenerCodigoUbigeoDistrito(cliente.id_distrito):'';
 const payload=mapper.mapComprobanteToInvoicePayload(doc,empresa,cliente,ubigeo);validarPayload(payload,p);return payload;
}
async function estado(){
 const l=await lote(),ns=await notas();
 const replacements=await db.query('SELECT serie,numero,estado,intentos FROM ven_cpe_correccion_reemplazo WHERE id_lote=$1 ORDER BY serie,numero',[loteId]);
 const report={fecha:new Date().toISOString(),lote:l.id,estado:l.estado,documentos:plan.length,
 notas:ns.map(n=>({id:n.id,original:`${n.serie_original}-${Number(n.numero_original)}`,nota:`${n.serie}-${n.numero}`,importe:Number(n.importe),estado:n.estado})),reemplazos:replacements.rows};
 fs.writeFileSync(path.join(folder,'ejecucion.json'),JSON.stringify(report,null,2));log(report);return report;
}
async function revisarYReservar(){
 const l=await lote();assert.ok(['DESCARTADO_SOLO_ORDEN_VENTAS','PREPARADO'].includes(l.estado),'El lote tiene una fase distinta');
 const ns=await notas();assert.equal(ns.length,6);
 const attempts=(await db.query('SELECT COUNT(*)::int AS n FROM ven_cpe_correccion_intento i JOIN ven_cpe_correccion_nota n ON n.id=i.id_nota WHERE n.id_lote=$1',[loteId])).rows[0].n;
 assert.equal(attempts,0,'Existen envíos de notas; no se regeneran sus payloads');
 await deps();validarOrden(plan);
 const revised=[];
 for(const p of plan){
  const evidence=await verificarOriginal(p);
  const proposed=await consultarStatus({ruc:empresa.ruc,tipo:evidence.doc.tipo,serie:p.serie,numero:String(Number(p.numeroNuevo))});
  assert.ok(sinCdr(proposed),'La referencia propuesta tiene evidencia externa: '+nombre(p));
  p.verificacion=evidence.valid;p.estadoProveedor=evidence.status;p.snapshot=evidence.doc;
  const payload=await payloadNuevo(p);revised.push({p,payload});
  log({fase:'REVISION',original:p.original,reemplazo:nombre(p),fechaVenta:p.fechaVenta,requiereNota:p.requiereNota,envios:0});
 }
 const notesPayload=[];
 for(const n of ns){
  await heartbeat();const p=plan.find(p=>p.id===n.id_comprobante_original);assert.ok(p?.requiereNota);
  const current=await consultarStatus({ruc:empresa.ruc,tipo:'07',serie:n.serie,numero:String(n.numero)});
  assert.ok(sinCdr(current),'La nota propuesta ya tiene resultado externo');
  const payload=structuredClone(n.payload);
  payload.codMotivo='10';
  payload.desMotivo='CORRECCION DE NUMERACION POR ERROR DE CORRELATIVOS EN EL SISTEMA Y REEMPLAZO DEL COMPROBANTE. LA VENTA SE MANTIENE VIGENTE.';
  validarNota(payload,n);assert.equal(payload.fechaEmision.slice(0,10),p.fechaFiscal);
  const xml=await provider.generarXmlNota(payload);assert.ok(xml.includes(`${n.serie}-${n.numero}`));
  notesPayload.push({n,payload,xml});
  fs.writeFileSync(path.join(folder,`${n.serie}-${n.numero}-revision.xml`),xml);
  fs.writeFileSync(path.join(folder,`${n.serie}-${n.numero}-revision.json`),JSON.stringify(payload,null,2));
 }
 // La reserva mantiene disponibles los números elegidos frente a nuevas ventas.
 await db.query(fs.readFileSync(path.join(__dirname,'../database_sql/migraciones/20261012_reservas_reordenamiento_fiscal.sql'),'utf8'));
 await db.withTransaction(async()=>{
  for(const serie of ['B002','F002']) await db.query('SELECT pg_advisory_xact_lock(872015,hashtext($1))',[serie]);
  for(const {p,payload} of revised){
   await db.query('SELECT id FROM ven_comprobante WHERE id=$1 FOR UPDATE',[p.id]);validarOriginal(await actual(p),p);
   const collision=(await db.query('SELECT id FROM ven_comprobante WHERE serie=$1 AND numero::numeric=$2',[p.serie,Number(p.numeroNuevo)])).rows;
   assert.equal(collision.length,0,'Colisión local en '+nombre(p));
   await db.query(`INSERT INTO ven_cpe_correccion_reserva(serie,numero,id_lote,id_comprobante) VALUES($1,$2,$3,$4)
     ON CONFLICT(serie,numero) DO NOTHING`,[p.serie,Number(p.numeroNuevo),loteId,p.id]);
   const reservation=(await db.query('SELECT id_lote,id_comprobante FROM ven_cpe_correccion_reserva WHERE serie=$1 AND numero=$2',[p.serie,Number(p.numeroNuevo)])).rows[0];
   assert.equal(reservation.id_lote,loteId);assert.equal(reservation.id_comprobante,p.id);
   await db.query(`INSERT INTO ven_cpe_correccion_reemplazo(id_lote,id_comprobante,serie,numero,payload) VALUES($1,$2,$3,$4,$5::jsonb)
     ON CONFLICT(id_lote,id_comprobante) DO UPDATE SET payload=EXCLUDED.payload,actualizado_en=NOW()
     WHERE ven_cpe_correccion_reemplazo.intentos=0`,[loteId,p.id,p.serie,p.numeroNuevo,JSON.stringify(payload)]);
  }
  for(const {n,payload,xml} of notesPayload) await db.query(`UPDATE ven_cpe_correccion_nota SET estado='PREPARADO',payload=$2::jsonb,xml_firmado=$3,
   verificacion_original=$4::jsonb,actualizado_en=NOW() WHERE id=$1 AND estado IN ('PREPARADO','DESCARTADO_NO_EMITIDO')`,[n.id,JSON.stringify(payload),xml,JSON.stringify(plan.find(p=>p.id===n.id_comprobante_original).verificacion)]);
  await db.query(`UPDATE ven_cpe_correccion_lote SET estado='PREPARADO',motivo=$2,plan=$3::jsonb,actualizado_en=NOW() WHERE id=$1`,
   [loteId,'Usuario reiteró expresamente NC total a seis CPE aceptados por error de correlativos y reemplazo cronológico conservando ventas. Motivo NC10: otros conceptos, detalle explícito de corrección de numeración.',JSON.stringify(plan)]);
 });
 fs.writeFileSync(path.join(folder,'lote-reactivado.json'),JSON.stringify({loteId,preparadoEn:new Date().toISOString(),plan},null,2));
 await estado();
}
async function guardarNota(n,response){
 const p=plan.find(p=>p.id===n.id_comprobante_original);
 const status=accepted(response,n.serie,n.numero,p.fechaFiscal)?'ACEPTADO':estadoDesdeCdr(response)==='RECHAZADO'&&cdrCorrespondeAlDocumento(response,n.serie,String(n.numero),p.fechaFiscal)?'RECHAZADO':'POR_CONFIRMAR';
 await db.query(`UPDATE ven_cpe_correccion_nota SET estado=$2,cdr_respuesta=$3::jsonb,xml_firmado=COALESCE($4,xml_firmado),hash_documento=COALESCE($5,hash_documento),actualizado_en=NOW() WHERE id=$1`,
 [n.id,status,JSON.stringify(response),response.xml??null,response.hash??null]);
 fs.writeFileSync(path.join(folder,`${n.serie}-${n.numero}-respuesta.json`),JSON.stringify(response,null,2));
 return status;
}
async function enviarNotas(){
 assert.ok(['PREPARADO','NOTAS_EN_CURSO','NOTAS_POR_CONFIRMAR'].includes((await lote()).estado),'Lote no listo para emitir notas');
 await deps();
 // Los 48 originales fueron consultados al reservar; se verifica identidad
 // local y se vuelve a consultar cada original aceptado justo antes de su NC.
 for(const p of plan)validarOriginal(await actual(p),p);
 await db.query("UPDATE ven_cpe_correccion_lote SET estado='NOTAS_EN_CURSO',actualizado_en=NOW() WHERE id=$1",[loteId]);
 for(const n of await notas()){
  await heartbeat();const p=plan.find(p=>p.id===n.id_comprobante_original);validarNota(n.payload,n);
  const current=await consultarStatus({ruc:empresa.ruc,tipo:'07',serie:n.serie,numero:String(n.numero)});
  if(accepted(current,n.serie,n.numero,p.fechaFiscal)){await guardarNota(n,current);log({nota:`${n.serie}-${n.numero}`,estado:'ACEPTADO',nuevoEnvio:false});continue;}
  const count=(await db.query('SELECT COUNT(*)::int AS n FROM ven_cpe_correccion_intento WHERE id_nota=$1',[n.id])).rows[0].n;
  assert.equal(count,0,'La nota '+n.serie+'-'+n.numero+' tuvo un envío sin aceptación confirmada. No se vuelve a enviar automáticamente.');
  assert.ok(sinCdr(current),'No está disponible la referencia de nota');
  await verificarOriginal(p);
  const attempt=await db.withTransaction(async()=>{
   const row=(await db.query('SELECT estado FROM ven_cpe_correccion_nota WHERE id=$1 FOR UPDATE',[n.id])).rows[0];assert.equal(row.estado,'PREPARADO');
   await db.query("UPDATE ven_cpe_correccion_nota SET estado='EN_CURSO',actualizado_en=NOW() WHERE id=$1",[n.id]);
   return (await db.query('INSERT INTO ven_cpe_correccion_intento(id_nota) VALUES($1) RETURNING id',[n.id])).rows[0].id;
  });
  let response;
  try{response=await provider.enviarNota(n.payload);}
  catch(error){response={error:{code:'TRANSPORTE',message:mensajeErrorCpe(error.message)},resultado:'SIN_CONFIRMACION'};}
  await db.query('UPDATE ven_cpe_correccion_intento SET terminado_en=NOW(),resultado=$2::jsonb WHERE id=$1',[attempt,JSON.stringify(response)]);
  let status=await guardarNota(n,response);
  if(status==='POR_CONFIRMAR'){
   try{const check=await consultarStatus({ruc:empresa.ruc,tipo:'07',serie:n.serie,numero:String(n.numero)});
    if(accepted(check,n.serie,n.numero,p.fechaFiscal))status=await guardarNota(n,check);
   }catch{} // La respuesta de transporte ya quedó preservada; no se reenvía.
  }
  log({original:p.original,nota:`${n.serie}-${n.numero}`,importe:Number(n.importe),estado:status});
  if(status!=='ACEPTADO'){
   await db.query("UPDATE ven_cpe_correccion_lote SET estado='NOTAS_POR_CONFIRMAR',actualizado_en=NOW() WHERE id=$1",[loteId]);
   throw new Error('Se detuvo el lote: '+n.serie+'-'+n.numero+' quedó '+status+'. No se renumeraron ventas.');
  }
 }
 assert.ok((await notas()).every(n=>n.estado==='ACEPTADO'));
 await db.query("UPDATE ven_cpe_correccion_lote SET estado='NOTAS_ACEPTADAS',actualizado_en=NOW() WHERE id=$1",[loteId]);
 await estado();
}
async function economico(){
 const ids=plan.map(p=>p.id),out={};
 const queries={
  ventas:`SELECT to_jsonb(c)-ARRAY['serie','numero','id_estado_sunat','fecha_emision_cpe','ticket_sunat','hash_documento','xml_firmado','cdr_respuesta','validez_sunat','cpe_verificacion','id_usuario_modificacion','fecha_modificacion'] AS dato FROM ven_comprobante c WHERE id=ANY($1::int[]) ORDER BY id`,
  lineas:'SELECT to_jsonb(c) AS dato FROM ven_comprobante_detalle c WHERE id_comprobante=ANY($1::int[]) ORDER BY id',
  cuotas:'SELECT to_jsonb(c) AS dato FROM ven_cuotas c WHERE id_comprobante=ANY($1::int[]) ORDER BY id',
  cuentas:`SELECT to_jsonb(c)-ARRAY['numero_comprobante','descripcion','id_usuario_modificacion','fecha_modificacion'] AS dato FROM fin_cuenta c WHERE id_comprobante_venta=ANY($1::int[]) ORDER BY id`,
  pagos:'SELECT to_jsonb(p) AS dato FROM fin_pago p WHERE id_cuenta IN (SELECT id FROM fin_cuenta WHERE id_comprobante_venta=ANY($1::int[])) ORDER BY id',
  movimientos:'SELECT to_jsonb(c) AS dato FROM inv_movimiento c WHERE id_documento_origen=ANY($1::int[]) ORDER BY id',
  bajas:`SELECT to_jsonb(c)-ARRAY['serie_comprobante','numero_comprobante','id_usuario_modificacion','fecha_modificacion'] AS dato FROM bal_baja_balon c WHERE id_comprobante_venta=ANY($1::int[]) ORDER BY id`,
  recargas:`SELECT to_jsonb(c)-ARRAY['serie_factura','numero_factura','id_usuario_modificacion','fecha_modificacion'] AS dato FROM bal_movimiento_recarga c WHERE id_comprobante=ANY($1::int[]) ORDER BY id`
 };
 for(const [key,sql] of Object.entries(queries))out[key]=(await db.query(sql,[ids])).rows;
 return out;
}
async function renumerar(probar=false){
 const current=await lote();if(current.estado==='RENUMERADO'&&!probar)return estado();
 const simulacionPrevia=probar&&current.estado==='PREPARADO';
 if(!simulacionPrevia)assert.equal(current.estado,'NOTAS_ACEPTADAS','No se renumera hasta confirmar las seis NC');
 const ns=await notas();assert.equal(ns.length,6);
 if(!simulacionPrevia)assert.ok(ns.every(n=>n.estado==='ACEPTADO'));
 for(const n of simulacionPrevia?[]:ns){await heartbeat();const p=plan.find(p=>p.id===n.id_comprobante_original);
  const status=await consultarStatus({ruc:empresa.ruc,tipo:'07',serie:n.serie,numero:String(n.numero)});
  assert.ok(accepted(status,n.serie,n.numero,p.fechaFiscal),'Una nota dejó de tener aceptación confirmada');
 }
 await deps();validarOrden(plan);
 if(!probar)for(const p of plan){const proof=await verificarOriginal(p);p.verificacion=proof.valid;p.estadoProveedor=proof.status;}
 const ids=plan.map(p=>p.id);let proof;
 try{await db.withTransaction(async()=>{
  for(const serie of ['B002','F002']) await db.query('SELECT pg_advisory_xact_lock(872015,hashtext($1))',[serie]);
  await db.query('SELECT id FROM ven_comprobante WHERE id=ANY($1::int[]) ORDER BY id FOR UPDATE',[ids]);
  await db.query('SELECT id FROM fin_cuenta WHERE id_comprobante_venta=ANY($1::int[]) ORDER BY id FOR UPDATE',[ids]);
  const before=await economico();
  const pendiente=await model.resolverIdEstadoSunat('PENDIENTE');assert.ok(pendiente);
  for(const p of plan){
   const doc=await actual(p);validarOriginal(doc,p);
   const collision=(await db.query('SELECT id FROM ven_comprobante WHERE serie=$1 AND numero::numeric=$2',[p.serie,Number(p.numeroNuevo)])).rows;assert.equal(collision.length,0);
   const note=ns.find(n=>n.id_comprobante_original===p.id);
   await db.query(`INSERT INTO ven_comprobante_historial_cpe(id_comprobante,serie,numero,datos_originales,verificacion_sunat,serie_nueva,numero_nuevo,fecha_emision_nueva)
    VALUES($1,$2,$3,$4::jsonb,$5::jsonb,$2,$6,$7)`,[p.id,p.serie,p.numeroOriginal,JSON.stringify(doc),JSON.stringify({validez:p.verificacion,proveedor:p.estadoProveedor,lote:loteId,notaFiscal:note?{serie:note.serie,numero:note.numero,importe:note.importe,cdr:note.cdr_respuesta}:null}),p.numeroNuevo,p.fechaFiscal]);
   const oldFull=`${p.serie}-${p.numeroOriginal}`,newFull=`${p.serie}-${p.numeroNuevo}`;
   await db.query('UPDATE doc_salida_referencia SET serie=$2,numero=$3,fecha=$4,fecha_modificacion=NOW() WHERE id_comprobante=$1',[p.id,p.serie,p.numeroNuevo,p.fechaFiscal]);
   await db.query('UPDATE doc_salida SET observaciones=replace(observaciones,$2,$3),fecha_modificacion=NOW() WHERE id_venta=$1 AND estado=1 AND observaciones LIKE $4',[p.id,oldFull,newFull,'%'+oldFull+'%']);
   await db.query('UPDATE fin_cuenta SET numero_comprobante=CASE WHEN numero_comprobante IS NULL THEN NULL ELSE $2 END,descripcion=replace(descripcion,$3,$2),fecha_modificacion=NOW() WHERE id_comprobante_venta=$1',[p.id,newFull,oldFull]);
   await db.query('UPDATE bal_baja_balon SET serie_comprobante=$2,numero_comprobante=$3,fecha_modificacion=NOW() WHERE id_comprobante_venta=$1',[p.id,p.serie,p.numeroNuevo]);
   await db.query('UPDATE bal_movimiento_recarga SET serie_factura=$2,numero_factura=$3,fecha_modificacion=NOW() WHERE id_comprobante=$1 AND serie_factura IS NOT NULL',[p.id,p.serie,p.numeroNuevo]);
   await db.query(`UPDATE ven_comprobante SET numero=$2,fecha_emision_cpe=$3,id_estado_sunat=$4,ticket_sunat=NULL,hash_documento=NULL,
    xml_firmado=NULL,cdr_respuesta=NULL,validez_sunat=NULL,cpe_verificacion=NULL,fecha_modificacion=NOW() WHERE id=$1`,[p.id,p.numeroNuevo,p.fechaFiscal,pendiente]);
  }
  const after=await economico();assert.equal(hash(before),hash(after),'Cambió algún dato económico; se revierte toda la transacción');
  proof={probadoEn:new Date().toISOString(),rollback:probar,simulacionPrevia,ventas:48,huellaAntes:hash(before),huellaDespues:hash(after),cambiosEconomicos:0};
  await db.query("UPDATE ven_cpe_correccion_lote SET estado='RENUMERADO',plan=$2::jsonb,actualizado_en=NOW() WHERE id=$1",[loteId,JSON.stringify(plan)]);
  if(probar)throw new Error('ROLLBACK_VERIFICADO');
 });}catch(error){if(!probar||error.message!=='ROLLBACK_VERIFICADO')throw error;}
 fs.writeFileSync(path.join(folder,probar?'prueba-transaccion.json':'renumeracion-aplicada.json'),JSON.stringify(proof,null,2));log(proof);await estado();
}
async function guardarReemplazo(p,response){
 const status=accepted(response,p.serie,p.numeroNuevo,p.fechaFiscal)?'ACEPTADO':estadoDesdeCdr(response)==='RECHAZADO'&&cdrCorrespondeAlDocumento(response,p.serie,p.numeroNuevo,p.fechaFiscal)?'RECHAZADO':'POR_CONFIRMAR';
 await db.withTransaction(async()=>{
  const idEstado=await model.resolverIdEstadoSunat(status==='POR_CONFIRMAR'?'PENDIENTE':status);
  const saved=await model.registrarRespuestaSunat(p.id,{idEstadoSunat:idEstado,hashDocumento:response.hash,xmlFirmado:response.xml,
   cdrRespuesta:JSON.stringify(status==='POR_CONFIRMAR'?{tipo:'emision_por_confirmar',fase:'SIN_RESPUESTA',fecha:new Date().toISOString(),sunatResponse:response.sunatResponse??response}:response.sunatResponse??response)},true);
  if(saved.error)throw new Error(saved.error);
  await db.query('UPDATE ven_cpe_correccion_reemplazo SET estado=$3,respuesta=$4::jsonb,xml_firmado=COALESCE($5,xml_firmado),actualizado_en=NOW() WHERE id_lote=$1 AND id_comprobante=$2',[loteId,p.id,status,JSON.stringify(response),response.xml??null]);
 });
 fs.writeFileSync(path.join(folder,`${nombre(p)}-respuesta.json`),JSON.stringify(response,null,2));return status;
}
async function emitirReemplazos(){
 assert.ok(['RENUMERADO','REEMPLAZOS_EN_CURSO','REEMPLAZOS_POR_CONFIRMAR'].includes((await lote()).estado));validarOrden(plan);
 await db.query("UPDATE ven_cpe_correccion_lote SET estado='REEMPLAZOS_EN_CURSO',actualizado_en=NOW() WHERE id=$1",[loteId]);
 for(const p of plan){
  await heartbeat();const doc=await actual(p);assert.equal(doc.serie,p.serie);assert.equal(doc.numero,p.numeroNuevo);assert.equal(Number(doc.total_importe),p.total);
  const r=(await db.query('SELECT * FROM ven_cpe_correccion_reemplazo WHERE id_lote=$1 AND id_comprobante=$2',[loteId,p.id])).rows[0];validarPayload(r.payload,p);
  const status=await consultarStatus({ruc:empresa.ruc,tipo:doc.tipo,serie:p.serie,numero:String(Number(p.numeroNuevo))});
  if(accepted(status,p.serie,p.numeroNuevo,p.fechaFiscal)){await guardarReemplazo(p,status);log({reemplazo:nombre(p),estado:'ACEPTADO',nuevoEnvio:false});continue;}
  assert.equal(r.intentos,0,'El reemplazo '+nombre(p)+' ya tuvo un envío sin aceptación confirmada. No se reenvía automáticamente.');assert.ok(sinCdr(status));
  const valid=await sunat.consultar(empresa.id,{tipo:doc.tipo,serie:p.serie,numero:p.numeroNuevo,fecha:p.fechaFiscal,total:p.total});assert.equal(valid.codigo,'0');
  const currentPayload=await payloadNuevo(p);assert.equal(hash(currentPayload),hash(r.payload),'Cambió el contenido de la venta');
  const xml=await provider.generarXmlFacturaBoleta(r.payload);assert.ok(xml.includes(nombre(p)));
  if(r.payload.formaPago?.tipo==='Credito'){
   assert.ok(r.payload.cuotas?.length>0,'La factura al crédito debe declarar cuotas en la raíz');
   assert.ok(/<cbc:PaymentMeansID>Cuota001<\/cbc:PaymentMeansID>/.test(xml),'El XML firmado no contiene cuotas; no se envía');
  }
  await db.withTransaction(async()=>{
   await db.query('SELECT id FROM ven_comprobante WHERE id=$1 FOR UPDATE',[p.id]);const now=await actual(p);assert.equal(now.numero,p.numeroNuevo);assert.equal(Number(now.total_importe),p.total);
   const count=await db.query(`UPDATE ven_cpe_correccion_reemplazo SET estado='EN_CURSO',intentos=intentos+1,xml_firmado=$3,actualizado_en=NOW()
     WHERE id_lote=$1 AND id_comprobante=$2 AND intentos=0 RETURNING id_comprobante`,[loteId,p.id,xml]);assert.equal(count.rowCount,1);
   await model.registrarRespuestaSunat(p.id,{xmlFirmado:xml,cdrRespuesta:JSON.stringify({tipo:'emision_por_confirmar',fase:'ENVIANDO',fecha:new Date().toISOString(),lote:loteId})},true);
  });
  let response;
  try{response=await provider.enviarFacturaBoleta(r.payload);}
  catch(error){response={error:{code:'TRANSPORTE',message:mensajeErrorCpe(error.message)},resultado:'SIN_CONFIRMACION'};}
  let result=await guardarReemplazo(p,response);
  if(result==='POR_CONFIRMAR')try{const check=await consultarStatus({ruc:empresa.ruc,tipo:doc.tipo,serie:p.serie,numero:String(Number(p.numeroNuevo))});
   if(accepted(check,p.serie,p.numeroNuevo,p.fechaFiscal))result=await guardarReemplazo(p,check);
  }catch{}
  log({original:p.original,reemplazo:nombre(p),fechaVenta:p.fechaVenta,importe:p.total,estado:result});
  if(result!=='ACEPTADO'){
   await db.query('UPDATE ven_cpe_correccion_lote SET estado=$2,actualizado_en=NOW() WHERE id=$1',[loteId,result==='RECHAZADO'?'REEMPLAZOS_RECHAZADOS':'REEMPLAZOS_POR_CONFIRMAR']);
   throw new Error('Se detuvo la emisión cronológica en '+nombre(p)+': '+result+'. No se enviaron los documentos posteriores.');
  }
 }
 await db.query("UPDATE ven_cpe_correccion_lote SET estado='COMPLETADO',actualizado_en=NOW() WHERE id=$1",[loteId]);await estado();
}
async function corregirCreditoYAvanzar(){
 assert.ok(['REEMPLAZOS_POR_CONFIRMAR','REEMPLAZOS_RECHAZADOS'].includes((await lote()).estado));
 const prior=(await db.query('SELECT * FROM ven_cpe_correccion_reemplazo WHERE id_lote=$1 ORDER BY id_comprobante',[loteId])).rows;
 const rejected=prior.filter(r=>r.intentos>0);assert.equal(rejected.length,1,'El salto solo aplica al primer rechazo confirmado');
 const first=rejected[0],pfirst=plan.find(p=>p.id===first.id_comprobante);
 assert.equal(first.estado,'RECHAZADO');assert.equal(first.serie,'F002');assert.equal(Number(first.numero),23);
 assert.equal(estadoDesdeCdr(first.respuesta),'RECHAZADO');
 assert.ok(cdrCorrespondeAlDocumento(first.respuesta,first.serie,first.numero,pfirst.fechaFiscal,'3249'),'La respuesta archivada no prueba el rechazo 3249');
 const check=await consultarStatus({ruc:empresa.ruc,tipo:'01',serie:first.serie,numero:String(Number(first.numero))});
 // SUNAT puede no devolver CDR en getStatusCdr para un documento rechazado.
 // La constancia real del envío está archivada y se valida antes del salto.
 assert.ok(sinCdr(check)||(estadoDesdeCdr(check)==='RECHAZADO'&&cdrCorrespondeAlDocumento(check,first.serie,first.numero,pfirst.fechaFiscal,'3249')),'El estado posterior contradice el rechazo archivado');
 assert.ok(prior.filter(r=>r.id_comprobante!==first.id_comprobante).every(r=>r.intentos===0&&r.estado==='PREPARADO'),'Otro documento ya se envió');
 await deps();
 const beforePlan=structuredClone(plan);
 const last=(await db.query(`SELECT GREATEST(
  COALESCE((SELECT MAX(numero::numeric) FROM ven_comprobante WHERE serie='F002' AND numero~'^[0-9]+$'),0),
  COALESCE((SELECT MAX(numero::numeric) FROM ven_comprobante_historial_cpe WHERE serie='F002' AND numero~'^[0-9]+$'),0),
  COALESCE((SELECT MAX(numero) FROM ven_cpe_correccion_reserva WHERE serie='F002'),0))::int AS ultimo`)).rows[0].ultimo;
 let next=last+1;
 const refreshed=[];
 for(const p of plan){
  await heartbeat();const doc=await actual(p);assert.equal(doc.numero,p.numeroNuevo);assert.equal(Number(doc.total_importe),p.total);
  const old=prior.find(r=>r.id_comprobante===p.id);assert.ok(old);
  p.numeroPrevio=p.numeroNuevo;
  if(p.serie==='F002'){
   p.numeroNuevo=String(next++).padStart(8,'0');p.propuesto=nombre(p);
   const available=await consultarStatus({ruc:empresa.ruc,tipo:'01',serie:p.serie,numero:String(Number(p.numeroNuevo))});assert.ok(sinCdr(available),'Referencia no disponible: '+nombre(p));
  }
  const payload=await payloadNuevo(p);
  // El cambio del esquema no cambia ni un importe ni una fecha de cuota.
  const legacy=old.payload.formaPago;
  if(legacy?.tipo==='Credito'){
   assert.equal(payload.formaPago.tipo,'Credito');assert.equal(payload.cuotas.length,legacy.cuotas.length);
   for(let i=0;i<payload.cuotas.length;i++){
    assert.equal(payload.cuotas[i].monto,legacy.cuotas[i].monto);
    assert.equal(payload.cuotas[i].fechaPago.slice(0,10),legacy.cuotas[i].fechaPago.slice(0,10));
   }
   const xml=await provider.generarXmlFacturaBoleta(payload);
   assert.ok(/<cbc:PaymentMeansID>Cuota001<\/cbc:PaymentMeansID>/.test(xml),'El XML aún no incluye la cuota requerida');
   fs.writeFileSync(path.join(folder,`${nombre(p)}-cuotas-corregidas.xml`),xml);
  }
  refreshed.push({p,doc,payload,old});
  log({fase:'CORRECCION_CUOTAS',previo:`${p.serie}-${Number(p.numeroPrevio)}`,propuesto:nombre(p),credito:payload.formaPago.tipo==='Credito'});
 }
 validarOrden(plan);const ids=plan.map(p=>p.id);let invariant;
 await db.withTransaction(async()=>{
  await db.query("SELECT pg_advisory_xact_lock(872015,hashtext('F002'))");
  await db.query('SELECT id FROM ven_comprobante WHERE id=ANY($1::int[]) ORDER BY id FOR UPDATE',[ids]);
  await db.query('SELECT id FROM fin_cuenta WHERE id_comprobante_venta=ANY($1::int[]) ORDER BY id FOR UPDATE',[ids]);
  await db.query('SELECT id FROM doc_salida WHERE id_venta=ANY($1::int[]) ORDER BY id FOR UPDATE',[ids]);
  await deps();const before=await economico();
  const pendiente=await model.resolverIdEstadoSunat('PENDIENTE');assert.ok(pendiente);
  for(const {p,doc,payload,old} of refreshed){
   const current=await actual(p);assert.equal(current.numero,p.numeroPrevio);assert.equal(Number(current.total_importe),p.total);
   if(p.serie==='F002'){
    assert.equal((await db.query('SELECT id FROM ven_comprobante WHERE serie=$1 AND numero::numeric=$2',[p.serie,Number(p.numeroNuevo)])).rowCount,0);
    await db.query(`INSERT INTO ven_comprobante_historial_cpe(id_comprobante,serie,numero,datos_originales,verificacion_sunat,serie_nueva,numero_nuevo,fecha_emision_nueva)
     VALUES($1,$2,$3,$4::jsonb,$5::jsonb,$2,$6,$7)`,[p.id,p.serie,p.numeroPrevio,JSON.stringify({...doc,intento_correccion:old}),
     JSON.stringify({lote:loteId,motivo:'Salto de rango por rechazo 3249 del primer correlativo. Los siguientes aún no fueron enviados.',rechazo:first.respuesta}),p.numeroNuevo,p.fechaFiscal]);
    await db.query('UPDATE ven_cpe_correccion_reserva SET numero=$3 WHERE id_lote=$1 AND id_comprobante=$2',[loteId,p.id,Number(p.numeroNuevo)]);
    const beforeRef=`${p.serie}-${p.numeroPrevio}`,afterRef=`${p.serie}-${p.numeroNuevo}`;
    await db.query('UPDATE doc_salida_referencia SET numero=$2,fecha=$3,fecha_modificacion=NOW() WHERE id_comprobante=$1',[p.id,p.numeroNuevo,p.fechaFiscal]);
    await db.query('UPDATE doc_salida SET observaciones=replace(observaciones,$2,$3),fecha_modificacion=NOW() WHERE id_venta=$1 AND estado=1 AND observaciones LIKE $4',[p.id,beforeRef,afterRef,'%'+beforeRef+'%']);
    await db.query('UPDATE fin_cuenta SET numero_comprobante=CASE WHEN numero_comprobante IS NULL THEN NULL ELSE $2 END,descripcion=replace(descripcion,$3,$2),fecha_modificacion=NOW() WHERE id_comprobante_venta=$1',[p.id,afterRef,beforeRef]);
    await db.query('UPDATE bal_baja_balon SET numero_comprobante=$2,fecha_modificacion=NOW() WHERE id_comprobante_venta=$1',[p.id,p.numeroNuevo]);
    await db.query('UPDATE bal_movimiento_recarga SET numero_factura=$2,fecha_modificacion=NOW() WHERE id_comprobante=$1 AND serie_factura IS NOT NULL',[p.id,p.numeroNuevo]);
    await db.query(`UPDATE ven_comprobante SET numero=$2,id_estado_sunat=$3,xml_firmado=NULL,hash_documento=NULL,cdr_respuesta=NULL,ticket_sunat=NULL,
     validez_sunat=NULL,cpe_verificacion=NULL,fecha_modificacion=NOW() WHERE id=$1`,[p.id,p.numeroNuevo,pendiente]);
   }else{
    await db.query('UPDATE doc_salida_referencia SET fecha=$2,fecha_modificacion=NOW() WHERE id_comprobante=$1 AND fecha IS DISTINCT FROM $2::date',[p.id,p.fechaFiscal]);
   }
   await db.query(`UPDATE ven_cpe_correccion_reemplazo SET numero=$3,payload=$4::jsonb,estado='PREPARADO',intentos=0,respuesta=NULL,xml_firmado=NULL,actualizado_en=NOW()
    WHERE id_lote=$1 AND id_comprobante=$2`,[loteId,p.id,p.numeroNuevo,JSON.stringify(payload)]);
  }
  const after=await economico();assert.equal(hash(before),hash(after),'Cambió un dato económico o una cuota; se revierte todo');
  invariant={fecha:new Date().toISOString(),antes:hash(before),despues:hash(after),cambiosEconomicos:0,rechazoArchivado:'F002-23 / 3249',primeraFactura:plan.find(p=>p.serie==='F002').propuesto,ultimaFactura:plan.filter(p=>p.serie==='F002').at(-1).propuesto};
  await db.query("UPDATE ven_cpe_correccion_lote SET estado='RENUMERADO',plan=$2::jsonb,actualizado_en=NOW() WHERE id=$1",[loteId,JSON.stringify(plan)]);
 });
 fs.writeFileSync(path.join(folder,'correccion-cuotas-y-rango.json'),JSON.stringify({invariant,planAnterior:beforePlan,plan},null,2));log(invariant);await estado();
}
async function exportarNotas(){
 const out=path.join(folder,'notas-aceptadas');fs.mkdirSync(out,{recursive:true});
 const exported=[];
 for(const n of await notas()){
  if(n.estado!=='ACEPTADO')continue;
  const ref=`${n.serie}-${n.numero}`,p=plan.find(p=>p.id===n.id_comprobante_original);
  assert.ok(accepted(n.cdr_respuesta,n.serie,n.numero,p.fechaFiscal),'No se exporta una aceptación sin CDR coincidente');
  const data=n.cdr_respuesta.sunatResponse??n.cdr_respuesta;
  fs.writeFileSync(path.join(out,`${ref}-CDR.zip`),Buffer.from(data.cdrZip,'base64'));
  if(n.xml_firmado)fs.writeFileSync(path.join(out,`${ref}.xml`),n.xml_firmado);
  const pdf=await provider.generarPdfNota(n.payload);assert.equal(pdf.subarray(0,4).toString(),'%PDF');
  fs.writeFileSync(path.join(out,`${ref}.pdf`),pdf);
  exported.push({nota:ref,original:p.original,reemplazo:nombre(p),importe:Number(n.importe),pdf:`${ref}.pdf`,estado:n.estado});
  log({fase:'EXPORTACION',nota:ref,pdf:true,xml:!!n.xml_firmado,cdr:true});
 }
 fs.writeFileSync(path.join(out,'indice.json'),JSON.stringify(exported,null,2));
}
async function protegerNumeracion(){
 await db.query(fs.readFileSync(path.join(__dirname,'../database_sql/migraciones/20261012_bloqueo_numeracion_entregada.sql'),'utf8'));
 await db.withTransaction(async()=>{
  const l=(await db.query('SELECT * FROM ven_cpe_correccion_lote WHERE id=$1 FOR UPDATE',[loteId])).rows[0];
  assert.ok(['RENUMERADO','REEMPLAZOS_EN_CURSO','REEMPLAZOS_POR_CONFIRMAR','REEMPLAZOS_RECHAZADOS','COMPLETADO'].includes(l.estado));
  for(const p of l.plan){const doc=await actual(p);assert.equal(doc.serie,p.serie);assert.equal(doc.numero,p.numeroNuevo);}
  await db.query(`UPDATE ven_cpe_correccion_lote SET numeracion_bloqueada=true,numeracion_bloqueada_en=COALESCE(numeracion_bloqueada_en,NOW()),
   motivo_bloqueo='Usuario indicó que los clientes empezarán a usar los documentos y prohibió volver a alterar sus correlativos.',actualizado_en=NOW() WHERE id=$1`,[loteId]);
 });
 let denied=0;const notaId=(await notas())[0].id;
 for(const attempt of [
  ()=>db.query("UPDATE ven_comprobante SET numero='99999998' WHERE id=$1",[plan[0].id]),
  ()=>db.query('UPDATE ven_cpe_correccion_nota SET numero=99999998 WHERE id=$1',[notaId])
 ]){
  try{await db.withTransaction(async()=>{await attempt();throw new Error('La protección no bloqueó el cambio; transacción revertida');});}
  catch(error){if(error.code!=='23514')throw error;denied++;}
 }
 const result={fecha:new Date().toISOString(),lote:loteId,comprobantesBloqueados:48,notasProtegidas:6,pruebasDeRenumeracionBloqueadas:denied,
  primeraFactura:plan.find(p=>p.serie==='F002').propuesto,ultimaFactura:plan.filter(p=>p.serie==='F002').at(-1).propuesto,
  primeraBoleta:plan.find(p=>p.serie==='B002').propuesto,ultimaBoleta:plan.filter(p=>p.serie==='B002').at(-1).propuesto};
 fs.writeFileSync(path.join(folder,'numeracion-bloqueada.json'),JSON.stringify(result,null,2));log(result);
}
async function verificarFinal(){
 const l=await lote();assert.equal(l.estado,'COMPLETADO');assert.equal(l.numeracion_bloqueada,true);validarOrden(plan);
 const ids=plan.map(p=>p.id);
 const docs=(await db.query(`SELECT c.*,s.nombre AS estado_sunat,c.fecha::text AS fecha_venta,
  COALESCE(c.fecha_emision_cpe,c.fecha::date)::text AS fecha_fiscal FROM ven_comprobante c
  JOIN gen_lista_opciones s ON s.id=c.id_estado_sunat WHERE c.id=ANY($1::int[]) ORDER BY c.fecha,c.id`,[ids])).rows;
 assert.equal(docs.length,48);
 for(const doc of docs){
  const p=plan.find(p=>p.id===doc.id);assert.equal(doc.serie,p.serie);assert.equal(doc.numero,p.numeroNuevo);
  assert.equal(doc.fecha_venta,p.fechaVenta);assert.equal(doc.fecha_fiscal,p.fechaFiscal);assert.equal(Number(doc.total_importe),p.total);
  assert.equal(doc.estado_sunat,'ACEPTADO');assert.ok(accepted(JSON.parse(doc.cdr_respuesta),doc.serie,doc.numero,doc.fecha_fiscal));
 }
 const ns=await notas();assert.equal(ns.length,6);
 for(const n of ns){const p=plan.find(p=>p.id===n.id_comprobante_original);assert.equal(n.estado,'ACEPTADO');assert.ok(accepted(n.cdr_respuesta,n.serie,n.numero,p.fechaFiscal));}
 const proof=JSON.parse(fs.readFileSync(path.join(folder,'correccion-cuotas-y-rango.json'),'utf8')).invariant;
 const actualEconomico=hash(await economico());assert.equal(actualEconomico,proof.despues,'Cambió algún dato económico desde la corrección; revisar antes de afirmar conservación íntegra');
 const siguientes={};
 for(const serie of ['F002','B002']){
  const doc=docs.find(d=>d.serie===serie);
  siguientes[serie]=await db.callFunctionJson('ven_obtener_siguiente_numero',[doc.id_tipo_comprobante,serie]);
 }
 const result={verificadoEn:new Date().toISOString(),lote:loteId,estado:l.estado,comprobantesAceptados:48,facturas:22,boletas:26,
  notasAceptadas:6,importeNotas:ns.reduce((sum,n)=>sum+Number(n.importe),0),totalVentas:plan.reduce((sum,p)=>sum+p.total,0),
  numeracionBloqueada:true,datosEconomicosConservados:true,siguientes};
 fs.writeFileSync(path.join(folder,'verificacion-final.json'),JSON.stringify(result,null,2));
 const notesIndex=ns.map(n=>({nota:`${n.serie}-${n.numero}`,original:`${n.serie_original}-${Number(n.numero_original)}`,reemplazo:nombre(plan.find(p=>p.id===n.id_comprobante_original)),importe:Number(n.importe),pdf:`${n.serie}-${n.numero}.pdf`,estado:n.estado}));
 fs.writeFileSync(path.join(folder,'notas-aceptadas/indice.json'),JSON.stringify(notesIndex,null,2));
 const csv=['id_venta,fecha_venta,fecha_fiscal,tipo,original,reemplazo,importe,estado'];
 for(const p of plan)csv.push([p.id,p.fechaVenta,p.fechaFiscal,p.serie.startsWith('F')?'01':'03',p.original,nombre(p),p.total.toFixed(2),'ACEPTADO'].join(','));
 fs.writeFileSync(path.join(folder,'correlativos-definitivos.csv'),csv.join('\n')+'\n');
 const md=[`# Resultado definitivo — 12/10/2026`, '',
  `Se verificaron en producción **48 comprobantes aceptados**: 22 facturas F002-45 a F002-66 y 26 boletas B002-27 a B002-52. Los números crecen por fecha de venta e id dentro de cada serie. Fecha fiscal: 12/10/2026.`, '',
  `También se emitieron **seis notas de crédito aceptadas**, por S/ 1,200.00, por la corrección y reemplazo solicitados. Los originales y sus respuestas se conservaron en el historial fiscal. No se ejecutó una devolución comercial ni una reversión de caja, pagos o inventario.`, '',
  '| Nota | Original | Reemplazo | Importe | PDF |','| --- | --- | --- | ---: | --- |',
  ...notesIndex.map(n=>`| ${n.nota} | ${n.original} | ${n.reemplazo} | S/ ${n.importe.toFixed(2)} | [PDF](notas-aceptadas/${n.pdf}) |`), '',
  `La base de datos bloquea cambios de serie, número y tipo de los 48 comprobantes del lote, y de las referencias de sus seis notas. Se comprobaron dos intentos de modificación y ambos fueron rechazados por la protección. Los siguientes números consultados son F002-${Number(siguientes.F002.numero)} y B002-${Number(siguientes.B002.numero)}; las nuevas ventas siguen su flujo habitual.`, '',
  `La comparación después de las emisiones conservó la misma huella de ventas, líneas, cuotas, cuentas, pagos, movimientos, bajas y recargas que la obtenida al corregir el rango. No se alteraron sus datos económicos.`, '',
  `El primer intento F002-23 fue rechazado con CDR 3249 por cuotas omitidas en el XML. Se archivó sin reutilizarlo. Se corrigió el mapper: APIs Perú exige cuotas en la raíz del documento y monto al crédito en formaPago. Se mantuvieron los vencimientos e importes almacenados. [Contrato de APIs Perú](https://facturacion.apisperu.com/).`, '',
  `Validación del código: 53 pruebas del backend y siete pruebas del proceso fiscal pasaron. Compilaciones del backend y frontend correctas. No se publicó el código ni la nueva interfaz de notas en el alojamiento. Para que el flujo normal de nuevas ventas use la corrección de cuotas, es necesario desplegar el backend actualizado; el panel de notas requiere desplegar también el frontend.`, '',
  `Cobertura: el lote contiene los 48 documentos de las series F002/B002. No se renumeraron los documentos anteriores B001-1, B001-3 y F001-15, que quedaron fuera de esta regularización por sus estados o referencias a GRE.`, '',
  `Detalle completo de la correspondencia: [correlativos definitivos](correlativos-definitivos.csv). Evidencia técnica: verificacion-final.json, numeracion-bloqueada.json y ejecución.json. Los PDF, XML y CDR de las notas están en notas-aceptadas/.`];
 fs.writeFileSync(path.join(folder,'resultado-definitivo.md'),md.join('\n'));log(result);
}
async function main(){
 empresa=await model.obtenerEmpresaEmisora();assert.equal(empresa.ruc,'10175332796');
 const l=await lote();assert.ok(l);plan=l.plan;assert.equal(plan.length,48);validarOrden(plan);
 if(process.argv.includes('--estado'))return estado();
 if(process.argv.includes('--exportar-notas'))return exportarNotas();
 if(process.argv.includes('--proteger-numeracion'))return protegerNumeracion();
 if(process.argv.includes('--verificar-final'))return verificarFinal();
 const today=(await db.query("SELECT (NOW() AT TIME ZONE 'America/Lima')::date::text AS fecha")).rows[0].fecha;
 assert.equal(today,l.fecha_fiscal.toISOString?.().slice(0,10)??String(l.fecha_fiscal).slice(0,10),'Cambió el día fiscal; se requiere revisión de fechas');
 lease=await model.reclamarOperacionCpe(empresa.id);assert.ok(lease,'Hay una operación activa de la empresa');
 if(process.argv.includes('--revisar-y-reservar'))await revisarYReservar();
 else if(process.argv.includes('--enviar-notas'))await enviarNotas();
 else if(process.argv.includes('--probar-renumeracion'))await renumerar(true);
 else if(process.argv.includes('--renumerar'))await renumerar();
 else if(process.argv.includes('--emitir-reemplazos'))await emitirReemplazos();
 else if(process.argv.includes('--corregir-credito-y-avanzar'))await corregirCreditoYAvanzar();
 else throw new Error('Selecciona una fase explícita');
}
main().catch(async error=>{console.error(mensajeErrorCpe(error.message));process.exitCode=1;
 try{if(plan)await estado();}catch{};
}).finally(async()=>{if(lease)await model.liberarOperacionCpe(empresa.id,lease);await db.onModuleDestroy();});
