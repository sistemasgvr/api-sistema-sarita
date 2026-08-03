-- Crea una cuenta financiera manual (externa a las ventas/compras).
-- Ej.: préstamo bancario a pagar, cobro esperado no derivado de una venta, etc.
-- No usa comprobante: es una cuenta suelta.
-- El tercero puede ser un cliente/proveedor (p_id_tercero) o un nombre libre
-- (p_tercero_nombre). Al menos UNO de los dos debe venir.

DROP FUNCTION IF EXISTS fin_crear_cuenta(VARCHAR, INT, DATE, DATE, NUMERIC, VARCHAR, INT);
DROP FUNCTION IF EXISTS fin_crear_cuenta(VARCHAR, INT, VARCHAR, DATE, DATE, NUMERIC, VARCHAR, VARCHAR, INT, NUMERIC, INT);
DROP FUNCTION IF EXISTS fin_crear_cuenta(VARCHAR, INT, VARCHAR, DATE, DATE, NUMERIC, VARCHAR, VARCHAR, INT, NUMERIC, VARCHAR, INT);

CREATE OR REPLACE FUNCTION fin_crear_cuenta(
    p_tipo             VARCHAR,   -- 'COBRAR' | 'PAGAR'
    p_id_tercero       INT       DEFAULT NULL,
    p_tercero_nombre   VARCHAR   DEFAULT NULL,
    p_fecha_emision    DATE      DEFAULT NULL,
    p_fecha_vencimiento DATE     DEFAULT NULL,
    p_monto            NUMERIC   DEFAULT NULL,
    p_descripcion      VARCHAR   DEFAULT NULL,
    p_observacion      VARCHAR   DEFAULT NULL,
    p_id_banco         INT       DEFAULT NULL,
    p_tasa_interes     NUMERIC   DEFAULT NULL,
    p_numero_comprobante VARCHAR DEFAULT NULL,
    p_id_usuario       INT       DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo    INT;
    v_id_tercero INT;
    v_nombre     VARCHAR;
    v_id_cuenta  INT;
    v_registro   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Validar tipo
    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(COALESCE(p_tipo, ''))
    LIMIT 1;

    IF v_id_tipo IS NULL THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', format(
                'Tipo de cuenta inválido. Recibido: %L. Opciones existentes en TipoCuentaFinanciera: [%s]. Ejecuta el seed fin_tipo_cuenta_opciones.sql si está vacío.',
                p_tipo,
                COALESCE((
                    SELECT string_agg(glo.nombre, ', ')
                    FROM gen_lista_opciones glo
                    JOIN gen_lista gl ON gl.id = glo.id_lista
                    WHERE gl.nombre = 'TipoCuentaFinanciera'
                ), 'vacío')
            )
        );
    END IF;

    -- Validar tercero: al menos uno de los dos
    v_nombre := NULLIF(TRIM(p_tercero_nombre), '');

    IF p_id_tercero IS NULL AND v_nombre IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Debe indicar el tercero (cliente/proveedor) o su nombre');
    END IF;

    IF p_id_tercero IS NOT NULL THEN
        SELECT id INTO v_id_tercero
        FROM cli_clientes
        WHERE id = p_id_tercero AND estado = 1;

        IF v_id_tercero IS NULL THEN
            RETURN json_build_object('registro', NULL, 'error', 'El tercero no existe o está inactivo');
        END IF;
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

    -- Inserción
    INSERT INTO fin_cuenta (
        id_tipo_cuenta, id_tercero, tercero_nombre,
        fecha_emision, fecha_vencimiento,
        monto_pendiente, monto_abonado, monto_saldo,
        descripcion, observacion,
        id_banco, tasa_interes,
        numero_comprobante,
        id_usuario_creacion
    ) VALUES (
        v_id_tipo, v_id_tercero, v_nombre,
        p_fecha_emision, p_fecha_vencimiento,
        p_monto, 0, p_monto,
        NULLIF(TRIM(p_descripcion), ''),
        NULLIF(TRIM(p_observacion), ''),
        p_id_banco, p_tasa_interes,
        NULLIF(TRIM(p_numero_comprobante), ''),
        p_id_usuario
    )
    RETURNING id INTO v_id_cuenta;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            fc.id,
            fc.id_tipo_cuenta,
            UPPER(p_tipo) AS tipo,
            fc.id_tercero,
            fc.tercero_nombre,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                fc.tercero_nombre,
                'Tercero #' || fc.id
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            fc.descripcion,
            fc.numero_comprobante,
            fc.fecha_emision,
            fc.fecha_vencimiento,
            fc.monto_pendiente,
            fc.monto_abonado,
            fc.monto_saldo AS saldo,
            fc.observacion,
            fc.id_banco,
            fc.tasa_interes
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        WHERE fc.id = v_id_cuenta
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$$;
