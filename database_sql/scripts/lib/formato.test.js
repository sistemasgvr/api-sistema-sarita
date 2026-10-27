const test = require('node:test')
const assert = require('node:assert')
const { formatearSql, equivalentes } = require('./formato')
const { argsIdentidad, sentenciasCreate } = require('../regenerar-funciones')

const FN = `-- Obtiene algo
drop function if exists public.f(p_id integer);

create or replace function public.f(p_id integer)
 returns json
 language plpgsql
as $function$
declare   x  int;
begin
  select 'a  b' into x;   return null;
end;
$function$;
`

test('formatearSql: cuerpo dollar-quoted intacto, comentario en línea 1, idempotente', () => {
  const r = formatearSql(FN)
  assert.ok(r.ok)
  const cuerpo = (s) => s.slice(s.indexOf('$function$'), s.lastIndexOf('$function$'))
  assert.strictEqual(cuerpo(r.texto), cuerpo(FN))
  assert.ok(r.texto.startsWith('-- Obtiene algo\nDROP FUNCTION '))
  assert.strictEqual(formatearSql(r.texto).texto, r.texto)
})

test('equivalentes: detecta cambios en literales', () => {
  assert.ok(equivalentes("select 'a'", "SELECT  'a'"))
  assert.ok(!equivalentes("select 'a'", "select 'A'"))
})

test('argsIdentidad quita DEFAULT y =', () => {
  assert.strictEqual(
    argsIdentidad('p_id integer, p_x varchar DEFAULT NULL, p_n numeric(10, 2) = 0'),
    'p_id integer, p_x varchar, p_n numeric(10, 2)',
  )
})

test('sentenciasCreate califica el nombre con public. y no toca el cuerpo', () => {
  const [s] = sentenciasCreate('CREATE OR REPLACE FUNCTION g(a int) RETURNS int AS $$ select 1 $$ LANGUAGE sql;')
  assert.strictEqual(s.nombre, 'g')
  assert.strictEqual(s.def, 'CREATE OR REPLACE FUNCTION public.g(a int) RETURNS int AS $$ select 1 $$ LANGUAGE sql')
})
