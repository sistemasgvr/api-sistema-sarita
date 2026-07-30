-- Crea una cuenta financiera manual (externa a las ventas/compras).
-- Ej.: préstamo bancario a pagar, cobro esperado no derivado de una venta, etc.
-- No usa comprobante: es una cuenta suelta.

DROP FUNCTION IF EXISTS fin_crear_cuenta(VARCHAR, INT, DATE, DATE, NUMERIC, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_crear_cuenta(
    p_tipo             VARCHAR,   -- 'COBRAR' | 'PAGAR'
    p_id_tercero       INT,
    p_fecha_emision    DATE,
    p_fecha_vencimiento DATE     DEFAULT NULL,
    p_monto            NUMERIC   DEFAULT NULL,
    p_observacion      VARCHAR   DEFAULT NULL,
    p_id_usuario       INT       DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo    INT;
    v_id_tercero INT;
    v_id_cuenta  INT;
    v_registro   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Validar tipo de cuenta
    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(COALESCE(p_tipo, ''))
    LIMIT 1;

    IF v_id_tipo IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Tipo de cuenta inválido (COBRAR / PAGAR)');
    END IF;

    -- Validar tercero
    IF p_id_tercero IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Debe indicar el tercero (cliente o proveedor)');
    END IF;

    SELECT id INTO v_id_tercero
    FROM cli_clientes
    WHERE id = p_id_tercero AND estado = 1;

    IF v_id_tercero IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El tercero no existe o está inactivo');
    END IF;

    -- Validar fechas
    IF p_fecha_emision IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha de emisión es obligatoria');
    END IF;

    IF p_fecha_vencimiento IS NOT NULL AND p_fecha_vencimiento < p_fecha_emision THEN
        RETURN json_build_object('registro', NULL, 'error', 'La fecha de vencimiento no puede ser anterior a la emisión');
    END IF;

    -- Validar monto
    IF p_monto IS NULL OR p_monto <= 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El monto debe ser mayor a cero');
    END IF;

    -- Inserción (sin comprobante: cuenta externa/manual)
    INSERT INTO fin_cuenta (
        id_tipo_cuenta,
        id_tercero,
        fecha_emision,
        fecha_vencimiento,
        monto_pendiente,
        monto_abonado,
        monto_saldo,
        observacion,
        id_usuario_creacion
    ) VALUES (
        v_id_tipo,
        v_id_tercero,
        p_fecha_emision,
        p_fecha_vencimiento,
        p_monto,
        0,
        p_monto,
        NULLIF(TRIM(p_observacion), ''),
        p_id_usuario
    )
    RETURNING id INTO v_id_cuenta;

    -- Devolver el registro con formato consistente con fin_obtener_cuenta
    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            fc.id,
            fc.id_tipo_cuenta,
            UPPER(p_tipo) AS tipo,
            fc.id_tercero,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                'Tercero #' || fc.id_tercero
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            fc.fecha_emision,
            fc.fecha_vencimiento,
            fc.monto_pendiente,
            fc.monto_abonado,
            fc.monto_saldo AS saldo,
            fc.observacion
        FROM fin_cuenta fc
        JOIN cli_clientes ter ON ter.id = fc.id_tercero
        WHERE fc.id = v_id_cuenta
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$$;
