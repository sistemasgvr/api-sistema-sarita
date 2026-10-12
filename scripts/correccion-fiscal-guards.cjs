const assert = require('node:assert/strict');
const {createHash} = require('node:crypto');
function canonical(value) {
  if(Array.isArray(value))return value.map(canonical);
  if(value&&typeof value==='object') {
    if(value instanceof Date)return value.toJSON();
    return Object.fromEntries(Object.keys(value).sort().filter(key=>value[key]!==undefined).map(key=>[key,canonical(value[key])]));
  }
  return value;
}
const hash = value => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
function validarOrden(plan) {
  const ids=new Set(),refs=new Set(),last={};
  let prior=null;
  for(const p of plan) {
    assert.ok(['F002','B002'].includes(p.serie));
    assert.ok(!ids.has(p.id),'Venta repetida');ids.add(p.id);
    const ref=`${p.serie}-${Number(p.numeroNuevo)}`;
    assert.ok(!refs.has(ref),'Referencia repetida');refs.add(ref);
    assert.ok(Number(p.numeroNuevo)>0);
    assert.ok(Number(p.numeroNuevo)>Number(p.numeroOriginal),'No se reutiliza el correlativo original');
    assert.ok(!prior || p.fechaVenta>prior.fechaVenta || (p.fechaVenta===prior.fechaVenta && p.id>prior.id),'Orden de fecha/id incorrecto');
    if(last[p.serie]) assert.ok(Number(p.numeroNuevo)>Number(last[p.serie].numeroNuevo),'Correlativo invertido dentro de la serie');
    last[p.serie]=p;prior=p;
  }
  return true;
}
function validarOriginal(actual,p) {
  assert.equal(actual.id,p.id);assert.equal(actual.estado,1);
  assert.equal(actual.serie,p.serie);assert.equal(actual.numero,p.numeroOriginal);
  assert.equal(Number(actual.total_importe),p.total);
  assert.equal(actual.id_cliente,p.snapshot.id_cliente);
  assert.equal(actual.id_tipo_comprobante,p.snapshot.id_tipo_comprobante);
  assert.equal(String(actual.fecha_venta??actual.fecha).slice(0,10),p.fechaVenta);
  assert.equal(actual.fecha_fiscal,p.fechaFiscal);
}
function validarPayload(payload,p) {
  assert.equal(payload.company.ruc,'10175332796');
  assert.equal(payload.serie,p.serie);
  assert.equal(Number(payload.correlativo),Number(p.numeroNuevo));
  assert.equal(Number(payload.mtoImpVenta),p.total);
  assert.equal(payload.fechaEmision.slice(0,10),p.fechaFiscal);
  assert.ok(payload.details?.length>0);
}
function validarNota(payload,n) {
  assert.equal(payload.tipoDoc,'07');assert.equal(payload.company.ruc,'10175332796');
  assert.equal(payload.serie,n.serie);assert.equal(Number(payload.correlativo),Number(n.numero));
  assert.equal(payload.numDocfectado,`${n.serie_original}-${Number(n.numero_original)}`);
  assert.equal(Number(payload.mtoImpVenta),Number(n.importe));
  assert.equal(payload.codMotivo,'10');
  assert.ok(payload.desMotivo.includes('CORRECCION DE NUMERACION'));
}
function sinCdr(status) {
  const data=status.sunatResponse??status;
  return String(data.error?.code??'')==='0127' && !data.cdrResponse && !data.cdrZip && !data.ticket;
}
module.exports={hash,validarOrden,validarOriginal,validarPayload,validarNota,sinCdr};
