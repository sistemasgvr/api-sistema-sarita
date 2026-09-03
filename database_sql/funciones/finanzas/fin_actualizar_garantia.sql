-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_actualizar_garantia
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS fin_actualizar_garantia(p_id integer, p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_actualizar_garantia(p_id integer, p_fecha date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer, p_id_medio_pago integer DEFAULT NULL::integer, p_importe numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia   fin_garantia%ROWTYPE;
    v_id_cliente INT;
    v_registro   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_garantia FROM fin_garantia WHERE id = p_id AND estado = 1;
    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La garantía no existe o está inactiva');
    END IF;

    -- No permitir editar datos si ya fue reembolsada
    IF v_garantia.fecha_reembolso IS NOT NULL THEN
        RETURN json_build_object('registro', NULL, 'error',
            'Esta garantía ya fue reembolsada. Anula el reembolso primero para editarla.');
    END IF;

    IF p_id_cliente IS NOT NULL THEN
        SELECT id INTO v_id_cliente FROM cli_clientes WHERE id = p_id_cliente AND estado = 1;
        IF v_id_cliente IS NULL THEN
            RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe o está inactivo');
        END IF;
    END IF;

    IF p_importe IS NOT NULL AND p_importe <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El importe debe ser mayor a cero');
    END IF;

    UPDATE fin_garantia SET
        fecha         = COALESCE(p_fecha, fecha),
        id_cliente    = COALESCE(p_id_cliente, id_cliente),
        id_medio_pago = COALESCE(p_id_medio_pago, id_medio_pago),
        importe       = COALESCE(p_importe, importe),
        observacion   = CASE
            WHEN p_observacion IS NULL THEN observacion
            WHEN TRIM(p_observacion) = '' THEN NULL
            ELSE TRIM(p_observacion)
        END,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
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
$function$;
