-- Function: age_cancelar_recojos_pendientes_origen
-- Source: migraciones/20260911_recojos_solo_actividades.sql
--
-- Cuando un préstamo se cierra o un alquiler se finaliza por fuera de la
-- agenda (devolución en mostrador, renovación POS), la actividad de RECOJO
-- que seguía PENDIENTE / PROGRAMADA para ese origen ya no tiene qué recoger.
-- Reemplaza lo que hacía bal_actualizar_recojo(CANCELADO) sobre bal_recojo.
--
-- Solo toca PENDIENTE / PROGRAMADA: una EN_RUTA la cierra el chofer con
-- age_culminar_recojo (que es quien devuelve los cilindros y llega aquí a
-- través de bal_devolver_*) o se cancela a mano con age_cancelar_actividad.
-- Devuelve cuántas actividades canceló. Nunca falla por no encontrar nada.

DROP FUNCTION IF EXISTS age_cancelar_recojos_pendientes_origen(character varying, integer, integer, character varying);

CREATE OR REPLACE FUNCTION age_cancelar_recojos_pendientes_origen(
    p_tipo_origen character varying,
    p_id_origen integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_motivo character varying DEFAULT NULL::character varying
)
RETURNS integer
LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo_origen  VARCHAR := UPPER(TRIM(COALESCE(p_tipo_origen, '')));
    v_id_cancelada INTEGER;
    v_motivo       VARCHAR := COALESCE(
        NULLIF(TRIM(p_motivo), ''),
        'Cancelada: el origen ya no tiene cilindros/accesorios pendientes de recojo'
    );
    v_n            INTEGER := 0;
BEGIN
    IF p_id_origen IS NULL OR v_tipo_origen NOT IN ('PRESTAMO', 'ALQUILER') THEN
        RETURN 0;
    END IF;

    SELECT o.id INTO v_id_cancelada
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(o.nombre)) = 'CANCELADA'
      AND o.estado = 1
    LIMIT 1;

    IF v_id_cancelada IS NULL THEN
        RETURN 0;
    END IF;

    UPDATE age_actividad a
    SET id_estado_actividad     = v_id_cancelada,
        fecha_hora_cierre       = NOW(),
        observaciones           = LEFT(
            TRIM(COALESCE(a.observaciones || ' — ', '') || v_motivo), 500
        ),
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, a.id_usuario_modificacion),
        fecha_modificacion      = NOW()
    FROM gen_lista_opciones ta, gen_lista_opciones ea
    WHERE ta.id = a.id_tipo_actividad
      AND ea.id = a.id_estado_actividad
      AND a.estado = 1
      AND UPPER(TRIM(ta.nombre)) = 'RECOJO'
      AND UPPER(TRIM(ea.nombre)) IN ('PENDIENTE', 'PROGRAMADA')
      AND (
          (v_tipo_origen = 'PRESTAMO' AND a.id_prestamo = p_id_origen)
          OR (v_tipo_origen = 'ALQUILER' AND a.id_alquiler = p_id_origen)
      );
    GET DIAGNOSTICS v_n = ROW_COUNT;

    RETURN v_n;
END;
$function$;
