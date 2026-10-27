const test = require('node:test')
const assert = require('node:assert/strict')

const { moduloDe } = require('./modulos')
const { quitarComentarios } = require('./comentarios')
const { elegirVersion, normalizarCuerpo } = require('./version')
const { renderFuncion } = require('./render')

test('moduloDe', () => {
  assert.deepEqual(moduloDe('ven_crear_comprobante'), { modulo: 'ventas', conocido: true })
  assert.deepEqual(moduloDe('gre_listar'), { modulo: 'documentos-salida', conocido: true })
  assert.deepEqual(moduloDe('tra_obtener_trabajador'), { modulo: 'personal', conocido: true })
  assert.deepEqual(moduloDe('xyz_algo'), { modulo: 'general', conocido: false })
})

test('quitarComentarios respeta literales', () => {
  assert.equal(quitarComentarios("SELECT 1; -- fin\nSELECT 2;"), 'SELECT 1;\nSELECT 2;')
  assert.equal(quitarComentarios("SELECT '-- no'; /* x */ SELECT 2;"), "SELECT '-- no';  SELECT 2;")
  assert.equal(quitarComentarios("SELECT 'it''s -- ok';"), "SELECT 'it''s -- ok';")
  assert.equal(quitarComentarios("EXECUTE $q$ SELECT 1 -- interno $q$;"), "EXECUTE $q$ SELECT 1 -- interno $q$;")
  assert.equal(quitarComentarios("SELECT \"col--x\";"), "SELECT \"col--x\";")
  assert.equal(quitarComentarios("a;\n\n\n\nb;"), 'a;\n\nb;')
})

test('quitarComentarios entra al cuerpo de la función', () => {
  const def = "CREATE FUNCTION f() RETURNS int LANGUAGE plpgsql AS $function$\nBEGIN\n  -- quitar\n  RETURN 1; /* quitar */\nEND;\n$function$"
  assert.equal(quitarComentarios(def), "CREATE FUNCTION f() RETURNS int LANGUAGE plpgsql AS $function$\nBEGIN\n  RETURN 1; \nEND;\n$function$")
})

test('quitarComentarios no cruza el cierre del cuerpo', () => {
  // Literal E'...' sin cerrar cuyo último carácter es "\" justo antes de $function$
  assert.equal(quitarComentarios("AS $function$ x := E'ab\\$function$"), "AS $function$ x := E'ab\\$function$")
  assert.equal(quitarComentarios("AS $function$ x := 'a'$function$;"), "AS $function$ x := 'a'$function$;")
  assert.equal(quitarComentarios('AS $function$ x := "a$function$ -- c'), 'AS $function$ x := "a$function$')
})

test('elegirVersion', () => {
  const A = { args: 'p int', def: 'AS $function$ A $function$' }, B = { args: 'p int', def: 'AS $function$ B $function$' }
  assert.equal(elegirVersion({ dev: [A], prod: [A], repoCuerpos: new Set() }).origen, 'ambas')
  assert.equal(elegirVersion({ dev: [A], prod: [B], repoCuerpos: new Set([normalizarCuerpo(A.def)]) }).origen, 'dev')
  assert.equal(elegirVersion({ dev: [A], prod: [B], repoCuerpos: new Set([normalizarCuerpo(B.def)]) }).origen, 'prod')
  assert.equal(elegirVersion({ dev: [A], prod: [B], repoCuerpos: new Set() }).origen, 'pendiente')
  assert.equal(elegirVersion({ prod: [B], repoCuerpos: new Set() }).origen, 'prod')
  const viejo = { args: 'p int', def: A.def }, nuevo = { args: 'p int, q int', def: B.def }
  const r = elegirVersion({ dev: [viejo], prod: [nuevo], repoCuerpos: new Set([normalizarCuerpo(B.def)]) })
  assert.deepEqual([r.origen, r.firmasObsoletas], ['prod', ['p int']])
})

test('renderFuncion', () => {
  const out = renderFuncion('f', 'Devuelve uno', [{ args: 'p int', def: 'CREATE OR REPLACE FUNCTION public.f(p int)\n RETURNS int\nAS $function$ -- x\nSELECT 1 $function$' }])
  assert.ok(out.startsWith('-- Devuelve uno\nDROP FUNCTION IF EXISTS public.f(p int);\n\nCREATE OR REPLACE FUNCTION public.f(p int)'))
  assert.ok(!out.includes('-- x'))
  assert.ok(out.trimEnd().endsWith('$function$;'))
})

test('elegirVersion con línea base (decisión anterior)', () => {
  const A = { args: 'p int', def: 'AS $function$ A $function$' }
  const B = { args: 'p int', def: 'AS $function$ B $function$' }
  const C = { args: 'p int', def: 'AS $function$ C $function$' }
  const base = { origen: 'ambas', firmas: [A] }
  const repoA = new Set([normalizarCuerpo(A.def)])
  // Edición directa en DEV: repo == PROD == base, pero solo DEV cambió → dev (no revertir).
  assert.equal(elegirVersion({ dev: [B], prod: [A], repoCuerpos: repoA, base }).origen, 'dev')
  assert.equal(elegirVersion({ dev: [B], prod: [A], repoCuerpos: repoA }).origen, 'prod') // sin base: regla del repo
  // Solo PROD cambió → prod.
  assert.equal(elegirVersion({ dev: [A], prod: [B], repoCuerpos: repoA, base }).origen, 'prod')
  // Cambiaron las dos → pendiente, aunque el repo coincida con una.
  assert.equal(elegirVersion({ dev: [B], prod: [C], repoCuerpos: new Set([normalizarCuerpo(B.def)]), base }).origen, 'pendiente')
  // Iguales → ambas, con o sin base.
  assert.equal(elegirVersion({ dev: [B], prod: [B], base }).origen, 'ambas')
  // Base que no fue 'ambas', o vacía → regla del repo.
  const repoB = new Set([normalizarCuerpo(B.def)])
  assert.equal(elegirVersion({ dev: [A], prod: [B], repoCuerpos: repoB, base: { origen: 'dev', firmas: [A] } }).origen, 'prod')
  assert.equal(elegirVersion({ dev: [A], prod: [B], repoCuerpos: repoB, base: { origen: 'ambas', firmas: [] } }).origen, 'prod')
  // Firma nueva solo en DEV respecto de la base → dev, con la firma vieja de PROD obsoleta.
  const nueva = { args: 'p int, q int', def: B.def }
  const r = elegirVersion({ dev: [nueva], prod: [A], repoCuerpos: repoA, base })
  assert.deepEqual([r.origen, r.firmasObsoletas], ['dev', ['p int']])
})

test('descripcionDe', () => {
  const { descripcionDe } = require('./descripcion')
  assert.equal(descripcionDe('gen_listar_almacenes', {}), 'Lista almacenes con filtros y paginación')
  assert.equal(descripcionDe('ven_obtener_comprobante', {}), 'Obtiene comprobante por id')
  assert.equal(descripcionDe('crear_cliente', {}), 'Crea cliente')
  assert.equal(descripcionDe('inv_eliminar_producto', {}), 'Elimina (lógicamente) producto')
  assert.equal(descripcionDe('inv_restaurar_producto', {}), 'Restaura producto eliminado')
  assert.equal(descripcionDe('gen_actualizar_almacen_stock', {}), 'Actualiza almacen stock')
  assert.throws(() => descripcionDe('fin_caja_calcular_totales', {}))
  assert.throws(() => descripcionDe('gen_listar', {}))
  assert.equal(descripcionDe('fin_caja_calcular_totales', { fin_caja_calcular_totales: 'Calcula totales' }), 'Calcula totales')
  assert.equal(descripcionDe('gen_listar_almacenes', { gen_listar_almacenes: 'Otra' }), 'Otra')
})
