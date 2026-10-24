// Real controller + DTO + logic + model + SQL against the fixed Docker copy.
// Every database call is wrapped in ROLLBACK. No AppModule, schedulers or external integrations.
require('reflect-metadata');
const { spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Test } = require('@nestjs/testing');
const { ValidationPipe } = require('@nestjs/common');
const request = require('supertest');
const { ComprobantesController } = require('../dist/modules/comprobantes/controllers/comprobantes.controller');
const { ComprobantesLogic } = require('../dist/modules/comprobantes/logic/comprobantes.logic');
const { ComprobantesModel } = require('../dist/modules/comprobantes/models/comprobantes.model');
const { HttpExceptionFilter } = require('../dist/common/filters/http-exception.filter');
const { TransformResponseInterceptor } = require('../dist/common/interceptors/transform-response.interceptor');
function literal(value) { return value == null ? 'NULL' : typeof value === 'number' ? String(value) : "'" + String(value).replaceAll("'", "''") + "'"; }
const db = {
  prefix: '',
  async query(sql, params = []) {
    const command = sql.replace(/\$(\d+)/g, (_, n) => literal(params[Number(n) - 1]));
    const input = `\\set VERBOSITY verbose\nBEGIN; ${this.prefix} SELECT COALESCE(json_agg(r),'[]'::json) FROM (${command}) r; ROLLBACK;`;
    const r = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local', 'psql', '-X', '-qAt', '-U', 'supabase_admin', '-d', 'sarita_vsd_20261017', '-v', 'ON_ERROR_STOP=1'], { input, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 });
    if (r.status !== 0) {
      const match = r.stderr.match(/ERROR:\s+(\w{5}):\s+([^\n]+)/);
      const error = new Error(match?.[2] || 'Local SQL failed'); error.code = match?.[1]; throw error;
    }
    return { rows: JSON.parse(r.stdout.trim()) };
  },
  async callFunctionJson(name, params) {
    const r = await this.query(`SELECT ${name}(${params.map((_, i) => '$' + (i + 1)).join(',')}) AS result`, params);
    return r.rows[0].result;
  },
};
async function main() {
  const model = new ComprobantesModel(db, { get: () => undefined });
  const logic = new ComprobantesLogic(model, {}, {}, {}, {}, {}, {}, {});
  const module = await Test.createTestingModule({ controllers: [ComprobantesController], providers: [{ provide: ComprobantesLogic, useValue: logic }] }).compile();
  const app = module.createNestApplication({ logger: false });
  const actor = (await db.query('SELECT min(id) id FROM auth_usuarios WHERE estado=true')).rows[0].id;
  app.use((req, res, next) => { req.user = { id: actor }; next(); });
  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new TransformResponseInterceptor());
  const passed = [];
  try {
    await app.listen(0, '127.0.0.1');
    const api = request(await app.getUrl());
    const check = (response, status, label) => { assert.equal(response.status, status, label + ': ' + (response.body.message || '')); passed.push(label); return response.body.data; };
    const v = check(await api.get('/comprobantes/141'), 200, 'GET devuelve venta con versión y metadatos');
    assert.ok(v.version); assert.ok(v.detalles[0].id_balon); assert.ok(v.detalles[0].item);
    const context = check(await api.get('/comprobantes/141/operaciones-vsd'), 200, 'GET devuelve balón actual e historial');
    assert.ok(context.balones.some(b => b.id === v.detalles[0].id_balon));
    db.prefix = `UPDATE ven_comprobante_detalle SET id_balon=1 WHERE id_comprobante=141 AND estado=1;
      INSERT INTO ven_vsd_operacion(id_comprobante,tipo,motivo,datos,anterior,posterior,id_usuario) VALUES
      (141,'CAMBIO_BALON','Fixture de corrección de reserva','{"idBalonActual":638,"idBalonNuevo":1,"idBalonOriginal":638,"tipoOperacion":"CORRECCION_RESERVA"}','{}','{}',${actor}),
      (141,'CAMBIO_BALON','Fixture de cambio posterior','{"idBalonActual":1,"idBalonNuevo":2,"idBalonOriginal":638,"tipoOperacion":"CAMBIO"}','{}','{}',${actor});`;
    const chain = check(await api.get('/comprobantes/141/operaciones-vsd'), 200, 'GET resuelve el balón vigente después de reserva y cambios encadenados');
    assert.deepEqual(chain.balones.map(b=>b.id), [2]);
    db.prefix = '';
    const payload = { versionEsperada: v.version, motivoCorreccion: 'Guardar metadatos sin perder el balón',
      detalles: v.detalles.map(d => ({ item: d.item, idProducto: d.id_producto, cantidad: Number(d.cantidad),
        precioUnitario: Number(d.precio_unitario), descuento: Number(d.descuento || 0), porcentajeIgv: Number(d.porcentaje_igv || 18),
        idAfectacionIgv: d.id_afectacion_igv ?? undefined, descripcion: d.descripcion ?? undefined,
        idUnidadMedida: d.id_unidad_medida ?? undefined, idBalon: d.id_balon ?? undefined,
        capacidadCilindro: d.capacidad_cilindro == null ? undefined : Number(d.capacidad_cilindro), idEstadoCilindro: d.id_estado_cilindro ?? undefined })) };
    const saved = check(await api.patch('/comprobantes/141').send(payload), 200, 'PATCH conserva la relación física sin alterar stock');
    assert.equal(saved.id, v.id);
    check(await api.patch('/comprobantes/141').send({ ...payload, versionEsperada: '0' }), 400, 'PATCH rechaza versión obsoleta mediante HTTP 400');
    const missing = structuredClone(payload); delete missing.detalles[0].idBalon;
    check(await api.patch('/comprobantes/141').send(missing), 400, 'PATCH rechaza pérdida de referencia del balón');
    check(await api.patch('/comprobantes/141').send({ versionEsperada: v.version }), 400, 'PATCH exige motivo');
    const exchange = { tipoOperacion: 'CAMBIO', solicitud: '71722ec7-71ce-4400-96ee-f23d46064909', versionEsperada: v.version,
      idBalonActual: v.detalles[0].id_balon, idBalonNuevo: v.detalles[0].id_balon, idAlmacen: v.id_almacen,
      cantidadGasDevuelta: 0, cantidadGasSalida: 6, condicionDevolucion: 'DISPONIBLE', motivo: 'Validación local del endpoint de cambio' };
    check(await api.post('/comprobantes/141/cambio-balon').send(exchange), 400, 'POST rechaza reemplazo por el mismo balón');
    check(await api.post('/comprobantes/141/cambio-balon').send({ ...exchange, idBalonNuevo: 9999999 }), 400, 'POST rechaza reemplazo inexistente');
    check(await api.post('/comprobantes/141/cambio-balon').send({ ...exchange, cantidadGasDevuelta: -1 }), 400, 'DTO rechaza cantidades negativas');
    check(await api.post('/comprobantes/141/cambio-balon').send({ ...exchange, solicitud: 'invalid' }), 400, 'DTO exige identificador de reintento válido');
    check(await api.post('/comprobantes/141/cambio-balon').send({ ...exchange, idUsuarioAuditoria: actor + 1 }), 400, 'HTTP impide suplantar el usuario de auditoría');
    check(await api.get('/comprobantes/9999999/operaciones-vsd'), 404, 'GET rechaza venta inexistente');
    for (const code of ['01','03']) {
      const candidate = (await db.query(`SELECT c.id FROM ven_comprobante c JOIN gen_lista_opciones tc ON tc.id=c.id_tipo_comprobante
        JOIN gen_lista_opciones es ON es.id=c.id_estado_sunat WHERE c.estado=1 AND tc.descripcion=$1 AND es.nombre='ACEPTADO'
        AND NOT EXISTS(SELECT 1 FROM ven_comprobante d WHERE d.id_comprobante_origen=c.id AND d.estado=1)
        AND NOT EXISTS(SELECT 1 FROM ven_resumen_diario_detalle rd JOIN ven_resumen_diario r ON r.id=rd.id_resumen WHERE rd.id_comprobante=c.id AND rd.estado=1 AND r.estado=1)
        ORDER BY c.id DESC LIMIT 1`, [code])).rows[0];
      assert.ok(candidate, 'Fixture CPE ' + code);
      const doc = check(await api.get(`/comprobantes/${candidate.id}`), 200, `${code} / HTTP identifica comprobante emitido como no editable`);
      assert.equal(doc.permite_edicion_segura, false);
      check(await api.get(`/comprobantes/${candidate.id}/operaciones-vsd`), 200, `${code} / HTTP permite consultar historial de boleta o factura`);
      check(await api.patch(`/comprobantes/${candidate.id}`).send({ versionEsperada: doc.version, motivoCorreccion: 'No debe editar un comprobante emitido' }), 400, `${code} / HTTP bloquea editar después de emitir`);
      db.prefix = `UPDATE ven_comprobante SET id_estado_sunat=(SELECT lo.id FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='EstadoSunat' AND lo.nombre='PENDIENTE' LIMIT 1),
        ticket_sunat=NULL,hash_documento=NULL,xml_firmado=NULL,cdr_respuesta=NULL,fecha_emision_cpe=NULL,validez_sunat=NULL,cpe_verificacion=NULL WHERE id=${candidate.id};`;
      const draft = check(await api.get(`/comprobantes/${candidate.id}`), 200, `${code} / HTTP habilita edición del borrador sin envío`);
      assert.equal(draft.permite_edicion_segura, true);
      db.prefix = '';
    }
    fs.writeFileSync(path.resolve(__dirname, '../../outputs/ventas-seguras/http-tests.json'), JSON.stringify({ passed: passed.length, checks: passed }, null, 2));
    console.log(JSON.stringify({ passed: passed.length, checks: passed }));
  } finally { await app.close(); }
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
