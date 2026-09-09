-- ============================================================
-- Migracion: el cilindro pasa a EN_TRANSITO mientras va en el camion
-- Fecha: 2026-09-09
--
-- Hasta ahora el balon decia PENDIENTE_ENVIO ("en preparacion, en el almacen")
-- durante todo el trayecto, y solo cambiaba al culminar la entrega. El estado
-- mentia justo en el tramo en que interesa saber donde esta.
--
-- EN_TRANSITO ya existia en el catalogo EstadoBalon, creado para esto
-- ("Se cambia el estado cuando se inicie la actividad") y nunca cableado, asi
-- que se reutiliza en vez de inventar uno nuevo.
--
-- Ciclo completo:
--     venta     -> PENDIENTE_ENVIO   (doc_crear_desde_venta)
--     iniciar   -> EN_TRANSITO       (age_iniciar_entrega)
--     culminar  -> EN_PODER_CLIENTE  (age_culminar_entrega)
--     cancelar  -> PENDIENTE_ENVIO   (age_cancelar_actividad)
--
-- El paso de vuelta no es opcional: sin el, cancelar un reparto ya salido
-- dejaria cilindros en transito para siempre, que es exactamente el atasco que
-- sufrio PENDIENTE_ENVIO por no tener salida.
--
-- No se registra movimiento de inventario a proposito. En el reparto nacido de
-- una venta el stock ya salio con la venta (doc_generar_salida solo mueve
-- inventario cuando id_venta IS NULL), asi que un movimiento aqui lo contaria
-- dos veces. Esto solo marca la situacion logistica del envase, igual que hace
-- doc_crear_desde_venta al poner PENDIENTE_ENVIO.
--
-- Por que no una FK en bal_balon apuntando a la actividad: el vinculo ya existe
-- en age_actividad_item.id_balon, que ademas apunta en el sentido correcto. Una
-- columna en bal_balon seria una segunda fuente de verdad que se desincroniza
-- en cuanto una actividad se cancele sin limpiarla.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_age_balon_en_transito.sql
-- ============================================================

-- Garantiza la opcion del catalogo en instalaciones donde falte.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion, estado)
SELECT l.id, 'EN_TRANSITO', 'Se cambia el estado cuando se inicie la actividad', 1
FROM gen_lista l
WHERE l.nombre = 'EstadoBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND UPPER(TRIM(lo.nombre)) = 'EN_TRANSITO'
  );


-- ============================================================
-- age_iniciar_entrega
-- ============================================================

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
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_estado_actividad
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

    IF v_observados > 0 THEN
        RETURN json_build_object(
            'error', format(
                '%s item(s) quedaron con observacion: resuelvelos volviendo a verificarlos como conformes',
                v_observados
            ),
            'registro', NULL
        );
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

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

    IF v_id_pend_envio IS NOT NULL AND v_id_transito IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_transito,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon = v_id_pend_envio;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;

-- ============================================================
-- age_culminar_entrega
-- ============================================================

DROP FUNCTION IF EXISTS age_culminar_entrega(integer, integer);

CREATE OR REPLACE FUNCTION age_culminar_entrega(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado  VARCHAR;
    v_id_realizada   INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pend_envio  INTEGER;
    v_id_transito    INTEGER;
    v_id_en_poder    INTEGER;
    v_id_cliente     INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
    v_cilindros      INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT UPPER(TRIM(lo.nombre)), a.id_cliente
    INTO v_nombre_estado, v_id_cliente
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones lo ON lo.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    -- Culminar exige haber pasado por EN_RUTA: si no, la verificacion de salida
    -- nunca se exigio y la de llegada no prueba nada.
    IF COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede culminar una entrega que este EN_RUTA',
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

    IF v_observados > 0 THEN
        RETURN json_build_object(
            'error', format(
                '%s item(s) llegaron con observacion: resuelvelos volviendo a verificarlos como conformes',
                v_observados
            ),
            'registro', NULL
        );
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- ------------------------------------------------------------
    -- Cierre de custodia: PENDIENTE_ENVIO -> EN_PODER_CLIENTE
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

    IF v_id_en_poder IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_en_poder,
            -- Un cilindro en poder del cliente sin cliente_ubicacion seria un
            -- estado roto; si la venta ya lo apunto, se respeta.
            id_cliente_ubicacion = COALESCE(b.id_cliente_ubicacion, v_id_cliente),
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon IN (v_id_transito, v_id_pend_envio);

        GET DIAGNOSTICS v_cilindros = ROW_COUNT;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;

-- ============================================================
-- age_cancelar_actividad
-- ============================================================

-- Generated: 2026-09-03T16:50:38.941Z
DROP FUNCTION IF EXISTS age_cancelar_actividad(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_cancelar_actividad(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_cancelada INTEGER;
    v_id_estado_actual INTEGER;
    v_nombre_estado_actual VARCHAR;
    v_id_pend_envio INTEGER;
    v_id_transito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT o.id INTO v_id_estado_cancelada
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(o.nombre)) = 'CANCELADA'
    LIMIT 1;

    IF v_id_estado_cancelada IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'No se encontró el estado CANCELADA en EstadoActividad.');
    END IF;

    SELECT a.id_estado_actividad, UPPER(TRIM(ea.nombre))
    INTO v_id_estado_actual, v_nombre_estado_actual
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_nombre_estado_actual = 'CANCELADA' THEN
        RETURN json_build_object('registro', NULL, 'error', 'La actividad ya se encuentra cancelada.');
    END IF;

    UPDATE age_actividad
    SET
        id_estado_actividad = v_id_estado_cancelada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- ------------------------------------------------------------
    -- Camino de vuelta de la custodia: EN_TRANSITO -> PENDIENTE_ENVIO
    --
    -- Si se cancela un reparto que ya habia salido, los cilindros vuelven a
    -- estar comprometidos pero sin viaje en curso. Sin esto quedarian en
    -- transito para siempre, que es justo el atasco que ya sufrio
    -- PENDIENTE_ENVIO por no tener salida.
    --
    -- Se filtra por el estado actual del cilindro y no por el de la actividad:
    -- asi es idempotente y no toca cilindros que ya siguieron otro camino.
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
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id
          AND ai.estado = 1
          AND ai.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon = v_id_transito;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
