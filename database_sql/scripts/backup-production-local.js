// Production is read only: credentials travel over stdin, never command arguments.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const output = path.resolve(root, '../outputs/ventas-seguras');
fs.mkdirSync(output, { recursive: true });
const line = fs.readFileSync(path.join(root, '.env'), 'utf8').split(/\r?\n/).find(s => /^DATABASE_URL=/.test(s));
if (!line) throw new Error('DATABASE_URL no encontrada');
const parsed = new URL(line.slice(line.indexOf('=') + 1).trim().replace(/^(['"])(.*)\1$/, '$2'));
// A dump needs one stable server session, not a transaction pooler.
if (parsed.hostname.endsWith('.pooler.supabase.com') && parsed.port === '6543') parsed.port = '5432';
parsed.searchParams.set('connect_timeout', '20');
const url = parsed.toString();
console.log(JSON.stringify({ sourceHost: parsed.hostname, port: parsed.port, database: parsed.pathname }));
const stamp = new Date().toISOString().replace(/[^0-9]/g, '').slice(0, 14);
const container = 'gvr-postgres-local';
const dump = `/tmp/sarita-production-${stamp}.dump`;
function docker(args, input) {
  const result = spawnSync('docker', args, { input, encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  if (result.status !== 0) throw new Error((result.stderr || result.error?.message || 'Docker falló').split(url).join('[REDACTED]'));
  return result.stdout;
}
// pg_dump takes a consistent snapshot of the complete database, all schemas/data.
docker(['exec', '-i', container, 'sh', '-c', 'IFS= read -r SOURCE_URL; export PGCONNECT_TIMEOUT=20 PGOPTIONS="-c default_transaction_read_only=on"; pg_dump --dbname="$SOURCE_URL" --format=custom --file="$1"', 'sh', dump], url + '\n');
const localDump = path.join(output, `production-${stamp}.dump`);
docker(['cp', `${container}:${dump}`, localDump]);
fs.writeFileSync(path.join(output, 'backup-latest.json'), JSON.stringify({ createdAt: new Date().toISOString(), container, containerDump: dump, localDump, bytes: fs.statSync(localDump).size }, null, 2));
console.log(JSON.stringify({ localDump, bytes: fs.statSync(localDump).size }));
