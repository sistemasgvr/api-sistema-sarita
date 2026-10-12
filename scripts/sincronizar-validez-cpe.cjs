// Migración y reconciliación autorizadas. No llama endpoints de emisión.
require('ts-node/register/transpile-only');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const { ConfigService } = require('@nestjs/config');
const env = require('dotenv').parse(fs.readFileSync(path.join(__dirname, '../.env')));
const { DatabaseService } = require('../src/database/database.service');
const { ComprobantesModel } = require('../src/modules/comprobantes/models/comprobantes.model');
const { SunatValidezClient } = require('../src/integrations/facturacion-electronica/sunat-validez.client');

const config = new ConfigService({ database: { url: env.DATABASE_URL } });
const db = new DatabaseService(config);
const model = new ComprobantesModel(db, config);
const sunat = new SunatValidezClient(db);
const reportPath = path.join(__dirname, '../../diagnosticos/sincronizacion-validez-cpe-20261012.json');
const report = { ejecutadoEn: new Date().toISOString(), envios: 0, pruebas: [], comprobantes: [] };

const fingerprintSql = `SELECT to_jsonb(c) - ARRAY['id_estado_sunat','validez_sunat','cpe_verificacion','id_usuario_modificacion','fecha_modificacion'] AS datos
  FROM ven_comprobante c WHERE id=$1`;

async function main() {
  if (process.argv.includes('--estado-verificador')) {
    const estados=(await db.query("SELECT id,serie,numero,cpe_verificacion->>'verificadoEn' AS ultima_verificacion,cpe_verificacion->>'estado' AS resultado FROM ven_comprobante WHERE id IN (68,67) ORDER BY id DESC")).rows;
    console.log(JSON.stringify({estados,pendientes:await model.pendientesDeVerificacion(),envios:0}));
    return;
  }
  if (process.argv.includes('--activar-verificacion-envio')) {
    await db.query(fs.readFileSync(path.join(__dirname,'../database_sql/migraciones/20261012_verificacion_envio_cpe.sql'),'utf8'));
    const { HttpService } = require('@nestjs/axios');
    const { FacturacionCredentialsService } = require('../src/integrations/facturacion-electronica/facturacion-credentials.service');
    const { FacturacionApisperuClient } = require('../src/integrations/facturacion-apisperu/facturacion-apisperu.client');
    const { ComprobantesLogic } = require('../src/modules/comprobantes/logic/comprobantes.logic');
    const provider = new FacturacionApisperuClient(new HttpService(),new FacturacionCredentialsService(db,config));
    const logic = Object.create(ComprobantesLogic.prototype);
    Object.assign(logic,{model,validezClient:sunat,facturacionClient:provider});
    const resultados=[];
    for (const id of [68,67]) {
      const before=(await db.query(fingerprintSql,[id])).rows[0].datos;
      const result=await logic.verificarEnvio(id);
      assert.deepEqual((await db.query(fingerprintSql,[id])).rows[0].datos,before);
      resultados.push({id,...result});
      console.log(JSON.stringify({id,...result,envios:0}));
    }
    const lock=await model.reclamarVerificacionGlobal();
    if (lock) {
      try { assert.equal(await model.reclamarVerificacionGlobal(),null); }
      finally { await model.liberarVerificacionGlobal(lock); }
    }
    fs.writeFileSync(path.join(__dirname,'../../diagnosticos/verificacion-envio-cpe-20261012.json'),JSON.stringify({envios:0,migracionAplicada:true,resultados,pruebas:['Bloqueo global evita verificadores simultáneos','Datos de la venta y XML/CDR intactos durante consultas inciertas']},null,2));
    return;
  }
  if (process.argv.includes('--consultar-pendientes')) {
    const { ComprobantesLogic } = require('../src/modules/comprobantes/logic/comprobantes.logic');
    const logic = Object.create(ComprobantesLogic.prototype);
    Object.assign(logic, {model, validezClient: sunat});
    const pendientes = (await db.query("SELECT id,serie,numero FROM ven_comprobante WHERE estado=1 AND serie='F002' AND numero::numeric IN (2,3) ORDER BY numero")).rows;
    const resultados = [];
    for (const doc of pendientes) {
      const validez = await logic.sincronizarValidez(doc.id, null);
      resultados.push({ referencia: `${doc.serie}-${Number(doc.numero)}`, ...validez });
      console.log(JSON.stringify({referencia:`${doc.serie}-${Number(doc.numero)}`,codigo:validez.codigo,estado:validez.estado,actualizado:validez.estadoActualizado,envios:0}));
    }
    fs.writeFileSync(path.join(__dirname,'../../diagnosticos/consulta-pendientes-20261012.json'),JSON.stringify({consultadoEn:new Date().toISOString(),envios:0,resultados},null,2));
    return;
  }
  if (process.argv.includes('--verificar-lista')) {
    const { ComprobantesLogic } = require('../src/modules/comprobantes/logic/comprobantes.logic');
    const { FiltroComprobantesDto } = require('../src/modules/comprobantes/dto/comprobantes.dto');
    const logic = Object.create(ComprobantesLogic.prototype);
    Object.assign(logic,{model});
    const filters = new FiltroComprobantesDto();
    filters.limite=100;
    const result = await logic.listar(filters);
    const row = result.data.find(item=>item.id===69);
    assert.equal(row.nombre_estado_sunat,'ACEPTADO');
    assert.equal(row.estado_envio,undefined);
    console.log(JSON.stringify({referencia:'F002-1',estado:row.nombre_estado_sunat,enCurso:false,envios:0}));
    return;
  }
  if (process.argv.includes('--inspeccionar')) {
    const result = await db.query(`SELECT pg_get_functiondef(p.oid) AS definicion FROM pg_proc p
      JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='ven_registrar_respuesta_sunat'`);
    console.log(result.rows[0].definicion);
    return;
  }
  const migration = fs.readFileSync(path.join(__dirname, '../database_sql/migraciones/20261012_sincronizacion_validez_cpe.sql'), 'utf8');
  const connection = await db.getClient();
  try {
    const before = (await connection.query(fingerprintSql, [69])).rows[0].datos;
    // Instala temporalmente, verifica el comportamiento y revierte toda la prueba.
    await connection.query(migration.replace(/COMMIT;\s*$/, ''));
    const original = (await connection.query(`SELECT c.*, t.descripcion AS tipo FROM ven_comprobante c
      JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante WHERE c.id=69`)).rows[0];
    const day = original.fecha_emision_cpe ?? original.fecha;
    const date = typeof day === 'string' ? day.slice(0,10) : new Date(day).toISOString().slice(0,10);
    const [y,m,d] = date.split('-');
    const prueba = { codigo:'1', consulta:{ codComp:original.tipo, numeroSerie:original.serie,
      numero:Number(original.numero), fechaEmision:`${d}/${m}/${y}`, monto:Number(original.total_importe) } };
    const states = (await connection.query(`SELECT lo.id,lo.nombre FROM gen_lista_opciones lo
      JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoSunat' AND lo.estado=1`)).rows;
    const accepted = states.find(s=>s.nombre==='ACEPTADO').id;
    const pending = states.find(s=>s.nombre==='PENDIENTE').id;
    const rejected = states.find(s=>s.nombre==='RECHAZADO').id;
    await connection.query('UPDATE ven_comprobante SET validez_sunat=$2::jsonb,id_estado_sunat=$3 WHERE id=$1', [69,JSON.stringify(prueba),accepted]);
    for (const state of [pending,rejected]) {
      await connection.query('SELECT ven_registrar_respuesta_sunat($1,$2,NULL,NULL,NULL,$3,NULL)', [69,state,JSON.stringify({tipo:'emision_por_confirmar'})]);
      const actual = (await connection.query('SELECT id_estado_sunat,ven_cpe_validez_aceptada(c) AS valido FROM ven_comprobante c WHERE id=69')).rows[0];
      assert.equal(actual.id_estado_sunat,accepted);
      assert.equal(actual.valido,true);
    }
    assert.deepEqual((await connection.query(fingerprintSql,[69])).rows[0].datos,before);
    for (const [field,value] of [['numeroSerie','F999'],['numero',99999999],['monto',1],['fechaEmision','01/01/2000'],['codComp','03']]) {
      await connection.query('UPDATE ven_comprobante SET validez_sunat=$2::jsonb WHERE id=$1', [69,JSON.stringify({...prueba,consulta:{...prueba.consulta,[field]:value}})]);
      assert.equal((await connection.query('SELECT ven_cpe_validez_aceptada(c) AS valido FROM ven_comprobante c WHERE id=69')).rows[0].valido,false);
    }
    await connection.query('ROLLBACK');
    report.pruebas.push('Timeout y rechazo tardíos no sobrescriben aceptación confirmada', 'Prueba revertida: datos comerciales y evidencias originales intactos', 'Evidencia de otro número, serie, fecha, importe o tipo no es aplicable');
    const definition = (await connection.query(`SELECT pg_get_functiondef(p.oid) AS definicion FROM pg_proc p
      JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='ven_registrar_respuesta_sunat'`)).rows[0].definicion;
    fs.writeFileSync(path.join(__dirname,'../../diagnosticos/funcion-respuesta-antes-sincronizacion-20261012.sql'),definition);
    await connection.query(migration);
    report.migracionAplicada=true;
  } catch (error) { await connection.query('ROLLBACK'); throw error; }
  finally { connection.release(); }

  // Reconcilia solo el documento mostrado por el usuario con una consulta real.
  const doc = (await model.obtenerCompleto(69)).registro;
  assert.equal(doc.serie,'F002');
  assert.equal(Number(doc.numero),1);
  const issuer = await model.obtenerEmpresaEmisora();
  assert.equal(issuer.ruc,'10175332796');
  const before = (await db.query(fingerprintSql,[69])).rows[0].datos;
  const proof = await sunat.consultar(issuer.id,{ tipo:doc.codigo_tipo_comprobante, serie:doc.serie,
    numero:doc.numero, fecha:doc.fecha_emision_cpe??doc.fecha, total:Number(doc.total_importe) });
  const actualizado = proof.codigo==='1' ? await model.sincronizarValidez(69,proof,null) : false;
  assert.deepEqual((await db.query(fingerprintSql,[69])).rows[0].datos,before);
  const after = (await db.query(`SELECT s.nombre AS estado,ven_cpe_validez_aceptada(c) AS confirmado
    FROM ven_comprobante c JOIN gen_lista_opciones s ON s.id=c.id_estado_sunat WHERE c.id=69`)).rows[0];
  report.comprobantes.push({id:69,referencia:'F002-1',validez:proof,actualizado,resultado:after});
  report.pruebas.push('Sincronización real mantiene intactos fecha, montos, estado de pago, XML y CDR');
  fs.writeFileSync(reportPath,JSON.stringify(report,null,2));
  console.log(JSON.stringify({migracion:report.migracionAplicada, pruebas:report.pruebas, documento:'F002-1',codigo:proof.codigo,actualizado,estado:after.estado,envios:0}));
}
main().catch(error=>{ console.error(error.message); process.exitCode=1; }).finally(()=>db.onModuleDestroy());
