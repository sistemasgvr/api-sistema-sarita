-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_prestamo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.534Z
DROP FUNCTION IF EXISTS bal_crear_prestamo(p_id_tipo_prestamo integer, p_numero_prestamo character varying, p_id_cliente integer, p_id_proveedor integer, p_id_almacen integer, p_fecha_salida date, p_fecha_retorno_pactada date, p_fecha_retorno_real date, p_titulo character varying, p_observacion character varying, p_id_estado integer, p_id_comprobante_venta integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_prestamo(p_id_tipo_prestamo integer, p_numero_prestamo character varying DEFAULT NULL::character varying, p_id_cliente integer DEFAULT NULL::integer, p_id_proveedor integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_fecha_salida date DEFAULT NULL::date, p_fecha_retorno_pactada date DEFAULT NULL::date, p_fecha_retorno_real date DEFAULT NULL::date, p_titulo character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_id_comprobante_venta integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_nombre_tipo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_tipo_prestamo IS NULL THEN
        RETURN json_build_object('error', 'El tipo de préstamo es obligatorio', 'registro', NULL);
    END IF;

    SELECT lo.nombre
    INTO v_nombre_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = p_id_tipo_prestamo AND lo.estado = 1;

    IF v_nombre_tipo IS NULL THEN
        RETURN json_build_object('error', 'El tipo de préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Contraparte cliente: el código del tipo en TipoPrestamo incluye CLIENTE
    IF v_nombre_tipo ILIKE '%CLIENTE%' THEN
        IF p_id_cliente IS NULL THEN
            RETURN json_build_object('error', 'El cliente es obligatorio para este tipo de préstamo', 'registro', NULL);
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
        END IF;
    ELSIF p_id_cliente IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Los préstamos a cliente deben nacer de una venta (punto de venta).
    -- De esta forma el cilindro queda reservado y vinculado al comprobante.
    IF v_nombre_tipo ILIKE '%CLIENTE%' AND p_id_comprobante_venta IS NULL THEN
        RETURN json_build_object(
            'error',
            'Los préstamos a cliente deben estar vinculados a un comprobante de venta. Regístralos desde la venta en punto de venta.',
            'registro',
            NULL
        );
    END IF;

    IF p_numero_prestamo IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_prestamo WHERE numero_prestamo = TRIM(p_numero_prestamo)
    ) THEN
        RETURN json_build_object('error', 'Ya existe un préstamo con el número ' || TRIM(p_numero_prestamo), 'registro', NULL);
    END IF;

    v_id_estado := p_id_estado;
    IF v_id_estado IS NULL THEN
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'ACTIVO' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado IS NULL THEN
            RETURN json_build_object(
                'error',
                'No se encontró el estado ACTIVO del préstamo. Revise el catálogo EstadoPrestamo.',
                'registro',
                NULL
            );
        END IF;
    END IF;

    INSERT INTO bal_prestamo (
        numero_prestamo, id_tipo_prestamo, id_cliente, id_proveedor, id_almacen,
        fecha_salida, fecha_retorno_pactada, fecha_retorno_real,
        titulo, observacion, id_estado,
        id_comprobante_venta, id_comprobante_compra,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        NULLIF(TRIM(p_numero_prestamo), ''), p_id_tipo_prestamo, p_id_cliente, p_id_proveedor, p_id_almacen,
        p_fecha_salida, p_fecha_retorno_pactada, p_fecha_retorno_real,
        p_titulo, p_observacion, v_id_estado,
        p_id_comprobante_venta, p_id_comprobante_compra,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_prestamo(v_id);
END;
$function$
