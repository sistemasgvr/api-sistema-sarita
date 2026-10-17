// Explicit production DDL deployment. Does not start the API or load integrations.
// URL is delivered over stdin to Docker, never printed or passed as an argument.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../..');
const output = path.resolve(root, '../outputs/despliegue-estructura');
fs.mkdirSync(output, { recursive: true });
const env = fs.readFileSync(path.join(root, '.env'), 'utf8');
const line = env.split(/\r?\n/).find(s => /^DATABASE_URL=/.test(s));
if (!line) throw new Error('DATABASE_URL no encontrada');
const source = new URL(line.slice(line.indexOf('=') + 1).trim().replace(/^(['"])(.*)\1$/, '$2'));
if (source.hostname.endsWith('.pooler.supabase.com') && source.port === '6543') source.port = '5432';
source.searchParams.set('connect_timeout', '20');
const url = source.toString();
function redact(s) {
  for (const value of [url, source.password, decodeURIComponent(source.password)]) if (value) s = s.split(value).join('[REDACTED]');
  return s;
}
function production(sql, readOnly = true) {
  const r = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local', 'sh', '-c',
    `IFS= read -r SOURCE_URL; export PGCONNECT_TIMEOUT=20; ${readOnly ? 'export PGOPTIONS="-c default_transaction_read_only=on";' : ''} exec psql --dbname="$SOURCE_URL" -X -qAt -v ON_ERROR_STOP=1`],
    { input: url + '\n' + sql, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024, timeout: 180000 });
  if (r.status !== 0) throw new Error(redact(r.stderr || r.error?.message || 'Production SQL failed'));
  return r.stdout.trim();
}
const metadataSql = `BEGIN READ ONLY;
    SELECT json_build_object('database',current_database(),'user',current_user,'version',current_setting('server_version'),
      'historyExists',to_regclass('public.ven_vsd_operacion') IS NOT NULL,
      'catalogCambioVsd',(SELECT count(*) FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='TipoDocumentoRef' AND lo.nombre='CAMBIO_VSD' AND lo.estado=1),
      'columns',(SELECT json_agg(r ORDER BY table_name,ordinal_position) FROM (SELECT table_name,column_name,data_type,udt_name,ordinal_position FROM information_schema.columns WHERE table_schema='public') r),
      'functions',(SELECT json_agg(r ORDER BY proname,signature) FROM (SELECT p.proname,oidvectortypes(p.proargtypes) signature,md5(pg_get_functiondef(p.oid)) hash,p.proacl::text privileges FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f') r),
      'defaultPrivileges',(SELECT json_agg(r) FROM (SELECT defaclrole::regrole::text role,defaclobjtype::text kind,defaclacl::text privileges FROM pg_default_acl WHERE defaclnamespace='public'::regnamespace) r));
    ROLLBACK;`;
function local(sql) {
  const r = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local', 'psql', '-X', '-qAt', '-U', 'supabase_admin', '-d', 'sarita_deploy_preflight_20261017', '-v', 'ON_ERROR_STOP=1'],
    { input: sql, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(r.stderr || 'Local rehearsal failed');
  return r.stdout.trim();
}
function schema(result) {
  return { columns: result.columns, functions: result.functions.map(({ privileges, ...f }) => f) };
}
function deploymentSql() {
  const migration = fs.readFileSync(path.join(root, 'database_sql/migraciones/20261017_cpe_edicion_segura_pre_emision.sql'), 'utf8').replace(/\r\n/g, '\n');
  assert.ok(migration.startsWith('BEGIN;\n') && migration.endsWith('COMMIT;\n'), 'Expected exact transactional migration');
  const body = migration.slice('BEGIN;\n'.length, -'COMMIT;\n'.length);
  const catalogStatement = `INSERT INTO gen_lista_opciones(id_lista,nombre,descripcion)
    SELECT id,'CAMBIO_VSD','Cambio físico de balón de venta sin documento' FROM gen_lista WHERE nombre='TipoDocumentoRef'
      AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id_lista=gen_lista.id AND nombre='CAMBIO_VSD');`;
  assert.ok(body.includes(catalogStatement), 'Only authorized catalog insertion is present');
  // Fixed, reviewed final migration hash prevents this deployer from running arbitrary SQL.
  const hash = crypto.createHash('sha256').update(fs.readFileSync(path.join(root, 'database_sql/migraciones/20261017_cpe_edicion_segura_pre_emision.sql'))).digest('hex');
  assert.equal(hash, '89c7c9abce2c2d3f30d5f97444a363a2bda52da90898ebd0948ba7863660904f', 'Reviewed migration hash');
  return `BEGIN ISOLATION LEVEL REPEATABLE READ;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='90s';
SET LOCAL search_path=public,pg_catalog;
DO $$ DECLARE t record; BEGIN
  IF NOT pg_try_advisory_xact_lock(872019,20261017) THEN RAISE EXCEPTION 'Another deployment is active'; END IF;
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename LOOP
    EXECUTE format('LOCK TABLE public.%I IN SHARE MODE',t.tablename);
  END LOOP;
  IF to_regclass('public.ven_vsd_operacion') IS NOT NULL THEN RAISE EXCEPTION 'History already exists: review before retrying'; END IF;
  IF (SELECT count(*) FROM gen_lista WHERE nombre='TipoDocumentoRef')<>1 THEN RAISE EXCEPTION 'Ambiguous document reference catalog'; END IF;
  IF EXISTS(SELECT 1 FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='TipoDocumentoRef' AND lo.nombre='CAMBIO_VSD') THEN RAISE EXCEPTION 'Catalog already exists: review before retrying'; END IF;
END $$;
CREATE TEMP TABLE deploy_original_tables AS SELECT schemaname,tablename FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog','information_schema') AND schemaname NOT LIKE 'pg_temp%';
CREATE TEMP TABLE deploy_before(nombre text PRIMARY KEY, filas bigint, hash text);
CREATE FUNCTION pg_temp.deploy_snapshot() RETURNS TABLE(nombre text, filas bigint, hash text) LANGUAGE plpgsql AS $$
DECLARE t record; predicate text;
BEGIN
  FOR t IN SELECT * FROM deploy_original_tables ORDER BY schemaname,tablename LOOP
    predicate:=CASE WHEN t.schemaname='public' AND t.tablename='gen_lista_opciones'
      THEN ' WHERE NOT (nombre=''CAMBIO_VSD'' AND id_lista IN (SELECT id FROM public.gen_lista WHERE nombre=''TipoDocumentoRef''))' ELSE '' END;
    RETURN QUERY EXECUTE format('SELECT %L::text,count(*),md5(coalesce(string_agg(row_to_json(r)::text,%L ORDER BY row_to_json(r)::text),%L)) FROM %I.%I r%s',t.schemaname||'.'||t.tablename,'','',t.schemaname,t.tablename,predicate);
  END LOOP;
END $$;
INSERT INTO deploy_before SELECT * FROM pg_temp.deploy_snapshot();
CREATE TEMP TABLE deploy_sequences_before AS SELECT schemaname,sequencename,last_value FROM pg_sequences
  WHERE schemaname NOT IN ('pg_catalog','information_schema') AND schemaname NOT LIKE 'pg_temp%';
${body}
CREATE TEMP TABLE deploy_after AS SELECT * FROM pg_temp.deploy_snapshot();
DO $$ BEGIN
  IF EXISTS(SELECT * FROM deploy_before EXCEPT SELECT * FROM deploy_after)
    OR EXISTS(SELECT * FROM deploy_after EXCEPT SELECT * FROM deploy_before) THEN RAISE EXCEPTION 'Data verification failed: deployment rolled back'; END IF;
  IF (SELECT count(*) FROM ven_vsd_operacion)<>0 THEN RAISE EXCEPTION 'New history must be empty'; END IF;
  IF (SELECT count(*) FROM gen_lista_opciones lo JOIN gen_lista l ON l.id=lo.id_lista WHERE l.nombre='TipoDocumentoRef' AND lo.nombre='CAMBIO_VSD' AND lo.estado=1)<>1 THEN RAISE EXCEPTION 'Authorized catalog insertion failed'; END IF;
  IF EXISTS(SELECT 1 FROM deploy_sequences_before b JOIN pg_sequences a USING(schemaname,sequencename)
    WHERE (b.schemaname,b.sequencename)<>('public','gen_lista_opciones_id_seq') AND a.last_value IS DISTINCT FROM b.last_value)
    THEN RAISE EXCEPTION 'An unrelated sequence changed'; END IF;
END $$;
SELECT json_build_object('originalTablesUnchanged',(SELECT count(*) FROM deploy_before),'historyRows',(SELECT count(*) FROM ven_vsd_operacion),
  'catalogCambioVsd',1,'verifiedInTransaction',true,'tableHashes',(SELECT json_agg(b ORDER BY nombre) FROM deploy_before b));
COMMIT;
`;
}
const mode = process.argv[2];
if (mode === 'preflight') {
  const result = JSON.parse(production(metadataSql));
  fs.writeFileSync(path.join(output, 'preflight.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ database: result.database, user: result.user, version: result.version, historyExists: result.historyExists,
    catalogCambioVsd: result.catalogCambioVsd, publicColumns: result.columns.length, functions: result.functions.length, defaultPrivileges: result.defaultPrivileges }));
} else if (mode === 'rehearse') {
  const current = JSON.parse(fs.readFileSync(path.join(output, 'preflight.json'), 'utf8'));
  const original = JSON.parse(local(metadataSql));
  assert.deepEqual(schema(original), schema(current), 'Live production schema matches the tested original backup');
  const command = deploymentSql();
  fs.writeFileSync(path.join(output, 'aplicar-estructura.sql'), command);
  const result = JSON.parse(local(command));
  const expected = JSON.parse(local(metadataSql));
  fs.writeFileSync(path.join(output, 'expected-schema.json'), JSON.stringify(schema(expected), null, 2));
  fs.writeFileSync(path.join(output, 'ensayo.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ schemaMatchesProduction: true, originalTablesUnchanged: result.originalTablesUnchanged, historyRows: result.historyRows, catalogCambioVsd: result.catalogCambioVsd }));
} else if (mode === 'apply-authorized-production') {
  const backup = JSON.parse(fs.readFileSync(path.resolve(root, '../outputs/ventas-seguras/backup-latest.json'), 'utf8'));
  assert.ok(Date.now()-Date.parse(backup.createdAt)<30*60*1000, 'A successful fresh production backup is required');
  assert.ok(fs.existsSync(backup.localDump) && fs.statSync(backup.localDump).size===backup.bytes, 'Local backup exists and size matches');
  const baseline = JSON.parse(fs.readFileSync(path.join(output, 'preflight.json'), 'utf8'));
  const current = JSON.parse(production(metadataSql));
  assert.deepEqual(schema(current), schema(baseline), 'Production schema has not changed since rehearsal');
  assert.equal(current.defaultPrivileges, null, 'Review any new default privileges before DDL');
  const expected = JSON.parse(fs.readFileSync(path.join(output, 'expected-schema.json'), 'utf8'));
  const command = deploymentSql();
  assert.equal(command, fs.readFileSync(path.join(output, 'aplicar-estructura.sql'), 'utf8'), 'Execute exactly the rehearsed SQL');
  const result = JSON.parse(production(command, false));
  // Persist the confirmed commit before any post-deploy network operation.
  fs.writeFileSync(path.join(output, 'production-committed.json'), JSON.stringify({ committedAt: new Date().toISOString(), backup: backup.localDump, ...result }, null, 2));
  const after = JSON.parse(production(metadataSql));
  assert.deepEqual(schema(after), expected, 'Deployed schema and function definitions match local rehearsal');
  assert.equal(after.catalogCambioVsd, 1);
  assert.equal(after.historyExists, true);
  fs.writeFileSync(path.join(output, 'production-verified.json'), JSON.stringify({ verifiedAt: new Date().toISOString(), functionsMatch: true,
    originalTablesUnchanged: result.originalTablesUnchanged, historyRows: result.historyRows, catalogCambioVsd: after.catalogCambioVsd,
    publicFunctions: after.functions.length, publicColumns: after.columns.length }, null, 2));
  console.log(fs.readFileSync(path.join(output, 'production-verified.json'), 'utf8'));
} else {
  throw new Error('Use preflight | rehearse | apply-authorized-production');
}
