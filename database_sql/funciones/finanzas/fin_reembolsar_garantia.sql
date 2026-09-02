-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_reembolsar_garantia
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.688Z
DROP FUNCTION IF EXISTS fin_reembolsar_garantia(p_id integer, p_fecha_reembolso date, p_id_medio_reembolso integer, p_observacion_reembolso character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_reembolsar_garantia(p_id integer, p_fecha_reembolso date, p_id_medio_reembolso integer, p_observacion_reembolso character varying DEFAULT NULL::character varying, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia  fin_garantia%ROWTYPE;
    v_id_devuelta INT;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia FROM fin_garantia WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La garantía no existe o está inactiva');
    END IF;

    IF v_garantia.fecha_reembolso IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta garantía ya fue reembolsada el ' || to_char(v_garantia.fecha_reembolso, 'DD/MM/YYYY'));
    END IF;

    IF p_fecha_reembolso IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha del reembolso es obligatoria');
    END IF;

    IF p_fecha_reembolso < v_garantia.fecha THEN
        RETURN json_build_object('registro', NULL, 'error',
            format('La fecha del reembolso (%s) no puede ser anterior a la fecha de recepción de la garantía (%s)',
                to_char(p_fecha_reembolso, 'DD/MM/YYYY'),
                to_char(v_garantia.fecha, 'DD/MM/YYYY')));
    END IF;

    SELECT glo.id INTO v_id_devuelta
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = 'DEVUELTA'
    LIMIT 1;

    UPDATE fin_garantia SET
        fecha_reembolso       = p_fecha_reembolso,
        id_medio_reembolso    = p_id_medio_reembolso,
        observacion_reembolso = NULLIF(TRIM(p_observacion_reembolso), ''),
        id_usuario_reembolso  = p_id_usuario,
        id_estado             = COALESCE(v_id_devuelta, id_estado),
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion    = NOW()
    WHERE id = p_id;

    SELECT row_to_json(t) INTO v_registro FROM (
        SELECT
            g.id, g.fecha,
            g.id_cliente,
            COALESCE(NULLIF(TRIM(c.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                     'Cliente #' || g.id_cliente) AS cliente,
            c.numero_documento AS documento_cliente,
            g.id_medio_pago, mp.nombre AS medio_pago,
            g.importe, g.observacion,
            g.fecha_reembolso,
            g.id_medio_reembolso, mr.nombre AS medio_reembolso,
            g.observacion_reembolso,
            g.id_estado, est.nombre AS estado_texto
        FROM fin_garantia g
        JOIN cli_clientes c ON c.id = g.id_cliente
        LEFT JOIN gen_lista_opciones mp  ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones mr  ON mr.id = g.id_medio_reembolso
        LEFT JOIN gen_lista_opciones est ON est.id = g.id_estado
        WHERE g.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
