-- ============================================================
-- Migración: custodia del reparto y candado de consistencia del recojo
-- Fecha: 2026-09-10
--
-- Continúa la regla fijada en
-- database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql: una validación
-- que falla DESPUÉS de haber mutado datos no puede devolverse como json
-- {'error': ...}; la función retorna normalmente, la transacción se confirma y
-- el cambio parcial queda grabado. Ese caso es RAISE (rollback).
--
-- Custodia de cilindros en el reparto
--  1) age_iniciar_entrega: el descuadre entre cilindros esperados y
--     actualizados se detecta con bal_balon ya mutado. Era un error soft, así
--     que la actividad no pasaba a EN_RUTA pero los cilindros que sí cambiaron
--     quedaban EN_TRANSITO sin viaje. Ahora es RAISE.
--  2) age_culminar_entrega: el mismo descuadre, también RAISE. Además se exige
--     el juego COMPLETO de cilindros en custodia (EN_TRANSITO /
--     PENDIENTE_ENVIO), igual que iniciar: con el "al menos uno" anterior
--     bastaba un cilindro en tránsito para cerrar la entrega y el resto se
--     quedaba fuera de EN_PODER_CLIENTE.
--  3) age_eliminar_actividad: EN_RUTA y REALIZADA dejan de poder eliminarse
--     (una en ruta se cancela, que es lo que devuelve los cilindros; una
--     realizada no se deshace por baja lógica). Y al revertir EN_TRANSITO se
--     restituye el almacén de la OS, como ya hacía age_cancelar_actividad: sin
--     eso el cilindro volvía a PENDIENTE_ENVIO con id_almacen NULL, es decir
--     comprometido y en ninguna parte.
--
-- Candado de consistencia del recojo de préstamos y alquileres
--  Actividades y el módulo Balones > Recojos conviven: ambos pueden programar
--  el recojo de un origen. Lo que no se admite es tener los dos vivos sobre el
--  mismo préstamo o alquiler, porque serían dos rutas y dos cierres moviendo el
--  estado de los mismos cilindros. El rechazo es previo a cualquier mutación
--  (error soft) y dice dónde está el duplicado.
--  4) age_crear_recojo_origen: rechaza el origen con visita bal_recojo
--     PROGRAMADO / EN_RUTA.
--  5) bal_crear_recojo: rechaza el origen con actividad RECOJO vigente. El
--     camino de recarga en planta (p_id_recarga_planta) queda intacto: ese
--     recojo solo existe en bal_recojo y no tiene contraparte en la agenda.
--  6) age_listar_vencidos_recojo: excluye los orígenes que ya tienen recojo
--     vivo en cualquiera de los dos módulos, que desde (4) ya no admiten
--     actividad.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260910_age_custodia_recojo_candado.sql
-- ============================================================


-- ============================================================
-- database_sql/funciones/actividades/age_iniciar_entrega.sql
-- ============================================================
-- Function: age_iniciar_entrega
-- Source: migraciones/20260909_age_reparto_flujo_entrega.sql
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
-- el descuadre de cilindros actualizados se detecta con bal_balon ya mutado, así
-- que es RAISE (rollback) y no un error soft que dejaría la custodia a medias.

DROP FUNCTION IF EXISTS age_iniciar_entrega(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_entrega(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act            RECORD;
    v_nombre_estado  VARCHAR;
    v_nombre_tipo    VARCHAR;
    v_id_en_ruta     INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pend_envio  INTEGER;
    v_id_transito    INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
    v_cilindros_tot  INTEGER := 0;
    v_cilindros_esp  INTEGER := 0;
    v_cilindros_upd  INTEGER := 0;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_usuario_responsable, a.id_estado_actividad
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
    FROM gen_lista_opciones lo WHERE lo.id = v_act.id_estado_actividad;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_tipo
    FROM age_actividad a JOIN gen_lista_opciones lo ON lo.id = a.id_tipo_actividad
    WHERE a.id = p_id;

    IF COALESCE(v_nombre_tipo, '') <> 'REPARTO' THEN
        RETURN json_build_object('error', 'Solo las actividades de REPARTO tienen flujo de entrega', 'registro', NULL);
    END IF;

    IF v_nombre_estado IN ('REALIZADA', 'CANCELADA', 'CANCELADO') THEN
        RETURN json_build_object('error', format('La actividad ya esta %s', v_nombre_estado), 'registro', NULL);
    END IF;

    IF v_nombre_estado = 'EN_RUTA' THEN
        RETURN json_build_object('error', 'La entrega ya esta en ruta', 'registro', NULL);
    END IF;

    -- Sin responsable no hay quien responda por la carga que sale.
    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object('error', 'Asigna un responsable antes de iniciar la entrega', 'registro', NULL);
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para iniciar la entrega',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_act.id_trabajador_responsable IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_act.id_trabajador_responsable)
        OR (v_act.id_usuario_responsable IS NOT NULL AND p_id_usuario_auditoria = v_act.id_usuario_responsable)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede iniciar esta entrega',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_en_ruta
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'EN_RUTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_en_ruta IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado EN_RUTA en EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_ok
                           AND ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida = v_id_observado)
    INTO v_items, v_pendientes, v_observados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_items = 0 THEN
        RETURN json_build_object('error', 'La actividad no tiene items que verificar', 'registro', NULL);
    END IF;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format('Faltan %s item(s) por verificar en la salida', v_pendientes),
            'registro', NULL
        );
    END IF;

    -- CON_OBSERVACION no bloquea: es un aviso leve que queda registrado.
    -- Solo los pendientes impiden salir del almacen.

    -- ------------------------------------------------------------
    -- Custodia: PENDIENTE_ENVIO -> EN_TRANSITO
    --
    -- Sin esto el cilindro sigue diciendo "en preparacion, en el almacen"
    -- mientras va en el camion. EN_TRANSITO ya existia en el catalogo, creado
    -- justo para esto ("Se cambia el estado cuando se inicie la actividad") y
    -- nunca cableado.
    --
    -- Como en doc_crear_desde_venta, es un UPDATE directo y no un movimiento de
    -- inventario: el stock ya salio con la venta, registrar otro movimiento lo
    -- contaria dos veces. Esto solo marca donde esta fisicamente el envase.
    --
    -- El camino de vuelta lo hace age_cancelar_actividad. Sin el, un reparto
    -- cancelado dejaria cilindros en transito para siempre.
    -- ------------------------------------------------------------
    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_pend_envio IS NULL OR v_id_transito IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados PENDIENTE_ENVIO o EN_TRANSITO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE ai.id_balon IS NOT NULL),
        COUNT(*) FILTER (WHERE ai.id_balon IS NOT NULL AND b.id_estado_balon = v_id_pend_envio)
    INTO v_cilindros_tot, v_cilindros_esp
    FROM age_actividad_item ai
    LEFT JOIN bal_balon b ON b.id = ai.id_balon AND b.estado = 1
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    -- Accesorios-only: sin cilindros no se exige custodia.
    -- Con cilindros se exige que TODOS esten en PENDIENTE_ENVIO (no "al menos uno").
    IF v_cilindros_tot > 0 AND v_cilindros_esp < v_cilindros_tot THEN
        RETURN json_build_object(
            'error', format(
                'Faltan %s cilindro(s) en PENDIENTE_ENVIO para iniciar la entrega (hay %s de %s)',
                v_cilindros_tot - v_cilindros_esp,
                v_cilindros_esp,
                v_cilindros_tot
            ),
            'registro', NULL
        );
    END IF;

    -- Custodia primero: si falla, la actividad no queda EN_RUTA a medias.
    -- id_almacen = NULL: ya no esta en el almacen, va en el camion.
    UPDATE bal_balon b
    SET id_estado_balon = v_id_transito,
        id_almacen = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id
      AND ai.estado = 1
      AND ai.id_balon = b.id
      AND b.estado = 1
      AND b.id_estado_balon = v_id_pend_envio;

    GET DIAGNOSTICS v_cilindros_upd = ROW_COUNT;

    -- El UPDATE ya corrió: un error soft aquí confirmaría los cilindros que sí
    -- cambiaron y dejaría la custodia partida entre almacén y camión.
    IF v_cilindros_esp > 0 AND v_cilindros_upd <> v_cilindros_esp THEN
        RAISE EXCEPTION
            'No se actualizaron todos los cilindros a EN_TRANSITO (se esperaban %, se actualizaron %)',
            v_cilindros_esp, v_cilindros_upd;
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/actividades/age_culminar_entrega.sql
-- ============================================================
-- Function: age_culminar_entrega
-- Source: migraciones/20260909_age_culminar_entrega_custodia.sql
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
--   · se exige el juego COMPLETO de cilindros en custodia, igual que
--     age_iniciar_entrega. Con "al menos uno" bastaba un cilindro en tránsito
--     para cerrar la entrega y los demás quedaban colgados en su estado previo;
--   · el descuadre posterior al UPDATE es RAISE (rollback), no error soft.

DROP FUNCTION IF EXISTS age_culminar_entrega(integer, integer);

CREATE OR REPLACE FUNCTION age_culminar_entrega(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act            RECORD;
    v_nombre_estado  VARCHAR;
    v_id_realizada   INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pend_envio  INTEGER;
    v_id_transito    INTEGER;
    v_id_en_poder    INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
    v_cilindros_tot  INTEGER := 0;
    v_cilindros_esp  INTEGER := 0;
    v_cilindros_upd  INTEGER := 0;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_cliente, a.id_trabajador_responsable, a.id_usuario_responsable,
           UPPER(TRIM(lo.nombre)) AS nombre_estado
    INTO v_act
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones lo ON lo.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    v_nombre_estado := v_act.nombre_estado;

    -- Culminar exige haber pasado por EN_RUTA: si no, la verificacion de salida
    -- nunca se exigio y la de llegada no prueba nada.
    IF COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede culminar una entrega que este EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF v_act.id_trabajador_responsable IS NULL AND v_act.id_usuario_responsable IS NULL THEN
        RETURN json_build_object(
            'error', 'Asigna un responsable antes de culminar la entrega',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para culminar la entrega',
            'registro', NULL
        );
    END IF;

    SELECT u.id_trabajador INTO v_id_trabajador_sesion
    FROM auth_usuarios u
    WHERE u.id = p_id_usuario_auditoria AND u.estado = TRUE;

    IF NOT (
        (v_act.id_trabajador_responsable IS NOT NULL AND v_id_trabajador_sesion IS NOT NULL
            AND v_id_trabajador_sesion = v_act.id_trabajador_responsable)
        OR (v_act.id_usuario_responsable IS NOT NULL AND p_id_usuario_auditoria = v_act.id_usuario_responsable)
    ) THEN
        RETURN json_build_object(
            'error', 'Solo el responsable asignado (usuario de sesion) puede culminar esta entrega',
            'registro', NULL
        );
    END IF;

    -- Se acota a la lista EstadoActividad: buscar 'realizada' suelto puede
    -- traer la opcion homonima de otra lista.
    SELECT lo.id INTO v_id_realizada
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'REALIZADA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_realizada IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado REALIZADA en EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_ok
                           AND ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada = v_id_observado)
    INTO v_items, v_pendientes, v_observados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format('Faltan %s item(s) por verificar en la llegada', v_pendientes),
            'registro', NULL
        );
    END IF;

    -- CON_OBSERVACION no bloquea: un arañazo o detalle leve queda en la
    -- bitacora y en el item, pero la entrega puede culminarse.

    -- ------------------------------------------------------------
    -- Cierre de custodia: EN_TRANSITO / PENDIENTE_ENVIO -> EN_PODER_CLIENTE
    -- ------------------------------------------------------------
    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    -- Lo normal es venir de EN_TRANSITO (lo puso iniciar entrega), pero se
    -- acepta tambien PENDIENTE_ENVIO: hay actividades anteriores a que
    -- existiera el transito, y el catalogo podria faltar en alguna instalacion.
    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_en_poder
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_PODER_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_en_poder IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontro el estado EN_PODER_CLIENTE en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    IF v_id_transito IS NULL AND v_id_pend_envio IS NULL THEN
        RETURN json_build_object(
            'error', 'Faltan estados EN_TRANSITO / PENDIENTE_ENVIO en catalogo EstadoBalon',
            'registro', NULL
        );
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE ai.id_balon IS NOT NULL),
        COUNT(*) FILTER (
            WHERE ai.id_balon IS NOT NULL
              AND b.id_estado_balon IN (v_id_transito, v_id_pend_envio)
        )
    INTO v_cilindros_tot, v_cilindros_esp
    FROM age_actividad_item ai
    LEFT JOIN bal_balon b ON b.id = ai.id_balon AND b.estado = 1
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    -- Accesorios-only: sin cilindros no se exige custodia.
    -- Con cilindros se exige que TODOS esten en custodia (no "al menos uno"):
    -- cerrar con un subconjunto dejaba al resto fuera de EN_PODER_CLIENTE.
    IF v_cilindros_tot > 0 AND v_cilindros_esp < v_cilindros_tot THEN
        RETURN json_build_object(
            'error', format(
                'Faltan %s cilindro(s) en EN_TRANSITO o PENDIENTE_ENVIO para culminar la entrega (hay %s de %s)',
                v_cilindros_tot - v_cilindros_esp,
                v_cilindros_esp,
                v_cilindros_tot
            ),
            'registro', NULL
        );
    END IF;

    -- Custodia primero: si falla, la actividad no queda REALIZADA a medias.
    UPDATE bal_balon b
    SET id_estado_balon = v_id_en_poder,
        -- Un cilindro en poder del cliente sin cliente_ubicacion seria un
        -- estado roto; si la venta ya lo apunto, se respeta.
        id_cliente_ubicacion = COALESCE(b.id_cliente_ubicacion, v_act.id_cliente),
        id_almacen = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id
      AND ai.estado = 1
      AND ai.id_balon = b.id
      AND b.estado = 1
      AND b.id_estado_balon IN (v_id_transito, v_id_pend_envio);

    GET DIAGNOSTICS v_cilindros_upd = ROW_COUNT;

    -- El UPDATE ya corrió: un error soft aquí confirmaría los cilindros que sí
    -- cambiaron y dejaría la entrega cerrada a medias.
    IF v_cilindros_esp > 0 AND v_cilindros_upd <> v_cilindros_esp THEN
        RAISE EXCEPTION
            'No se actualizaron todos los cilindros a EN_PODER_CLIENTE (se esperaban %, se actualizaron %)',
            v_cilindros_esp, v_cilindros_upd;
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/actividades/age_eliminar_actividad.sql
-- ============================================================
-- Function: age_eliminar_actividad
-- Baja lógica + revierte custodia EN_TRANSITO -> PENDIENTE_ENVIO
-- (mismo camino de vuelta que age_cancelar_actividad).
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
--   · EN_RUTA y REALIZADA ya no se pueden eliminar. Una actividad en ruta debe
--     cancelarse (age_cancelar_actividad) y una realizada no se deshace por
--     baja lógica: borrarlas por aquí saltaba los cierres de custodia;
--   · al revertir EN_TRANSITO se restituye el almacén de la OS, igual que
--     cancelar. Sin ello el cilindro volvía a PENDIENTE_ENVIO con
--     id_almacen NULL, es decir comprometido y en ninguna parte.

DROP FUNCTION IF EXISTS age_eliminar_actividad(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_eliminar_actividad(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado VARCHAR;
    v_id_transito   INTEGER;
    v_id_pend_envio INTEGER;
    v_id_almacen_os INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT UPPER(TRIM(ea.nombre))
    INTO v_nombre_estado
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_nombre_estado = 'EN_RUTA' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'La actividad está EN_RUTA; cancélala para devolver los cilindros antes de eliminarla'
        );
    END IF;

    IF v_nombre_estado = 'REALIZADA' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede eliminar una actividad REALIZADA'
        );
    END IF;

    SELECT ds.id_almacen INTO v_id_almacen_os
    FROM age_actividad a
    JOIN doc_salida ds ON ds.id = a.id_doc_salida AND ds.estado = 1
    WHERE a.id = p_id;

    UPDATE age_actividad
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- ------------------------------------------------------------
    -- Camino de vuelta de la custodia: EN_TRANSITO -> PENDIENTE_ENVIO
    --
    -- Con EN_RUTA bloqueado esto solo alcanza residuales (actividades que
    -- quedaron en tránsito por flujos antiguos), pero se mantiene: eliminar no
    -- puede dejar cilindros en un viaje que ya no existe. Misma regla que
    -- cancelar, incluida la restitución del almacén de la OS.
    -- ------------------------------------------------------------
    SELECT lo.id INTO v_id_transito
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_pend_envio
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_transito IS NOT NULL AND v_id_pend_envio IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_pend_envio,
            id_almacen = COALESCE(v_id_almacen_os, b.id_almacen),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon = v_id_transito;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/actividades/age_crear_recojo_origen.sql
-- ============================================================
-- Function: age_crear_recojo_origen
-- Synced from migracion 20260909_age_crear_recojo_hora_inicio.sql
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
-- candado de consistencia con bal_recojo. Ambos módulos siguen pudiendo
-- programar el recojo de un préstamo o alquiler; lo que no se admite es tener
-- los dos vivos sobre el mismo origen, porque serían dos rutas y dos cierres
-- moviendo el estado del mismo cilindro. El candado recíproco está en
-- bal_crear_recojo.

DROP FUNCTION IF EXISTS age_crear_recojo_origen(character varying, integer, date, integer, character varying, integer);
DROP FUNCTION IF EXISTS age_crear_recojo_origen(character varying, integer, date, time without time zone, integer, character varying, integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_origen(
    p_tipo_origen character varying,
    p_id_origen integer,
    p_fecha_programada date DEFAULT NULL::date,
    p_hora_inicio_estimada time without time zone DEFAULT NULL::time without time zone,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_observaciones character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo_origen   VARCHAR := UPPER(TRIM(COALESCE(p_tipo_origen, '')));
    v_id_existente  INTEGER;
    v_id_tipo       INTEGER;
    v_id_estado     INTEGER;
    v_id_prioridad  INTEGER;
    v_id_origen_cat INTEGER;
    v_id_actividad  INTEGER;
    v_id_cliente    INTEGER;
    v_numero        VARCHAR;
    v_nombre_cli    VARCHAR;
    v_fecha_pactada DATE;
    v_titulo        VARCHAR;
    v_descripcion   VARCHAR;
    v_id_visita     INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF v_tipo_origen NOT IN ('PRESTAMO', 'ALQUILER') THEN
        RETURN json_build_object('error', 'tipoOrigen debe ser PRESTAMO o ALQUILER', 'registro', NULL);
    END IF;

    IF p_id_origen IS NULL THEN
        RETURN json_build_object('error', 'idOrigen es obligatorio', 'registro', NULL);
    END IF;

    IF p_hora_inicio_estimada IS NULL THEN
        RETURN json_build_object('error', 'La hora de inicio es obligatoria', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoActividad' AND lo.nombre = 'RECOJO' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoActividad' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    IF v_id_tipo IS NULL OR v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Faltan catálogos TipoActividad/EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_prioridad
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PrioridadActividad' AND lo.nombre = 'ALTA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_origen_cat
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrigenActividad' AND lo.nombre = v_tipo_origen AND lo.estado = 1 LIMIT 1;

    IF v_tipo_origen = 'PRESTAMO' THEN
        SELECT p.id_cliente, p.numero_prestamo, p.fecha_retorno_pactada,
               COALESCE(
                   NULLIF(TRIM(cli.razon_social), ''),
                   NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
                   cli.numero_documento
               )
        INTO v_id_cliente, v_numero, v_fecha_pactada, v_nombre_cli
        FROM bal_prestamo p
        LEFT JOIN cli_clientes cli ON cli.id = p.id_cliente
        WHERE p.id = p_id_origen AND p.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El préstamo no existe o está anulado', 'registro', NULL);
        END IF;

        SELECT a.id INTO v_id_existente
        FROM age_actividad a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_prestamo = p_id_origen
          AND a.estado = 1
          AND a.id_tipo_actividad = v_id_tipo
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
        ORDER BY a.id DESC
        LIMIT 1;

        v_titulo := format('Recojo préstamo %s', COALESCE(v_numero, p_id_origen::TEXT));
        v_descripcion := format('Recojo de cilindros de %s', COALESCE(v_nombre_cli, 'cliente'));
    ELSE
        SELECT a.id_cliente, a.numero_alquiler, a.fecha_fin_pactada,
               COALESCE(
                   NULLIF(TRIM(cli.razon_social), ''),
                   NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
                   cli.numero_documento
               )
        INTO v_id_cliente, v_numero, v_fecha_pactada, v_nombre_cli
        FROM bal_alquiler a
        LEFT JOIN cli_clientes cli ON cli.id = a.id_cliente
        WHERE a.id = p_id_origen AND a.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El alquiler no existe o está anulado', 'registro', NULL);
        END IF;

        SELECT act.id INTO v_id_existente
        FROM age_actividad act
        JOIN gen_lista_opciones ea ON ea.id = act.id_estado_actividad
        WHERE act.id_alquiler = p_id_origen
          AND act.estado = 1
          AND act.id_tipo_actividad = v_id_tipo
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
        ORDER BY act.id DESC
        LIMIT 1;

        v_titulo := format('Recojo alquiler %s', COALESCE(v_numero, p_id_origen::TEXT));
        v_descripcion := format('Recojo de alquiler de %s', COALESCE(v_nombre_cli, 'cliente'));
    END IF;

    IF v_id_existente IS NOT NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object('id', v_id_existente, 'creada', FALSE, 'items', 0)
        );
    END IF;

    -- Candado de consistencia: una visita viva en bal_recojo ya se está
    -- ocupando de este origen. Programar además la actividad lo duplicaría.
    SELECT r.id INTO v_id_visita
    FROM bal_recojo r
    JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.estado = 1
      AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
      AND (
          (v_tipo_origen = 'PRESTAMO' AND r.id_prestamo = p_id_origen)
          OR (v_tipo_origen = 'ALQUILER' AND r.id_alquiler = p_id_origen)
      )
    ORDER BY r.id DESC
    LIMIT 1;

    IF v_id_visita IS NOT NULL THEN
        RETURN json_build_object(
            'error', format(
                'Este %s ya tiene la visita de recojo #%s programada o en ruta en Balones > Recojos. Ciérrala o cancélala allí antes de programar la actividad.',
                LOWER(v_tipo_origen),
                v_id_visita
            ),
            'registro', NULL
        );
    END IF;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada, hora_inicio_estimada,
        id_tipo_actividad, id_prioridad,
        id_cliente, id_trabajador_responsable, id_estado_actividad, observaciones,
        id_prestamo, id_alquiler, id_tipo_origen,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        v_titulo, v_descripcion,
        COALESCE(p_fecha_programada, v_fecha_pactada, CURRENT_DATE),
        p_hora_inicio_estimada,
        v_id_tipo, v_id_prioridad,
        v_id_cliente, p_id_trabajador_responsable, v_id_estado, p_observaciones,
        CASE WHEN v_tipo_origen = 'PRESTAMO' THEN p_id_origen ELSE NULL END,
        CASE WHEN v_tipo_origen = 'ALQUILER' THEN p_id_origen ELSE NULL END,
        v_id_origen_cat,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_actividad;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id', v_id_actividad, 'creada', TRUE, 'items', 0)
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/recojos/bal_crear_recojo.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_recojo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
-- Actualizada por database_sql/migraciones/20260910_inv_soft_raise_y_recojo.sql:
-- el recojo de recarga en planta exige la orden GENERADA / EMITIDA_SUNAT; antes
-- pedía 'ENVIADO' / 'CERRADO', que no existen en EstadoCicloSalida.
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
-- candado de consistencia con age_actividad. Esta vía sigue abierta para
-- programar el recojo de un préstamo o alquiler; lo que se rechaza es hacerlo
-- cuando el origen ya tiene una actividad RECOJO vigente, porque serían dos
-- rutas y dos cierres sobre los mismos cilindros. El camino de recarga en
-- planta (p_id_recarga_planta) no se toca: ese recojo solo existe aquí.
DROP FUNCTION IF EXISTS bal_crear_recojo(p_id_cliente integer, p_id_prestamo integer, p_id_alquiler integer, p_id_recarga_planta integer, p_fecha_programada date, p_hora_estimada time without time zone, p_id_usuario_responsable integer, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer, p_marcar_balon_por_recoger boolean);

CREATE OR REPLACE FUNCTION bal_crear_recojo(p_id_cliente integer, p_id_prestamo integer DEFAULT NULL::integer, p_id_alquiler integer DEFAULT NULL::integer, p_id_recarga_planta integer DEFAULT NULL::integer, p_fecha_programada date DEFAULT NULL::date, p_hora_estimada time without time zone DEFAULT NULL::time without time zone, p_id_usuario_responsable integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_marcar_balon_por_recoger boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_estado INTEGER;
    v_por_recoger INTEGER;
    x JSONB;
    v_pd INTEGER;
    v_ad INTEGER;
    v_b INTEGER;
    v_balon INTEGER;
    v_cliente INTEGER;
    v_dev DATE;
    v_len INTEGER;
    v_producto INTEGER;
    v_id_recarga_planta INTEGER;
    v_proveedor INTEGER;
    v_rp_estado VARCHAR;
    v_id_estado_balon_local INTEGER;
    v_id_actividad_recojo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_len := jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB));

    IF p_id_cliente IS NULL OR p_fecha_programada IS NULL THEN
        RETURN json_build_object(
            'error', 'Cliente y fecha son obligatorios',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'Cliente inválido', 'registro', NULL);
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM bal_prestamo p
        JOIN gen_lista_opciones e ON e.id = p.id_estado AND e.nombre = 'ACTIVO'
        WHERE p.id = p_id_prestamo
          AND p.id_cliente = p_id_cliente
          AND p.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'Préstamo activo inválido para el cliente',
            'registro', NULL
        );
    END IF;

    IF p_id_alquiler IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM bal_alquiler a
        JOIN gen_lista_opciones e ON e.id = a.id_estado AND e.nombre = 'ACTIVO'
        WHERE a.id = p_id_alquiler
          AND a.id_cliente = p_id_cliente
          AND a.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'Alquiler activo inválido para el cliente',
            'registro', NULL
        );
    END IF;

    -- Candado de consistencia: con una actividad RECOJO vigente sobre el mismo
    -- origen, crear aquí otra visita duplicaría la ruta y el cierre de custodia.
    IF p_id_recarga_planta IS NULL AND (p_id_prestamo IS NOT NULL OR p_id_alquiler IS NOT NULL) THEN
        SELECT a.id INTO v_id_actividad_recojo
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.estado = 1
          AND UPPER(TRIM(ta.nombre)) = 'RECOJO'
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
          AND (
              (p_id_prestamo IS NOT NULL AND a.id_prestamo = p_id_prestamo)
              OR (p_id_alquiler IS NOT NULL AND a.id_alquiler = p_id_alquiler)
          )
        ORDER BY a.id DESC
        LIMIT 1;

        IF v_id_actividad_recojo IS NOT NULL THEN
            RETURN json_build_object(
                'error', format(
                    'Este %s ya tiene la actividad de recojo #%s vigente en Operativa > Actividades. Ciérrala o cancélala allí antes de programar la visita.',
                    CASE WHEN p_id_prestamo IS NOT NULL THEN 'préstamo' ELSE 'alquiler' END,
                    v_id_actividad_recojo
                ),
                'registro', NULL
            );
        END IF;
    END IF;

    -- Validación de origen recarga en planta: el "cliente" del recojo es el proveedor
    IF p_id_recarga_planta IS NOT NULL THEN
        SELECT rp.id_proveedor, est.nombre
        INTO v_proveedor, v_rp_estado
        FROM doc_salida rp
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        WHERE rp.id = p_id_recarga_planta AND rp.estado = 1;

        IF v_proveedor IS NULL THEN
            RETURN json_build_object(
                'error', 'Orden de recarga en planta no encontrada',
                'registro', NULL
            );
        END IF;

        -- Sin salida generada los cilindros nunca llegaron a la planta: no hay
        -- nada que recoger.
        IF COALESCE(v_rp_estado, '') NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
            RETURN json_build_object(
                'error', CASE
                    WHEN v_rp_estado = 'ANULADA' THEN 'La orden de recarga en planta está anulada'
                    ELSE 'La orden aún está en borrador: genérala antes de programar el recojo'
                END,
                'registro', NULL
            );
        END IF;

        IF v_proveedor <> p_id_cliente THEN
            RETURN json_build_object(
                'error', 'El cliente del recojo debe coincidir con el proveedor de la recarga',
                'registro', NULL
            );
        END IF;

        IF v_len = 0 THEN
            RETURN json_build_object(
                'error', 'El recojo de recarga en planta requiere al menos un cilindro',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Recojo sin cilindros: solo alquiler de regulador/accesorio
    IF v_len = 0 THEN
        IF p_id_alquiler IS NULL OR p_id_prestamo IS NOT NULL OR p_id_recarga_planta IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'Cliente, fecha y detalles son obligatorios',
                'registro', NULL
            );
        END IF;

        SELECT COALESCE(a.id_producto_regulador, a.id_producto_stock)
        INTO v_producto
        FROM bal_alquiler a
        WHERE a.id = p_id_alquiler AND a.estado = 1;

        IF v_producto IS NULL THEN
            RETURN json_build_object(
                'error', 'El alquiler no tiene regulador/accesorio para recojo',
                'registro', NULL
            );
        END IF;

        -- Permitido con o sin cilindros pendientes: visita solo de regulador/accesorio

        IF EXISTS (
            SELECT 1
            FROM bal_recojo r
            JOIN gen_lista_opciones e ON e.id = r.id_estado
            WHERE r.id_alquiler = p_id_alquiler
              AND r.estado = 1
              AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
        ) THEN
            RETURN json_build_object(
                'error', 'El alquiler ya tiene un recojo programado o en ruta',
                'registro', NULL
            );
        END IF;
    END IF;

    SELECT lo.id INTO v_estado
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = 'PROGRAMADO' AND lo.estado = 1;

    SELECT lo.id INTO v_por_recoger
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'POR_RECOGER' AND lo.estado = 1;

    INSERT INTO bal_recojo (
        id_cliente,
        id_prestamo,
        id_alquiler,
        id_doc_salida,
        fecha_programada,
        hora_estimada,
        id_usuario_responsable,
        id_estado,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_prestamo,
        p_id_alquiler,
        p_id_recarga_planta,
        p_fecha_programada,
        p_hora_estimada,
        p_id_usuario_responsable,
        v_estado,
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR x IN SELECT * FROM jsonb_array_elements(COALESCE(p_detalles::JSONB, '[]'::JSONB))
    LOOP
        v_pd := COALESCE(
            NULLIF(x->>'idPrestamoDetalle', '')::INTEGER,
            NULLIF(x->>'id_prestamo_detalle', '')::INTEGER
        );
        v_ad := COALESCE(
            NULLIF(x->>'idAlquilerDetalle', '')::INTEGER,
            NULLIF(x->>'id_alquiler_detalle', '')::INTEGER
        );
        v_b := COALESCE(
            NULLIF(x->>'idBalon', '')::INTEGER,
            NULLIF(x->>'id_balon', '')::INTEGER
        );

        IF (v_pd IS NOT NULL)::INTEGER + (v_ad IS NOT NULL)::INTEGER + (v_b IS NOT NULL)::INTEGER <> 1 THEN
            RAISE EXCEPTION 'Cada detalle debe tener exactamente un origen (préstamo, alquiler o balón)';
        END IF;

        IF v_pd IS NOT NULL THEN
            SELECT pd.id_balon, p.id_cliente, pd.fecha_devolucion
            INTO v_balon, v_cliente, v_dev
            FROM bal_prestamo_detalle pd
            JOIN bal_prestamo p ON p.id = pd.id_prestamo
            JOIN gen_lista_opciones e ON e.id = p.id_estado AND e.nombre = 'ACTIVO'
            WHERE pd.id = v_pd AND pd.estado = 1;

            IF v_cliente IS NULL
               OR v_cliente <> p_id_cliente
               OR v_dev IS NOT NULL
               OR (
                   p_id_prestamo IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM bal_prestamo_detalle
                       WHERE id = v_pd AND id_prestamo = p_id_prestamo
                   )
               )
            THEN
                RAISE EXCEPTION 'Detalle de préstamo inválido';
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_prestamo_detalle = v_pd
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El detalle de préstamo ya tiene recojo';
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_prestamo_detalle,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_pd,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );

            IF v_balon IS NOT NULL AND v_por_recoger IS NOT NULL AND p_marcar_balon_por_recoger THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_por_recoger,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_balon AND estado = 1;
            END IF;
        ELSIF v_ad IS NOT NULL THEN
            SELECT ad.id_balon, a.id_cliente, ad.fecha_devolucion
            INTO v_balon, v_cliente, v_dev
            FROM bal_alquiler_detalle ad
            JOIN bal_alquiler a ON a.id = ad.id_alquiler
            JOIN gen_lista_opciones e ON e.id = a.id_estado AND e.nombre = 'ACTIVO'
            WHERE ad.id = v_ad AND ad.estado = 1;

            IF v_cliente IS NULL
               OR v_cliente <> p_id_cliente
               OR v_dev IS NOT NULL
               OR (
                   p_id_alquiler IS NOT NULL
                   AND NOT EXISTS (
                       SELECT 1 FROM bal_alquiler_detalle
                       WHERE id = v_ad AND id_alquiler = p_id_alquiler
                   )
               )
            THEN
                RAISE EXCEPTION 'Detalle de alquiler inválido';
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_alquiler_detalle = v_ad
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El detalle de alquiler ya tiene recojo';
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_alquiler_detalle,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_ad,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );

            IF v_balon IS NOT NULL AND v_por_recoger IS NOT NULL AND p_marcar_balon_por_recoger THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_por_recoger,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_balon AND estado = 1;
            END IF;
        ELSE
            -- Origen recarga en planta externa: el balón permanece EN_RECARGA_EXTERNA
            -- hasta que se cierra el recojo (distribución manual de gas).
            IF p_id_recarga_planta IS NULL THEN
                RAISE EXCEPTION 'El detalle por balón requiere el documento de salida de la recarga';
            END IF;

            SELECT b.id, b.id_estado_balon
            INTO v_balon, v_id_estado_balon_local
            FROM bal_balon b
            WHERE b.id = v_b AND b.estado = 1;

            IF v_balon IS NULL THEN
                RAISE EXCEPTION 'Balón % no encontrado', v_b;
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM doc_salida_detalle d
                WHERE d.id_doc_salida = p_id_recarga_planta
                  AND d.id_balon = v_b
                  AND d.estado = 1
            ) THEN
                RAISE EXCEPTION 'El balón % no pertenece a la orden de recarga en planta', v_b;
            END IF;

            IF NOT EXISTS (
                SELECT 1
                FROM bal_balon b
                JOIN gen_lista_opciones e ON e.id = b.id_estado_balon
                WHERE b.id = v_b AND b.estado = 1 AND e.nombre = 'EN_RECARGA_EXTERNA'
            ) THEN
                RAISE EXCEPTION 'El balón % no está en estado EN_RECARGA_EXTERNA', v_b;
            END IF;

            IF EXISTS (
                SELECT 1
                FROM bal_recojo_detalle rd
                JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
                JOIN gen_lista_opciones e ON e.id = r.id_estado
                WHERE rd.id_balon = v_b
                  AND rd.estado = 1
                  AND e.nombre IN ('PROGRAMADO', 'EN_RUTA')
            ) THEN
                RAISE EXCEPTION 'El balón % ya tiene un recojo programado', v_b;
            END IF;

            INSERT INTO bal_recojo_detalle (
                id_recojo,
                id_balon,
                observacion,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id,
                v_b,
                NULLIF(TRIM(x->>'observacion'), ''),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END IF;
    END LOOP;

    RETURN bal_obtener_recojo(v_id);
EXCEPTION
    WHEN OTHERS THEN
        IF v_id IS NOT NULL THEN
            DELETE FROM bal_recojo WHERE id = v_id;
        END IF;
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;


-- ============================================================
-- database_sql/funciones/actividades/age_listar_vencidos_recojo.sql
-- ============================================================
-- Function: age_listar_vencidos_recojo
-- Synced from migracion 20260908_age_recojo_vencidos_fk.sql
--
-- Actualizada por database_sql/migraciones/20260910_age_custodia_recojo_candado.sql:
-- además de la actividad RECOJO vigente, se excluyen los orígenes con una
-- visita viva en bal_recojo. La lista alimenta el botón de crear actividad de
-- recojo, que ahora rechaza esos orígenes (candado de consistencia):
-- ofrecerlos era ofrecer un error.

DROP FUNCTION IF EXISTS age_listar_vencidos_recojo(character varying, integer, integer);

CREATE OR REPLACE FUNCTION age_listar_vencidos_recojo(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 30,
    p_offset integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_busqueda VARCHAR := LOWER(TRIM(COALESCE(p_busqueda, '')));
    v_rows JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH vigentes AS (
        SELECT a.id_prestamo, a.id_alquiler
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.estado = 1
          AND ta.nombre = 'RECOJO'
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
    ),
    visitas AS (
        SELECT r.id_prestamo, r.id_alquiler
        FROM bal_recojo r
        JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.estado = 1
          AND UPPER(TRIM(er.nombre)) IN ('PROGRAMADO', 'EN_RUTA')
    ),
    base AS (
        SELECT
            'PRESTAMO'::VARCHAR AS origen,
            p.id AS id_origen,
            p.numero_prestamo AS numero,
            p.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            p.fecha_retorno_pactada AS fecha_pactada,
            (CURRENT_DATE - p.fecha_retorno_pactada)::INTEGER AS dias_vencido,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = p.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pd.id_balon IS NOT NULL
            ) AS cilindros_pendientes,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_prestamo = p.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ) AS garantias_activas,
            FALSE AS regulador_pendiente
        FROM bal_prestamo p
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND p.fecha_retorno_pactada IS NOT NULL
          AND p.fecha_retorno_pactada < CURRENT_DATE
          AND COALESCE(ep.nombre, 'ACTIVO') = 'ACTIVO'
          AND EXISTS (
              SELECT 1
              FROM bal_prestamo_detalle pd
              WHERE pd.id_prestamo = p.id
                AND pd.estado = 1
                AND pd.fecha_devolucion IS NULL
                AND pd.id_balon IS NOT NULL
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_prestamo = p.id)
          AND NOT EXISTS (SELECT 1 FROM visitas vi WHERE vi.id_prestamo = p.id)

        UNION ALL

        SELECT
            'ALQUILER'::VARCHAR,
            a.id,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ),
            a.fecha_fin_pactada,
            (CURRENT_DATE - a.fecha_fin_pactada)::INTEGER,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = a.id
                  AND ad.estado = 1
                  AND ad.fecha_devolucion IS NULL
                  AND ad.id_balon IS NOT NULL
            ),
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_alquiler = a.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ),
            (
                a.id_producto_regulador IS NOT NULL
                AND a.fecha_devolucion_regulador IS NULL
            )
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        WHERE a.estado = 1
          AND a.fecha_fin_real IS NULL
          AND a.fecha_fin_pactada IS NOT NULL
          AND a.fecha_fin_pactada < CURRENT_DATE
          AND COALESCE(ea.nombre, 'ACTIVO') = 'ACTIVO'
          AND (
              EXISTS (
                  SELECT 1
                  FROM bal_alquiler_detalle ad
                  WHERE ad.id_alquiler = a.id
                    AND ad.estado = 1
                    AND ad.fecha_devolucion IS NULL
                    AND ad.id_balon IS NOT NULL
              )
              OR (
                  a.id_producto_regulador IS NOT NULL
                  AND a.fecha_devolucion_regulador IS NULL
              )
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_alquiler = a.id)
          AND NOT EXISTS (SELECT 1 FROM visitas vi WHERE vi.id_alquiler = a.id)
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE v_busqueda = ''
           OR LOWER(COALESCE(numero, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(COALESCE(nombre_cliente, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(origen) LIKE '%' || v_busqueda || '%'
    )
    SELECT COUNT(*) INTO v_total FROM filtrado;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.dias_vencido DESC, t.numero), '[]'::JSON)
    INTO v_rows
    FROM (
        SELECT *
        FROM filtrado
        ORDER BY dias_vencido DESC, numero
        LIMIT GREATEST(COALESCE(p_limite, 30), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_rows, 'total', v_total);
END;
$function$;
