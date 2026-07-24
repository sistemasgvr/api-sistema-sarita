-- AI3: el contrato de alquiler medicinal rastrea el regulador (producto), no solo el cilindro.
ALTER TABLE bal_alquiler
  ADD COLUMN IF NOT EXISTS id_producto_regulador INT REFERENCES pro_producto(id);

COMMENT ON COLUMN bal_alquiler.id_producto_regulador IS
  'Producto/servicio del regulador en alquiler (cobro recurrente medicinal). El cilindro va en bal_alquiler_detalle.';

CREATE INDEX IF NOT EXISTS idx_bal_alquiler_producto_regulador
  ON bal_alquiler (id_producto_regulador)
  WHERE id_producto_regulador IS NOT NULL;

-- Evitar sobrecargas antiguas (sin id_producto_regulador) si ya existían
DROP FUNCTION IF EXISTS bal_crear_alquiler(
  character varying, integer, integer, date, date, date,
  numeric, numeric, integer, character varying, integer, integer
);
DROP FUNCTION IF EXISTS bal_actualizar_alquiler(
  integer, character varying, integer, integer, date, date, date,
  numeric, numeric, integer, character varying, integer, integer
);
CREATE OR REPLACE FUNCTION bal_crear_alquiler(
    p_numero_alquiler VARCHAR,
    p_id_cliente INTEGER,
    p_id_almacen INTEGER,
    p_fecha_inicio DATE,
    p_fecha_fin_pactada DATE DEFAULT NULL,
    p_fecha_fin_real DATE DEFAULT NULL,
    p_tarifa_diaria NUMERIC DEFAULT 0,
    p_total_cobrado NUMERIC DEFAULT 0,
    p_id_estado INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_producto_regulador INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_numero_alquiler IS NULL OR TRIM(p_numero_alquiler) = '' THEN
        RETURN json_build_object('error', 'El número de alquiler es obligatorio', 'registro', NULL);
    END IF;

    IF p_fecha_inicio IS NULL THEN
        RETURN json_build_object('error', 'La fecha de inicio es obligatoria', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_alquiler WHERE LOWER(TRIM(numero_alquiler)) = LOWER(TRIM(p_numero_alquiler))
    ) THEN
        RETURN json_build_object('error', 'Ya existe un alquiler con el número ' || TRIM(p_numero_alquiler), 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_producto_regulador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto_regulador AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto regulador indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO bal_alquiler (
        numero_alquiler, id_cliente, id_almacen, fecha_inicio,
        fecha_fin_pactada, fecha_fin_real, tarifa_diaria, total_cobrado,
        id_estado, observacion, id_comprobante_venta, id_producto_regulador,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        TRIM(p_numero_alquiler), p_id_cliente, p_id_almacen, p_fecha_inicio,
        p_fecha_fin_pactada, p_fecha_fin_real, COALESCE(p_tarifa_diaria, 0), COALESCE(p_total_cobrado, 0),
        p_id_estado, p_observacion, p_id_comprobante_venta, p_id_producto_regulador,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_alquiler(v_id);
END;
$function$;
CREATE OR REPLACE FUNCTION bal_actualizar_alquiler(
    p_id INTEGER,
    p_numero_alquiler VARCHAR DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_fecha_inicio DATE DEFAULT NULL,
    p_fecha_fin_pactada DATE DEFAULT NULL,
    p_fecha_fin_real DATE DEFAULT NULL,
    p_tarifa_diaria NUMERIC DEFAULT NULL,
    p_total_cobrado NUMERIC DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_producto_regulador INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero := NULLIF(TRIM(p_numero_alquiler), '');

    IF v_numero IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_alquiler WHERE LOWER(TRIM(numero_alquiler)) = LOWER(v_numero) AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro alquiler con el número ' || v_numero, 'registro', NULL);
    END IF;

    IF p_id_producto_regulador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto_regulador AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto regulador indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    UPDATE bal_alquiler
    SET
        numero_alquiler = COALESCE(v_numero, numero_alquiler),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        fecha_inicio = COALESCE(p_fecha_inicio, fecha_inicio),
        fecha_fin_pactada = COALESCE(p_fecha_fin_pactada, fecha_fin_pactada),
        fecha_fin_real = COALESCE(p_fecha_fin_real, fecha_fin_real),
        tarifa_diaria = COALESCE(p_tarifa_diaria, tarifa_diaria),
        total_cobrado = COALESCE(p_total_cobrado, total_cobrado),
        id_estado = COALESCE(p_id_estado, id_estado),
        observacion = COALESCE(p_observacion, observacion),
        id_comprobante_venta = COALESCE(p_id_comprobante_venta, id_comprobante_venta),
        id_producto_regulador = COALESCE(p_id_producto_regulador, id_producto_regulador),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_alquiler(p_id);
END;
$function$;
CREATE OR REPLACE FUNCTION bal_obtener_alquiler(p_id INTEGER)
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
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            c.razon_social AS nombre_cliente,
            al.id_almacen,
            a.nombre AS nombre_almacen,
            al.fecha_inicio,
            al.fecha_fin_pactada,
            al.fecha_fin_real,
            al.tarifa_diaria,
            al.total_cobrado,
            al.id_estado,
            ea.nombre AS nombre_estado,
            al.observacion,
            al.id_comprobante_venta,
            cv.serie AS serie_comprobante_venta,
            cv.numero AS numero_comprobante_venta,
            cv.fecha AS fecha_comprobante_venta,
            cv_cli.razon_social AS nombre_cliente_comprobante_venta,
            cv.total_importe AS total_comprobante_venta,
            al.id_producto_regulador,
            pr.codigo AS codigo_producto_regulador,
            pr.nombre AS nombre_producto_regulador,
            al.estado,
            al.fecha_creacion,
            al.fecha_modificacion,
            al.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            al.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = al.id AND ad.estado = 1
            ) AS total_detalles
        FROM bal_alquiler al
        INNER JOIN cli_clientes c ON al.id_cliente = c.id
        INNER JOIN gen_almacen a ON al.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        LEFT JOIN ven_comprobante cv ON al.id_comprobante_venta = cv.id
        LEFT JOIN cli_clientes cv_cli ON cv.id_cliente = cv_cli.id
        LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
        LEFT JOIN auth_usuarios uc ON al.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON al.id_usuario_modificacion = um.id
        WHERE al.id = p_id AND al.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
CREATE OR REPLACE FUNCTION bal_listar_alquileres(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
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
    FROM bal_alquiler al
    LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
    WHERE al.estado = 1
      AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
      AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
      AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR LOWER(al.numero_alquiler) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(al.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.codigo, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            c.razon_social AS nombre_cliente,
            al.id_almacen,
            a.nombre AS nombre_almacen,
            al.fecha_inicio,
            al.fecha_fin_pactada,
            al.fecha_fin_real,
            al.tarifa_diaria,
            al.total_cobrado,
            al.id_estado,
            ea.nombre AS nombre_estado,
            al.id_comprobante_venta,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante_venta,
            al.id_producto_regulador,
            pr.codigo AS codigo_producto_regulador,
            pr.nombre AS nombre_producto_regulador,
            al.estado,
            al.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = al.id AND ad.estado = 1
            ) AS total_detalles,
            (
                al.id_comprobante_venta IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_alquiler_detalle ad
                    WHERE ad.id_alquiler = al.id AND ad.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_alquiler al
        INNER JOIN cli_clientes c ON al.id_cliente = c.id
        INNER JOIN gen_almacen a ON al.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        LEFT JOIN ven_comprobante cv ON al.id_comprobante_venta = cv.id
        LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
        WHERE al.estado = 1
          AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
          AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
          AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR LOWER(al.numero_alquiler) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(al.observacion, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.codigo, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY al.fecha_inicio DESC, al.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
