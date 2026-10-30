// node test/rutas-pueblos-local.cjs
// Usa exclusivamente el contenedor local; no lee .env ni conecta a DEV/PROD.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root,
  'database_sql/migraciones/20261030_rutas_pueblos_consumo_entero.sql'), 'utf8');
const fixture = fs.readFileSync(path.join(__dirname, 'sql/rutas-pueblos-retorno.sql'), 'utf8');
const sql = 'BEGIN;\n' + migration.replace(/^BEGIN;\s*$/m, '').replace(/^COMMIT;\s*$/m, '')
  + '\n' + fixture + '\nROLLBACK;';
const result = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local',
  'psql', '-X', '-q', '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'],
  { input: sql, encoding: 'utf8' });
if (result.error) console.error(result.error.message);
process.stderr.write(result.stderr || '');
if (result.status !== 0) process.stdout.write(result.stdout || '');
process.exit(result.status ?? 1);
