// Two real PostgreSQL sessions: a stale correction must wait, then fail.
const { spawn, spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const args = ['exec', '-i', 'gvr-postgres-local', 'psql', '-X', '-qAt', '-U', 'supabase_admin', '-d', 'sarita_vsd_20261017', '-v', 'ON_ERROR_STOP=1'];
function sync(sql) { const r=spawnSync('docker',args,{input:sql,encoding:'utf8'}); if(r.status!==0) throw new Error(r.stderr); return r.stdout.trim(); }
async function main() {
  const version=sync('SELECT xmin::text FROM ven_comprobante WHERE id=141;');
  const actor=sync('SELECT min(id) FROM auth_usuarios WHERE estado=true;');
  const first=spawn('docker',args,{stdio:['pipe','pipe','pipe']});
  let errors=''; first.stderr.on('data',chunk=>errors+=chunk);
  const done=new Promise(resolve=>first.on('close',resolve));
  const locked=new Promise(resolve=>first.stdout.on('data',chunk=>{if(String(chunk).includes('LOCKED')) resolve();}));
  first.stdin.end("BEGIN; SELECT id FROM ven_comprobante WHERE id=141 FOR UPDATE; SELECT 'LOCKED'; SELECT pg_sleep(3); UPDATE ven_comprobante SET id=id WHERE id=141; COMMIT;");
  await locked;
  const started=Date.now();
  const second=spawnSync('docker',args,{input:`SELECT ven_actualizar_comprobante(p_id=>141,p_observaciones=>'No debe guardarse',p_id_usuario_auditoria=>${actor},p_motivo_correccion=>'Prueba de dos sesiones simultáneas',p_version_esperada=>'${version}');`,encoding:'utf8'});
  const elapsed=Date.now()-started;
  assert.notEqual(second.status,0); assert.match(second.stderr,/venta cambió/); assert.ok(elapsed>1500);
  assert.equal(await done,0,errors);
  const emission=spawn('docker',args,{stdio:['pipe','pipe','pipe']});
  let emissionError=''; emission.stderr.on('data',chunk=>emissionError+=chunk);
  const emissionDone=new Promise(resolve=>emission.on('close',resolve));
  const emissionLocked=new Promise(resolve=>emission.stdout.on('data',chunk=>{if(String(chunk).includes('EMISSION_LOCKED')) resolve();}));
  emission.stdin.end("SELECT pg_advisory_lock(872016,141); SELECT 'EMISSION_LOCKED'; SELECT pg_sleep(5); SELECT pg_advisory_unlock(872016,141);");
  await emissionLocked;
  const update=spawnSync('docker',args,{input:`SELECT ven_actualizar_comprobante(p_id=>141,p_id_usuario_auditoria=>${actor},p_motivo_correccion=>'No editar durante emisión',p_version_esperada=>'0');`,encoding:'utf8'});
  assert.notEqual(update.status,0); assert.match(update.stderr,/emisión en curso/);
  const data=JSON.stringify({tipoOperacion:'CAMBIO',solicitud:'71722ec7-71ce-4400-96ee-f23d46064998',versionEsperada:'0',idBalonActual:638,idBalonNuevo:9999999,idAlmacen:2,cantidadGasDevuelta:0,cantidadGasSalida:6,condicionDevolucion:'DISPONIBLE',motivo:'No cambiar balón durante emisión'});
  const exchange=spawnSync('docker',args,{input:`SELECT ven_cambiar_balon_vsd(141,'${data}'::jsonb,${actor});`,encoding:'utf8'});
  assert.notEqual(exchange.status,0); assert.match(exchange.stderr,/emisión en curso/);
  assert.equal(await emissionDone,0,emissionError);
  console.log(JSON.stringify({ passed: 3, tests:['Dos sesiones rechazan versión obsoleta','No permite editar durante emisión','No permite cambiar balón durante emisión'], elapsedMs:elapsed }));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
