-- AI7: módulo de garantía (cobro / saldo / devolución)
-- Seeds EstadoGarantia + TipoMovimientoGarantia (si faltan)

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('EstadoGarantia', 'Estados de garantía: ACTIVA, DEVUELTA, PARCIAL'),
        ('TipoMovimientoGarantia', 'COBRO y DEVOLUCION de garantía')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('ACTIVA', 'Garantía cobrada con saldo pendiente'),
        ('PARCIAL', 'Garantía con devolución parcial'),
        ('DEVUELTA', 'Garantía devuelta en su totalidad')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoGarantia'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('COBRO', 'Cobro inicial de garantía'),
        ('DEVOLUCION', 'Devolución parcial o total de garantía')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMovimientoGarantia'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- TipoVenta.GARANTIA (por si el seed base no se aplicó)
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('GARANTIA', 'Cobro de garantía')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoVenta'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

CREATE OR REPLACE FUNCTION ven_obtener_garantia(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            c.razon_social AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            pr.titulo AS titulo_prestamo,
            g.ubicacion,
            g.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.precio_garantia AS precio_garantia_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.estado,
            g.fecha_creacion,
            g.fecha_modificacion,
            g.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            g.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            (
                SELECT COALESCE(json_agg(row_to_json(m) ORDER BY m.fecha DESC, m.id DESC), '[]'::JSON)
                FROM (
                    SELECT
                        gm.id,
                        gm.id_garantia,
                        gm.id_tipo_movimiento,
                        tm.nombre AS nombre_tipo_movimiento,
                        gm.id_comprobante,
                        vc.serie AS serie_comprobante,
                        vc.numero AS numero_comprobante,
                        CASE
                            WHEN vc.id IS NULL THEN NULL
                            ELSE CONCAT_WS('-', vc.serie, vc.numero)
                        END AS comprobante,
                        gm.fecha,
                        gm.monto,
                        gm.observacion,
                        gm.fecha_creacion
                    FROM ven_garantia_movimiento gm
                    LEFT JOIN gen_lista_opciones tm ON gm.id_tipo_movimiento = tm.id
                    LEFT JOIN ven_comprobante vc ON gm.id_comprobante = vc.id
                    WHERE gm.id_garantia = g.id AND gm.estado = 1
                ) m
            ) AS movimientos
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON g.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN auth_usuarios uc ON g.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON g.id_usuario_modificacion = umod.id
        WHERE g.id = p_id AND g.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;


CREATE OR REPLACE FUNCTION ven_listar_garantias(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM ven_garantia g
    LEFT JOIN cli_clientes c ON g.id_cliente = c.id
    LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
    LEFT JOIN pro_producto p ON g.id_producto = p.id
    WHERE g.estado = 1
      AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
      AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR LOWER(COALESCE(c.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.numero_prestamo, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(p.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(g.ubicacion, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            c.razon_social AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.ubicacion,
            g.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            g.cantidad_venta,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.estado,
            g.fecha_creacion
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        WHERE g.estado = 1
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR g.id_prestamo = p_id_prestamo)
          AND (p_id_estado IS NULL OR g.id_estado = p_id_estado)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR LOWER(COALESCE(c.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.numero_prestamo, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(p.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(g.ubicacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY g.fecha_registro DESC, g.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;


CREATE OR REPLACE FUNCTION ven_crear_garantia(
    p_id_cliente INTEGER,
    p_monto NUMERIC,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_ubicacion VARCHAR DEFAULT NULL,
    p_cantidad_venta NUMERIC DEFAULT NULL,
    p_id_unidad_medida INTEGER DEFAULT NULL,
    p_fecha_registro DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado_activa INTEGER;
    v_id_tipo_cobro INTEGER;
    v_monto NUMERIC(12,4);
    v_fecha DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    v_monto := ROUND(COALESCE(p_monto, 0)::NUMERIC, 4);
    IF v_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto de garantÃ­a debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El prÃ©stamo indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    IF p_id_producto IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    IF p_id_comprobante IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_activa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'ACTIVA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_activa IS NULL THEN
        RETURN json_build_object('error', 'Falta opciÃ³n EstadoGarantia.ACTIVA en catÃ¡logo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_cobro
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'COBRO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_cobro IS NULL THEN
        RETURN json_build_object('error', 'Falta opciÃ³n TipoMovimientoGarantia.COBRO en catÃ¡logo', 'registro', NULL);
    END IF;

    v_fecha := COALESCE(p_fecha_registro, CURRENT_DATE);

    INSERT INTO ven_garantia (
        id_cliente,
        id_prestamo,
        ubicacion,
        id_producto,
        cantidad_venta,
        id_unidad_medida,
        fecha_registro,
        monto_cobrado,
        monto_devuelto,
        monto_saldo,
        id_estado,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_prestamo,
        NULLIF(TRIM(COALESCE(p_ubicacion, '')), ''),
        p_id_producto,
        p_cantidad_venta,
        p_id_unidad_medida,
        v_fecha,
        v_monto,
        0,
        v_monto,
        v_id_estado_activa,
        NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    INSERT INTO ven_garantia_movimiento (
        id_garantia,
        id_tipo_movimiento,
        id_comprobante,
        fecha,
        monto,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_id,
        v_id_tipo_cobro,
        p_id_comprobante,
        v_fecha,
        v_monto,
        'Cobro inicial de garantÃ­a',
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(v_id);
END;
$function$;


CREATE OR REPLACE FUNCTION ven_devolver_garantia(
    p_id INTEGER,
    p_monto NUMERIC,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_fecha DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia RECORD;
    v_monto NUMERIC(12,4);
    v_nuevo_devuelto NUMERIC(12,4);
    v_nuevo_saldo NUMERIC(12,4);
    v_id_tipo_devolucion INTEGER;
    v_id_estado INTEGER;
    v_nombre_estado VARCHAR;
    v_fecha DATE;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id IS NULL THEN
        RETURN json_build_object('error', 'El id de garantÃ­a es obligatorio', 'registro', NULL);
    END IF;

    SELECT * INTO v_garantia
    FROM ven_garantia
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'GarantÃ­a no encontrada', 'registro', NULL);
    END IF;

    IF COALESCE(v_garantia.monto_saldo, 0) <= 0 THEN
        RETURN json_build_object('error', 'La garantÃ­a no tiene saldo pendiente', 'registro', NULL);
    END IF;

    v_monto := ROUND(COALESCE(p_monto, 0)::NUMERIC, 4);
    IF v_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto a devolver debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF v_monto > v_garantia.monto_saldo THEN
        RETURN json_build_object(
            'error',
            'El monto a devolver (' || v_monto || ') supera el saldo (' || v_garantia.monto_saldo || ')',
            'registro',
            NULL
        );
    END IF;

    IF p_id_comprobante IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_devolucion
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'DEVOLUCION' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_devolucion IS NULL THEN
        RETURN json_build_object('error', 'Falta opciÃ³n TipoMovimientoGarantia.DEVOLUCION en catÃ¡logo', 'registro', NULL);
    END IF;

    v_nuevo_devuelto := ROUND(COALESCE(v_garantia.monto_devuelto, 0) + v_monto, 4);
    v_nuevo_saldo := ROUND(COALESCE(v_garantia.monto_cobrado, 0) - v_nuevo_devuelto, 4);
    IF v_nuevo_saldo < 0 THEN
        v_nuevo_saldo := 0;
    END IF;

    IF v_nuevo_saldo = 0 THEN
        v_nombre_estado := 'DEVUELTA';
    ELSE
        v_nombre_estado := 'PARCIAL';
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = v_nombre_estado AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object(
            'error',
            'Falta opciÃ³n EstadoGarantia.' || v_nombre_estado || ' en catÃ¡logo',
            'registro',
            NULL
        );
    END IF;

    v_fecha := COALESCE(p_fecha, CURRENT_DATE);

    UPDATE ven_garantia
    SET
        monto_devuelto = v_nuevo_devuelto,
        monto_saldo = v_nuevo_saldo,
        id_estado = v_id_estado,
        observacion = COALESCE(NULLIF(TRIM(COALESCE(p_observacion, '')), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    INSERT INTO ven_garantia_movimiento (
        id_garantia,
        id_tipo_movimiento,
        id_comprobante,
        fecha,
        monto,
        observacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id,
        v_id_tipo_devolucion,
        p_id_comprobante,
        v_fecha,
        v_monto,
        COALESCE(NULLIF(TRIM(COALESCE(p_observacion, '')), ''), 'DevoluciÃ³n de garantÃ­a'),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(p_id);
END;
$function$;
