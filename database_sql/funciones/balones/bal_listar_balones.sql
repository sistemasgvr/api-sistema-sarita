DROP FUNCTION IF EXISTS bal_listar_balones(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN);
DROP FUNCTION IF EXISTS bal_listar_balones(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN, VARCHAR);
DROP FUNCTION IF EXISTS bal_listar_balones(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN, VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS bal_listar_balones(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN, VARCHAR, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS bal_listar_balones(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN, VARCHAR, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS bal_listar_balones(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN, INTEGER, INTEGER, BOOLEAN, VARCHAR, INTEGER, INTEGER, INTEGER, BOOLEAN);

CREATE OR REPLACE FUNCTION bal_listar_balones(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_tipo_balon INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_estado_balon INTEGER DEFAULT NULL,
    p_id_cliente_ubicacion INTEGER DEFAULT NULL,
    p_id_marca_cilindro INTEGER DEFAULT NULL,
    p_ph_vencida BOOLEAN DEFAULT NULL,
    p_ph_por_vencer_dias INTEGER DEFAULT NULL,
    p_id_cliente_relacionado INTEGER DEFAULT NULL,
    p_solo_bajas BOOLEAN DEFAULT NULL,
    p_familia_gas VARCHAR DEFAULT NULL,
    p_id_propietario INTEGER DEFAULT NULL,
    p_id_estado_contenido INTEGER DEFAULT NULL,
    p_id_producto_gas INTEGER DEFAULT NULL,
    p_solo_llenos_fuera BOOLEAN DEFAULT NULL
)
RETURNS JSON
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
            'en_almacen', COUNT(*) FILTER (WHERE eb.nombre = 'EN_ALMACEN'),
            -- Llenos/vacíos solo del stock en almacén (en cliente el contenido es incierto).
            'llenos', COUNT(*) FILTER (WHERE eb.nombre = 'EN_ALMACEN' AND ec.nombre = 'LLENO'),
            'vacios', COUNT(*) FILTER (WHERE eb.nombre = 'EN_ALMACEN' AND ec.nombre = 'VACIO')
        )
    INTO v_total, v_resumen
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    LEFT JOIN gen_lista_opciones ec ON b.id_estado_contenido = ec.id
    LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
    LEFT JOIN cli_clientes cu ON b.id_cliente_ubicacion = cu.id
    LEFT JOIN cli_clientes cp ON b.id_cliente_propietario = cp.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_estado_contenido IS NULL OR b.id_estado_contenido = p_id_estado_contenido)
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
              COALESCE(ec.nombre, '') = 'LLENO'
              AND COALESCE(eb.nombre, '') IS DISTINCT FROM 'EN_ALMACEN'
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
          OR gen_texto_coincide(COALESCE(cu.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cu.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cu.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(cp.razon_social, ''), p_busqueda)
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
            um.nombre AS nombre_unidad_medida,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_estado_contenido,
            ec.nombre AS nombre_estado_contenido,
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
            b.capacidad_restante,
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
                OR EXISTS (SELECT 1 FROM bal_movimiento m WHERE m.id_balon = b.id AND m.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_movimiento_recarga mr WHERE mr.id_balon = b.id AND mr.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_prestamo_detalle pd WHERE pd.id_balon = b.id AND pd.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_alquiler_detalle ad WHERE ad.id_balon = b.id AND ad.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_mantenimiento mt WHERE mt.id_balon = b.id AND mt.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_balon_ph_historial ph WHERE ph.id_balon = b.id AND ph.estado = 1)
                OR EXISTS (SELECT 1 FROM bal_balon_estado_historial eh WHERE eh.id_balon = b.id AND eh.estado = 1)
                OR EXISTS (SELECT 1 FROM ven_comprobante_detalle vd WHERE vd.id_balon = b.id AND vd.estado = 1)
                OR EXISTS (SELECT 1 FROM gre_guia_remision_detalle gd WHERE gd.id_balon = b.id AND gd.estado = 1)
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
        LEFT JOIN gen_lista_opciones ec ON b.id_estado_contenido = ec.id
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
          AND (p_id_estado_contenido IS NULL OR b.id_estado_contenido = p_id_estado_contenido)
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
                  COALESCE(ec.nombre, '') = 'LLENO'
                  AND COALESCE(eb.nombre, '') IS DISTINCT FROM 'EN_ALMACEN'
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
              OR gen_texto_coincide(COALESCE(cu.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.numero_documento, ''), p_busqueda)
          )
        ORDER BY b.codigo_balon ASC
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
