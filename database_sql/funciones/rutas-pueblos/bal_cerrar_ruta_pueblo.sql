-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_cerrar_ruta_pueblo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.525Z
DROP FUNCTION IF EXISTS bal_cerrar_ruta_pueblo(p_id integer, p_m3_reportado_ventas numeric, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_cerrar_ruta_pueblo(p_id integer, p_m3_reportado_ventas numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_estado INTEGER;
    v_m3_calc NUMERIC;
    v_m3_rep NUMERIC;
    v_tolerancia NUMERIC;
    v_descuadre NUMERIC;
    v_pendientes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.m3_calculado, r.tolerancia_m3, r.m3_reportado_ventas
    INTO v_estado, v_m3_calc, v_tolerancia, v_m3_rep
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado = 'CERRADA' THEN
        RETURN bal_obtener_ruta_pueblo(p_id);
    END IF;

    IF v_estado = 'CANCELADA' THEN
        RETURN json_build_object('error', 'No se puede cerrar una ruta cancelada', 'registro', NULL);
    END IF;

    SELECT COUNT(*)::INT INTO v_pendientes
    FROM bal_ruta_pueblo_detalle d
    WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NULL;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error',
            format('Faltan %s cilindro(s) sin libras de retorno', v_pendientes),
            'registro',
            NULL
        );
    END IF;

    SELECT COALESCE(SUM(d.m3_delta), 0) INTO v_m3_calc
    FROM bal_ruta_pueblo_detalle d
    WHERE d.id_ruta_pueblo = p_id AND d.estado = 1;

    v_m3_rep := COALESCE(p_m3_reportado_ventas, v_m3_rep);
    IF v_m3_rep IS NULL THEN
        RETURN json_build_object(
            'error',
            'Indica los mÂ³ reportados por el repartidor (ventas de la ruta)',
            'registro',
            NULL
        );
    END IF;

    v_descuadre := ROUND(v_m3_calc - v_m3_rep, 4);

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'CERRADA' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_ruta_pueblo
    SET
        m3_calculado = v_m3_calc,
        m3_reportado_ventas = v_m3_rep,
        descuadre_m3 = v_descuadre,
        id_estado = v_id_estado,
        observacion = CASE
            WHEN p_observacion IS NULL THEN observacion
            ELSE NULLIF(TRIM(p_observacion), '')
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$
