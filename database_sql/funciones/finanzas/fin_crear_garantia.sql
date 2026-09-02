-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_crear_garantia
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.675Z
DROP FUNCTION IF EXISTS fin_crear_garantia(p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_crear_garantia(p_fecha date, p_id_cliente integer, p_id_medio_pago integer, p_importe numeric, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INT;
    v_id_estado  INT;
    v_id_garantia INT;
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha es obligatoria');
    END IF;
    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente es obligatorio');
    END IF;

    SELECT id INTO v_id_cliente FROM cli_clientes WHERE id = p_id_cliente AND estado = 1;
    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe o está inactivo');
    END IF;

    IF p_importe IS NULL OR p_importe <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El importe debe ser mayor a cero');
    END IF;

    SELECT glo.id INTO v_id_estado
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = 'ACTIVA'
    LIMIT 1;

    INSERT INTO fin_garantia (
        fecha, id_cliente, id_medio_pago, importe, observacion,
        id_estado, id_usuario_creacion
    ) VALUES (
        p_fecha, v_id_cliente, p_id_medio_pago, p_importe,
        NULLIF(TRIM(p_observacion), ''),
        v_id_estado, p_id_usuario
    ) RETURNING id INTO v_id_garantia;

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
            g.id_estado, est.nombre AS estado_texto,
            g.fecha_creacion
        FROM fin_garantia g
        JOIN cli_clientes c ON c.id = g.id_cliente
        LEFT JOIN gen_lista_opciones mp  ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones mr  ON mr.id = g.id_medio_reembolso
        LEFT JOIN gen_lista_opciones est ON est.id = g.id_estado
        WHERE g.id = v_id_garantia
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$
