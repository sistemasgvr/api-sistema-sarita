// node test/rutas-pueblos-manual-local.cjs. Solo Docker local, sin .env ni DEV/PROD.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = p => fs.readFileSync(path.join(root, p), 'utf8');
const unwrapped = s => s.replace(/^BEGIN;\s*$/m, '').replace(/^COMMIT;\s*$/m, '');
const manualMigration = unwrapped(read('database_sql/migraciones/20261030_rutas_pueblos_gas_manual.sql'))
  .replace(/public\.(bal_ruta_pueblo_detalle|bal_ruta_pueblo|pro_producto)\b/g, 'test_ruta_retorno.$1');
const sql = 'BEGIN;\n'
  + unwrapped(read('database_sql/migraciones/20261030_rutas_pueblos_consumo_entero.sql'))
  + '\n' + read('test/sql/rutas-pueblos-retorno.sql')
  + '\n' + read('test/sql/rutas-pueblos-manual-setup.sql')
  + '\n' + read('database_sql/funciones/inventario/inv_signo_tipo_movimiento.sql')
  + '\n' + read('database_sql/funciones/inventario/inv_convertir_a_unidad_producto.sql')
  + '\n' + read('database_sql/funciones/inventario/inv_registrar_movimiento.sql')
  + '\n' + manualMigration + '\n' + manualMigration
  + '\n' + read('test/sql/rutas-pueblos-manual.sql') + '\nROLLBACK;';
const result = spawnSync('docker', ['exec', '-i', 'gvr-postgres-local', 'psql', '-X', '-q',
  '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'], { input: sql, encoding: 'utf8' });
process.stderr.write(result.stderr || '');
if (result.status !== 0) process.stdout.write(result.stdout || '');
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
