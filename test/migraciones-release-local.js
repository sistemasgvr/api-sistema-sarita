// HISTÓRICO, YA NO EJECUTABLE: lee migraciones sueltas de database_sql/migraciones/ que se retiraron en la
// limpieza del 2026-10-27 (database_sql/ ahora solo tiene migraciones/sync-*.sql). Se conserva como registro del
// ensayo de release del 2026-10-17; los archivos originales están en git (commit c07be19).
// Rehearsal against an explicitly named local Docker restoration. Never loads .env.
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const database = 'sarita_release_review_20261017';
const output = path.resolve(__dirname, '../../outputs/revision-produccion');
fs.mkdirSync(output, { recursive: true });
function sql(input) {
  const r = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local', 'psql', '-X', '-qAt', '-U', 'supabase_admin', '-d', database, '-v', 'ON_ERROR_STOP=1'], { input, encoding: 'utf8', maxBuffer: 30 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(r.stderr || 'Local migration rehearsal failed');
  return r.stdout.trim();
}
function snapshot() {
  return JSON.parse(sql(`BEGIN; CREATE TEMP TABLE release_snapshot(nombre text, filas bigint, hash text);
    DO $$ DECLARE t record; filter text; BEGIN
      FOR t IN SELECT schemaname,tablename FROM pg_tables
        WHERE schemaname NOT IN ('pg_catalog','information_schema') AND schemaname NOT LIKE 'pg_temp%'
          AND tablename<>'ven_vsd_operacion' ORDER BY schemaname,tablename LOOP
        filter := CASE WHEN t.schemaname='public' AND t.tablename='gen_lista_opciones'
          THEN ' WHERE NOT (nombre=''CAMBIO_VSD'' AND id_lista IN (SELECT id FROM gen_lista WHERE nombre=''TipoDocumentoRef''))' ELSE '' END;
        EXECUTE format('INSERT INTO release_snapshot SELECT %L,count(*),md5(coalesce(string_agg(row_to_json(r)::text,%L ORDER BY row_to_json(r)::text),%L)) FROM %I.%I r%s',
          t.schemaname||'.'||t.tablename,'','',t.schemaname,t.tablename,filter);
      END LOOP; END $$;
    SELECT json_agg(r ORDER BY nombre) FROM release_snapshot r; ROLLBACK;`));
}
const files = ['20261017_vsd_correccion_cambio_seguro.sql', '20261017_cpe_edicion_segura_pre_emision.sql'];
const before = snapshot();
const hashes = {};
for (const file of files) {
  const input = fs.readFileSync(path.resolve(__dirname, '../database_sql/migraciones', file), 'utf8');
  hashes[file] = require('node:crypto').createHash('sha256').update(input).digest('hex');
  sql("SET lock_timeout='5s'; SET statement_timeout='120s';\n" + input);
  assert.deepEqual(snapshot(), before, `${file}: existing rows preserved`);
}
const history = JSON.parse(sql("SELECT json_build_object('historyRows',(SELECT count(*) FROM ven_vsd_operacion),'catalogRows',(SELECT count(*) FROM gen_lista_opciones WHERE nombre='CAMBIO_VSD' AND id_lista IN (SELECT id FROM gen_lista WHERE nombre='TipoDocumentoRef')))"));
assert.equal(history.historyRows, 0);
assert.equal(history.catalogRows, 1);
// Execute the full business regression on the newly migrated original backup.
const log = sql(fs.readFileSync(path.resolve(__dirname, 'sql/vsd-correccion-cambio-seguro.sql'), 'utf8'));
fs.writeFileSync(path.join(output, 'sql-tests.log'), log);
assert.deepEqual(snapshot(), before, 'Regression preserves all original tables');
// Reapplying the final migration must preserve data and avoid duplicate catalog rows.
sql(fs.readFileSync(path.resolve(__dirname, '../database_sql/migraciones', files[1]), 'utf8'));
assert.deepEqual(snapshot(), before, 'Final migration can be repeated safely');
const after = snapshot();
fs.writeFileSync(path.join(output, 'integridad.json'), JSON.stringify({ before, after }, null, 2));
const result = { database, migrations: files, sha256: hashes, originalTablesUnchanged: before.length,
  historyRows: history.historyRows, catalogRows: history.catalogRows, sqlRegression: 'passed', finalMigrationReapplied: true };
fs.writeFileSync(path.join(output, 'resultado.json'), JSON.stringify(result, null, 2));
console.log(JSON.stringify(result, null, 2));
