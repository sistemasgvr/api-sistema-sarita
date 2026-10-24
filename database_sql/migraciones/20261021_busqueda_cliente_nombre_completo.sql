-- Búsqueda por nombre de cliente en todos los listados.
--
-- 1. gen_texto_coincide exige cada palabra del texto buscado, en cualquier orden,
--    en lugar de la frase exacta: "MUNDACA PEREZ CLARIZA" encuentra a
--    "CLARIZA DEL CARMEN MUNDACA PEREZ".
-- 2. cli_texto_busqueda junta razón social, nombres, apellidos, documento y código
--    del cliente. Los listados que buscaban solo en razon_social no encontraban a las
--    personas naturales, que la tienen vacía.
BEGIN;
SET LOCAL lock_timeout = '10s';

CREATE OR REPLACE FUNCTION gen_texto_coincide(p_haystack text, p_needle text)
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT NOT EXISTS (
    SELECT 1
    FROM regexp_split_to_table(btrim(gen_normalizar_texto(p_needle)), '\s+') AS t(palabra)
    WHERE t.palabra <> ''
      AND strpos(gen_normalizar_texto(p_haystack), t.palabra) = 0
  );
$function$;

CREATE OR REPLACE FUNCTION cli_texto_busqueda(p_cliente cli_clientes)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT concat_ws(' ',
    p_cliente.razon_social,
    p_cliente.nombres,
    p_cliente.apellido_paterno,
    p_cliente.apellido_materno,
    p_cliente.numero_documento,
    p_cliente.codigo_interno
  );
$function$;

-- age_listar_actividades
CREATE OR REPLACE FUNCTION public.age_listar_actividades(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_id_estado integer DEFAULT NULL::integer, p_id_tipo integer DEFAULT NULL::integer, p_id_prioridad integer DEFAULT NULL::integer, p_sin_responsable boolean DEFAULT NULL::boolean)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM age_actividad act
    LEFT JOIN cli_clientes c ON act.id_cliente = c.id
    WHERE act.estado = 1
      AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
      AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
      AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
      AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
      AND (p_sin_responsable IS NULL OR (
          (p_sin_responsable AND act.id_trabajador_responsable IS NULL)
          OR (NOT p_sin_responsable AND act.id_trabajador_responsable IS NOT NULL)
      ))
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(act.titulo, p_busqueda)
          OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
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
            COALESCE(NULLIF(TRIM(c.razon_social), ''), NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''), c.numero_documento) AS razon_social_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_trabajador_apoyo,
            TRIM(CONCAT_WS(' ', ap.nombres, ap.apellido_paterno, ap.apellido_materno)) AS nombre_trabajador_apoyo,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            ch.id AS id_chofer_responsable,
            NULLIF(TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)), '') AS nombre_chofer_responsable,
            COALESCE(act.id_comprobante, ds.id_venta) AS id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            cc.id AS id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            act.id_doc_salida,
            ds.serie AS serie_doc_salida,
            ds.numero_sunat AS numero_sunat_doc_salida,
            ds.numero AS numero_doc_salida,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.fecha_creacion,
            act.fecha_modificacion,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
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
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN tra_trabajadores ap ON ap.id = act.id_trabajador_apoyo
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN doc_salida ds ON act.id_doc_salida = ds.id
        LEFT JOIN LATERAL (
            SELECT ch0.* FROM gen_chofer ch0
            WHERE ch0.id = COALESCE(act.id_chofer_responsable, ds.id_chofer)
               OR (act.id_chofer_responsable IS NULL AND ds.id_chofer IS NULL AND ch0.id_trabajador = tr.id AND ch0.estado = 1)
            ORDER BY ch0.id LIMIT 1
        ) ch ON TRUE
        LEFT JOIN ven_comprobante vc ON vc.id = COALESCE(act.id_comprobante, ds.id_venta)
        LEFT JOIN LATERAL (
            SELECT compra.id, compra.serie, compra.numero FROM com_comprobante_compra compra
            WHERE compra.id = ds.id_comprobante_compra
               OR (ds.id_comprobante_compra IS NULL AND compra.id_doc_salida = ds.id AND compra.estado = 1)
            ORDER BY compra.id DESC LIMIT 1
        ) cc ON TRUE
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
        WHERE act.estado = 1
          AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
          AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
          AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
          AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
          AND (p_sin_responsable IS NULL OR (
              (p_sin_responsable AND act.id_trabajador_responsable IS NULL)
              OR (NOT p_sin_responsable AND act.id_trabajador_responsable IS NOT NULL)
          ))
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(act.titulo, p_busqueda)
              OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
          )
        ORDER BY
            CASE
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('PENDIENTE', 'PROGRAMADA') THEN 0
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('CANCELADA', 'CANCELADO') THEN 2
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA' THEN 3
                ELSE 1
            END ASC,
            act.fecha_programada DESC,
            act.hora_inicio_estimada DESC NULLS LAST,
            act.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- age_listar_vencidos_recojo
CREATE OR REPLACE FUNCTION public.age_listar_vencidos_recojo(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 30, p_offset integer DEFAULT 0, p_incluir_no_vencidos boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_busqueda VARCHAR := LOWER(TRIM(COALESCE(p_busqueda, '')));
    v_rows JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH vigentes AS (
        SELECT a.id, a.id_prestamo, a.id_alquiler
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
                JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
                JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                WHERE pd.id_prestamo = p.id
                  AND pd.estado = 1 AND pd.rol = 'ENTREGADO'
                  AND pd.fecha_devolucion IS NULL
                  AND UPPER(TRIM(eb.nombre)) IN ('EN_PODER_CLIENTE', 'PRESTADO_CLIENTE')
                  AND b.id_cliente_ubicacion = p.id_cliente
            ) AS cilindros_pendientes,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_prestamo = p.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ) AS garantias_activas,
            FALSE AS regulador_pendiente,
            (SELECT v.id FROM vigentes v WHERE v.id_prestamo = p.id ORDER BY v.id DESC LIMIT 1) AS recojo_abierto,
            COALESCE((SELECT json_agg(row_to_json(x)) FROM age_balones_disponibles_recojo(p.id) x), '[]'::JSON) AS balones_disponibles
        FROM bal_prestamo p
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND (p_incluir_no_vencidos OR p.fecha_retorno_pactada < CURRENT_DATE)
          AND COALESCE(ep.nombre, 'ACTIVO') = 'ACTIVO'

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
            0::INTEGER,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_alquiler = a.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ),
            (
                COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
                AND a.fecha_devolucion_regulador IS NULL
            ),
            (SELECT v.id FROM vigentes v WHERE v.id_alquiler = a.id ORDER BY v.id DESC LIMIT 1),
            '[]'::JSON
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        WHERE a.estado = 1
          AND a.fecha_fin_real IS NULL
          AND (p_incluir_no_vencidos OR a.fecha_fin_pactada < CURRENT_DATE)
          AND COALESCE(ea.nombre, 'ACTIVO') = 'ACTIVO'
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE v_busqueda = ''
           OR LOWER(COALESCE(numero, '')) LIKE '%' || v_busqueda || '%'
           OR gen_texto_coincide(nombre_cliente, v_busqueda)
           OR LOWER(origen) LIKE '%' || v_busqueda || '%'
    )
    SELECT
        (SELECT COUNT(*) FROM filtrado),
        (
            SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.dias_vencido DESC NULLS LAST, t.numero), '[]'::JSON)
            FROM (
                SELECT *
                FROM filtrado
                ORDER BY dias_vencido DESC NULLS LAST, numero
                LIMIT GREATEST(COALESCE(p_limite, 30), 1)
                OFFSET GREATEST(COALESCE(p_offset, 0), 0)
            ) t
        )
    INTO v_total, v_rows;

    RETURN json_build_object('registros', v_rows, 'total', v_total);
END;
$function$;

-- bal_listar_alquileres
CREATE OR REPLACE FUNCTION public.bal_listar_alquileres(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
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
    LEFT JOIN pro_producto ps ON al.id_producto_stock = ps.id
    LEFT JOIN cli_clientes c ON al.id_cliente = c.id
    WHERE al.estado = 1
      AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
      AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
      AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(al.numero_alquiler, p_busqueda)
          OR gen_texto_coincide(COALESCE(al.observacion, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(ps.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(ps.codigo, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            al.id,
            al.numero_alquiler,
            al.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
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
            al.id_producto_stock,
            ps.codigo AS codigo_producto_stock,
            ps.nombre AS nombre_producto_stock,
            al.fecha_devolucion_regulador,
            al.id_condicion_regulador,
            cr.nombre AS nombre_condicion_regulador,
            al.id_mantenimiento_regulador,
            al.estado,
            al.fecha_creacion,
            (al.id_comprobante_venta IS NULL) AS puede_eliminar
        FROM bal_alquiler al
        INNER JOIN cli_clientes c ON al.id_cliente = c.id
        INNER JOIN gen_almacen a ON al.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ea ON al.id_estado = ea.id
        LEFT JOIN gen_lista_opciones cr ON al.id_condicion_regulador = cr.id
        LEFT JOIN ven_comprobante cv ON al.id_comprobante_venta = cv.id
        LEFT JOIN pro_producto pr ON al.id_producto_regulador = pr.id
        LEFT JOIN pro_producto ps ON al.id_producto_stock = ps.id
        WHERE al.estado = 1
          AND (p_id_cliente IS NULL OR al.id_cliente = p_id_cliente)
          AND (p_id_almacen IS NULL OR al.id_almacen = p_id_almacen)
          AND (p_id_estado IS NULL OR al.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(al.numero_alquiler, p_busqueda)
              OR gen_texto_coincide(COALESCE(al.observacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(ps.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(ps.codigo, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
          )
        ORDER BY al.fecha_inicio DESC, al.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- bal_listar_balones
CREATE OR REPLACE FUNCTION public.bal_listar_balones(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_marca_cilindro integer DEFAULT NULL::integer, p_ph_vencida boolean DEFAULT NULL::boolean, p_ph_por_vencer_dias integer DEFAULT NULL::integer, p_id_cliente_relacionado integer DEFAULT NULL::integer, p_solo_bajas boolean DEFAULT NULL::boolean, p_familia_gas character varying DEFAULT NULL::character varying, p_id_propietario integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_solo_llenos_fuera boolean DEFAULT NULL::boolean, p_id_planta integer DEFAULT NULL::integer, p_tipo_valvula character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_alertas JSON;
    v_resumen JSON;
    v_familia_gas VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_familia_gas := NULLIF(TRIM(COALESCE(p_familia_gas, '')), '');

    SELECT
        COUNT(*),
        json_build_object(
            'total', COUNT(*),
            'en_almacen', COUNT(*) FILTER (WHERE eb.nombre = 'DISPONIBLE')
        )
    INTO v_total, v_resumen
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
    LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
    LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_producto_gas IS NULL OR b.id_producto_gas = p_id_producto_gas)
      AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
      AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
      AND (p_id_propietario IS NULL OR b.id_propietario = p_id_propietario)
      AND (
          p_id_cliente_relacionado IS NULL
          OR b.id_cliente_ubicacion = p_id_cliente_relacionado
          OR b.id_cliente_propietario = p_id_cliente_relacionado
      )
      AND (
          p_id_cliente_relacionado IS NULL
          OR eb.nombre IS NULL
          OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
      )
      AND (
          p_solo_bajas IS NULL
          OR (
              p_solo_bajas = TRUE
              AND eb.nombre IN ('DADO_DE_BAJA', 'ROBO')
          )
          OR (
              p_solo_bajas = FALSE
              AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
          )
      )
      AND (
          p_solo_llenos_fuera IS NOT TRUE
          OR (
              COALESCE(eb.nombre, '') IS DISTINCT FROM 'DISPONIBLE'
              AND COALESCE(eb.nombre, '') NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
      )
      AND (
          p_ph_vencida IS NULL
          OR (
              p_ph_vencida = TRUE
              AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
          )
          OR (
              p_ph_vencida = FALSE
              AND (
                  b.fecha_proxima_prueba_hidrostatica IS NULL
                  OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              )
          )
      )
      AND (
          p_ph_por_vencer_dias IS NULL
          OR (
              b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
          )
      )
      AND (
          v_familia_gas IS NULL
          OR gen_texto_coincide(COALESCE(tb.nombre, ''), v_familia_gas)
          OR gen_texto_coincide(COALESCE(pg.nombre, ''), v_familia_gas)
          OR gen_texto_coincide(COALESCE(pg.codigo, ''), v_familia_gas)
      )
      AND (p_id_planta IS NULL OR b.id_planta = p_id_planta)
      AND (
          p_tipo_valvula IS NULL
          OR b.tipo_valvula ILIKE '%' || TRIM(p_tipo_valvula) || '%'
      )
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(b.codigo_balon, p_busqueda)
          OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(b.libro_cilindro, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(tb.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pg.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(mc.nombre, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(cu), p_busqueda)
          OR gen_texto_coincide(COALESCE(cu.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cu.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(cp), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.numero_documento, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.libro_cilindro,
            b.pagina_libro,
            b.fecha_registro,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_cliente_ubicacion,
            COALESCE(
                NULLIF(TRIM(cu.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cu.nombres, cu.apellido_paterno, cu.apellido_materno)), ''),
                cu.numero_documento
            ) AS nombre_cliente_ubicacion,
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                cp.numero_documento
            ) AS nombre_cliente_propietario,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            tb.capacidad_lb,
            tb.peso AS peso_tipo_balon,
            b.peso_aproximado_kg,
            COALESCE(b.peso_aproximado_kg, tb.peso) AS peso_guia_kg,
            b.sello_inspeccion,
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            b.organo_inspector_no_aplica,
            b.id_planta,
            COALESCE(pl.razon_social, TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno))) AS nombre_planta,
            b.anio_fabricacion,
            b.mes_fabricacion,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.presion_actual,
            b.tipo_valvula,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'PENDIENTE'
            ) AS tiene_solicitud_baja_pendiente,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'APROBADA'
            ) AS tiene_baja_aprobada,
            NOT (
                COALESCE(eb.nombre, '') IN ('DADO_DE_BAJA', 'ROBO')
                OR EXISTS (
                    SELECT 1 FROM bal_baja_balon bb
                    WHERE bb.id_balon = b.id AND bb.estado = 1
                      AND bb.estado_aprobacion IN ('PENDIENTE', 'APROBADA')
                )
                OR EXISTS (SELECT 1 FROM inv_movimiento m WHERE m.id_balon = b.id AND m.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_movimiento_recarga mr WHERE mr.id_balon = b.id AND mr.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_prestamo_detalle pd WHERE pd.id_balon = b.id AND pd.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_mantenimiento mt WHERE mt.id_balon = b.id AND mt.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_balon_ph_historial ph WHERE ph.id_balon = b.id AND ph.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_balon_estado_historial eh WHERE eh.id_balon = b.id AND eh.estado = 1)
                OR EXISTS (SELECT 1 FROM ven_comprobante_detalle vd WHERE vd.id_balon = b.id AND vd.estado = 1)
                OR EXISTS (SELECT 1 FROM doc_salida_detalle gd WHERE gd.id_balon = b.id AND gd.estado = 1)
            ) AS puede_eliminar,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_lista_opciones um ON tb.id_unidad_medida = um.id
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones oi ON b.id_organo_inspector = oi.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
        LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
        LEFT JOIN cli_clientes pl ON b.id_planta = pl.id
        WHERE b.estado = 1
          AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
          AND (p_id_producto_gas IS NULL OR b.id_producto_gas = p_id_producto_gas)
          AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
          AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
          AND (p_id_propietario IS NULL OR b.id_propietario = p_id_propietario)
          AND (
              p_id_cliente_relacionado IS NULL
              OR b.id_cliente_ubicacion = p_id_cliente_relacionado
              OR b.id_cliente_propietario = p_id_cliente_relacionado
          )
          AND (
              p_id_cliente_relacionado IS NULL
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (
              p_solo_bajas IS NULL
              OR (
                  p_solo_bajas = TRUE
                  AND eb.nombre IN ('DADO_DE_BAJA', 'ROBO')
              )
              OR (
                  p_solo_bajas = FALSE
                  AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
              )
          )
          AND (
              p_solo_llenos_fuera IS NOT TRUE
              OR (
                  COALESCE(eb.nombre, '') IS DISTINCT FROM 'DISPONIBLE'
                  AND COALESCE(eb.nombre, '') NOT IN ('DADO_DE_BAJA', 'ROBO')
              )
          )
          AND (
              p_ph_vencida IS NULL
              OR (
                  p_ph_vencida = TRUE
                  AND b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
              )
              OR (
                  p_ph_vencida = FALSE
                  AND (
                      b.fecha_proxima_prueba_hidrostatica IS NULL
                      OR b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  )
              )
          )
          AND (
              p_ph_por_vencer_dias IS NULL
              OR (
                  b.fecha_proxima_prueba_hidrostatica IS NOT NULL
                  AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
                  AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + make_interval(days => p_ph_por_vencer_dias)
              )
          )
          AND (
              v_familia_gas IS NULL
              OR gen_texto_coincide(COALESCE(tb.nombre, ''), v_familia_gas)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), v_familia_gas)
              OR gen_texto_coincide(COALESCE(pg.codigo, ''), v_familia_gas)
          )
          AND (p_id_planta IS NULL OR b.id_planta = p_id_planta)
          AND (
              p_tipo_valvula IS NULL
              OR b.tipo_valvula ILIKE '%' || TRIM(p_tipo_valvula) || '%'
          )
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(b.codigo_balon, p_busqueda)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.libro_cilindro, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(tb.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(mc.nombre, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(cu), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(cp), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.numero_documento, ''), p_busqueda)
          )
        ORDER BY b.fecha_creacion DESC NULLS LAST, b.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    SELECT json_build_object(
        'ph_por_vencer_90', COUNT(*) FILTER (
            WHERE b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica >= CURRENT_DATE
              AND b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days'
              AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
        ),
        'ph_vencida', COUNT(*) FILTER (
            WHERE b.fecha_proxima_prueba_hidrostatica IS NOT NULL
              AND b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE
              AND (eb.nombre IS NULL OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO'))
        ),
        'dados_de_baja', COUNT(*) FILTER (
            WHERE eb.nombre IN ('DADO_DE_BAJA', 'ROBO')
        )
    )
    INTO v_alertas
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    WHERE b.estado = 1;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'alertas', v_alertas,
        'resumen', v_resumen
    );
END;
$function$;

-- bal_listar_lotes_protocolo
CREATE OR REPLACE FUNCTION public.bal_listar_lotes_protocolo(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_vencidos boolean DEFAULT NULL::boolean, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*)
    INTO v_total
    FROM bal_lote_protocolo lp
    LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
    LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
    WHERE lp.estado = 1
      AND (p_id_proveedor IS NULL OR lp.id_proveedor = p_id_proveedor)
      AND (p_id_producto_gas IS NULL OR lp.id_producto_gas = p_id_producto_gas)
      AND (p_fecha_desde IS NULL OR lp.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR lp.fecha_emision <= p_fecha_hasta)
      AND (
          p_vencidos IS NULL
          OR (p_vencidos = TRUE AND lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE)
          OR (p_vencidos = FALSE AND (lp.fecha_vencimiento IS NULL OR lp.fecha_vencimiento >= CURRENT_DATE))
      )
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(lp.numero_lote, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(lp.numero_protocolo, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(pv), p_busqueda)
          OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno), ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(lp.cilindro_muestreado_serie, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            lp.id,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno, pv.apellido_materno)), ''),
                pv.numero_documento
            ) AS nombre_proveedor,
            lp.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            lp.descripcion_producto,
            lp.presentacion,
            lp.fecha_analisis,
            lp.fecha_emision,
            lp.fecha_fabricacion,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.tamano_lote_m3,
            lp.cantidad_envases,
            lp.valoracion_o2_pct,
            lp.cilindro_muestreado_serie,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf,
            ar.nombre_original AS nombre_archivo_pdf,
            (
                SELECT COUNT(*)::INT
                FROM bal_lote_protocolo_envase e
                WHERE e.id_lote_protocolo = lp.id AND e.estado = 1
            ) AS total_envases,
            (
                SELECT COUNT(*)::INT
                FROM bal_lote_protocolo_envase e
                WHERE e.id_lote_protocolo = lp.id AND e.estado = 1 AND e.id_balon IS NOT NULL
            ) AS total_envases_vinculados,
            (
                SELECT COUNT(*)::INT
                FROM bal_balon b
                WHERE b.id_lote_protocolo_vigente = lp.id AND b.estado = 1
            ) AS total_balones_vigentes,
            lp.fecha_creacion,
            lp.fecha_modificacion
        FROM bal_lote_protocolo lp
        LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
        LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        WHERE lp.estado = 1
          AND (p_id_proveedor IS NULL OR lp.id_proveedor = p_id_proveedor)
          AND (p_id_producto_gas IS NULL OR lp.id_producto_gas = p_id_producto_gas)
          AND (p_fecha_desde IS NULL OR lp.fecha_emision >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR lp.fecha_emision <= p_fecha_hasta)
          AND (
              p_vencidos IS NULL
              OR (p_vencidos = TRUE AND lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE)
              OR (p_vencidos = FALSE AND (lp.fecha_vencimiento IS NULL OR lp.fecha_vencimiento >= CURRENT_DATE))
          )
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(lp.numero_lote, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(lp.numero_protocolo, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(pv), p_busqueda)
          OR gen_texto_coincide(COALESCE(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno), ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(lp.cilindro_muestreado_serie, ''), p_busqueda)
          )
        ORDER BY lp.fecha_emision DESC NULLS LAST, lp.id DESC
        LIMIT GREATEST(COALESCE(p_limite, 10), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- bal_listar_movimientos_recarga
CREATE OR REPLACE FUNCTION public.bal_listar_movimientos_recarga(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_movimiento_recarga mr
    INNER JOIN bal_balon b ON mr.id_balon = b.id
    LEFT JOIN doc_salida rp ON rp.id = mr.id_doc_salida AND rp.estado = 1
    LEFT JOIN doc_salida grs ON grs.id = rp.id AND grs.estado = 1
    LEFT JOIN com_comprobante_compra cc ON cc.id = mr.id_comprobante_compra AND cc.estado = 1
    LEFT JOIN cli_clientes cli ON mr.id_cliente = cli.id
    LEFT JOIN gen_lista_opciones tr ON mr.id_tipo_recarga = tr.id
    WHERE mr.estado = 1
      AND (p_id_balon IS NULL OR mr.id_balon = p_id_balon)
      AND (p_id_almacen IS NULL OR mr.id_almacen = p_id_almacen)
      AND (p_fecha_desde IS NULL OR mr.fecha_salida_almacen >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR mr.fecha_salida_almacen <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(b.codigo_balon, p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(cli), p_busqueda)
          OR gen_texto_coincide(COALESCE(mr.numero_guia_salida, rp.numero_guia_salida, grs.numero_sunat, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(mr.numero_factura, cc.numero, rp.numero_factura, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(tr.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            mr.id,
            mr.fecha_salida_almacen,
            mr.id_balon,
            b.codigo_balon,
            mr.id_balon_origen,
            bo.codigo_balon AS codigo_balon_origen,
            mr.id_comprobante_compra,
            mr.id_cliente,
            cli.razon_social AS nombre_cliente,
            mr.id_tipo_recarga,
            tr.nombre AS tipo_recarga_nombre,
            mr.id_producto,
            p.nombre AS nombre_producto,
            COALESCE(mr.capacidad, tb.capacidad) AS capacidad,
            mr.id_doc_salida,
            rp.numero AS numero_recarga_planta,
            rp.id,
            COALESCE(mr.serie_guia_salida, rp.serie_guia_salida, grs.serie) AS serie_guia_salida,
            COALESCE(mr.numero_guia_salida, rp.numero_guia_salida, grs.numero_sunat) AS numero_guia_salida,
            COALESCE(mr.serie_factura, cc.serie, rp.serie_factura) AS serie_factura,
            COALESCE(mr.numero_factura, cc.numero, rp.numero_factura) AS numero_factura,
            mr.id_comprobante,
            mr.fecha_llegada_almacen,
            mr.id_almacen,
            a.nombre AS nombre_almacen,
            mr.estado,
            mr.fecha_creacion,
            mr.id_comprobante IS NULL
            AND NOT EXISTS (
                SELECT 1 FROM bal_balon_ph_historial ph
                WHERE ph.id_movimiento_recarga = mr.id AND ph.estado = 1
            ) AS puede_eliminar
        FROM bal_movimiento_recarga mr
        INNER JOIN bal_balon b ON mr.id_balon = b.id
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN bal_balon bo ON mr.id_balon_origen = bo.id
        LEFT JOIN doc_salida rp ON rp.id = mr.id_doc_salida AND rp.estado = 1
        LEFT JOIN doc_salida grs ON grs.id = rp.id AND grs.estado = 1
        LEFT JOIN com_comprobante_compra cc ON cc.id = mr.id_comprobante_compra AND cc.estado = 1
        LEFT JOIN cli_clientes cli ON mr.id_cliente = cli.id
        LEFT JOIN gen_lista_opciones tr ON mr.id_tipo_recarga = tr.id
        LEFT JOIN pro_producto p ON mr.id_producto = p.id
        LEFT JOIN gen_almacen a ON mr.id_almacen = a.id
        WHERE mr.estado = 1
          AND (p_id_balon IS NULL OR mr.id_balon = p_id_balon)
          AND (p_id_almacen IS NULL OR mr.id_almacen = p_id_almacen)
          AND (p_fecha_desde IS NULL OR mr.fecha_salida_almacen >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR mr.fecha_salida_almacen <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(b.codigo_balon, p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(cli), p_busqueda)
              OR gen_texto_coincide(COALESCE(mr.numero_guia_salida, rp.numero_guia_salida, grs.numero_sunat, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(mr.numero_factura, cc.numero, rp.numero_factura, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(tr.nombre, ''), p_busqueda)
          )
        ORDER BY mr.fecha_salida_almacen DESC, mr.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- bal_listar_prestamo_detalles
CREATE OR REPLACE FUNCTION public.bal_listar_prestamo_detalles(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_prestamo integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
    LEFT JOIN bal_balon b ON pd.id_balon = b.id
    LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
    WHERE pd.estado = 1
      AND (p_id_prestamo IS NULL OR pd.id_prestamo = p_id_prestamo)
      AND (p_id_balon IS NULL OR pd.id_balon = p_id_balon)
      AND (p_id_estado IS NULL OR pd.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pd.motivo_especifico, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            pd.id,
            pd.id_prestamo,
            pr.numero_prestamo,
            pd.id_balon,
            b.codigo_balon,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            c.razon_social AS nombre_cliente,
            pr.id_almacen,
            a.nombre AS nombre_almacen,
            pd.id_producto,
            COALESCE(pg.nombre, p.nombre) AS nombre_producto,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            eb.nombre AS nombre_estado_balon,
            pd.fecha_entregado,
            pd.fecha_prestamo,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            pd.id_doc_salida_entrega AS id_guia_entrega,
            pd.serie_guia_entrega,
            pd.numero_guia_entrega,
            pd.id_doc_salida_devolucion AS id_guia_devolucion,
            pd.serie_guia_devolucion,
            pd.numero_guia_devolucion,
            pd.id_estado,
            ep.nombre AS nombre_estado,
            pd.rol,
            pd.estado,
            pd.fecha_creacion
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
        LEFT JOIN bal_balon b ON pd.id_balon = b.id
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN gen_almacen a ON pr.id_almacen = a.id
        LEFT JOIN pro_producto p ON pd.id_producto = p.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones ep ON pd.id_estado = ep.id
        WHERE pd.estado = 1
          AND (p_id_prestamo IS NULL OR pd.id_prestamo = p_id_prestamo)
          AND (p_id_balon IS NULL OR pd.id_balon = p_id_balon)
          AND (p_id_estado IS NULL OR pd.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pd.motivo_especifico, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
          )
        ORDER BY pd.fecha_prestamo DESC NULLS LAST, pd.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- bal_listar_prestamos
CREATE OR REPLACE FUNCTION public.bal_listar_prestamos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_prestamo integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_prestamo pr
    LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
    LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
    WHERE pr.estado = 1
      AND (p_id_tipo_prestamo IS NULL OR pr.id_tipo_prestamo = p_id_tipo_prestamo)
      AND (p_id_cliente IS NULL OR pr.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR pr.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.titulo, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            pr.id,
            pr.numero_prestamo,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            pr.fecha_salida,
            pr.fecha_retorno_pactada,
            pr.fecha_retorno_real,
            pr.titulo,
            pr.id_estado,
            ep.nombre AS nombre_estado,
            pr.id_prestamo_origen,
            po.numero_prestamo AS numero_prestamo_origen,
            pr.id_comprobante_venta,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante_venta,
            pr.id_comprobante_compra,
            CASE
                WHEN cc.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cc.serie, cc.numero)
            END AS comprobante_compra,
            pr.estado,
            pr.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = pr.id AND pd.estado = 1
            ) AS total_detalles,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia vg
                WHERE vg.id_prestamo = pr.id AND vg.estado = 1
            ) AS total_garantias,
            (
                pr.id_comprobante_venta IS NULL
                AND pr.id_comprobante_compra IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_prestamo_detalle pd
                    WHERE pd.id_prestamo = pr.id AND pd.estado = 1
                )
                AND NOT EXISTS (
                    SELECT 1 FROM ven_garantia vg
                    WHERE vg.id_prestamo = pr.id AND vg.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_prestamo pr
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN gen_lista_opciones ep ON pr.id_estado = ep.id
        LEFT JOIN ven_comprobante cv ON pr.id_comprobante_venta = cv.id
        LEFT JOIN bal_prestamo po ON po.id = pr.id_prestamo_origen
        LEFT JOIN com_comprobante_compra cc ON pr.id_comprobante_compra = cc.id
        WHERE pr.estado = 1
          AND (p_id_tipo_prestamo IS NULL OR pr.id_tipo_prestamo = p_id_tipo_prestamo)
          AND (p_id_cliente IS NULL OR pr.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR pr.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.titulo, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
          )
        ORDER BY pr.fecha_salida DESC NULLS LAST, pr.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- bal_reporte_alquileres_antiguedad
CREATE OR REPLACE FUNCTION public.bal_reporte_alquileres_antiguedad(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_rango_dias character varying DEFAULT NULL::character varying, p_solo_pendientes boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH base AS (
        SELECT
            a.id AS id_alquiler,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            a.id_almacen,
            alm.nombre AS nombre_almacen,
            COALESCE(a.id_producto_regulador, a.id_producto_stock) AS id_producto,
            COALESCE(pr.nombre, ps.nombre) AS nombre_producto,
            COALESCE(pr.codigo, ps.codigo) AS codigo_producto,
            ea.nombre AS nombre_estado,
            a.dias_periodo,
            a.tarifa_diaria,
            a.fecha_inicio AS fecha_inicio_alquiler,
            a.fecha_fin_pactada,
            a.fecha_devolucion_regulador AS fecha_devolucion,
            cr.nombre AS nombre_condicion_regulador,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN NULL
                ELSE (CURRENT_DATE - a.fecha_inicio)::INTEGER
            END AS dias_en_alquiler,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN NULL
                WHEN a.fecha_fin_pactada IS NULL THEN NULL
                ELSE GREATEST((CURRENT_DATE - a.fecha_fin_pactada)::INTEGER, 0)
            END AS dias_atraso,
            CASE
                WHEN a.fecha_devolucion_regulador IS NOT NULL THEN 'DEVUELTO'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 180 THEN 'CRITICO_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 90 THEN 'SEGUIMIENTO_90_180'
                WHEN (CURRENT_DATE - a.fecha_inicio) >= 30 THEN 'ATENCION_30_90'
                ELSE 'RECIENTE_0_30'
            END AS rango_antiguedad
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_almacen alm ON alm.id = a.id_almacen
        LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
        LEFT JOIN pro_producto ps ON ps.id = a.id_producto_stock
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        LEFT JOIN gen_lista_opciones cr ON cr.id = a.id_condicion_regulador
        WHERE a.estado = 1
          AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
          AND a.fecha_inicio IS NOT NULL
          AND (p_solo_pendientes = FALSE OR a.fecha_devolucion_regulador IS NULL)
          AND (p_id_cliente IS NULL OR a.id_cliente = p_id_cliente)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(a.numero_alquiler, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.nombre, ps.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.codigo, ps.codigo, ''), p_busqueda)
          )
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE (
            p_rango_dias IS NULL
            OR p_rango_dias = ''
            OR rango_antiguedad = p_rango_dias
        )
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM filtrado) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT *
                    FROM filtrado
                    ORDER BY
                        CASE WHEN dias_en_alquiler IS NULL THEN 1 ELSE 0 END,
                        dias_atraso DESC NULLS LAST,
                        dias_en_alquiler DESC NULLS LAST,
                        nombre_cliente ASC NULLS LAST,
                        numero_alquiler ASC NULLS LAST
                    LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'total_pendientes', COUNT(*) FILTER (WHERE rango_antiguedad <> 'DEVUELTO'),
                    'reciente_0_30', COUNT(*) FILTER (WHERE rango_antiguedad = 'RECIENTE_0_30'),
                    'atencion_30_90', COUNT(*) FILTER (WHERE rango_antiguedad = 'ATENCION_30_90'),
                    'seguimiento_90_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'SEGUIMIENTO_90_180'),
                    'critico_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'CRITICO_180')
                )
                FROM base
            ) AS resumen
    )
    SELECT ag.total, ag.registros, ag.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado ag;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'total_pendientes', 0,
                'reciente_0_30', 0,
                'atencion_30_90', 0,
                'seguimiento_90_180', 0,
                'critico_180', 0
            )
        )
    );
END;
$function$;

-- bal_reporte_balones_propietario
CREATE OR REPLACE FUNCTION public.bal_reporte_balones_propietario(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0, p_tipo_propietario character varying DEFAULT NULL::character varying, p_id_planta integer DEFAULT NULL::integer, p_id_cliente_propietario integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_excluir_bajas boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
    v_buscar VARCHAR;
    v_tipo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(COALESCE(p_busqueda, '')), '');
    v_tipo := NULLIF(UPPER(TRIM(COALESCE(p_tipo_propietario, ''))), '');

    WITH base AS (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.id_propietario,
            UPPER(COALESCE(prop.nombre, '')) AS nombre_propietario,
            b.id_planta,
            COALESCE(
                NULLIF(TRIM(pl.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno, pl.apellido_materno)), ''),
                pl.numero_documento
            ) AS nombre_planta,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                cp.numero_documento
            ) AS nombre_cliente_propietario,
            CASE UPPER(COALESCE(prop.nombre, ''))
                WHEN 'PLANTA' THEN COALESCE(
                    NULLIF(TRIM(pl.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno, pl.apellido_materno)), ''),
                    pl.numero_documento,
                    'Sin proveedor'
                )
                WHEN 'CLIENTE' THEN COALESCE(
                    NULLIF(TRIM(cp.razon_social), ''),
                    NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                    cp.numero_documento,
                    'Sin cliente'
                )
                WHEN 'EMPRESA' THEN 'Empresa'
                ELSE COALESCE(prop.nombre, 'Sin propietario')
            END AS nombre_titular,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.fecha_proxima_prueba_hidrostatica
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN cli_clientes pl ON pl.id = b.id_planta
        LEFT JOIN cli_clientes cp ON cp.id = b.id_cliente_propietario
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones um ON um.id = tb.id_unidad_medida
        LEFT JOIN pro_producto pg ON pg.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN gen_almacen a ON a.id = b.id_almacen
        WHERE b.estado = 1
          AND (
              p_excluir_bajas = FALSE
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_planta IS NULL OR b.id_planta = p_id_planta)
          AND (p_id_cliente_propietario IS NULL OR b.id_cliente_propietario = p_id_cliente_propietario)
          AND (
              v_tipo IS NULL
              OR UPPER(COALESCE(prop.nombre, '')) = v_tipo
          )
          AND (
              v_buscar IS NULL
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(prop.nombre, ''), v_buscar)
              OR gen_texto_coincide(cli_texto_busqueda(pl), v_buscar)
              OR gen_texto_coincide(COALESCE(pl.nombres, ''), v_buscar)
              OR gen_texto_coincide(cli_texto_busqueda(cp), v_buscar)
              OR gen_texto_coincide(COALESCE(cp.nombres, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), v_buscar)
          )
    ),
    universo AS (
        -- Conteos globales (sin filtro de tipo/titular) para las cards del resumen.
        SELECT
            b.id,
            UPPER(COALESCE(prop.nombre, '')) AS nombre_propietario,
            b.id_planta,
            COALESCE(
                NULLIF(TRIM(pl.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno, pl.apellido_materno)), ''),
                pl.numero_documento,
                'Sin proveedor'
            ) AS nombre_planta,
            b.id_cliente_propietario,
            COALESCE(
                NULLIF(TRIM(cp.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cp.nombres, cp.apellido_paterno, cp.apellido_materno)), ''),
                cp.numero_documento,
                'Sin cliente'
            ) AS nombre_cliente_propietario
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN cli_clientes pl ON pl.id = b.id_planta
        LEFT JOIN cli_clientes cp ON cp.id = b.id_cliente_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.estado = 1
          AND (
              p_excluir_bajas = FALSE
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM base) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT *
                    FROM base
                    ORDER BY
                        nombre_propietario ASC,
                        nombre_titular ASC NULLS LAST,
                        codigo_balon ASC NULLS LAST
                    LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'total', COUNT(*),
                    'empresa', COUNT(*) FILTER (WHERE nombre_propietario = 'EMPRESA'),
                    'planta', COUNT(*) FILTER (WHERE nombre_propietario = 'PLANTA'),
                    'cliente', COUNT(*) FILTER (WHERE nombre_propietario = 'CLIENTE'),
                    'otros', COUNT(*) FILTER (
                        WHERE nombre_propietario NOT IN ('EMPRESA', 'PLANTA', 'CLIENTE')
                           OR nombre_propietario = ''
                    ),
                    'por_planta', (
                        SELECT COALESCE(json_agg(row_to_json(p) ORDER BY p.cantidad DESC, p.nombre_planta), '[]'::JSON)
                        FROM (
                            SELECT
                                id_planta,
                                nombre_planta,
                                COUNT(*)::INT AS cantidad
                            FROM universo
                            WHERE nombre_propietario = 'PLANTA'
                            GROUP BY id_planta, nombre_planta
                        ) p
                    ),
                    'por_cliente', (
                        SELECT COALESCE(json_agg(row_to_json(c) ORDER BY c.cantidad DESC, c.nombre_cliente_propietario), '[]'::JSON)
                        FROM (
                            SELECT
                                id_cliente_propietario,
                                nombre_cliente_propietario,
                                COUNT(*)::INT AS cantidad
                            FROM universo
                            WHERE nombre_propietario = 'CLIENTE'
                            GROUP BY id_cliente_propietario, nombre_cliente_propietario
                        ) c
                    )
                )
                FROM universo
            ) AS resumen
    )
    SELECT a.total, a.registros, a.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado a;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'total', 0,
                'empresa', 0,
                'planta', 0,
                'cliente', 0,
                'otros', 0,
                'por_planta', '[]'::JSON,
                'por_cliente', '[]'::JSON
            )
        )
    );
END;
$function$;

-- bal_reporte_prestamos_antiguedad
CREATE OR REPLACE FUNCTION public.bal_reporte_prestamos_antiguedad(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_rango_dias character varying DEFAULT NULL::character varying, p_excluir_bajas boolean DEFAULT true, p_solo_pendientes boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH base AS (
        SELECT
            pd.id AS id_detalle,
            p.id AS id_prestamo,
            p.numero_prestamo,
            p.id_almacen,
            p.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            p.id_proveedor,
            COALESCE(
                NULLIF(TRIM(prov.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), ''),
                prov.numero_documento
            ) AS nombre_proveedor,
            pd.id_balon,
            b.codigo_balon,
            b.numero_serie,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad,
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            b.organo_inspector_no_aplica,
            b.id_planta,
            COALESCE(pl.razon_social, TRIM(CONCAT_WS(' ', pl.nombres, pl.apellido_paterno))) AS nombre_planta,
            b.fecha_proxima_prueba_hidrostatica,
            b.mes_fabricacion,
            b.anio_fabricacion,
            eb.nombre AS nombre_estado_balon,
            COALESCE(pd.fecha_prestamo, pd.fecha_entregado, p.fecha_salida) AS fecha_inicio_prestamo,
            pd.fecha_devolucion,
            pd.fecha_vencimiento,
            pd.dias_prestamo,
            CASE
                WHEN pd.fecha_devolucion IS NOT NULL THEN NULL
                ELSE (CURRENT_DATE - COALESCE(pd.fecha_prestamo, pd.fecha_entregado, p.fecha_salida))::INTEGER
            END AS dias_en_prestamo,
            CASE
                WHEN pd.fecha_devolucion IS NOT NULL THEN 'DEVUELTO'
                WHEN (CURRENT_DATE - COALESCE(pd.fecha_prestamo, pd.fecha_entregado, p.fecha_salida)) >= 180 THEN 'CRITICO_180'
                WHEN (CURRENT_DATE - COALESCE(pd.fecha_prestamo, pd.fecha_entregado, p.fecha_salida)) >= 90 THEN 'SEGUIMIENTO_90_180'
                WHEN (CURRENT_DATE - COALESCE(pd.fecha_prestamo, pd.fecha_entregado, p.fecha_salida)) >= 30 THEN 'ATENCION_30_90'
                ELSE 'RECIENTE_0_30'
            END AS rango_antiguedad
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_lista_opciones um ON tb.id_unidad_medida = um.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones oi ON b.id_organo_inspector = oi.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN cli_clientes c ON p.id_cliente = c.id
        LEFT JOIN cli_clientes prov ON p.id_proveedor = prov.id
        LEFT JOIN cli_clientes pl ON b.id_planta = pl.id
        WHERE pd.estado = 1
          AND (p_solo_pendientes = FALSE OR pd.fecha_devolucion IS NULL)
          AND (
              p_excluir_bajas = FALSE
              OR eb.nombre IS NULL
              OR eb.nombre NOT IN ('DADO_DE_BAJA', 'ROBO')
          )
          AND (p_id_cliente IS NULL OR p.id_cliente = p_id_cliente)
          AND COALESCE(pd.fecha_prestamo, pd.fecha_entregado, p.fecha_salida) IS NOT NULL
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(p.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(c), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pg.nombre, ''), p_busqueda)
          )
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE (
            p_rango_dias IS NULL
            OR p_rango_dias = ''
            OR rango_antiguedad = p_rango_dias
        )
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM filtrado) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT *
                    FROM filtrado
                    ORDER BY
                        CASE WHEN dias_en_prestamo IS NULL THEN 1 ELSE 0 END,
                        dias_en_prestamo DESC NULLS LAST,
                        nombre_cliente ASC NULLS LAST,
                        codigo_balon ASC NULLS LAST
                    LIMIT p_limite
                    OFFSET p_offset
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'total_pendientes', COUNT(*) FILTER (WHERE rango_antiguedad <> 'DEVUELTO'),
                    'reciente_0_30', COUNT(*) FILTER (WHERE rango_antiguedad = 'RECIENTE_0_30'),
                    'atencion_30_90', COUNT(*) FILTER (WHERE rango_antiguedad = 'ATENCION_30_90'),
                    'seguimiento_90_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'SEGUIMIENTO_90_180'),
                    'critico_180', COUNT(*) FILTER (WHERE rango_antiguedad = 'CRITICO_180')
                )
                FROM base
            ) AS resumen
    )
    SELECT a.total, a.registros, a.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado a;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'total_pendientes', 0,
                'reciente_0_30', 0,
                'atencion_30_90', 0,
                'seguimiento_90_180', 0,
                'critico_180', 0
            )
        )
    );
END;
$function$;

-- cli_listar_bajas_cliente
CREATE OR REPLACE FUNCTION public.cli_listar_bajas_cliente(p_solo_activos integer DEFAULT NULL::integer, p_buscar character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_cliente integer DEFAULT NULL::integer, p_id_estado_aprobacion integer DEFAULT NULL::integer, p_id_tipo_solicitud integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM cli_baja_cliente bc
    INNER JOIN cli_clientes c ON bc.id_cliente = c.id
    LEFT JOIN auth_usuarios us ON bc.id_usuario_solicita = us.id
    WHERE (p_solo_activos IS NULL OR bc.estado = p_solo_activos)
      AND (p_id_cliente IS NULL OR bc.id_cliente = p_id_cliente)
      AND (p_id_estado_aprobacion IS NULL OR bc.id_estado_aprobacion = p_id_estado_aprobacion)
      AND (p_id_tipo_solicitud IS NULL OR bc.id_tipo_solicitud = p_id_tipo_solicitud)
      AND (
          p_buscar = ''
          OR gen_texto_coincide(COALESCE(bc.motivo_detalle, ''), p_buscar)
          OR gen_texto_coincide(cli_texto_busqueda(c), p_buscar)
          OR gen_texto_coincide(
              TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)),
              p_buscar
          )
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(us.nombre, ''), p_buscar)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            bc.id,
            bc.id_tipo_solicitud,
            ts.nombre AS nombre_tipo_solicitud,
            bc.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            bc.id_motivo_baja,
            mb.nombre AS nombre_motivo_baja,
            bc.fecha_baja,
            bc.id_usuario_solicita,
            us.nombre AS nombre_usuario_solicita,
            bc.id_usuario_autoriza,
            ua.nombre AS nombre_usuario_autoriza,
            bc.fecha_autorizacion,
            bc.id_estado_aprobacion,
            ea.nombre AS nombre_estado_aprobacion,
            bc.motivo_detalle,
            bc.estado,
            bc.fecha_creacion,
            bc.fecha_modificacion,
            bc.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            bc.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM cli_baja_cliente bc
        INNER JOIN cli_clientes c ON bc.id_cliente = c.id
        LEFT JOIN gen_lista_opciones ts ON bc.id_tipo_solicitud = ts.id
        LEFT JOIN gen_lista_opciones mb ON bc.id_motivo_baja = mb.id
        LEFT JOIN gen_lista_opciones ea ON bc.id_estado_aprobacion = ea.id
        LEFT JOIN auth_usuarios us ON bc.id_usuario_solicita = us.id
        LEFT JOIN auth_usuarios ua ON bc.id_usuario_autoriza = ua.id
        LEFT JOIN auth_usuarios uc ON bc.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON bc.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR bc.estado = p_solo_activos)
          AND (p_id_cliente IS NULL OR bc.id_cliente = p_id_cliente)
          AND (p_id_estado_aprobacion IS NULL OR bc.id_estado_aprobacion = p_id_estado_aprobacion)
          AND (p_id_tipo_solicitud IS NULL OR bc.id_tipo_solicitud = p_id_tipo_solicitud)
          AND (
              p_buscar = ''
              OR gen_texto_coincide(COALESCE(bc.motivo_detalle, ''), p_buscar)
              OR gen_texto_coincide(cli_texto_busqueda(c), p_buscar)
              OR gen_texto_coincide(
                  TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)),
                  p_buscar
              )
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(us.nombre, ''), p_buscar)
          )
        -- Pendientes primero (trabajo pendiente), luego más recientes
        ORDER BY
            CASE WHEN ea.nombre = 'PENDIENTE' THEN 0 ELSE 1 END ASC,
            bc.fecha_creacion DESC,
            bc.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- cli_listar_clientes
CREATE OR REPLACE FUNCTION public.cli_listar_clientes(p_solo_activos integer DEFAULT NULL::integer, p_id_tipo_cliente integer DEFAULT NULL::integer, p_buscar character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');

    WITH filtrados AS (
        SELECT
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.id_tipo_cliente,
            tc.nombre AS nombre_tipo_cliente,
            c.id_tipo_persona,
            tp.nombre AS nombre_tipo_persona,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            c.numero_documento,
            -- Dirección principal 
            dir.id            AS id_direccion,
            dir.direccion,
            dir.referencia,
            dir.latitud,
            dir.longitud,
            dir.id_departamento,
            dep.nombre         AS nombre_departamento,
            dir.id_provincia,
            prov.nombre        AS nombre_provincia,
            dir.id_distrito,
            dist.nombre        AS nombre_distrito,
            dir.id_pais,
            pa.nombre          AS nombre_pais,
            c.telefono,
            c.email,
            c.es_agente_percepcion,
            c.es_buen_contribuyente,
            c.es_agente_retenedor,
            c.afecto_rus,
            c.situacion_sunat,
            c.estado_contribuyente_sunat,
            c.observacion,
            c.estado,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            c.fecha_creacion,
            c.fecha_modificacion,
            -- Datos de baja (si tiene solicitud pendiente/activa)
            bc.id AS id_baja_pendiente,
            ea.nombre AS estado_baja_aprobacion,
            bc.motivo_detalle AS motivo_baja_detalle,
            mb.nombre AS motivo_baja_opciones
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_cliente = tc.id
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        LEFT JOIN gen_lista_opciones td ON c.id_tipo_documento = td.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id

        -- FIX: se reemplaza el LEFT JOIN directo por LATERAL + LIMIT 1
        -- para evitar duplicar la fila del cliente cuando existe más
        -- de un registro de baja con estado = 1 para el mismo cliente.
        LEFT JOIN LATERAL (
            SELECT b.*
            FROM cli_baja_cliente b
            WHERE b.id_cliente = c.id
              AND b.estado = 1
            ORDER BY b.id DESC
            LIMIT 1
        ) bc ON TRUE
        LEFT JOIN gen_lista_opciones ea ON bc.id_estado_aprobacion = ea.id
                                       AND ea.nombre = 'PENDIENTE'
        LEFT JOIN gen_lista_opciones mb ON bc.id_motivo_baja = mb.id

        LEFT JOIN LATERAL (
            SELECT cd.*
            FROM cli_direcciones cd
            WHERE cd.id_cliente = c.id
              AND cd.es_principal = TRUE
              AND cd.estado = 1
            ORDER BY cd.id DESC
            LIMIT 1
        ) dir ON TRUE

        LEFT JOIN gen_departamento dep  ON dir.id_departamento = dep.id
        LEFT JOIN gen_provincia    prov ON dir.id_provincia    = prov.id
        LEFT JOIN gen_distrito     dist ON dir.id_distrito     = dist.id
        LEFT JOIN gen_pais         pa   ON dir.id_pais          = pa.id

        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_cliente IS NULL OR c.id_tipo_cliente = p_id_tipo_cliente)
          AND (
                v_buscar IS NULL
                OR gen_texto_coincide(cli_texto_busqueda(c), v_buscar)
                OR gen_texto_coincide(c.nombres, v_buscar)
                OR gen_texto_coincide(c.apellido_paterno, v_buscar)
                OR gen_texto_coincide(c.apellido_materno, v_buscar)
                OR gen_texto_coincide(c.numero_documento, v_buscar)
                OR gen_texto_coincide(c.codigo_interno, v_buscar)
                OR gen_texto_coincide(dir.direccion, v_buscar)
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY fecha_creacion DESC NULLS LAST, id DESC
        LIMIT p_limite
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$;

-- cli_listar_clientes_mapa
CREATE OR REPLACE FUNCTION public.cli_listar_clientes_mapa(p_solo_activos integer DEFAULT 1, p_buscar character varying DEFAULT NULL::character varying, p_filtro_balones character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 500, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_filtro    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');
    v_filtro := NULLIF(UPPER(TRIM(p_filtro_balones)), '');

    WITH balones_campo AS (
        SELECT
            x.id_cliente,
            x.id_balon,
            x.codigo_balon,
            x.numero_serie,
            x.nombre_estado_balon,
            x.nombre_tipo_balon,
            x.tipo_relacion,
            x.fecha_inicio,
            x.fecha_limite,
            x.dias_en_cliente,
            x.vencido,
            x.alerta_antiguedad
        FROM (
            SELECT
                COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) AS id_cliente,
                b.id AS id_balon,
                b.codigo_balon,
                b.numero_serie,
                eb.nombre AS nombre_estado_balon,
                tb.nombre AS nombre_tipo_balon,
                CASE eb.nombre
                    WHEN 'PRESTADO_CLIENTE' THEN 'PRESTAMO'
                    WHEN 'POR_RECOGER' THEN 'PRESTAMO'
                    WHEN 'ALQUILADO' THEN 'ALQUILER'
                    WHEN 'EN_PODER_CLIENTE' THEN 'PROPIO'
                    ELSE eb.nombre
                END AS tipo_relacion,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER')
                        THEN COALESCE(prest.fecha_inicio, b.fecha_modificacion::date)
                    WHEN eb.nombre = 'ALQUILADO'
                        THEN COALESCE(NULL::date, b.fecha_modificacion::date)
                    ELSE NULL
                END AS fecha_inicio,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_limite
                    WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                    ELSE NULL
                END AS fecha_limite,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER', 'ALQUILADO')
                         AND COALESCE(
                             CASE
                                 WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                 WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                             END,
                             b.fecha_modificacion::date
                         ) IS NOT NULL
                    THEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    )::INTEGER
                    ELSE NULL
                END AS dias_en_cliente,
                CASE
                    WHEN eb.nombre = 'ALQUILADO'
                         AND NULL::date IS NOT NULL
                         AND CURRENT_DATE > NULL::date
                    THEN TRUE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER')
                         AND prest.fecha_limite IS NOT NULL
                         AND CURRENT_DATE > prest.fecha_limite
                    THEN TRUE
                    ELSE FALSE
                END AS vencido,
                CASE
                    WHEN eb.nombre NOT IN ('PRESTADO_CLIENTE', 'POR_RECOGER', 'ALQUILADO') THEN NULL
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 180 THEN 'CRITICO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 90 THEN 'SEGUIMIENTO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN NULL::date
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 30 THEN 'ATENCION'
                    ELSE 'RECIENTE'
                END AS alerta_antiguedad
            FROM bal_balon b
            INNER JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
            LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
            LEFT JOIN LATERAL (
                SELECT
                    COALESCE(pd.fecha_prestamo, pd.fecha_entregado, pr.fecha_salida) AS fecha_inicio,
                    pd.fecha_vencimiento AS fecha_limite
                FROM bal_prestamo_detalle pd
                INNER JOIN bal_prestamo pr ON pr.id = pd.id_prestamo AND pr.estado = 1
                WHERE pd.id_balon = b.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pr.id_cliente = COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario)
                ORDER BY pd.id DESC
                LIMIT 1
            ) prest ON TRUE
            WHERE b.estado = 1
              -- ALQUILADO ya no existe como custodia: el cilindro nunca se alquila.
              AND eb.nombre IN (
                  'PRESTADO_CLIENTE',
                  'POR_RECOGER',
                  'EN_PODER_CLIENTE'
              )
              AND COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) IS NOT NULL
        ) x
    ),
    balones_agg AS (
        SELECT
            bc.id_cliente,
            json_agg(
                json_build_object(
                    'id_balon', bc.id_balon,
                    'codigo_balon', bc.codigo_balon,
                    'numero_serie', bc.numero_serie,
                    'nombre_estado_balon', bc.nombre_estado_balon,
                    'nombre_tipo_balon', bc.nombre_tipo_balon,
                    'tipo_relacion', bc.tipo_relacion,
                    'fecha_inicio', bc.fecha_inicio,
                    'fecha_limite', bc.fecha_limite,
                    'dias_en_cliente', bc.dias_en_cliente,
                    'vencido', bc.vencido,
                    'alerta_antiguedad', bc.alerta_antiguedad
                )
                ORDER BY
                    CASE WHEN bc.vencido THEN 0 ELSE 1 END,
                    bc.dias_en_cliente DESC NULLS LAST,
                    bc.codigo_balon
            ) AS balones,
            COUNT(*)::INT AS total_balones,
            BOOL_OR(bc.tipo_relacion = 'PRESTAMO') AS tiene_prestamo,
            BOOL_OR(bc.tipo_relacion = 'ALQUILER') AS tiene_alquiler,
            BOOL_OR(bc.tipo_relacion = 'PROPIO') AS tiene_propio,
            BOOL_OR(COALESCE(bc.vencido, FALSE)) AS tiene_vencidos,
            MAX(bc.dias_en_cliente) AS max_dias_en_cliente
        FROM (
            SELECT DISTINCT ON (id_cliente, id_balon)
                id_cliente,
                id_balon,
                codigo_balon,
                numero_serie,
                nombre_estado_balon,
                nombre_tipo_balon,
                tipo_relacion,
                fecha_inicio,
                fecha_limite,
                dias_en_cliente,
                vencido,
                alerta_antiguedad
            FROM balones_campo
            ORDER BY id_cliente, id_balon, tipo_relacion
        ) bc
        GROUP BY bc.id_cliente
    ),
    filtrados AS (
        SELECT
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.numero_documento,
            tp.nombre AS nombre_tipo_persona,
            c.telefono,
            dir.direccion,
            dir.referencia,
            dir.latitud,
            dir.longitud,
            c.estado,
            COALESCE(ba.balones, '[]'::json) AS balones,
            COALESCE(ba.total_balones, 0) AS total_balones,
            COALESCE(ba.tiene_prestamo, FALSE) AS tiene_prestamo,
            COALESCE(ba.tiene_alquiler, FALSE) AS tiene_alquiler,
            COALESCE(ba.tiene_propio, FALSE) AS tiene_propio,
            COALESCE(ba.tiene_vencidos, FALSE) AS tiene_vencidos,
            ba.max_dias_en_cliente
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        -- Dirección a dibujar: la principal si tiene coordenadas; si no, la
        -- georreferenciada más reciente (ej. la marcada desde una orden de salida).
        INNER JOIN LATERAL (
            SELECT cd.*
            FROM cli_direcciones cd
            WHERE cd.id_cliente = c.id
              AND cd.estado = 1
              AND cd.latitud IS NOT NULL
              AND cd.longitud IS NOT NULL
            ORDER BY cd.es_principal DESC, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN balones_agg ba ON ba.id_cliente = c.id
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (
                v_buscar IS NULL
                OR gen_texto_coincide(cli_texto_busqueda(c), v_buscar)
                OR gen_texto_coincide(c.nombres, v_buscar)
                OR gen_texto_coincide(c.apellido_paterno, v_buscar)
                OR gen_texto_coincide(c.apellido_materno, v_buscar)
                OR gen_texto_coincide(c.numero_documento, v_buscar)
                OR gen_texto_coincide(c.codigo_interno, v_buscar)
                OR gen_texto_coincide(dir.direccion, v_buscar)
              )
          AND (
                v_filtro IS NULL
                OR (v_filtro = 'CON_BALONES' AND COALESCE(ba.total_balones, 0) > 0)
                OR (v_filtro = 'PRESTADO_CLIENTE' AND COALESCE(ba.tiene_prestamo, FALSE))
                OR (v_filtro = 'ALQUILADO' AND COALESCE(ba.tiene_alquiler, FALSE))
                OR (v_filtro = 'EN_PODER_CLIENTE' AND COALESCE(ba.tiene_propio, FALSE))
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY
            CASE WHEN tiene_vencidos THEN 0 ELSE 1 END,
            total_balones DESC,
            razon_social NULLS LAST,
            nombres NULLS LAST,
            id DESC
        LIMIT GREATEST(COALESCE(p_limite, 500), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$;

-- cli_listar_contactos
CREATE OR REPLACE FUNCTION public.cli_listar_contactos(p_solo_activos integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_buscar character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');

    WITH filtrados AS (
        SELECT 
            co.id,
            co.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            co.nombre,
            co.apellido_paterno,
            co.apellido_materno,
            co.direccion,
            co.email,
            co.telefono1,
            co.telefono2,
            co.telefono3,
            co.es_principal,
            co.estado,
            co.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            co.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            co.fecha_creacion,
            co.fecha_modificacion
        FROM cli_contacto co
        LEFT JOIN cli_clientes c ON co.id_cliente = c.id
        LEFT JOIN auth_usuarios uc ON co.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON co.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR co.estado = p_solo_activos)
          AND (p_id_cliente IS NULL OR co.id_cliente = p_id_cliente)
          AND (
                v_buscar IS NULL 
                OR gen_texto_coincide(co.nombre, v_buscar)
                OR gen_texto_coincide(co.apellido_paterno, v_buscar)
                OR gen_texto_coincide(co.apellido_materno, v_buscar)
                OR gen_texto_coincide(co.email, v_buscar)
                OR gen_texto_coincide(co.telefono1, v_buscar)
                OR gen_texto_coincide(cli_texto_busqueda(c), v_buscar)
                OR gen_texto_coincide(c.numero_documento, v_buscar)
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY es_principal DESC, nombre ASC, id DESC
        LIMIT p_limite 
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$;

-- cli_listar_direcciones
CREATE OR REPLACE FUNCTION public.cli_listar_direcciones(p_solo_activos integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_buscar character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');

    WITH filtrados AS (
        SELECT
            d.id,
            d.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            d.descripcion,
            d.direccion,
            d.id_pais,
            pa.nombre AS nombre_pais,
            d.id_departamento,
            dep.nombre AS nombre_departamento,
            d.id_provincia,
            prov.nombre AS nombre_provincia,
            d.id_distrito,
            dist.nombre AS nombre_distrito,
            d.referencia,
            d.latitud,
            d.longitud,
            d.es_principal,
            d.estado,
            d.fecha_creacion,
            d.fecha_modificacion,
            d.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            d.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM cli_direcciones d
        INNER JOIN cli_clientes c
            ON d.id_cliente = c.id
        LEFT JOIN gen_pais pa
            ON d.id_pais = pa.id
        LEFT JOIN gen_departamento dep
            ON d.id_departamento = dep.id
        LEFT JOIN gen_provincia prov
            ON d.id_provincia = prov.id
        LEFT JOIN gen_distrito dist
            ON d.id_distrito = dist.id
        LEFT JOIN auth_usuarios uc
            ON d.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um
            ON d.id_usuario_modificacion = um.id
        WHERE
            (p_solo_activos IS NULL OR d.estado = p_solo_activos)
            AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
            AND (
                v_buscar IS NULL
                OR d.direccion ILIKE '%' || v_buscar || '%'
                OR COALESCE(d.descripcion, '') ILIKE '%' || v_buscar || '%'
                OR COALESCE(d.referencia, '') ILIKE '%' || v_buscar || '%'
                OR gen_texto_coincide(cli_texto_busqueda(c), v_buscar)
                OR c.nombres ILIKE '%' || v_buscar || '%'
                OR c.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR c.apellido_materno ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
            )
    ),
    total_count AS (
        SELECT COUNT(*) AS total
        FROM filtrados
    ),
    paginados AS (
        SELECT *
        FROM filtrados
        ORDER BY es_principal DESC, id DESC
        LIMIT p_limite
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    )
    INTO v_resultado;

    RETURN v_resultado;
END;
$function$;

-- com_listar_compras
CREATE OR REPLACE FUNCTION public.com_listar_compras(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_proveedor integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_estado integer DEFAULT NULL::integer, p_id_tipo_registro integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_sin_comprobante boolean DEFAULT NULL::boolean)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM com_comprobante_compra c
    LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor
    WHERE (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
      AND (p_id_almacen IS NULL OR c.id_almacen = p_id_almacen)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_estado IS NULL OR c.estado = p_estado)
      AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
      AND (p_id_categoria_gasto IS NULL OR c.id_categoria_gasto = p_id_categoria_gasto)
      -- Una compra "sin comprobante" es la que no tiene serie o no tiene número:
      -- el ingreso quedó registrado pero el documento del proveedor nunca llegó.
      AND (
          p_sin_comprobante IS NULL
          OR (
              p_sin_comprobante = TRUE
              AND (COALESCE(TRIM(c.serie), '') = '' OR COALESCE(TRIM(c.numero), '') = '')
          )
          OR (
              p_sin_comprobante = FALSE
              AND COALESCE(TRIM(c.serie), '') <> ''
              AND COALESCE(TRIM(c.numero), '') <> ''
          )
      )
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR gen_texto_coincide(cli_texto_busqueda(pr), p_busqueda)
          OR LOWER(COALESCE(pr.nombres, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_registros
    FROM (
        SELECT
            c.id, c.serie, c.numero, c.fecha,
            c.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pr.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pr.nombres, pr.apellido_paterno, pr.apellido_materno)), ''),
                pr.numero_documento
            ) AS nombre_proveedor,
            c.id_almacen, alm.nombre AS almacen,
            c.id_tipo_registro, tr.nombre AS tipo_registro,
            c.id_categoria_gasto, cat.nombre AS categoria_gasto,
            c.sub_total, c.total_importe,
            c.estado,
            (
                COALESCE(TRIM(c.serie), '') <> '' AND COALESCE(TRIM(c.numero), '') <> ''
            ) AS tiene_comprobante,
            com_tiene_movimientos_inventario(c.id) AS tiene_movimientos_inventario,
            c.id_comprobante_referencia
        FROM com_comprobante_compra c
        LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor
        LEFT JOIN gen_almacen alm ON alm.id = c.id_almacen
        LEFT JOIN gen_lista_opciones tr ON tr.id = c.id_tipo_registro
        LEFT JOIN gen_lista_opciones cat ON cat.id = c.id_categoria_gasto
        WHERE (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
          AND (p_id_almacen IS NULL OR c.id_almacen = p_id_almacen)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_estado IS NULL OR c.estado = p_estado)
          AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
          AND (p_id_categoria_gasto IS NULL OR c.id_categoria_gasto = p_id_categoria_gasto)
      -- Una compra "sin comprobante" es la que no tiene serie o no tiene número:
      -- el ingreso quedó registrado pero el documento del proveedor nunca llegó.
      AND (
          p_sin_comprobante IS NULL
          OR (
              p_sin_comprobante = TRUE
              AND (COALESCE(TRIM(c.serie), '') = '' OR COALESCE(TRIM(c.numero), '') = '')
          )
          OR (
              p_sin_comprobante = FALSE
              AND COALESCE(TRIM(c.serie), '') <> ''
              AND COALESCE(TRIM(c.numero), '') <> ''
          )
      )
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR gen_texto_coincide(cli_texto_busqueda(pr), p_busqueda)
              OR LOWER(COALESCE(pr.nombres, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- doc_listar_salidas
CREATE OR REPLACE FUNCTION public.doc_listar_salidas(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_orden integer DEFAULT NULL::integer, p_id_estado_ciclo integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_emitido_sunat boolean DEFAULT NULL::boolean, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_codigo_tipo_orden character varying DEFAULT NULL::character varying, p_sin_actividad_vigente boolean DEFAULT NULL::boolean, p_id_proveedor integer DEFAULT NULL::integer, p_codigo_estado_ciclo character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
    v_estados_ciclo TEXT[];
BEGIN
    SET TIME ZONE 'America/Lima';

    -- 'GENERADA,EMITIDA_SUNAT' -> {GENERADA,EMITIDA_SUNAT}; vacío = sin filtro.
    IF NULLIF(TRIM(COALESCE(p_codigo_estado_ciclo, '')), '') IS NOT NULL THEN
        SELECT array_agg(UPPER(TRIM(x))) FILTER (WHERE TRIM(x) <> '')
        INTO v_estados_ciclo
        FROM unnest(string_to_array(p_codigo_estado_ciclo, ',')) AS x;
    END IF;

    SELECT COUNT(*),
           json_build_object(
               'total', COUNT(*),
               'borrador', COUNT(*) FILTER (WHERE ec.nombre = 'BORRADOR'),
               'generada', COUNT(*) FILTER (WHERE ec.nombre = 'GENERADA'),
               'emitida_sunat', COUNT(*) FILTER (WHERE ec.nombre = 'EMITIDA_SUNAT'),
               'anulada', COUNT(*) FILTER (WHERE ec.nombre = 'ANULADA')
           )
    INTO v_total, v_resumen
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
    WHERE d.estado = 1
      AND (p_id_tipo_orden IS NULL OR d.id_tipo_orden = p_id_tipo_orden)
      AND (COALESCE(p_codigo_tipo_orden,'') = '' OR tor.nombre = UPPER(TRIM(p_codigo_tipo_orden)))
      AND (p_id_estado_ciclo IS NULL OR d.id_estado_ciclo = p_id_estado_ciclo)
      AND (p_id_sucursal IS NULL OR d.id_sucursal = p_id_sucursal)
      AND (p_id_almacen IS NULL OR d.id_almacen = p_id_almacen)
      AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
      AND (p_id_proveedor IS NULL OR d.id_proveedor = p_id_proveedor)
      AND (v_estados_ciclo IS NULL OR ec.nombre = ANY (v_estados_ciclo))
      AND (p_emitido_sunat IS NULL OR d.emitido_sunat = p_emitido_sunat)
      AND (p_fecha_desde IS NULL OR d.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR d.fecha <= p_fecha_hasta)
      AND (
          p_sin_actividad_vigente IS NOT TRUE
          OR (
              ec.nombre NOT IN ('BORRADOR', 'ANULADA')
              AND NOT EXISTS (
                  SELECT 1
                  FROM age_actividad a
                  LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                  WHERE a.id_doc_salida = d.id
                    AND a.estado = 1
                    AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
              )
          )
      )
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(d.numero, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(d.serie, '') || '-' || COALESCE(d.numero_sunat, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(cli), p_busqueda)
          OR gen_texto_coincide(COALESCE(d.observaciones, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            d.id, d.numero,
            d.id_tipo_orden, tor.nombre AS nombre_tipo_orden,
            d.id_estado_ciclo, ec.nombre AS nombre_estado_ciclo,
            d.emitido_sunat,
            d.serie, d.numero_sunat,
            d.id_estado_sunat, es.nombre AS nombre_estado_sunat,
            -- El menú de la fila decide con esto si ofrece «Consultar estado SUNAT»
            -- o «Emitir» (mismo criterio que el detalle, doc_obtener_salida).
            d.ticket_sunat,
            (SELECT i.estado FROM doc_gre_intento i WHERE i.id_doc_salida = d.id ORDER BY i.id DESC LIMIT 1) AS gre_estado_envio,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.fecha, d.fecha_traslado, d.fecha_llegada_almacen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
            d.id_almacen_destino, almdest.nombre AS nombre_almacen_destino,
            d.id_almacen_retorno, almret.nombre AS nombre_almacen_retorno,
            -- Retorno físico: los envases de la orden tienen su entrada
            -- vigente. La fecha de llegada sola no mueve inventario.
            EXISTS (
                SELECT 1
                FROM inv_movimiento m
                JOIN doc_salida_detalle ddr ON ddr.id = m.id_documento_detalle
                JOIN gen_lista_opciones tmv ON tmv.id = m.id_tipo_movimiento
                JOIN gen_lista ltmv ON ltmv.id = tmv.id_lista
                WHERE m.estado = 1
                  AND m.naturaleza = 'BALON'
                  AND ltmv.nombre = 'TipoMovInvUnificado'
                  AND tmv.nombre = 'ENTRADA_PLANTA_EXTERNA'
                  AND ddr.id_doc_salida = d.id
                  AND ddr.id_balon IS NOT NULL
                  AND m.id_balon = ddr.id_balon
            ) AS retorno_fisico,
            d.id_cliente,
            COALESCE(NULLIF(TRIM(cli.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), '')) AS nombre_cliente,
            d.id_proveedor,
            COALESCE(NULLIF(TRIM(prov.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), '')) AS nombre_proveedor,
            d.id_comprobante_compra,
            d.lote, d.observaciones,
            (d.id_venta IS NOT NULL) AS detalle_desde_venta,
            CASE
                WHEN d.id_venta IS NOT NULL THEN (
                    SELECT COUNT(*) FROM ven_comprobante_detalle vd
                    WHERE vd.id_comprobante = d.id_venta AND (vd.estado = 1 OR vc.estado = 0)
                )
                ELSE (
                    SELECT COUNT(*) FROM doc_salida_detalle dd
                    WHERE dd.id_doc_salida = d.id AND dd.estado = 1
                )
            END AS total_items,
            -- Solo líneas propias: en órdenes desde venta el detalle vive en la venta.
            (
                SELECT COUNT(*) FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = d.id AND dd.estado = 1 AND dd.id_balon IS NOT NULL
            ) AS total_cilindros,
            (
                SELECT COUNT(*) FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = d.id AND dd.estado = 1 AND dd.id_balon IS NULL
            ) AS total_productos,
            d.fecha_creacion
        FROM doc_salida d
        JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
        JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = d.id_estado_sunat
        LEFT JOIN ven_comprobante vc ON vc.id = d.id_venta
        LEFT JOIN gen_sucursal suc ON suc.id = d.id_sucursal
        LEFT JOIN gen_almacen alm ON alm.id = d.id_almacen
        LEFT JOIN gen_almacen almdest ON almdest.id = d.id_almacen_destino
        LEFT JOIN gen_almacen almret ON almret.id = d.id_almacen_retorno
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        WHERE d.estado = 1
          AND (p_id_tipo_orden IS NULL OR d.id_tipo_orden = p_id_tipo_orden)
          AND (COALESCE(p_codigo_tipo_orden,'') = '' OR tor.nombre = UPPER(TRIM(p_codigo_tipo_orden)))
          AND (p_id_estado_ciclo IS NULL OR d.id_estado_ciclo = p_id_estado_ciclo)
          AND (p_id_sucursal IS NULL OR d.id_sucursal = p_id_sucursal)
          AND (p_id_almacen IS NULL OR d.id_almacen = p_id_almacen)
          AND (p_id_cliente IS NULL OR d.id_cliente = p_id_cliente)
          AND (p_id_proveedor IS NULL OR d.id_proveedor = p_id_proveedor)
          AND (v_estados_ciclo IS NULL OR ec.nombre = ANY (v_estados_ciclo))
          AND (p_emitido_sunat IS NULL OR d.emitido_sunat = p_emitido_sunat)
          AND (p_fecha_desde IS NULL OR d.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR d.fecha <= p_fecha_hasta)
          AND (
              p_sin_actividad_vigente IS NOT TRUE
              OR (
                  ec.nombre NOT IN ('BORRADOR', 'ANULADA')
                  AND NOT EXISTS (
                      SELECT 1
                      FROM age_actividad a
                      LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
                      WHERE a.id_doc_salida = d.id
                        AND a.estado = 1
                        AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
                  )
              )
          )
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(d.numero, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(d.serie, '') || '-' || COALESCE(d.numero_sunat, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(cli), p_busqueda)
              OR gen_texto_coincide(COALESCE(d.observaciones, ''), p_busqueda)
          )
        ORDER BY d.fecha DESC, d.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total, 'resumen', v_resumen);
END;
$function$;

-- fin_listar_cuentas
CREATE OR REPLACE FUNCTION public.fin_listar_cuentas(p_tipo character varying DEFAULT NULL::character varying, p_id_tercero integer DEFAULT NULL::integer, p_estado character varying DEFAULT NULL::character varying, p_solo_pendientes integer DEFAULT NULL::integer, p_buscar character varying DEFAULT NULL::character varying, p_id_padre integer DEFAULT NULL::integer, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_id_tipo   INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;

    WITH base AS (
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
            fc.id_comprobante_venta,
            fc.id_comprobante_compra,
            fc.id_cuenta_padre,
            fc.numero_cuota,
            fc.numero_cuotas_total,
            fc.descripcion,
            fc.id_banco,
            fc.tasa_interes,
            fc.numero_comprobante,
            COALESCE(
                NULLIF(CONCAT_WS('-', vc.serie, vc.numero), '-'),
                NULLIF(CONCAT_WS('-', cc.serie, cc.numero), '-'),
                fc.numero_comprobante
            ) AS comprobante,
            fc.fecha_emision,
            fc.fecha_vencimiento,
            fin_redondear_monto(fc.monto_pendiente) AS monto_pendiente,
            fin_redondear_monto(COALESCE(fc.monto_abonado, 0)) AS monto_abonado,
            fin_redondear_monto(COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0))) AS saldo,
            fc.observacion,
            -- Indica si es cabecera de un plan de cuotas
            (fc.numero_cuotas_total IS NOT NULL) AS es_plan
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        LEFT JOIN ven_comprobante vc ON vc.id = fc.id_comprobante_venta
        LEFT JOIN com_comprobante_compra cc ON cc.id = fc.id_comprobante_compra
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
          AND (p_id_tercero IS NULL OR fc.id_tercero = p_id_tercero)
          -- Alcance: si p_id_padre viene, listar hijas; si no, solo primer nivel
          AND (
                (p_id_padre IS NULL AND fc.id_cuenta_padre IS NULL)
             OR (p_id_padre IS NOT NULL AND fc.id_cuenta_padre = p_id_padre)
          )
    ),
    calculado AS (
        SELECT b.*,
            fin_estado_cuenta_calculado(b.saldo, b.monto_abonado, b.fecha_vencimiento) AS estado_calculado,
            CASE
                WHEN b.saldo > 0
                     AND b.fecha_vencimiento IS NOT NULL
                     AND b.fecha_vencimiento < CURRENT_DATE
                    THEN (CURRENT_DATE - b.fecha_vencimiento)
                ELSE 0
            END AS dias_vencido
        FROM base b
    ),
    filtrados AS (
        SELECT * FROM calculado c
        WHERE (p_estado IS NULL OR c.estado_calculado = UPPER(p_estado))
          AND (p_solo_pendientes IS NULL OR p_solo_pendientes <> 1 OR c.saldo > 0)
          AND (
                v_buscar IS NULL
                OR gen_texto_coincide(c.tercero, v_buscar)
                OR c.documento_tercero ILIKE '%' || v_buscar || '%'
                OR c.comprobante ILIKE '%' || v_buscar || '%'
                OR c.descripcion ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY
            COALESCE(numero_cuota, 0),
            (fecha_vencimiento IS NULL),
            fecha_vencimiento ASC,
            id DESC
        LIMIT p_limite
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$;

-- fin_listar_garantias
CREATE OR REPLACE FUNCTION public.fin_listar_garantias(p_buscar character varying DEFAULT NULL::character varying, p_id_cliente integer DEFAULT NULL::integer, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date, p_estado character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_id_estado_filtro INT;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_buscar := NULLIF(TRIM(p_buscar), '');

    IF p_estado IS NOT NULL AND UPPER(p_estado) IN ('ACTIVA', 'DEVUELTA') THEN
        SELECT glo.id INTO v_id_estado_filtro
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'EstadoGarantia' AND glo.nombre = UPPER(p_estado)
        LIMIT 1;
    END IF;

    WITH base AS (
        SELECT
            g.id, g.fecha,
            g.id_cliente,
            COALESCE(NULLIF(TRIM(c.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                     'Cliente #' || g.id_cliente) AS cliente,
            c.numero_documento AS documento_cliente,
            g.id_medio_pago, mp.nombre AS medio_pago,
            g.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            g.importe, g.observacion,
            g.fecha_reembolso,
            g.id_medio_reembolso, mr.nombre AS medio_reembolso,
            g.id_cuenta_bancaria_reembolso,
            COALESCE(cbr.alias, cbr.titular, cbr.numero_cuenta) AS cuenta_bancaria_reembolso,
            g.observacion_reembolso,
            g.id_estado, est.nombre AS estado_texto,
            g.fecha_creacion
        FROM fin_garantia g
        JOIN cli_clientes c ON c.id = g.id_cliente
        LEFT JOIN gen_lista_opciones mp  ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones mr  ON mr.id = g.id_medio_reembolso
        LEFT JOIN gen_lista_opciones est ON est.id = g.id_estado
        LEFT JOIN gen_cuenta_bancaria cb  ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN gen_cuenta_bancaria cbr ON cbr.id = g.id_cuenta_bancaria_reembolso
        WHERE g.estado = 1
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (p_desde IS NULL OR g.fecha >= p_desde)
          AND (p_hasta IS NULL OR g.fecha <= p_hasta)
          AND (v_id_estado_filtro IS NULL OR g.id_estado = v_id_estado_filtro)
          AND (
                v_buscar IS NULL
                OR gen_texto_coincide(cli_texto_busqueda(c), v_buscar)
                OR c.nombres ILIKE '%' || v_buscar || '%'
                OR c.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR c.apellido_materno ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
                OR g.observacion ILIKE '%' || v_buscar || '%'
                OR g.observacion_reembolso ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (SELECT COUNT(*) AS total FROM base),
    paginados AS (
        SELECT * FROM base
        ORDER BY fecha DESC, id DESC
        LIMIT p_limite OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$;

-- fin_saldos_por_tercero
CREATE OR REPLACE FUNCTION public.fin_saldos_por_tercero(p_tipo character varying DEFAULT 'COBRAR'::character varying, p_fecha_corte date DEFAULT CURRENT_DATE, p_buscar character varying DEFAULT NULL::character varying, p_solo_pendientes integer DEFAULT 1, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo   INT;
    v_buscar    VARCHAR;
    v_corte     DATE;
    v_registros JSON;
    v_total     BIGINT;
    v_resumen   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(COALESCE(p_buscar, '')), '');
    v_corte  := COALESCE(p_fecha_corte, CURRENT_DATE);

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;

    WITH cuentas AS (
        SELECT
            fc.id,
            fc.id_tercero,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                fc.tercero_nombre,
                'Tercero #' || fc.id
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            COALESCE(fc.id_tercero::text, LOWER(TRIM(COALESCE(fc.tercero_nombre, '')))) AS tercero_key,
            fc.monto_pendiente::NUMERIC AS debe,
            COALESCE((
                SELECT SUM(p.monto)
                FROM fin_pago p
                WHERE p.id_cuenta = fc.id
                  AND p.estado = 1
                  AND p.fecha_pago <= v_corte
            ), 0)::NUMERIC AS abonado
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
          AND fc.numero_cuotas_total IS NULL
          AND (fc.fecha_emision IS NULL OR fc.fecha_emision <= v_corte)
          AND (
              v_buscar IS NULL
              OR gen_texto_coincide(cli_texto_busqueda(ter), v_buscar)
              OR gen_texto_coincide(COALESCE(ter.nombres, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(fc.tercero_nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(ter.numero_documento, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(fc.numero_comprobante, ''), v_buscar)
          )
    ),
    por_cuenta AS (
        SELECT
            *,
            GREATEST(debe - abonado, 0)::NUMERIC AS saldo
        FROM cuentas
    ),
    agrupado AS (
        SELECT
            MAX(id_tercero) AS id_tercero,
            MAX(tercero) AS tercero,
            MAX(documento_tercero) AS documento_tercero,
            tercero_key,
            COUNT(*)::INT AS cantidad_cuentas,
            SUM(debe)::NUMERIC AS debe,
            SUM(abonado)::NUMERIC AS abonado,
            SUM(saldo)::NUMERIC AS saldo
        FROM por_cuenta
        GROUP BY tercero_key
    ),
    filtrado AS (
        SELECT *
        FROM agrupado
        WHERE COALESCE(p_solo_pendientes, 1) = 0
           OR saldo > 0
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM filtrado) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT
                        id_tercero,
                        tercero,
                        documento_tercero,
                        cantidad_cuentas,
                        debe,
                        abonado,
                        saldo
                    FROM filtrado
                    ORDER BY saldo DESC, tercero ASC
                    LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'fechaCorte', v_corte,
                    'totalDebe', COALESCE(SUM(debe), 0),
                    'totalAbonado', COALESCE(SUM(abonado), 0),
                    'totalSaldo', COALESCE(SUM(saldo), 0),
                    'cantidadTerceros', COUNT(*)
                )
                FROM filtrado
            ) AS resumen
    )
    SELECT a.total, a.registros, a.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado a;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'fechaCorte', v_corte,
                'totalDebe', 0,
                'totalAbonado', 0,
                'totalSaldo', 0,
                'cantidadTerceros', 0
            )
        )
    );
END;
$function$;

-- pro_listar_catalogo_precios
CREATE OR REPLACE FUNCTION public.pro_listar_catalogo_precios(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_catalogo integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_id_proveedor integer DEFAULT NULL::integer, p_periodo character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM pro_catalogo_precio cp
    LEFT JOIN gen_lista_opciones tc ON cp.id_tipo_catalogo = tc.id
    LEFT JOIN pro_producto p ON cp.id_producto = p.id
    LEFT JOIN cli_clientes prov ON cp.id_proveedor = prov.id
    WHERE cp.estado = 1
      AND (p_id_tipo_catalogo IS NULL OR cp.id_tipo_catalogo = p_id_tipo_catalogo)
      AND (p_id_producto IS NULL OR cp.id_producto = p_id_producto)
      AND (p_id_proveedor IS NULL OR cp.id_proveedor = p_id_proveedor)
      AND (p_periodo IS NULL OR cp.periodo = p_periodo)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(cp.nombre_item, p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.periodo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.clasificacion, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.modelo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(prov), p_busqueda)
          OR gen_texto_coincide(COALESCE(tc.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cp.id,
            cp.id_tipo_catalogo,
            tc.nombre AS nombre_tipo_catalogo,
            cp.periodo,
            cp.nombre_item,
            cp.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            cp.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            cp.id_proveedor,
            COALESCE(prov.razon_social, prov.nombres) AS nombre_proveedor,
            cp.clasificacion,
            cp.modelo,
            cp.capacidad,
            cp.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            cp.descripcion_presentacion,
            cp.costo_producto,
            cp.costo_flete,
            cp.porcentaje_margen,
            cp.precio_final,
            cp.precio_garantia,
            cp.estado,
            cp.fecha_creacion,
            cp.fecha_modificacion,
            cp.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cp.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM pro_catalogo_precio cp
        LEFT JOIN gen_lista_opciones tc ON cp.id_tipo_catalogo = tc.id
        LEFT JOIN pro_producto p ON cp.id_producto = p.id
        LEFT JOIN bal_tipo_balon tb ON cp.id_tipo_balon = tb.id
        LEFT JOIN cli_clientes prov ON cp.id_proveedor = prov.id
        LEFT JOIN gen_lista_opciones um ON cp.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON cp.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON cp.id_usuario_modificacion = um2.id
        WHERE cp.estado = 1
          AND (p_id_tipo_catalogo IS NULL OR cp.id_tipo_catalogo = p_id_tipo_catalogo)
          AND (p_id_producto IS NULL OR cp.id_producto = p_id_producto)
          AND (p_id_proveedor IS NULL OR cp.id_proveedor = p_id_proveedor)
          AND (p_periodo IS NULL OR cp.periodo = p_periodo)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(cp.nombre_item, p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.periodo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.clasificacion, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.modelo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(prov), p_busqueda)
              OR gen_texto_coincide(COALESCE(tc.nombre, ''), p_busqueda)
          )
        ORDER BY cp.periodo DESC NULLS LAST, cp.nombre_item ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- ven_listar_comprobantes
CREATE OR REPLACE FUNCTION public.ven_listar_comprobantes(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_comprobante integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_id_estado_sunat integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_serie character varying DEFAULT NULL::character varying, p_solo_activos integer DEFAULT 1)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_busqueda TEXT;
    v_busqueda_norm TEXT;
    v_busqueda_sin_guion TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_busqueda := TRIM(COALESCE(p_busqueda, ''));
    v_busqueda_norm := LOWER(REPLACE(REPLACE(v_busqueda, ' ', ''), '/', '-'));
    v_busqueda_sin_guion := REPLACE(v_busqueda_norm, '-', '');

    SELECT COUNT(*) INTO v_total
    FROM ven_comprobante c
    LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
    LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
    WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
      AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
      AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
      AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
      AND (
          v_busqueda = ''
          OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
          OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR gen_texto_coincide(cli_texto_busqueda(cl), v_busqueda)
          OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
          OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.fecha,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            cd.id AS id_comprobante_destino,
            cd.serie AS serie_comprobante_destino,
            cd.numero AS numero_comprobante_destino,
            tc_destino.descripcion AS codigo_tipo_comprobante_destino,
            tc_destino.nombre AS nombre_tipo_comprobante_destino,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.total_importe,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            (act.id IS NOT NULL) AS tiene_actividad,
            docsal.id AS id_doc_salida,
            docsal.numero AS numero_doc_salida,
            c.estado,
            c.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_comprobante_detalle d
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS total_detalles
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN LATERAL (
            SELECT d.id, d.serie, d.numero, d.id_tipo_comprobante
            FROM ven_comprobante d
            WHERE d.id_comprobante_origen = c.id AND d.estado = 1
            ORDER BY d.id DESC
            LIMIT 1
        ) cd ON TRUE
        LEFT JOIN gen_lista_opciones tc_destino ON cd.id_tipo_comprobante = tc_destino.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            -- El reparto se programa desde la orden de salida, que es lo que
            -- realmente sale a la calle, asi que cuelga de doc_salida y no del
            -- comprobante. La venta lo sigue mostrando alcanzandolo por JOIN a
            -- traves de su orden. Se conserva la rama por id_comprobante para
            -- los repartos creados antes de ese cambio.
            WHERE (
                    a.id_comprobante = c.id
                    OR a.id_doc_salida IN (
                        SELECT ds.id
                        FROM doc_salida ds
                        WHERE ds.id_venta = c.id AND ds.estado = 1
                    )
                  )
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        LEFT JOIN LATERAL (
            SELECT d.id, d.numero
            FROM doc_salida d
            JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
            WHERE d.id_venta = c.id
              AND d.estado = 1
              AND ec.nombre <> 'ANULADA'
            ORDER BY d.id DESC
            LIMIT 1
        ) docsal ON TRUE
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
          AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
          AND (
              v_busqueda = ''
              OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
              OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR gen_texto_coincide(cli_texto_busqueda(cl), v_busqueda)
              OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
              OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
COMMIT;
