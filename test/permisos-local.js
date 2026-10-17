// Fixed Docker clone only. No .env, AppModule, production credentials or external jobs.
require('reflect-metadata');
const { spawnSync } = require('node:child_process');
const { randomBytes } = require('node:crypto');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Test } = require('@nestjs/testing');
const { Reflector } = require('@nestjs/core');
const { ConfigService } = require('@nestjs/config');
const { JwtService } = require('@nestjs/jwt');
const { ValidationPipe } = require('@nestjs/common');
const { PassportModule } = require('@nestjs/passport');
const request = require('supertest');
const { DatabaseService } = require('../dist/database/database.service');
const { JwtStrategy } = require('../dist/common/strategies/jwt.strategy');
const { JwtAuthGuard } = require('../dist/common/guards/jwt-auth.guard');
const { PermisosGuard } = require('../dist/common/guards/permisos.guard');
const { PermisoBanderas } = require('../dist/common/constants/permiso-banderas');
const { PERMISOS_KEY } = require('../dist/common/decorators/permisos.decorator');
const { CajaController } = require('../dist/modules/caja/controllers/caja.controller');
const { CajaLogic } = require('../dist/modules/caja/logic/caja.logic');
const { CajaModel } = require('../dist/modules/caja/models/caja.model');
const { HttpExceptionFilter } = require('../dist/common/filters/http-exception.filter');
const { TransformResponseInterceptor } = require('../dist/common/interceptors/transform-response.interceptor');
const output = path.resolve(__dirname, '../../outputs/permisos');
fs.mkdirSync(output, { recursive: true });
const literal = v => v == null ? 'NULL' : typeof v === 'number' ? String(v) : "'" + String(v).replaceAll("'", "''") + "'";
function sql(command) {
  const r = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local', 'psql', '-X', '-qAt', '-U', 'supabase_admin', '-d', 'sarita_vsd_20261017', '-v', 'ON_ERROR_STOP=1'], { input: command, encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(r.stderr || 'Docker local SQL failed');
  return JSON.parse(r.stdout.trim());
}
function snapshot() {
  return sql(`BEGIN; CREATE TEMP TABLE audit_snapshot(nombre text, filas bigint, hash text);
    DO $$ DECLARE t record; BEGIN FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename LOOP
      EXECUTE format('INSERT INTO audit_snapshot SELECT %L,count(*),md5(coalesce(string_agg(row_to_json(r)::text,%L ORDER BY row_to_json(r)::text),%L)) FROM public.%I r',t.tablename,'','',t.tablename);
    END LOOP; END $$;
    SELECT json_agg(a ORDER BY nombre) FROM audit_snapshot a; ROLLBACK;`);
}
const db = {
  prefix: '',
  async query(command, params = []) {
    command = command.replace(/\$(\d+)/g, (_, n) => literal(params[Number(n) - 1]));
    return { rows: sql(`BEGIN; SET LOCAL TIME ZONE 'America/Lima'; ${this.prefix} SELECT coalesce(json_agg(r),'[]'::json) FROM (${command}) r; ROLLBACK;`) };
  },
  async callFunctionJson(name, params) {
    return (await this.query(`SELECT ${name}(${params.map((_, i) => '$' + (i + 1)).join(',')}) result`, params)).rows[0].result;
  },
};
async function main() {
  const before = snapshot();
  const sequenceSql = "SELECT sequencename,last_value FROM pg_sequences WHERE schemaname='public' ORDER BY sequencename";
  const sequencesBefore = (await db.query(sequenceSql)).rows;
  const flags = Object.values(PermisoBanderas);
  const front = fs.readFileSync(path.resolve(__dirname, '../../admin-sistema-sarita/src/shared/constants/permissions.ts'), 'utf8');
  const frontFlags = [...front.matchAll(/^\s+\w+: '([^']+)'/gm)].map(m => m[1]);
  // configuracion.ver is a UI grouping flag; examples/licencias have no UI module.
  assert.deepEqual(frontFlags.filter(f => f !== 'configuracion.ver' && !flags.includes(f)), [], 'UI flags recognized by API');
  assert.deepEqual(flags.filter(f => !frontFlags.includes(f) && !/^(ejemplos|licencias)\./.test(f)), [], 'Operational API flags present in UI');
  const catalog = (await db.query('SELECT nombre FROM auth_permisos WHERE estado=true')).rows.map(r => r.nombre);
  assert.deepEqual(flags.filter(f => !f.startsWith('ejemplos.') && !catalog.includes(f)), [], 'All operational permission flags exist and are active in clone');
  const reflector = new Reflector();
  const guard = new PermisosGuard(reflector);
  let matrixChecks = 0;
  for (const flag of flags) {
    const handler = () => {};
    Reflect.defineMetadata(PERMISOS_KEY, [flag], handler);
    for (const permissions of [[], [flag], ['auth.todo']]) {
      const ctx = { getType: () => 'http', getHandler: () => handler, getClass: () => CajaController,
        switchToHttp: () => ({ getRequest: () => ({ user: { permisos: permissions } }) }) };
      if (permissions.length) assert.equal(guard.canActivate(ctx), true);
      else assert.throws(() => guard.canActivate(ctx), e => e.getStatus() === 403);
      matrixChecks++;
    }
  }
  // Inspect every controller reference too: misspelled keys cannot silently remove checks.
  let controllerFiles = 0;
  function audit(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, entry.name);
      if (entry.isDirectory()) audit(p);
      else if (p.endsWith('.controller.ts')) {
        controllerFiles++;
        for (const m of fs.readFileSync(p, 'utf8').matchAll(/PermisoBanderas\.(\w+)/g)) assert.ok(PermisoBanderas[m[1]], `${p}: ${m[1]}`);
      }
    }
  }
  audit(path.resolve(__dirname, '../src/modules'));
  const user = (await db.query("SELECT id FROM auth_usuarios WHERE lower(nombre)='cruiz' AND estado=true")).rows[0];
  assert.ok(user, 'cruiz exists in clone');
  const effective = (await db.callFunctionJson('auth_obtener_permisos_usuario', [user.id])).permisos;
  assert.ok(effective.includes('caja.registrar_gasto'));
  const secret = randomBytes(32).toString('hex');
  const jwt = new JwtService({ secret });
  const token = jwt.sign({ sub: user.id, correo: 'local-test@example.invalid' }, { expiresIn: '10m' });
  const session = `INSERT INTO auth_sesiones(id,id_usuario,token) VALUES(-900001,${user.id},${literal(token)});`;
  const caja = `UPDATE fin_caja_sesion SET estado=0 WHERE fecha=CURRENT_DATE;
    INSERT INTO fin_caja_sesion(id,fecha,id_sucursal,id_estado,id_usuario_apertura)
    SELECT -900001,CURRENT_DATE,1,id_estado,${user.id} FROM fin_caja_sesion WHERE id=11;
    CREATE TEMP SEQUENCE test_gasto_seq INCREMENT -1 MINVALUE -999999 MAXVALUE -1 START -900001;
    ALTER TABLE fin_caja_gasto ALTER COLUMN id SET DEFAULT nextval('pg_temp.test_gasto_seq');`;
  const module = await Test.createTestingModule({ imports: [PassportModule], controllers: [CajaController], providers: [
    CajaLogic, CajaModel, JwtStrategy,
    { provide: DatabaseService, useValue: db },
    { provide: ConfigService, useValue: new ConfigService({ jwt: { secret } }) },
  ] }).compile();
  const app = module.createNestApplication({ logger: false });
  app.useGlobalGuards(new JwtAuthGuard(reflector), guard);
  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true }));
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new TransformResponseInterceptor());
  const checks = [];
  try {
    await app.listen(0, '127.0.0.1');
    const api = request(await app.getUrl());
    const today = (await db.query("SELECT to_char(CURRENT_TIMESTAMP AT TIME ZONE 'America/Lima','YYYY-MM-DD') fecha")).rows[0].fecha;
    const payload = { fecha: today, concepto: 'Prueba local con rollback', monto: 1 };
    const check = (r, status, label) => { assert.equal(r.status, status, `${label}: ${JSON.stringify(r.body)}`); checks.push(label); return r.body.data; };
    db.prefix = session + caja;
    check(await api.post('/caja/gastos').send(payload), 401, 'Sin autenticación: 401');
    check(await api.post('/caja/gastos').auth('invalid', { type: 'bearer' }).send(payload), 401, 'JWT inválido: 401');
    const post = body => api.post('/caja/gastos').auth(token, { type: 'bearer' }).send(body);
    const missingBranch = await post(payload);
    check(missingBranch, 400, 'Reproduce fallo anterior: sin sucursal no encuentra caja');
    assert.match(missingBranch.body.message, /caja/i);
    const created = check(await post({ ...payload, idSesion: -900001, idSucursal: 1 }), 201, 'cruiz registra gasto con su permiso real y caja seleccionada');
    assert.equal(created.idSesion, -900001);
    const options = check(await api.get(`/caja/sesiones?fechaDesde=${today}&fechaHasta=${today}&estadoCaja=ABIERTA`).auth(token, { type: 'bearer' }), 200, 'cruiz consulta cajas abiertas sin permisos de configuración');
    assert.ok(options.some(s => s.id === -900001 && s.idSucursal === 1));
    check(await post({ ...payload, idSesion: -900001, monto: 0 }), 400, 'Rechaza monto cero');
    check(await post({ ...payload, idSesion: -900001, idCuentaBancaria: 999999 }), 400, 'Rechaza cuenta incompatible');
    db.prefix = session + caja + `UPDATE auth_roles_permisos rp SET estado=false FROM auth_permisos p WHERE p.id=rp.id_permiso AND p.nombre IN ('caja.registrar_gasto','auth.todo');`;
    check(await post({ ...payload, idSesion: -900001, idSucursal: 1 }), 403, 'Permiso revocado durante sesión: 403 inmediato');
    db.prefix = session + caja + `UPDATE auth_roles SET estado=false;`;
    check(await post({ ...payload, idSesion: -900001, idSucursal: 1 }), 403, 'Roles inactivos no conceden acceso');
    db.prefix = session + caja + `UPDATE auth_usuarios_roles SET estado=false WHERE id_usuario=${user.id};`;
    check(await post({ ...payload, idSesion: -900001, idSucursal: 1 }), 403, 'Asignaciones de rol inactivas no conceden acceso');
    db.prefix = session + caja + `UPDATE auth_permisos SET estado=false WHERE nombre='caja.registrar_gasto';`;
    check(await post({ ...payload, idSesion: -900001, idSucursal: 1 }), 403, 'Permiso inactivo no concede acceso');
    db.prefix = session + caja + `UPDATE auth_usuarios SET estado=false WHERE id=${user.id};`;
    check(await post(payload), 401, 'Usuario inactivo: 401');
    db.prefix = session + caja + `UPDATE auth_sesiones SET estado=false WHERE id=-900001;`;
    check(await post(payload), 401, 'Sesión revocada: 401');
    db.prefix = session + caja + `UPDATE auth_sesiones SET id_usuario=(SELECT min(id) FROM auth_usuarios WHERE estado=true AND id<>${user.id}) WHERE id=-900001;`;
    check(await post(payload), 401, 'JWT no coincide con usuario de la sesión: 401');
    db.prefix = session;
    check(await post({ ...payload, idSesion: 10, idSucursal: 1 }), 400, 'Caja cerrada mantiene bloqueo de negocio');
    check(await post({ ...payload, idSesion: 11, idSucursal: 1 }), 400, 'Caja de fecha anterior mantiene bloqueo de negocio');
  } finally { await app.close(); db.prefix = ''; }
  const after = snapshot();
  assert.deepEqual(after, before, 'Every public table preserves exact row count and hash');
  const sequencesAfter = (await db.query(sequenceSql)).rows;
  assert.deepEqual(sequencesAfter, sequencesBefore, 'Public sequences remain unchanged');
  const result = { flags: flags.length, matrixChecks, controllerFiles, httpChecks: checks.length, checks,
    allPublicTablesUnchanged: before.length, sequencesUnchanged: sequencesBefore.length, cruiz: { id: user.id, canRegisterExpense: true, canOpenCaja: effective.includes('caja.abrir'), canCloseCaja: effective.includes('caja.cerrar') } };
  fs.writeFileSync(path.join(output, 'resultado.json'), JSON.stringify(result, null, 2));
  fs.writeFileSync(path.join(output, 'integridad.json'), JSON.stringify({ before, after, sequencesBefore, sequencesAfter }, null, 2));
  console.log(JSON.stringify(result, null, 2));
}
main().catch(e => { console.error(e.message); process.exitCode = 1; });
