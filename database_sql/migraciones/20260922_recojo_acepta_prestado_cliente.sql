-- ============================================================
-- Migración: el recojo acepta el cilindro despachado por préstamo
-- Fecha: 2026-09-22
--
-- Problema: bal_prestamo_aplicar_salida_cilindro deja el cilindro en
-- PRESTADO_CLIENTE al despachar el préstamo, mientras que la entrega
-- confirmada (age_culminar_entrega y ven_confirmar_entrega_mostrador) lo deja
-- en EN_PODER_CLIENTE. La cadena de recojo solo aceptaba el segundo, así que
-- un préstamo que nunca pasó por un reparto no podía recogerse nunca: el
-- cilindro no aparecía en el selector y el trigger rechazaba el ítem.
--
-- Decisión: los dos estados significan "lo tiene el cliente y está pendiente
-- de devolución". Se conservan intactas las demás validaciones — detalle
-- ENTREGADO sin fecha_devolucion, préstamo vigente, ubicación del cilindro en
-- el cliente del préstamo y sin otro recojo activo.
--
-- Qué cambia
--  1) age_balones_disponibles_recojo: acepta ambos estados.
--  2) age_validar_item_recojo: mismo criterio en el trigger de ítems.
--  3) age_iniciar_recojo: mismo criterio al pasar el recojo a EN_RUTA.
-- ============================================================

-- ==== age_balones_disponibles_recojo
-- Balones físicamente entregados, todavía prestados y sin recojo activo.
CREATE OR REPLACE FUNCTION age_balones_disponibles_recojo(p_id_prestamo integer)
RETURNS TABLE (id_detalle integer, id_balon integer, id_producto integer, codigo_balon varchar)
LANGUAGE sql STABLE AS $function$
    SELECT pd.id, pd.id_balon, COALESCE(pd.id_producto, b.id_producto_gas), b.codigo_balon
    FROM bal_prestamo_detalle pd
    JOIN bal_prestamo p ON p.id = pd.id_prestamo
    JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
    JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE pd.id_prestamo = p_id_prestamo AND p.estado = 1
      AND p.fecha_retorno_real IS NULL
      AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones ep WHERE ep.id = p.id_estado AND UPPER(TRIM(ep.nombre)) <> 'ACTIVO')
      AND pd.estado = 1 AND pd.rol = 'ENTREGADO' AND pd.fecha_devolucion IS NULL
      -- Dos estados significan "lo tiene el cliente": PRESTADO_CLIENTE lo pone
      -- bal_prestamo_aplicar_salida_cilindro al despachar el préstamo, y
      -- EN_PODER_CLIENTE lo pone la entrega confirmada (age_culminar_entrega o
      -- mostrador). Exigir solo el segundo dejaba sin recojo posible a todo
      -- préstamo que no pasó por un reparto.
      AND UPPER(TRIM(eb.nombre)) IN ('EN_PODER_CLIENTE', 'PRESTADO_CLIENTE')
      AND b.id_cliente_ubicacion = p.id_cliente
      AND NOT EXISTS (
          SELECT 1 FROM age_actividad act
          JOIN gen_lista_opciones ta ON ta.id = act.id_tipo_actividad
          JOIN gen_lista_opciones ea ON ea.id = act.id_estado_actividad
          WHERE act.estado = 1 AND UPPER(TRIM(ta.nombre)) = 'RECOJO'
            AND UPPER(TRIM(ea.nombre)) NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
            AND (EXISTS (SELECT 1 FROM age_actividad_item ai WHERE ai.id_actividad = act.id AND ai.estado = 1 AND ai.id_balon = pd.id_balon)
              OR (act.id_prestamo = pd.id_prestamo AND NOT EXISTS (SELECT 1 FROM age_actividad_item ai WHERE ai.id_actividad = act.id AND ai.estado = 1)))
      );
$function$;

-- ==== age_validar_item_recojo
-- Valida también los ítems agregados mediante edición y la materialización de recojos antiguos.
CREATE OR REPLACE FUNCTION age_validar_item_recojo() RETURNS trigger LANGUAGE plpgsql AS $function$
DECLARE v_prestamo integer;
BEGIN
    IF NEW.estado <> 1 OR NEW.id_balon IS NULL THEN RETURN NEW; END IF;
    SELECT a.id_prestamo INTO v_prestamo FROM age_actividad a
    JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
    WHERE a.id = NEW.id_actividad AND UPPER(TRIM(ta.nombre)) = 'RECOJO';
    IF NOT FOUND THEN RETURN NEW; END IF;
    PERFORM pg_advisory_xact_lock(hashtext('recojo:balon'), NEW.id_balon);
    IF NOT EXISTS (SELECT 1 FROM bal_prestamo_detalle pd
        JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
        JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE pd.id = NEW.id_prestamo_detalle AND pd.id_prestamo = v_prestamo
          AND pd.id_balon = NEW.id_balon AND pd.estado = 1 AND pd.rol = 'ENTREGADO'
          AND pd.fecha_devolucion IS NULL AND p.fecha_retorno_real IS NULL
          -- Mismo criterio que age_balones_disponibles_recojo: el cilindro está
          -- con el cliente tanto si salió por el préstamo (PRESTADO_CLIENTE)
          -- como si la entrega se confirmó (EN_PODER_CLIENTE).
          AND b.id_cliente_ubicacion = p.id_cliente
          AND UPPER(TRIM(eb.nombre)) IN ('EN_PODER_CLIENTE', 'PRESTADO_CLIENTE')) THEN
        RAISE EXCEPTION 'El balón no está entregado y pendiente de devolución en este préstamo.';
    END IF;
    IF EXISTS (SELECT 1 FROM age_actividad_item ai
        JOIN age_actividad a ON a.id = ai.id_actividad
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE ai.id_balon = NEW.id_balon AND ai.estado = 1 AND ai.id <> NEW.id
          AND a.estado = 1 AND UPPER(TRIM(ta.nombre)) = 'RECOJO'
          AND UPPER(TRIM(ea.nombre)) NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')) THEN
        RAISE EXCEPTION 'El balón ya está asignado a un recojo activo.';
    END IF;
    RETURN NEW;
END;
$function$;
DROP TRIGGER IF EXISTS trg_age_item_recojo ON age_actividad_item;
CREATE TRIGGER trg_age_item_recojo BEFORE INSERT OR UPDATE OF id_balon, id_prestamo_detalle, id_actividad, estado
ON age_actividad_item FOR EACH ROW EXECUTE FUNCTION age_validar_item_recojo();

-- ==== age_iniciar_recojo
-- Function: age_iniciar_recojo
-- Pone el recojo EN_RUTA. Exige responsable e ítems materializados.
-- La verificación (escaneo) se hace mientras se recoge; el cierre con
-- almacén destino es age_culminar_recojo.

DROP FUNCTION IF EXISTS age_iniciar_recojo(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_recojo(
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
    v_items          INTEGER;
    v_id_trabajador_sesion INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_usuario_responsable,
           a.id_estado_actividad, a.id_prestamo, a.id_alquiler
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id AND a.estado = 1 FOR UPDATE;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
    FROM gen_lista_opciones lo WHERE lo.id = v_act.id_estado_actividad;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_tipo
    FROM age_actividad a JOIN gen_lista_opciones lo ON lo.id = a.id_tipo_actividad
    WHERE a.id = p_id;

    IF COALESCE(v_nombre_tipo, '') <> 'RECOJO' THEN
        RETURN json_build_object('error', 'Solo las actividades de RECOJO tienen este flujo', 'registro', NULL);
    END IF;

    IF v_act.id_prestamo IS NULL AND v_act.id_alquiler IS NULL THEN
        RETURN json_build_object('error', 'El recojo no tiene prestamo ni alquiler de origen', 'registro', NULL);
    END IF;

    IF v_nombre_estado IN ('REALIZADA', 'CANCELADA', 'CANCELADO') THEN
        RETURN json_build_object('error', format('La actividad ya esta %s', v_nombre_estado), 'registro', NULL);
    END IF;

    IF v_nombre_estado = 'EN_RUTA' THEN
        RETURN json_build_object('error', 'El recojo ya esta en ruta', 'registro', NULL);
    END IF;

    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object('error', 'Asigna un responsable antes de iniciar el recojo', 'registro', NULL);
    END IF;

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object(
            'error', 'Se requiere el usuario de sesion para iniciar el recojo',
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
            'error', 'Solo el responsable asignado (usuario de sesion) puede iniciar este recojo',
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

    -- Materializa ítems si aún no están (préstamo/alquiler lazy).
    PERFORM age_iniciar_verificacion(p_id, p_id_usuario_auditoria);

    SELECT COUNT(*) INTO v_items
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_items = 0 THEN
        RETURN json_build_object(
            'error', 'El recojo no tiene cilindros/accesorios pendientes que recoger',
            'registro', NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM age_actividad_item ai
        LEFT JOIN bal_prestamo_detalle pd ON pd.id = ai.id_prestamo_detalle
        LEFT JOIN bal_balon b ON b.id = ai.id_balon
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE ai.id_actividad = p_id AND ai.estado = 1 AND ai.id_balon IS NOT NULL
          AND (pd.id IS NULL OR pd.estado <> 1 OR pd.fecha_devolucion IS NOT NULL
               OR pd.id_prestamo IS DISTINCT FROM v_act.id_prestamo
               -- Mismo criterio que age_balones_disponibles_recojo: vale tanto
               -- el despacho del préstamo como la entrega confirmada.
               OR COALESCE(UPPER(TRIM(eb.nombre)), '') NOT IN ('EN_PODER_CLIENTE', 'PRESTADO_CLIENTE'))
    ) THEN
        RETURN json_build_object('error', 'Hay balones que ya no están pendientes de devolución o no fueron entregados. Revisa el recojo.', 'registro', NULL);
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- No se mueve custodia aquí: el cilindro sigue en poder del cliente hasta
    -- age_culminar_recojo, que llama a bal_devolver_* con el almacén destino.

    RETURN age_obtener_actividad(p_id);
END;
$function$;

