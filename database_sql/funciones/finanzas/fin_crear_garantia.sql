-- Registra una nueva garantía dejada por un cliente. Estado inicial = ACTIVA.

DROP FUNCTION IF EXISTS fin_crear_garantia(DATE, INT, INT, NUMERIC, VARCHAR, INT);
DROP FUNCTION IF EXISTS fin_crear_garantia(DATE, INT, INT, NUMERIC, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION fin_crear_garantia(
    p_fecha          DATE,
    p_id_cliente     INT,
    p_id_medio_pago  INT,
    p_importe        NUMERIC,
    p_observacion    VARCHAR DEFAULT NULL,
    p_id_usuario     INT     DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
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
$$;
