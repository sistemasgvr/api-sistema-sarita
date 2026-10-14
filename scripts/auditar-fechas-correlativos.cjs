// Auditoría únicamente: no altera números, no anula y no emite.
const fs=require('node:fs'); const path=require('node:path'); const {Client}=require('pg');
const env=require('dotenv').parse(fs.readFileSync(path.join(__dirname,'../.env')));
const db=new Client({connectionString:env.DATABASE_URL,connectionTimeoutMillis:10000,options:'-c default_transaction_read_only=on'});
async function main(){
  await db.connect();
  const rows=(await db.query(`SELECT c.id,t.descripcion AS tipo,c.serie,c.numero,c.fecha::text AS fecha_venta,
    COALESCE(c.fecha_emision_cpe,c.fecha::date)::text AS fecha_fiscal,c.fecha_creacion,c.fecha_modificacion,
    s.nombre AS estado_sunat,c.total_importe,c.xml_firmado,c.hash_documento,c.cdr_respuesta,
    EXISTS(SELECT 1 FROM ven_comprobante_historial_cpe h WHERE h.id_comprobante=c.id) AS regularizado,
    EXISTS(SELECT 1 FROM ven_comprobante nc JOIN gen_lista_opciones nct ON nct.id=nc.id_tipo_comprobante
      WHERE nc.estado=1 AND nc.id_comprobante_origen=c.id AND nct.descripcion IN ('07','08')) AS tiene_nota
    FROM ven_comprobante c JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones s ON s.id=c.id_estado_sunat
    WHERE c.estado=1 AND t.descripcion IN ('01','03') ORDER BY c.serie,c.numero::numeric`)).rows;
  const docs=rows.map(row=>{
    const raw=row.xml_firmado??'';
    const xml=raw.trimStart().startsWith('<')?raw:Buffer.from(raw,'base64').toString();
    return {id:row.id,tipo:row.tipo,referencia:`${row.serie}-${Number(row.numero)}`,serie:row.serie,numero:Number(row.numero),
      fechaVenta:row.fecha_venta.slice(0,10),fechaFiscal:row.fecha_fiscal,fechaXml:xml.match(/<cbc:IssueDate[^>]*>([^<]+)<\/cbc:IssueDate>/)?.[1]??null,
      estado:row.estado_sunat,total:Number(row.total_importe),regularizado:row.regularizado,tieneNota:row.tiene_nota,
      tieneEvidenciaEnvio:!!(row.hash_documento||row.xml_firmado||row.cdr_respuesta),
      creado:row.fecha_creacion,modificado:row.fecha_modificacion};
  });
  const inversiones=[];
  for(let i=1;i<docs.length;i++){
    const a=docs[i-1],b=docs[i];
    if(a.serie===b.serie && a.fechaFiscal>b.fechaFiscal) inversiones.push({anterior:a.referencia,fechaAnterior:a.fechaFiscal,siguiente:b.referencia,fechaSiguiente:b.fechaFiscal});
  }
  const report={auditadoEn:new Date().toISOString(),soloLectura:true,envios:0,anulaciones:0,inversionesFiscales:inversiones,
    fechasDistintas:docs.filter(d=>d.fechaVenta!==d.fechaFiscal).length,documentos:docs};
  if(process.argv.includes('--validez')) {
    require('ts-node/register/transpile-only');
    const {SunatValidezClient}=require('../src/integrations/facturacion-electronica/sunat-validez.client');
    const cliente=new SunatValidezClient(db);
    const empresa=(await db.query('SELECT id_empresa FROM gen_configuracion_sunat WHERE estado=1')).rows[0].id_empresa;
    for(const doc of docs.filter(d=>d.estado==='ACEPTADO')) {
      const validez=await cliente.consultar(empresa,{tipo:doc.tipo,serie:doc.serie,numero:String(doc.numero),fecha:doc.fechaFiscal,total:doc.total});
      doc.validezActual={codigo:validez.codigo,estado:validez.estado,consultadoEn:validez.consultadoEn};
      console.log(JSON.stringify({referencia:doc.referencia,estadoGuardado:doc.estado,fechaFiscal:doc.fechaFiscal,estadoSunat:validez.estado}));
    }
  }
  fs.writeFileSync(path.join(__dirname,'../../diagnosticos/auditoria-fechas-correlativos-20261012.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({total:docs.length,inversionesFiscales:inversiones,fechasVentaFiscalDistintas:report.fechasDistintas,
    ejemplo:docs.find(d=>d.referencia==='F002-21'),primeros:docs.filter(d=>['F002-1','B002-1'].includes(d.referencia)),
    estados:docs.reduce((r,d)=>(r[d.estado]=(r[d.estado]??0)+1,r),{}),sinEnvio:docs.filter(d=>!d.tieneEvidenciaEnvio).length}));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;}).finally(()=>db.end());
