const {test}=require('node:test'),assert=require('node:assert/strict');
const {hash,validarOrden,validarOriginal,validarPayload,validarNota,sinCdr}=require('./correccion-fiscal-guards.cjs');
test('huella compara JSONB sin depender del orden de claves',()=>{
 assert.equal(hash({total:75,details:[{importe:75,cantidad:1}]}),hash({details:[{cantidad:1,importe:75}],total:75}));
 assert.notEqual(hash({total:75}),hash({total:70}));
});
const row=(id,fechaVenta,serie,original,nuevo)=>({id,fechaVenta,serie,numeroOriginal:String(original),numeroNuevo:String(nuevo)});
test('ordena fechas e id con secuencias independientes de factura/boleta',()=>{
 assert.equal(validarOrden([row(3,'2026-10-05','F002',21,23),row(6,'2026-10-06','B002',25,27),row(69,'2026-10-12','F002',1,24)]),true);
});
test('rechaza inversión de fecha, duplicados y números reutilizados',()=>{
 for(const rows of [
  [row(6,'2026-10-06','B002',1,3),row(3,'2026-10-05','F002',1,3)],
  [row(3,'2026-10-05','F002',1,3),row(6,'2026-10-06','F002',2,3)],
  [row(3,'2026-10-05','F002',21,21)],
  [row(3,'2026-10-05','F002',1,5),row(6,'2026-10-06','F002',2,4)]
 ]) assert.throws(()=>validarOrden(rows));
});
test('rechaza un original editado o una fecha fiscal alterada',()=>{
 const p={...row(3,'2026-10-05','F002',21,23),fechaFiscal:'2026-10-12',total:75,snapshot:{id_cliente:1,id_tipo_comprobante:2}};
 const a={id:3,estado:1,serie:'F002',numero:'21',total_importe:'75',id_cliente:1,id_tipo_comprobante:2,fecha_venta:'2026-10-05',fecha_fiscal:'2026-10-12'};
 validarOriginal(a,p);
 assert.throws(()=>validarOriginal({...a,total_importe:'70'},p));
 assert.throws(()=>validarOriginal({...a,fecha_fiscal:'2026-10-05'},p));
});
test('reemplazo conserva importe y fecha fiscal real',()=>{
 const p={serie:'F002',numeroNuevo:'23',total:75,fechaFiscal:'2026-10-12'};
 const payload={company:{ruc:'10175332796'},serie:'F002',correlativo:'23',mtoImpVenta:75,fechaEmision:'2026-10-12T00:00:00-05:00',details:[{}]};
 validarPayload(payload,p);assert.throws(()=>validarPayload({...payload,fechaEmision:'2026-10-05T00:00:00-05:00'},p));
});
test('nota exige referencia original exacta e importe completo',()=>{
 const n={serie:'FC02',numero:1,serie_original:'F002',numero_original:'1',importe:330};
 const payload={company:{ruc:'10175332796'},tipoDoc:'07',serie:'FC02',correlativo:'1',numDocfectado:'F002-1',mtoImpVenta:330,codMotivo:'10',desMotivo:'CORRECCION DE NUMERACION'};
 validarNota(payload,n);
 assert.throws(()=>validarNota({...payload,numDocfectado:'F002-2'},n));
 assert.throws(()=>validarNota({...payload,mtoImpVenta:135},n));
});
test('0127 con ticket o CDR nunca habilita referencia nueva',()=>{
 assert.equal(sinCdr({error:{code:'0127'}}),true);
 assert.equal(sinCdr({success:true}),false);
 assert.equal(sinCdr({error:{code:'0127'},ticket:'x'}),false);
 assert.equal(sinCdr({error:{code:'0127'},cdrResponse:{code:'0'}}),false);
 assert.equal(sinCdr({error:{code:'HTTP'}}),false);
});
