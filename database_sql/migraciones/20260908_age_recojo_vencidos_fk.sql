-- ============================================================
-- Migracion: RECOJO desde vencidos por FK (prestamo/alquiler)
-- Fecha: 2026-09-08
--
-- - age_actividad.id_alquiler
-- - TipoOrigenActividad.ALQUILER
-- - age_actividad_item.id_alquiler_detalle
-- - age_listar_vencidos_recojo
-- - age_crear_recojo_origen (sin materializar items)
-- - age_crear_recojo_prestamo (wrapper)
-- - age_obtener_actividad (FKs + detalle_origen en vivo)
-- - age_iniciar_verificacion (materializa items)
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260908_age_recojo_vencidos_fk.sql
-- ============================================================

ALTER TABLE age_actividad
    ADD COLUMN IF NOT EXISTS id_alquiler INT NULL REFERENCES bal_alquiler(id);

CREATE INDEX IF NOT EXISTS idx_age_actividad_id_alquiler
    ON age_actividad (id_alquiler)
    WHERE id_alquiler IS NOT NULL;

ALTER TABLE age_actividad_item
    ADD COLUMN IF NOT EXISTS id_alquiler_detalle INT NULL REFERENCES bal_alquiler_detalle(id);

CREATE INDEX IF NOT EXISTS idx_age_actividad_item_id_alquiler_detalle
    ON age_actividad_item (id_alquiler_detalle)
    WHERE id_alquiler_detalle IS NOT NULL;

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion, estado)
SELECT l.id, 'ALQUILER', 'Nace de un alquiler de cilindros', 1
FROM gen_lista l
WHERE l.nombre = 'TipoOrigenActividad'
  AND NOT EXISTS (
      SELECT 1
      FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = 'ALQUILER' AND lo.estado = 1
  );

-- ---------------------------------------------------------------------------
-- Listar prestamos/alquileres vencidos sin actividad RECOJO vigente
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS age_listar_vencidos_recojo(character varying, integer, integer);

CREATE OR REPLACE FUNCTION age_listar_vencidos_recojo(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 30,
    p_offset integer DEFAULT 0
)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_busqueda VARCHAR := LOWER(TRIM(COALESCE(p_busqueda, '')));
    v_rows JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH vigentes AS (
        SELECT a.id_prestamo, a.id_alquiler
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.estado = 1
          AND ta.nombre = 'RECOJO'
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
    ),
    base AS (
        SELECT
            'PRESTAMO'::VARCHAR AS origen,
            p.id AS id_origen,
            p.numero_prestamo AS numero,
            p.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            p.fecha_retorno_pactada AS fecha_pactada,
            (CURRENT_DATE - p.fecha_retorno_pactada)::INTEGER AS dias_vencido,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = p.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pd.id_balon IS NOT NULL
            ) AS cilindros_pendientes,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_prestamo = p.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ) AS garantias_activas,
            FALSE AS regulador_pendiente
        FROM bal_prestamo p
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND p.fecha_retorno_pactada IS NOT NULL
          AND p.fecha_retorno_pactada < CURRENT_DATE
          AND COALESCE(ep.nombre, 'ACTIVO') = 'ACTIVO'
          AND EXISTS (
              SELECT 1
              FROM bal_prestamo_detalle pd
              WHERE pd.id_prestamo = p.id
                AND pd.estado = 1
                AND pd.fecha_devolucion IS NULL
                AND pd.id_balon IS NOT NULL
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_prestamo = p.id)

        UNION ALL

        SELECT
            'ALQUILER'::VARCHAR,
            a.id,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ),
            a.fecha_fin_pactada,
            (CURRENT_DATE - a.fecha_fin_pactada)::INTEGER,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_alquiler_detalle ad
                WHERE ad.id_alquiler = a.id
                  AND ad.estado = 1
                  AND ad.fecha_devolucion IS NULL
                  AND ad.id_balon IS NOT NULL
            ),
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_alquiler = a.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ),
            (
                a.id_producto_regulador IS NOT NULL
                AND a.fecha_devolucion_regulador IS NULL
            )
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        WHERE a.estado = 1
          AND a.fecha_fin_real IS NULL
          AND a.fecha_fin_pactada IS NOT NULL
          AND a.fecha_fin_pactada < CURRENT_DATE
          AND COALESCE(ea.nombre, 'ACTIVO') = 'ACTIVO'
          AND (
              EXISTS (
                  SELECT 1
                  FROM bal_alquiler_detalle ad
                  WHERE ad.id_alquiler = a.id
                    AND ad.estado = 1
                    AND ad.fecha_devolucion IS NULL
                    AND ad.id_balon IS NOT NULL
              )
              OR (
                  a.id_producto_regulador IS NOT NULL
                  AND a.fecha_devolucion_regulador IS NULL
              )
          )
          AND NOT EXISTS (SELECT 1 FROM vigentes v WHERE v.id_alquiler = a.id)
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE v_busqueda = ''
           OR LOWER(COALESCE(numero, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(COALESCE(nombre_cliente, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(origen) LIKE '%' || v_busqueda || '%'
    )
    SELECT COUNT(*) INTO v_total FROM filtrado;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.dias_vencido DESC, t.numero), '[]'::JSON)
    INTO v_rows
    FROM (
        SELECT *
        FROM filtrado
        ORDER BY dias_vencido DESC, numero
        LIMIT GREATEST(COALESCE(p_limite, 30), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_rows, 'total', v_total);
END;
$function$;

-- ---------------------------------------------------------------------------
-- Crear recojo solo con FK (sin copiar items)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS age_crear_recojo_origen(character varying, integer, date, integer, character varying, integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_origen(
    p_tipo_origen character varying,
    p_id_origen integer,
    p_fecha_programada date DEFAULT NULL::date,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_observaciones character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo_origen   VARCHAR := UPPER(TRIM(COALESCE(p_tipo_origen, '')));
    v_id_existente  INTEGER;
    v_id_tipo       INTEGER;
    v_id_estado     INTEGER;
    v_id_prioridad  INTEGER;
    v_id_origen_cat INTEGER;
    v_id_actividad  INTEGER;
    v_id_cliente    INTEGER;
    v_numero        VARCHAR;
    v_nombre_cli    VARCHAR;
    v_fecha_pactada DATE;
    v_titulo        VARCHAR;
    v_descripcion   VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF v_tipo_origen NOT IN ('PRESTAMO', 'ALQUILER') THEN
        RETURN json_build_object('error', 'tipoOrigen debe ser PRESTAMO o ALQUILER', 'registro', NULL);
    END IF;

    IF p_id_origen IS NULL THEN
        RETURN json_build_object('error', 'idOrigen es obligatorio', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoActividad' AND lo.nombre = 'RECOJO' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoActividad' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    IF v_id_tipo IS NULL OR v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Faltan catálogos TipoActividad/EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_prioridad
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PrioridadActividad' AND lo.nombre = 'ALTA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_origen_cat
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoOrigenActividad' AND lo.nombre = v_tipo_origen AND lo.estado = 1 LIMIT 1;

    IF v_tipo_origen = 'PRESTAMO' THEN
        SELECT p.id_cliente, p.numero_prestamo, p.fecha_retorno_pactada,
               COALESCE(
                   NULLIF(TRIM(cli.razon_social), ''),
                   NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
                   cli.numero_documento
               )
        INTO v_id_cliente, v_numero, v_fecha_pactada, v_nombre_cli
        FROM bal_prestamo p
        LEFT JOIN cli_clientes cli ON cli.id = p.id_cliente
        WHERE p.id = p_id_origen AND p.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El préstamo no existe o está anulado', 'registro', NULL);
        END IF;

        SELECT a.id INTO v_id_existente
        FROM age_actividad a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.id_prestamo = p_id_origen
          AND a.estado = 1
          AND a.id_tipo_actividad = v_id_tipo
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
        ORDER BY a.id DESC
        LIMIT 1;

        v_titulo := format('Recojo préstamo %s', COALESCE(v_numero, p_id_origen::TEXT));
        v_descripcion := format('Recojo de cilindros de %s', COALESCE(v_nombre_cli, 'cliente'));
    ELSE
        SELECT a.id_cliente, a.numero_alquiler, a.fecha_fin_pactada,
               COALESCE(
                   NULLIF(TRIM(cli.razon_social), ''),
                   NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno)), ''),
                   cli.numero_documento
               )
        INTO v_id_cliente, v_numero, v_fecha_pactada, v_nombre_cli
        FROM bal_alquiler a
        LEFT JOIN cli_clientes cli ON cli.id = a.id_cliente
        WHERE a.id = p_id_origen AND a.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'El alquiler no existe o está anulado', 'registro', NULL);
        END IF;

        SELECT act.id INTO v_id_existente
        FROM age_actividad act
        JOIN gen_lista_opciones ea ON ea.id = act.id_estado_actividad
        WHERE act.id_alquiler = p_id_origen
          AND act.estado = 1
          AND act.id_tipo_actividad = v_id_tipo
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
        ORDER BY act.id DESC
        LIMIT 1;

        v_titulo := format('Recojo alquiler %s', COALESCE(v_numero, p_id_origen::TEXT));
        v_descripcion := format('Recojo de alquiler de %s', COALESCE(v_nombre_cli, 'cliente'));
    END IF;

    IF v_id_existente IS NOT NULL THEN
        RETURN json_build_object(
            'error', NULL,
            'registro', json_build_object('id', v_id_existente, 'creada', FALSE, 'items', 0)
        );
    END IF;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada, id_tipo_actividad, id_prioridad,
        id_cliente, id_trabajador_responsable, id_estado_actividad, observaciones,
        id_prestamo, id_alquiler, id_tipo_origen,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        v_titulo, v_descripcion,
        COALESCE(p_fecha_programada, v_fecha_pactada, CURRENT_DATE),
        v_id_tipo, v_id_prioridad,
        v_id_cliente, p_id_trabajador_responsable, v_id_estado, p_observaciones,
        CASE WHEN v_tipo_origen = 'PRESTAMO' THEN p_id_origen ELSE NULL END,
        CASE WHEN v_tipo_origen = 'ALQUILER' THEN p_id_origen ELSE NULL END,
        v_id_origen_cat,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_actividad;

    -- Sin copiar ítems: el detalle se lee por FK hasta iniciar verificación.
    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id', v_id_actividad, 'creada', TRUE, 'items', 0)
    );
END;
$function$;

DROP FUNCTION IF EXISTS age_crear_recojo_prestamo(integer, date, integer, character varying, integer);

CREATE OR REPLACE FUNCTION age_crear_recojo_prestamo(
    p_id_prestamo integer,
    p_fecha_programada date DEFAULT NULL::date,
    p_id_trabajador_responsable integer DEFAULT NULL::integer,
    p_observaciones character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN age_crear_recojo_origen(
        'PRESTAMO',
        p_id_prestamo,
        p_fecha_programada,
        p_id_trabajador_responsable,
        p_observaciones,
        p_id_usuario_auditoria
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- Obtener actividad: FKs origen + detalle_origen en vivo si no hay items
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION age_obtener_actividad(p_id integer)
RETURNS json
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
    v_items JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_detalle_origen JSON := NULL;
    v_tiene_items BOOLEAN;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON)
    INTO v_items
    FROM (
        SELECT
            i.id,
            i.item,
            i.id_producto,
            COALESCE(p.nombre, i.descripcion) AS nombre_producto,
            i.descripcion,
            i.cantidad,
            um.nombre AS nombre_unidad_medida,
            i.id_balon,
            b.codigo_balon,
            b.numero_serie AS numero_serie_balon,
            tb.nombre AS nombre_tipo_balon,
            COALESCE(pgb.nombre, p.nombre) AS nombre_producto_gas,
            i.id_estado_verificacion_salida,
            evs.nombre AS estado_verificacion_salida,
            i.observacion_salida,
            i.id_estado_verificacion_llegada,
            evl.nombre AS estado_verificacion_llegada,
            i.observacion_llegada,
            i.id_estado_producto_recogido,
            epr.nombre AS estado_producto_recogido,
            i.id_doc_salida_detalle,
            i.id_venta_detalle,
            i.id_prestamo_detalle,
            i.id_alquiler_detalle
        FROM age_actividad_item i
        LEFT JOIN pro_producto p ON p.id = i.id_producto
        LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
        LEFT JOIN bal_balon b ON b.id = i.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones evs ON evs.id = i.id_estado_verificacion_salida
        LEFT JOIN gen_lista_opciones evl ON evl.id = i.id_estado_verificacion_llegada
        LEFT JOIN gen_lista_opciones epr ON epr.id = i.id_estado_producto_recogido
        WHERE i.id_actividad = p_id AND i.estado = 1
    ) t;

    v_tiene_items := COALESCE(json_array_length(v_items), 0) > 0;

    SELECT act.id_prestamo, act.id_alquiler
    INTO v_id_prestamo, v_id_alquiler
    FROM age_actividad act
    WHERE act.id = p_id AND act.estado = 1;

    IF NOT v_tiene_items AND v_id_prestamo IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'PRESTAMO',
            'id_origen', p.id,
            'numero', p.numero_prestamo,
            'fecha_pactada', p.fecha_retorno_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        pd.id,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        COALESCE(pd.id_producto, b.id_producto_gas) AS id_producto,
                        COALESCE(pg.nombre, pgb.nombre) AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pg ON pg.id = pd.id_producto
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE pd.id_prestamo = p.id
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                      AND pd.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_prestamo = p.id AND vg.estado = 1
                ) g
            ), '[]'::JSON)
        )
        INTO v_detalle_origen
        FROM bal_prestamo p
        WHERE p.id = v_id_prestamo;
    ELSIF NOT v_tiene_items AND v_id_alquiler IS NOT NULL THEN
        SELECT json_build_object(
            'origen', 'ALQUILER',
            'id_origen', a.id,
            'numero', a.numero_alquiler,
            'fecha_pactada', a.fecha_fin_pactada,
            'cilindros', COALESCE((
                SELECT json_agg(row_to_json(c) ORDER BY c.id)
                FROM (
                    SELECT
                        ad.id,
                        ad.id_balon,
                        b.codigo_balon,
                        b.numero_serie AS numero_serie_balon,
                        tb.nombre AS nombre_tipo_balon,
                        b.id_producto_gas AS id_producto,
                        pgb.nombre AS nombre_producto,
                        pgb.nombre AS nombre_producto_gas,
                        1::NUMERIC AS cantidad
                    FROM bal_alquiler_detalle ad
                    LEFT JOIN bal_balon b ON b.id = ad.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
                    WHERE ad.id_alquiler = a.id
                      AND ad.estado = 1
                      AND ad.fecha_devolucion IS NULL
                      AND ad.id_balon IS NOT NULL
                ) c
            ), '[]'::JSON),
            'garantias', COALESCE((
                SELECT json_agg(row_to_json(g) ORDER BY g.id)
                FROM (
                    SELECT
                        vg.id,
                        vg.monto_saldo,
                        vg.monto_cobrado,
                        vg.monto_devuelto,
                        eg.nombre AS nombre_estado,
                        pr.nombre AS nombre_producto
                    FROM ven_garantia vg
                    LEFT JOIN gen_lista_opciones eg ON eg.id = vg.id_estado
                    LEFT JOIN pro_producto pr ON pr.id = vg.id_producto
                    WHERE vg.id_alquiler = a.id AND vg.estado = 1
                ) g
            ), '[]'::JSON),
            'regulador', CASE
                WHEN a.id_producto_regulador IS NOT NULL AND a.fecha_devolucion_regulador IS NULL
                THEN json_build_object(
                    'id_producto', a.id_producto_regulador,
                    'nombre_producto', COALESCE(pr.nombre, ps.nombre),
                    'codigo_producto', COALESCE(pr.codigo, ps.codigo),
                    'pendiente', TRUE
                )
                ELSE NULL
            END
        )
        INTO v_detalle_origen
        FROM bal_alquiler a
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        WHERE a.id = v_id_alquiler;
    END IF;

    SELECT row_to_json(t)
    INTO v_registro
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            dir.latitud AS latitud_cliente,
            dir.longitud AS longitud_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
            act.id_prestamo,
            bp.numero_prestamo,
            bp.fecha_retorno_pactada AS fecha_retorno_pactada_prestamo,
            act.id_alquiler,
            ba.numero_alquiler,
            ba.fecha_fin_pactada AS fecha_fin_pactada_alquiler,
            act.id_tipo_origen,
            tor.nombre AS nombre_tipo_origen,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.estado,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            act.fecha_creacion,
            act.fecha_modificacion,
            v_items AS items,
            v_detalle_origen AS detalle_origen
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN gen_lista_opciones tor ON tor.id = act.id_tipo_origen
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud
            FROM cli_direcciones cd
            WHERE cd.id_cliente = act.id_cliente AND cd.estado = 1
            ORDER BY cd.es_principal DESC NULLS LAST, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch ON ch.id_trabajador = tr.id AND ch.estado = 1
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN bal_prestamo bp ON bp.id = act.id_prestamo
        LEFT JOIN bal_alquiler ba ON ba.id = act.id_alquiler
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON act.id_usuario_modificacion = umod.id
        WHERE act.id = p_id AND act.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ---------------------------------------------------------------------------
-- Materializar items al iniciar verificacion
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS age_iniciar_verificacion(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_verificacion(
    p_id_actividad integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act RECORD;
    v_id_pendiente INTEGER;
    v_items INTEGER := 0;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_prestamo, a.id_alquiler
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id_actividad AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM age_actividad_item i
        WHERE i.id_actividad = p_id_actividad AND i.estado = 1
    ) THEN
        RETURN age_obtener_actividad(p_id_actividad);
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_act.id_prestamo IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY pd.id),
            COALESCE(pd.id_producto, b.id_producto_gas),
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            pd.id_balon,
            pd.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_prestamo_detalle pd
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        WHERE pd.id_prestamo = v_act.id_prestamo
          AND pd.estado = 1
          AND pd.fecha_devolucion IS NULL
          AND pd.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;
    ELSIF v_act.id_alquiler IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_alquiler_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY ad.id),
            b.id_producto_gas,
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            ad.id_balon,
            ad.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_alquiler_detalle ad
        LEFT JOIN bal_balon b ON b.id = ad.id_balon
        WHERE ad.id_alquiler = v_act.id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL
          AND ad.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;

        -- Regulador pendiente: fila sin balon, solo producto.
        IF EXISTS (
            SELECT 1 FROM bal_alquiler a
            WHERE a.id = v_act.id_alquiler
              AND a.id_producto_regulador IS NOT NULL
              AND a.fecha_devolucion_regulador IS NULL
        ) THEN
            SELECT COALESCE(MAX(item), 0) INTO v_n
            FROM age_actividad_item
            WHERE id_actividad = p_id_actividad AND estado = 1;

            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_estado_verificacion_salida, id_estado_verificacion_llegada,
                id_usuario_creacion, id_usuario_modificacion
            )
            SELECT
                p_id_actividad,
                v_n + 1,
                a.id_producto_regulador,
                COALESCE(pr.nombre, 'Regulador / accesorio'),
                1,
                NULL,
                v_id_pendiente,
                v_id_pendiente,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            FROM bal_alquiler a
            LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
            WHERE a.id = v_act.id_alquiler;

            v_items := v_items + 1;
        END IF;
    ELSE
        RETURN json_build_object(
            'error', 'La actividad no tiene origen de recojo (prestamo/alquiler)',
            'registro', NULL
        );
    END IF;

    RETURN age_obtener_actividad(p_id_actividad);
END;
$function$;
