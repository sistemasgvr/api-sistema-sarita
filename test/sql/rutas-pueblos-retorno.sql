-- Solo PostgreSQL local. Cargar primero las funciones modificadas, en la misma
-- transacción que este fixture. El ejecutor debe hacer ROLLBACK al terminar.
CREATE SCHEMA test_ruta_retorno;
SET LOCAL search_path = test_ruta_retorno, public;
CREATE TABLE gen_lista (id integer, nombre text);
CREATE TABLE gen_lista_opciones (id integer, nombre text, id_lista integer, estado integer DEFAULT 1);
CREATE TABLE pro_producto (id integer, estado integer DEFAULT 1, factor_kg_m3 numeric, factor_lb_m3 numeric);
CREATE TABLE bal_tipo_balon (id integer, nombre text, estado integer DEFAULT 1,
    capacidad numeric, capacidad_lb numeric, id_unidad_medida integer, id_gas integer);
CREATE TABLE bal_balon (id integer, codigo_balon text, estado integer DEFAULT 1,
    id_tipo_balon integer, id_producto_gas integer, id_almacen integer,
    id_cliente_ubicacion integer, id_estado_balon integer,
    id_usuario_modificacion integer, fecha_modificacion timestamp);
CREATE TABLE bal_ruta_pueblo (id integer, estado integer DEFAULT 1, id_estado integer,
    id_almacen integer, factor_lb_m3 numeric, m3_calculado numeric,
    id_usuario_modificacion integer, fecha_modificacion timestamp);
CREATE TABLE bal_ruta_pueblo_detalle (id integer, id_ruta_pueblo integer, id_balon integer,
    estado integer DEFAULT 1, lb_salida numeric, lb_retorno numeric, m3_delta numeric,
    capacidad_restante_m3 numeric, observacion text, id_usuario_modificacion integer,
    fecha_modificacion timestamp);
CREATE TABLE bal_ruta_pueblo_detalle_producto (id_ruta_pueblo integer, estado integer);

-- Campos de lectura para probar también la respuesta real de la ruta.
CREATE TABLE gen_almacen (id integer, nombre text);
CREATE TABLE auth_usuarios (id integer, nombre text);
CREATE TABLE gen_chofer (id integer, nombres text, apellido_paterno text, apellido_materno text);
ALTER TABLE pro_producto ADD COLUMN codigo text, ADD COLUMN nombre text;
ALTER TABLE bal_ruta_pueblo ADD COLUMN fecha date, ADD COLUMN id_usuario_responsable integer,
    ADD COLUMN id_chofer integer, ADD COLUMN tolerancia_m3 numeric DEFAULT 0.5,
    ADD COLUMN m3_reportado_ventas numeric, ADD COLUMN descuadre_m3 numeric,
    ADD COLUMN observacion text, ADD COLUMN fecha_creacion timestamp;
ALTER TABLE bal_ruta_pueblo_detalle ADD COLUMN sellado boolean DEFAULT false;
ALTER TABLE bal_ruta_pueblo_detalle_producto ADD COLUMN id integer, ADD COLUMN id_producto integer,
    ADD COLUMN cantidad numeric, ADD COLUMN cantidad_retorno numeric, ADD COLUMN observacion text;

CREATE FUNCTION test_ruta_retorno.bal_registrar_salida_documento(integer, varchar, integer,
    varchar, integer, integer, varchar, boolean, integer, varchar, integer) RETURNS json
LANGUAGE plpgsql AS $$ BEGIN
    IF current_setting('test_ruta.mov_falla', true) = 'si' THEN
        RETURN json_build_object('error', 'Movimiento bloqueado para prueba');
    END IF;
    RETURN json_build_object('error', NULL, 'creado', true);
END $$;
CREATE FUNCTION test_ruta_retorno.ok(boolean, text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    IF $1 IS DISTINCT FROM TRUE THEN RAISE EXCEPTION 'FAIL: %', $2; END IF;
    RAISE NOTICE 'OK: %', $2;
END $$;

INSERT INTO gen_lista VALUES (1, 'EstadoBalon'), (2, 'EstadoRutaPueblo');
INSERT INTO gen_lista_opciones(id, nombre, id_lista) VALUES
    (1, 'MT3', NULL), (2, 'KG', NULL), (3, 'LB', NULL),
    (4, 'EN_RUTA', NULL), (5, 'DISPONIBLE', 1), (6, 'ABIERTA', NULL), (7, 'CERRADA', 2);
INSERT INTO pro_producto(id, estado, factor_kg_m3, factor_lb_m3) VALUES (1, 1, 0.5, 0.25);
INSERT INTO bal_tipo_balon VALUES
    (1, 'En m3', 1, 10, 20, 1, 1),
    (2, 'En kg', 1, 20, 40, 2, 1),
    (3, 'En lb', 1, 40, 40, 3, 1);
INSERT INTO bal_balon(id, codigo_balon, id_tipo_balon) VALUES
    (1, 'TEST-M3', 1), (2, 'TEST-KG', 2), (3, 'TEST-LB', 3);
SELECT ok(bal_factor_ruta_balon(1) = 0.5, 'Capacidad en m3: factor 10/20');
SELECT ok(bal_factor_ruta_balon(2) = 0.25, 'Capacidad en kg: factor (20*0.5)/40');
SELECT ok(bal_factor_ruta_balon(3) = 0.25, 'Capacidad en lb: factor (40*0.25)/40');

DO $$ BEGIN
    UPDATE pro_producto SET factor_kg_m3 = NULL;
    BEGIN
        PERFORM public.bal_factor_ruta_balon(2);
        RAISE EXCEPTION 'FAIL: Debe rechazar kg sin equivalencia';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%factor de kg a m³%', 'Error indica la equivalencia faltante');
    END;
    PERFORM ok(public.bal_factor_ruta_balon(2, FALSE) IS NULL, 'Lectura sin equivalencia no inventa factor');
    UPDATE pro_producto SET factor_kg_m3 = 0.5;
END $$;

INSERT INTO bal_ruta_pueblo(id, id_estado, id_almacen) VALUES (1, 4, 1);
INSERT INTO bal_ruta_pueblo_detalle(id, id_ruta_pueblo, id_balon, lb_salida) VALUES
    (1, 1, 1, 20), (2, 1, 2, 40), (3, 1, 3, 40);

SELECT public.bal_registrar_retorno_ruta_pueblo(1, '[{"idBalon":1,"lbRetorno":4}]');
SELECT ok(lb_retorno = 4 AND m3_delta = 8 AND capacidad_restante_m3 = 2,
    'Retorno guarda consumo y residual en m3') FROM bal_ruta_pueblo_detalle WHERE id = 1;
SELECT ok(m3_calculado = 8, 'Acumulado de ruta correcto') FROM bal_ruta_pueblo WHERE id = 1;

DO $$ BEGIN
    BEGIN
        PERFORM public.bal_registrar_retorno_ruta_pueblo(1, '[{"idBalon":2,"lbRetorno":41}]');
        RAISE EXCEPTION 'FAIL: Debe rechazar retorno mayor a salida';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%no puede superar lb salida%', 'Error de retorno muestra causa real');
    END;
    PERFORM set_config('test_ruta.mov_falla', 'si', true);
    BEGIN
        PERFORM public.bal_registrar_retorno_ruta_pueblo(1, '[{"idBalon":2,"lbRetorno":10}]');
        RAISE EXCEPTION 'FAIL: Debe propagar error del movimiento';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%Movimiento bloqueado para prueba%', 'Propaga error del movimiento');
    END;
    PERFORM ok((SELECT lb_retorno IS NULL FROM bal_ruta_pueblo_detalle WHERE id = 2),
        'Movimiento fallido revierte el retorno');
    PERFORM set_config('test_ruta.mov_falla', 'no', true);
END $$;

SELECT public.bal_registrar_retorno_ruta_pueblo(1, '[{"idBalon":2,"lbRetorno":10},{"idBalon":3,"lbRetorno":0}]');
SELECT ok(m3_calculado = 25, 'Ruta mixta trunca la suma de todos los cilindros')
FROM bal_ruta_pueblo WHERE id = 1;

SELECT ok((public.bal_obtener_ruta_pueblo(1)->'registro'->>'m3_calculado_exacto')::numeric = 25.5,
    'Respuesta conserva total exacto');
SELECT ok((public.bal_obtener_ruta_pueblo(1)->'registro'->>'ajuste_truncamiento_m3')::numeric = -0.5,
    'Respuesta registra ajuste con signo negativo');
SELECT ok(public.bal_obtener_ruta_pueblo(1)->'registro'->>'observacion_truncamiento' LIKE '%-0.5%',
    'Comentario automático explica la fracción descartada');
SELECT public.bal_cerrar_ruta_pueblo(1, 25, 'Observación del usuario');
SELECT ok(m3_calculado = 25 AND descuadre_m3 = 0 AND observacion = 'Observación del usuario',
    'Cierre usa total truncado y respeta observación manual') FROM bal_ruta_pueblo WHERE id = 1;
SELECT public.bal_cerrar_ruta_pueblo(1, 25);
SELECT ok((public.bal_obtener_ruta_pueblo(1)->'registro'->>'ajuste_truncamiento_m3')::numeric = -0.5,
    'Repetir cierre conserva ajuste sin acumularlo');

INSERT INTO bal_ruta_pueblo(id, id_estado, id_almacen) VALUES (2, 4, 1), (3, 4, 1), (4, 4, 1);
INSERT INTO bal_ruta_pueblo_detalle(id, id_ruta_pueblo, id_balon, lb_salida) VALUES
    (4, 2, 1, 2), (5, 2, 2, 4), (6, 3, 1, 2), (7, 4, 1, 20), (8, 4, 2, 4);
SELECT public.bal_registrar_retorno_ruta_pueblo(2, '[{"idBalon":1,"lbRetorno":0.8}]');
SELECT ok(m3_calculado = 0, 'Retorno parcial menor a 1 m3 queda en cero') FROM bal_ruta_pueblo WHERE id = 2;
SELECT public.bal_registrar_retorno_ruta_pueblo(2, '[{"idBalon":2,"lbRetorno":1.6}]');
SELECT ok(m3_calculado = 1, 'Retornos sucesivos suman 0.6 + 0.6 antes de truncar') FROM bal_ruta_pueblo WHERE id = 2;
SELECT ok((SELECT SUM(m3_delta) FROM bal_ruta_pueblo_detalle WHERE id_ruta_pueblo = 2) = 1.2,
    'Conserva decimales individuales para retornos parciales');
SELECT public.bal_registrar_retorno_ruta_pueblo(2, '[{"idBalon":2,"lbRetorno":1.6}]');
SELECT ok(m3_calculado = 1, 'Repetir retorno no acumula consumo ni ajuste') FROM bal_ruta_pueblo WHERE id = 2;
SELECT public.bal_registrar_retorno_ruta_pueblo(3, '[{"idBalon":1,"lbRetorno":0}]');
SELECT ok(public.bal_obtener_ruta_pueblo(3)->'registro'->>'observacion_truncamiento' IS NULL,
    'Consumo entero no genera comentario de ajuste');
SELECT public.bal_registrar_retorno_ruta_pueblo(4, '[{"idBalon":1,"lbRetorno":0},{"idBalon":2,"lbRetorno":1.6}]');
SELECT ok(m3_calculado = 10, 'Ejemplo 10.6 m3 se registra como 10') FROM bal_ruta_pueblo WHERE id = 4;
SELECT ok((public.bal_obtener_ruta_pueblo(4)->'registro'->>'ajuste_truncamiento_m3')::numeric = -0.6,
    'Ejemplo 10.6 m3 conserva ajuste de -0.6');
