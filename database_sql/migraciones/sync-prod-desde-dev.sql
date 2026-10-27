-- Lleva a PROD lo elegido de DEV: tablas solo de DEV, funciones con origen dev y datos asociados.
-- Respaldar la base de PROD antes de aplicarlo.
-- No ejecutar sin revisión: generado por database_sql/scripts/generar-sync.js.
-- Funciones pendientes no incluidas (ven_actualizar_comprobante, ven_obtener_siguiente_numero): ver database_sql/.cache/reporte-funciones.md
BEGIN;

CREATE TABLE IF NOT EXISTS public.fin_caja_sesion_evento (
  id integer NOT NULL,
  id_sesion integer NOT NULL,
  tipo character varying(20) NOT NULL,
  monto numeric(12, 2),
  diferencia numeric(12, 2),
  observacion character varying(500),
  id_usuario integer,
  fecha_hora timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT fin_caja_sesion_evento_tipo_check CHECK (
    (
      (tipo)::text = ANY (
        (
          ARRAY[
            'ABRIR'::character varying,
            'CERRAR'::character varying,
            'REABRIR'::character varying
          ]
        )::TEXT[]
      )
    )
  )
);

CREATE SEQUENCE IF NOT EXISTS public.fin_caja_sesion_evento_id_seq AS integer START
WITH
  1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;

ALTER SEQUENCE public.fin_caja_sesion_evento_id_seq OWNED BY public.fin_caja_sesion_evento.id;

ALTER TABLE ONLY public.fin_caja_sesion_evento
ALTER COLUMN id
SET DEFAULT nextval('public.fin_caja_sesion_evento_id_seq'::regclass);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.fin_caja_sesion_evento'::regclass AND conname = 'fin_caja_sesion_evento_pkey') THEN
    ALTER TABLE ONLY public.fin_caja_sesion_evento
    ADD CONSTRAINT fin_caja_sesion_evento_pkey PRIMARY KEY (id);
  END IF;
END
$sync$;

CREATE INDEX IF NOT EXISTS idx_fin_caja_sesion_evento_sesion_fecha ON public.fin_caja_sesion_evento USING btree (id_sesion, fecha_hora);

DO $sync$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.fin_caja_sesion_evento'::regclass AND conname = 'fin_caja_sesion_evento_id_sesion_fkey') THEN
    ALTER TABLE ONLY public.fin_caja_sesion_evento
    ADD CONSTRAINT fin_caja_sesion_evento_id_sesion_fkey FOREIGN KEY (id_sesion) REFERENCES public.fin_caja_sesion (id);
  END IF;
END
$sync$;

DROP FUNCTION IF EXISTS public.bal_listar_balones (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_tipo_balon integer,
  p_id_almacen integer,
  p_id_estado_balon integer,
  p_id_cliente_ubicacion integer,
  p_id_marca_cilindro integer,
  p_ph_vencida boolean,
  p_ph_por_vencer_dias integer
);

CREATE OR REPLACE FUNCTION public.bal_listar_balones (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_tipo_balon integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_estado_balon integer DEFAULT NULL::integer,
  p_id_cliente_ubicacion integer DEFAULT NULL::integer,
  p_id_marca_cilindro integer DEFAULT NULL::integer,
  p_ph_vencida boolean DEFAULT NULL::boolean,
  p_ph_por_vencer_dias integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
      AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
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
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
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
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.anio_fabricacion,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.presion_actual,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'PENDIENTE'
            ) AS tiene_solicitud_baja_pendiente,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        WHERE b.estado = 1
          AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
          AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
          AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
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
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY b.codigo_balon ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS public.bal_listar_balones (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_tipo_balon integer,
  p_id_almacen integer,
  p_id_estado_balon integer,
  p_id_cliente_ubicacion integer,
  p_id_marca_cilindro integer,
  p_ph_vencida boolean,
  p_ph_por_vencer_dias integer,
  p_id_cliente_relacionado integer
);

CREATE OR REPLACE FUNCTION public.bal_listar_balones (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_tipo_balon integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_estado_balon integer DEFAULT NULL::integer,
  p_id_cliente_ubicacion integer DEFAULT NULL::integer,
  p_id_marca_cilindro integer DEFAULT NULL::integer,
  p_ph_vencida boolean DEFAULT NULL::boolean,
  p_ph_por_vencer_dias integer DEFAULT NULL::integer,
  p_id_cliente_relacionado integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_balon b
    LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
    LEFT JOIN gen_almacen a ON b.id_almacen = a.id
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
    WHERE b.estado = 1
      AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
      AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
      AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
      AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
      AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
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
          p_busqueda = ''
          OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
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
            b.id_propietario,
            prop.nombre AS nombre_propietario,
            b.id_cliente_propietario,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            b.id_estado_balon,
            eb.nombre AS nombre_estado_balon,
            b.id_marca_cilindro,
            mc.nombre AS nombre_marca_cilindro,
            b.anio_fabricacion,
            b.fecha_proxima_prueba_hidrostatica,
            CASE
                WHEN b.fecha_proxima_prueba_hidrostatica IS NULL THEN NULL
                WHEN b.fecha_proxima_prueba_hidrostatica < CURRENT_DATE THEN 'VENCIDA'
                WHEN b.fecha_proxima_prueba_hidrostatica <= CURRENT_DATE + INTERVAL '90 days' THEN 'POR_VENCER'
                ELSE 'VIGENTE'
            END AS estado_ph,
            b.presion_actual,
            EXISTS (
                SELECT 1
                FROM bal_baja_balon bb
                WHERE bb.id_balon = b.id
                  AND bb.estado = 1
                  AND bb.estado_aprobacion = 'PENDIENTE'
            ) AS tiene_solicitud_baja_pendiente,
            b.estado,
            b.fecha_creacion,
            b.fecha_modificacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
        LEFT JOIN gen_almacen a ON b.id_almacen = a.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones mc ON b.id_marca_cilindro = mc.id
        LEFT JOIN gen_lista_opciones prop ON b.id_propietario = prop.id
        WHERE b.estado = 1
          AND (p_id_tipo_balon IS NULL OR b.id_tipo_balon = p_id_tipo_balon)
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
          AND (p_id_estado_balon IS NULL OR b.id_estado_balon = p_id_estado_balon)
          AND (p_id_cliente_ubicacion IS NULL OR b.id_cliente_ubicacion = p_id_cliente_ubicacion)
          AND (p_id_marca_cilindro IS NULL OR b.id_marca_cilindro = p_id_marca_cilindro)
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
              p_busqueda = ''
              OR LOWER(b.codigo_balon) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.numero_serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(b.libro_cilindro, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(tb.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(a.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(mc.nombre, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY b.codigo_balon ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS public.bal_listar_balones (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_tipo_balon integer,
  p_id_almacen integer,
  p_id_estado_balon integer,
  p_id_cliente_ubicacion integer,
  p_id_marca_cilindro integer,
  p_ph_vencida boolean,
  p_ph_por_vencer_dias integer,
  p_id_cliente_relacionado integer,
  p_solo_bajas boolean,
  p_familia_gas character varying,
  p_id_propietario integer,
  p_id_producto_gas integer,
  p_solo_llenos_fuera boolean,
  p_id_planta integer,
  p_tipo_valvula character varying
);

CREATE OR REPLACE FUNCTION public.bal_listar_balones (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_tipo_balon integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_estado_balon integer DEFAULT NULL::integer,
  p_id_cliente_ubicacion integer DEFAULT NULL::integer,
  p_id_marca_cilindro integer DEFAULT NULL::integer,
  p_ph_vencida boolean DEFAULT NULL::boolean,
  p_ph_por_vencer_dias integer DEFAULT NULL::integer,
  p_id_cliente_relacionado integer DEFAULT NULL::integer,
  p_solo_bajas boolean DEFAULT NULL::boolean,
  p_familia_gas character varying DEFAULT NULL::character varying,
  p_id_propietario integer DEFAULT NULL::integer,
  p_id_producto_gas integer DEFAULT NULL::integer,
  p_solo_llenos_fuera boolean DEFAULT NULL::boolean,
  p_id_planta integer DEFAULT NULL::integer,
  p_tipo_valvula character varying DEFAULT NULL::character varying
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.bal_listar_lotes_protocolo (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_proveedor integer,
  p_id_producto_gas integer,
  p_vencidos boolean,
  p_fecha_desde date,
  p_fecha_hasta date
);

CREATE OR REPLACE FUNCTION public.bal_listar_lotes_protocolo (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_proveedor integer DEFAULT NULL::integer,
  p_id_producto_gas integer DEFAULT NULL::integer,
  p_vencidos boolean DEFAULT NULL::boolean,
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.bal_listar_movimientos_recarga (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_balon integer,
  p_id_almacen integer,
  p_fecha_desde date,
  p_fecha_hasta date
);

CREATE OR REPLACE FUNCTION public.bal_listar_movimientos_recarga (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_balon integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.bal_listar_prestamo_detalles (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_prestamo integer,
  p_id_balon integer,
  p_id_estado integer
);

CREATE OR REPLACE FUNCTION public.bal_listar_prestamo_detalles (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_prestamo integer DEFAULT NULL::integer,
  p_id_balon integer DEFAULT NULL::integer,
  p_id_estado integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.bal_reporte_alquileres_antiguedad (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_cliente integer,
  p_rango_dias character varying,
  p_solo_pendientes boolean
);

CREATE OR REPLACE FUNCTION public.bal_reporte_alquileres_antiguedad (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_id_cliente integer DEFAULT NULL::integer,
  p_rango_dias character varying DEFAULT NULL::character varying,
  p_solo_pendientes boolean DEFAULT TRUE
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.bal_reporte_balones_propietario (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_tipo_propietario character varying,
  p_id_planta integer,
  p_id_cliente_propietario integer,
  p_id_almacen integer,
  p_excluir_bajas boolean
);

CREATE OR REPLACE FUNCTION public.bal_reporte_balones_propietario (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_tipo_propietario character varying DEFAULT NULL::character varying,
  p_id_planta integer DEFAULT NULL::integer,
  p_id_cliente_propietario integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_excluir_bajas boolean DEFAULT TRUE
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.bal_reporte_prestamos_antiguedad (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_cliente integer,
  p_rango_dias character varying,
  p_excluir_bajas boolean,
  p_solo_pendientes boolean
);

CREATE OR REPLACE FUNCTION public.bal_reporte_prestamos_antiguedad (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 50,
  p_offset integer DEFAULT 0,
  p_id_cliente integer DEFAULT NULL::integer,
  p_rango_dias character varying DEFAULT NULL::character varying,
  p_excluir_bajas boolean DEFAULT TRUE,
  p_solo_pendientes boolean DEFAULT TRUE
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.cli_listar_bajas_cliente (
  p_solo_activos integer,
  p_buscar character varying,
  p_limite integer,
  p_offset integer,
  p_id_cliente integer,
  p_id_estado_aprobacion integer,
  p_id_tipo_solicitud integer
);

CREATE OR REPLACE FUNCTION public.cli_listar_bajas_cliente (
  p_solo_activos integer DEFAULT NULL::integer,
  p_buscar character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_cliente integer DEFAULT NULL::integer,
  p_id_estado_aprobacion integer DEFAULT NULL::integer,
  p_id_tipo_solicitud integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.cli_listar_contactos (
  p_solo_activos integer,
  p_id_cliente integer,
  p_buscar character varying,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.cli_listar_contactos (
  p_solo_activos integer DEFAULT NULL::integer,
  p_id_cliente integer DEFAULT NULL::integer,
  p_buscar character varying DEFAULT NULL::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.cli_listar_direcciones (
  p_solo_activos integer,
  p_id_cliente integer,
  p_buscar character varying,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.cli_listar_direcciones (
  p_solo_activos integer DEFAULT NULL::integer,
  p_id_cliente integer DEFAULT NULL::integer,
  p_buscar character varying DEFAULT NULL::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.doc_listar_salidas (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_tipo_orden integer,
  p_id_estado_ciclo integer,
  p_id_sucursal integer,
  p_id_almacen integer,
  p_id_cliente integer,
  p_emitido_sunat boolean,
  p_fecha_desde date,
  p_fecha_hasta date,
  p_codigo_tipo_orden character varying,
  p_sin_actividad_vigente boolean,
  p_id_proveedor integer,
  p_codigo_estado_ciclo character varying
);

CREATE OR REPLACE FUNCTION public.doc_listar_salidas (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_tipo_orden integer DEFAULT NULL::integer,
  p_id_estado_ciclo integer DEFAULT NULL::integer,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_id_cliente integer DEFAULT NULL::integer,
  p_emitido_sunat boolean DEFAULT NULL::boolean,
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_codigo_tipo_orden character varying DEFAULT NULL::character varying,
  p_sin_actividad_vigente boolean DEFAULT NULL::boolean,
  p_id_proveedor integer DEFAULT NULL::integer,
  p_codigo_estado_ciclo character varying DEFAULT NULL::character varying
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
    v_estados_ciclo TEXT[];
BEGIN
    SET TIME ZONE 'America/Lima';

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
            d.ticket_sunat,
            (SELECT i.estado FROM doc_gre_intento i WHERE i.id_doc_salida = d.id ORDER BY i.id DESC LIMIT 1) AS gre_estado_envio,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.fecha, d.fecha_traslado, d.fecha_llegada_almacen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
            d.id_almacen_destino, almdest.nombre AS nombre_almacen_destino,
            d.id_almacen_retorno, almret.nombre AS nombre_almacen_retorno,
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

DROP FUNCTION IF EXISTS public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado_abierta INT;
    v_existente RECORD;
    v_abierta RECORD;
    v_id INT;
    v_registro JSON;
    v_hora_txt TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_abierta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA'
    LIMIT 1;

    IF v_estado_abierta IS NULL THEN
        RETURN json_build_object('error', 'No existe estado de caja ABIERTA', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha es obligatoria', 'registro', NULL);
    END IF;

    IF COALESCE(p_monto_inicial, 0) < 0 THEN
        RETURN json_build_object('error', 'El monto inicial no puede ser negativo', 'registro', NULL);
    END IF;

    SELECT s.* INTO v_existente
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        v_hora_txt := to_char(v_existente.fecha_apertura AT TIME ZONE 'America/Lima', 'DD/MM/YYYY HH24:MI');
        RETURN json_build_object(
            'error', format(
                'Ya existe una sesión de caja para esa fecha (abierta el %s). No se puede repetir la misma fecha.',
                COALESCE(v_hora_txt, to_char(p_fecha, 'DD/MM/YYYY'))
            ),
            'registro', NULL
        );
    END IF;

    SELECT s.* INTO v_abierta
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.id_estado = v_estado_abierta
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        v_hora_txt := to_char(v_abierta.fecha_apertura AT TIME ZONE 'America/Lima', 'DD/MM/YYYY HH24:MI');
        RETURN json_build_object(
            'error', format(
                'Ya hay una caja ABIERTA del %s (apertura %s). Ciérrala antes de abrir otra.',
                to_char(v_abierta.fecha, 'DD/MM/YYYY'),
                COALESCE(v_hora_txt, '—')
            ),
            'registro', NULL
        );
    END IF;

    BEGIN
        INSERT INTO fin_caja_sesion (
            fecha, id_sucursal, id_estado, monto_inicial,
            observacion_apertura, fecha_apertura, id_usuario_apertura,
            id_usuario_creacion
        ) VALUES (
            p_fecha, p_id_sucursal, v_estado_abierta, COALESCE(p_monto_inicial, 0),
            NULLIF(TRIM(p_observacion), ''), NOW(), p_id_usuario,
            p_id_usuario
        )
        RETURNING id INTO v_id;
    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object(
                'error', 'Ya existe una sesión de caja para esa fecha / sucursal. No se puede repetir.',
                'registro', NULL
            );
    END;

    INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, observacion, id_usuario)
    VALUES (v_id, 'ABRIR', ROUND(COALESCE(p_monto_inicial, 0), 2), NULLIF(TRIM(p_observacion), ''), p_id_usuario);

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id
    ) t;

    PERFORM fin_notificar_caja_admins(v_id, 'APERTURA', p_id_usuario);

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer,
  p_observacion character varying,
  p_id_usuario integer,
  p_id_sesion integer
);

CREATE OR REPLACE FUNCTION public.fin_abrir_caja_sesion (
  p_fecha date,
  p_monto_inicial numeric,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer,
  p_id_sesion integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado_abierta INT;
    v_estado_cerrada INT;
    v_existente RECORD;
    v_abierta RECORD;
    v_id INT;
    v_registro JSON;
    v_hora_txt TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_abierta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA'
    LIMIT 1;

    SELECT lo.id INTO v_estado_cerrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'CERRADA'
    LIMIT 1;

    IF v_estado_abierta IS NULL THEN
        RETURN json_build_object('error', 'No existe estado de caja ABIERTA', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha es obligatoria', 'registro', NULL);
    END IF;

    IF COALESCE(p_monto_inicial, 0) < 0 THEN
        RETURN json_build_object('error', 'El monto inicial no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_sesion IS NOT NULL THEN
        SELECT s.* INTO v_existente
        FROM fin_caja_sesion s
        WHERE s.id = p_id_sesion
          AND s.estado = 1
        LIMIT 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'Sesión de caja no encontrada', 'registro', NULL);
        END IF;

        IF v_existente.id_estado = v_estado_abierta THEN
            v_hora_txt := to_char(
                v_existente.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'La caja del %s ya está ABIERTA (desde %s).',
                    to_char(v_existente.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        SELECT s.* INTO v_abierta
        FROM fin_caja_sesion s
        WHERE s.estado = 1
          AND s.id_estado = v_estado_abierta
          AND s.id <> v_existente.id
          AND COALESCE(s.id_sucursal, 0) = COALESCE(v_existente.id_sucursal, 0)
        LIMIT 1;

        IF FOUND THEN
            v_hora_txt := to_char(
                v_abierta.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'Ya hay otra caja ABIERTA del %s (apertura %s). Ciérrala antes de reabrir.',
                    to_char(v_abierta.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        UPDATE fin_caja_sesion
        SET id_estado = v_estado_abierta,
            fecha_apertura = NOW(),
            id_usuario_apertura = p_id_usuario,
            observacion_apertura = NULLIF(TRIM(p_observacion), ''),
            monto_inicial = ROUND(COALESCE(p_monto_inicial, 0), 2),
            fecha_cierre = NULL,
            id_usuario_cierre = NULL,
            monto_efectivo_contado = NULL,
            monto_esperado = NULL,
            diferencia = NULL,
            observacion_cierre = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_existente.id
        RETURNING id INTO v_id;

        INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, observacion, id_usuario)
        VALUES (v_id, 'REABRIR', ROUND(COALESCE(p_monto_inicial, 0), 2), NULLIF(TRIM(p_observacion), ''), p_id_usuario);

        SELECT row_to_json(t) INTO v_registro
        FROM (
            SELECT
                s.id,
                s.fecha,
                s.id_sucursal AS "idSucursal",
                suc.nombre AS "nombreSucursal",
                s.id_estado AS "idEstado",
                est.nombre AS "estadoCaja",
                s.monto_inicial AS "montoInicial",
                s.monto_efectivo_contado AS "montoEfectivoContado",
                s.monto_esperado AS "montoEsperado",
                s.diferencia,
                s.observacion_apertura AS "observacionApertura",
                s.observacion_cierre AS "observacionCierre",
                s.fecha_apertura AS "fechaApertura",
                s.fecha_cierre AS "fechaCierre",
                s.id_usuario_apertura AS "idUsuarioApertura",
                s.id_usuario_cierre AS "idUsuarioCierre"
            FROM fin_caja_sesion s
            LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
            LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
            WHERE s.id = v_id
        ) t;

        PERFORM fin_notificar_caja_admins(v_id, 'APERTURA', p_id_usuario);

        RETURN json_build_object('registro', v_registro);
    END IF;

    SELECT s.* INTO v_existente
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        IF v_existente.id_estado = v_estado_abierta THEN
            v_hora_txt := to_char(
                v_existente.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'Ya hay una caja ABIERTA del %s (apertura %s). Ciérrala antes de abrir otra.',
                    to_char(v_existente.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        RETURN json_build_object(
            'error', format(
                'La caja del %s ya fue cerrada. Para reabrirla usa la acción «Reabrir caja» (envía idSesion=%s).',
                to_char(v_existente.fecha, 'DD/MM/YYYY'),
                v_existente.id
            ),
            'registro', NULL
        );
    ELSE
        SELECT s.* INTO v_abierta
        FROM fin_caja_sesion s
        WHERE s.estado = 1
          AND s.id_estado = v_estado_abierta
          AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
        LIMIT 1;

        IF FOUND THEN
            v_hora_txt := to_char(
                v_abierta.fecha_apertura AT TIME ZONE 'America/Lima',
                'DD/MM/YYYY HH24:MI'
            );
            RETURN json_build_object(
                'error', format(
                    'Ya hay una caja ABIERTA del %s (apertura %s). Ciérrala antes de abrir otra.',
                    to_char(v_abierta.fecha, 'DD/MM/YYYY'),
                    COALESCE(v_hora_txt, '—')
                ),
                'registro', NULL
            );
        END IF;

        BEGIN
            INSERT INTO fin_caja_sesion (
                fecha, id_sucursal, id_estado, monto_inicial,
                observacion_apertura, fecha_apertura, id_usuario_apertura,
                id_usuario_creacion
            ) VALUES (
                p_fecha, p_id_sucursal, v_estado_abierta, ROUND(COALESCE(p_monto_inicial, 0), 2),
                NULLIF(TRIM(p_observacion), ''), NOW(), p_id_usuario,
                p_id_usuario
            )
            RETURNING id INTO v_id;
        EXCEPTION
            WHEN unique_violation THEN
                SELECT s.* INTO v_existente
                FROM fin_caja_sesion s
                WHERE s.estado = 1
                  AND s.fecha = p_fecha
                  AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
                LIMIT 1;

                IF FOUND AND v_existente.id_estado IS DISTINCT FROM v_estado_abierta THEN
                    RETURN json_build_object(
                        'error', format(
                            'La caja del %s ya fue cerrada. Para reabrirla usa la acción «Reabrir caja» (envía idSesion=%s).',
                            to_char(v_existente.fecha, 'DD/MM/YYYY'),
                            v_existente.id
                        ),
                        'registro', NULL
                    );
                END IF;

                RETURN json_build_object(
                    'error', 'Ya existe una sesión de caja para esa fecha y sucursal.',
                    'registro', NULL
                );
        END;

        INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, observacion, id_usuario)
        VALUES (v_id, 'ABRIR', ROUND(COALESCE(p_monto_inicial, 0), 2), NULLIF(TRIM(p_observacion), ''), p_id_usuario);
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id
    ) t;

    PERFORM fin_notificar_caja_admins(v_id, 'APERTURA', p_id_usuario);

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_caja_calcular_totales (p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION public.fin_caja_calcular_totales (
  p_fecha date,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_efectivo_id INT;
    v_ventas_contado NUMERIC(14,4) := 0;
    v_ventas_credito NUMERIC(14,4) := 0;
    v_ventas_caja NUMERIC(14,4) := 0;
    v_ventas_efectivo NUMERIC(14,4) := 0;
    v_ventas_otros NUMERIC(14,4) := 0;
    v_cobranzas NUMERIC(14,4) := 0;
    v_cobranzas_caja NUMERIC(14,4) := 0;
    v_cobranzas_efectivo NUMERIC(14,4) := 0;
    v_pagos_proveedor NUMERIC(14,4) := 0;
    v_pagos_proveedor_caja NUMERIC(14,4) := 0;
    v_gastos_caja NUMERIC(14,4) := 0;
    v_gastos_caja_medios NUMERIC(14,4) := 0;
    v_gastos_compra NUMERIC(14,4) := 0;
    v_depositos NUMERIC(14,4) := 0;
    v_garantias_cobro NUMERIC(14,4) := 0;
    v_garantias_cobro_caja NUMERIC(14,4) := 0;
    v_garantias_dev NUMERIC(14,4) := 0;
    v_garantias_dev_caja NUMERIC(14,4) := 0;
    v_por_medio JSON;
    v_efectivo_neto NUMERIC(14,4) := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    WITH mov AS (
        SELECT
            'VENTA'::TEXT AS tipo,
            COALESCE(pg.id_medio_pago, v_efectivo_id) AS id_medio_pago,
            pg.monto * CASE WHEN UPPER(COALESCE(tip.nombre, '')) = 'NOTA_CREDITO' THEN -1 ELSE 1 END AS monto
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        WHERE c.estado = 1
          AND c.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND NOT EXISTS (
              SELECT 1
              FROM ven_comprobante ori
              JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
              WHERE ori.id = c.id_comprobante_origen
                AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                AND COALESCE(tip.descripcion, '') IN ('01', '03')
          )

        UNION ALL

        SELECT
            CASE WHEN UPPER(tc.nombre) = 'COBRAR' THEN 'COBRANZA' ELSE 'PAGO_PROVEEDOR' END,
            COALESCE(p.id_medio_pago, v_efectivo_id),
            p.monto
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        WHERE p.estado = 1
          AND p.fecha_pago = p_fecha
          AND UPPER(tc.nombre) IN ('COBRAR', 'PAGAR')
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        SELECT 'PAGO_PROVEEDOR', cc.id_medio_pago, cc.total_importe
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND cc.fecha = p_fecha
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )

        UNION ALL

        SELECT 'GASTO', COALESCE(g.id_medio_pago, v_efectivo_id), g.monto
        FROM fin_caja_gasto g
        LEFT JOIN fin_caja_sesion s ON s.id = g.id_sesion AND s.estado = 1
        WHERE g.estado = 1 AND g.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        SELECT 'DEPOSITO', v_efectivo_id, d.monto
        FROM fin_caja_deposito d
        LEFT JOIN fin_caja_sesion s ON s.id = d.id_sesion AND s.estado = 1
        WHERE d.estado = 1 AND d.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        SELECT 'GARANTIA_COBRO', COALESCE(gm.id_medio_pago, g.id_medio_pago, v_efectivo_id), gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'COBRO'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          )

        UNION ALL

        SELECT
            'GARANTIA_DEVOLUCION',
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago, v_efectivo_id),
            gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'DEVOLUCION'
          AND (
              p_id_sucursal IS NULL
              OR gm.id_sucursal = p_id_sucursal
          )
    ),
    m AS (
        SELECT
            mov.tipo,
            mov.id_medio_pago,
            mov.monto,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_CREDITO')  AS es_credito,
            fin_medio_pago_flag(mov.id_medio_pago, 'AFECTA_CAJA') AS afecta_caja,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_EFECTIVO') AS es_efectivo
        FROM mov
    ),
    por_medio AS (
        SELECT
            m.id_medio_pago,
            BOOL_OR(m.es_efectivo) AS es_efectivo,
            BOOL_OR(m.afecta_caja) AS afecta_caja,
            SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA') AS ventas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA') AS cobranzas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO') AS garantias_cobro,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO') AS gastos,
            SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR') AS pagos_proveedor,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION') AS garantias_devolucion,
            SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO') AS depositos
        FROM m
        WHERE NOT m.es_credito
        GROUP BY m.id_medio_pago
    )
    SELECT
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito AND NOT m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION' AND m.afecta_caja), 0),
        COALESCE(SUM(CASE
            WHEN m.tipo IN ('VENTA', 'COBRANZA', 'GARANTIA_COBRO') THEN m.monto
            ELSE -m.monto END) FILTER (WHERE m.es_efectivo), 0),
        (
            SELECT COALESCE(json_agg(row_to_json(r) ORDER BY r.orden, r."medioPago"), '[]'::JSON)
            FROM (
                SELECT
                    pm.id_medio_pago AS "idMedioPago",
                    COALESCE(o.nombre, 'SIN MEDIO') AS "medioPago",
                    pm.es_efectivo AS "esEfectivo",
                    pm.afecta_caja AS "afectaCaja",
                    COALESCE(pm.ventas, 0) AS ventas,
                    COALESCE(pm.cobranzas, 0) AS cobranzas,
                    COALESCE(pm.garantias_cobro, 0) AS "garantiasCobro",
                    COALESCE(pm.gastos, 0) AS gastos,
                    COALESCE(pm.pagos_proveedor, 0) AS "pagosProveedor",
                    COALESCE(pm.garantias_devolucion, 0) AS "garantiasDevolucion",
                    COALESCE(pm.depositos, 0) AS depositos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0) AS ingresos,
                    COALESCE(pm.gastos, 0) + COALESCE(pm.pagos_proveedor, 0)
                        + COALESCE(pm.garantias_devolucion, 0) + COALESCE(pm.depositos, 0) AS egresos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0)
                        - COALESCE(pm.gastos, 0) - COALESCE(pm.pagos_proveedor, 0)
                        - COALESCE(pm.garantias_devolucion, 0) - COALESCE(pm.depositos, 0) AS neto,
                    COALESCE(cfg.orden, 999) AS orden
                FROM por_medio pm
                LEFT JOIN gen_lista_opciones o ON o.id = pm.id_medio_pago
                LEFT JOIN fin_medio_pago_config cfg ON cfg.id_medio_pago = pm.id_medio_pago
            ) r
        )
    INTO v_ventas_contado, v_ventas_credito, v_ventas_caja, v_ventas_efectivo, v_ventas_otros,
         v_cobranzas, v_cobranzas_caja, v_cobranzas_efectivo,
         v_pagos_proveedor, v_pagos_proveedor_caja,
         v_gastos_caja, v_gastos_caja_medios,
         v_depositos,
         v_garantias_cobro, v_garantias_cobro_caja,
         v_garantias_dev, v_garantias_dev_caja,
         v_efectivo_neto,
         v_por_medio
    FROM m;

    SELECT COALESCE(SUM(cc.total_importe), 0)
    INTO v_gastos_compra
    FROM com_comprobante_compra cc
    LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
    WHERE cc.estado = 1
      AND cc.fecha = p_fecha
      AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
      AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal);

    RETURN json_build_object(
        'ventasContado', v_ventas_contado,
        'ventasCredito', v_ventas_credito,
        'ventasMediosCaja', v_ventas_caja,
        'ventasEfectivo', v_ventas_efectivo,
        'ventasOtrosMedios', v_ventas_otros,
        'cobranzas', v_cobranzas,
        'cobranzasMediosCaja', v_cobranzas_caja,
        'cobranzasEfectivo', v_cobranzas_efectivo,
        'pagosProveedor', v_pagos_proveedor,
        'pagosProveedorMediosCaja', v_pagos_proveedor_caja,
        'gastosCaja', v_gastos_caja,
        'gastosCajaMediosCaja', v_gastos_caja_medios,
        'gastosCompra', v_gastos_compra,
        'gastos', v_gastos_caja + v_gastos_compra,
        'depositos', v_depositos,
        'garantiasCobro', v_garantias_cobro,
        'garantiasCobroMediosCaja', v_garantias_cobro_caja,
        'garantiasDevolucion', v_garantias_dev,
        'garantiasDevolucionMediosCaja', v_garantias_dev_caja,
        'efectivoNeto', v_efectivo_neto,
        'porMedio', v_por_medio
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_cerrar_caja_sesion (
  p_id integer,
  p_monto_efectivo_contado numeric,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_cerrar_caja_sesion (
  p_id integer,
  p_monto_efectivo_contado numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_sesion RECORD;
    v_estado_cerrada INT;
    v_totales JSON;
    v_esperado NUMERIC(14,4);
    v_diferencia NUMERIC(14,4);
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_cerrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'CERRADA'
    LIMIT 1;

    SELECT s.*, est.nombre AS estado_nombre
    INTO v_sesion
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.id = p_id AND s.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Sesión de caja no encontrada', 'registro', NULL);
    END IF;

    IF UPPER(COALESCE(v_sesion.estado_nombre, '')) = 'CERRADA' THEN
        RETURN json_build_object('error', 'La caja ya está cerrada', 'registro', NULL);
    END IF;

    IF p_monto_efectivo_contado IS NULL OR p_monto_efectivo_contado < 0 THEN
        RETURN json_build_object('error', 'Indique el efectivo contado (arqueo)', 'registro', NULL);
    END IF;

    v_totales := fin_caja_calcular_totales(v_sesion.fecha, v_sesion.id_sucursal);
    v_esperado := COALESCE(v_sesion.monto_inicial, 0)
        + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0);
    v_diferencia := COALESCE(p_monto_efectivo_contado, 0) - v_esperado;

    UPDATE fin_caja_sesion
    SET id_estado = v_estado_cerrada,
        monto_efectivo_contado = p_monto_efectivo_contado,
        monto_esperado = v_esperado,
        diferencia = v_diferencia,
        totales_cierre = v_totales,
        observacion_cierre = NULLIF(TRIM(p_observacion), ''),
        fecha_cierre = NOW(),
        id_usuario_cierre = p_id_usuario,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario)
    VALUES (p_id, 'CERRAR', p_monto_efectivo_contado, v_diferencia, NULLIF(TRIM(p_observacion), ''), p_id_usuario);

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre",
            v_totales AS totales
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = p_id
    ) t;

    PERFORM fin_notificar_caja_admins(p_id, 'CIERRE', p_id_usuario);

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_listar_caja_sesiones (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_sucursal integer,
  p_estado_caja character varying,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.fin_listar_caja_sesiones (
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_estado_caja character varying DEFAULT NULL::character varying,
  p_limite integer DEFAULT 20,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.estado = 1
      AND (p_fecha_desde IS NULL OR s.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR s.fecha <= p_fecha_hasta)
      AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
      AND (p_estado_caja IS NULL OR UPPER(est.nombre) = UPPER(p_estado_caja));

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            ua.nombre AS "usuarioApertura",
            uc.nombre AS "usuarioCierre",
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            (SELECT COUNT(*) FROM fin_caja_sesion_evento e WHERE e.id_sesion = s.id) AS "cantidadEventos"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        LEFT JOIN auth_usuarios uc ON uc.id = s.id_usuario_cierre
        WHERE s.estado = 1
          AND (p_fecha_desde IS NULL OR s.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR s.fecha <= p_fecha_hasta)
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)
          AND (p_estado_caja IS NULL OR UPPER(est.nombre) = UPPER(p_estado_caja))
        ORDER BY s.fecha DESC, s.id DESC
        LIMIT GREATEST(COALESCE(p_limite, 20), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_listar_cuentas (
  p_tipo character varying,
  p_id_tercero integer,
  p_estado character varying,
  p_solo_pendientes integer,
  p_buscar character varying,
  p_id_padre integer,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.fin_listar_cuentas (
  p_tipo character varying DEFAULT NULL::character varying,
  p_id_tercero integer DEFAULT NULL::integer,
  p_estado character varying DEFAULT NULL::character varying,
  p_solo_pendientes integer DEFAULT NULL::integer,
  p_buscar character varying DEFAULT NULL::character varying,
  p_id_padre integer DEFAULT NULL::integer,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
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
            (fc.numero_cuotas_total IS NOT NULL) AS es_plan
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        LEFT JOIN ven_comprobante vc ON vc.id = fc.id_comprobante_venta
        LEFT JOIN com_comprobante_compra cc ON cc.id = fc.id_comprobante_compra
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
          AND (p_id_tercero IS NULL OR fc.id_tercero = p_id_tercero)
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

DROP FUNCTION IF EXISTS public.fin_listar_garantias (
  p_buscar character varying,
  p_id_cliente integer,
  p_desde date,
  p_hasta date,
  p_estado character varying,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.fin_listar_garantias (
  p_buscar character varying DEFAULT NULL::character varying,
  p_id_cliente integer DEFAULT NULL::integer,
  p_desde date DEFAULT NULL::date,
  p_hasta date DEFAULT NULL::date,
  p_estado character varying DEFAULT NULL::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.fin_obtener_caja_sesion (p_id integer);

CREATE OR REPLACE FUNCTION public.fin_obtener_caja_sesion (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registro JSON;
    v_totales JSON;
    v_fecha DATE;
    v_id_sucursal INT;
    v_fecha_cierre TIMESTAMP;
    v_totales_congelados JSON;
    v_totales_vivo JSON;
    v_gastos JSON;
    v_depositos JSON;
    v_eventos JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.fecha, s.id_sucursal, s.fecha_cierre, s.totales_cierre
    INTO v_fecha, v_id_sucursal, v_fecha_cierre, v_totales_congelados
    FROM fin_caja_sesion s WHERE s.id = p_id AND s.estado = 1;

    IF v_fecha IS NULL THEN
        RETURN json_build_object('error', 'Sesión no encontrada', 'registro', NULL);
    END IF;

    IF v_fecha_cierre IS NOT NULL AND v_totales_congelados IS NOT NULL THEN
        v_totales := v_totales_congelados;
    ELSE
        v_totales := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
    END IF;

    IF v_totales::JSONB->'porMedio' IS NULL THEN
        v_totales_vivo := fin_caja_calcular_totales(v_fecha, v_id_sucursal);
        v_totales := (v_totales::JSONB || jsonb_build_object(
            'porMedio', v_totales_vivo->'porMedio',
            'efectivoNeto', v_totales_vivo->'efectivoNeto'
        ))::JSON;
    END IF;

    SELECT COALESCE(json_agg(row_to_json(g) ORDER BY g.id), '[]'::JSON) INTO v_gastos
    FROM (
        SELECT
            cg.id,
            cg.fecha,
            cg.concepto,
            cg.monto,
            cg.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cbg.alias, cbg.titular, cbg.numero_cuenta) AS "cuentaBancaria",
            cg.numero_operacion AS "numeroOperacion",
            cg.observacion
        FROM fin_caja_gasto cg
        LEFT JOIN gen_lista_opciones mp ON mp.id = cg.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cbg ON cbg.id = cg.id_cuenta_bancaria
        WHERE cg.estado = 1 AND cg.id_sesion = p_id
    ) g;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON) INTO v_depositos
    FROM (
        SELECT
            cd.id,
            cd.fecha,
            cd.monto,
            cd.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            cd.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            cd.numero_operacion AS "numeroOperacion",
            cd.observacion
        FROM fin_caja_deposito cd
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cd.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = cd.id_medio_pago
        WHERE cd.estado = 1 AND cd.id_sesion = p_id
    ) d;

    SELECT COALESCE(json_agg(row_to_json(ev) ORDER BY ev."fechaHora", ev.id), '[]'::JSON) INTO v_eventos
    FROM (
        SELECT
            e.id,
            e.tipo,
            e.monto,
            e.diferencia,
            e.observacion,
            e.id_usuario AS "idUsuario",
            u.nombre AS usuario,
            e.fecha_hora AS "fechaHora"
        FROM fin_caja_sesion_evento e
        LEFT JOIN auth_usuarios u ON u.id = e.id_usuario
        WHERE e.id_sesion = p_id
    ) ev;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            ua.nombre AS "usuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre",
            uc.nombre AS "usuarioCierre",
            v_totales AS totales,
            v_gastos AS gastos,
            v_depositos AS depositos,
            v_eventos AS eventos,
            COALESCE(s.monto_inicial, 0)
                + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0) AS "efectivoEsperado"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        LEFT JOIN auth_usuarios ua ON ua.id = s.id_usuario_apertura
        LEFT JOIN auth_usuarios uc ON uc.id = s.id_usuario_cierre
        WHERE s.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_obtener_libro_diario (
  p_fecha_desde date,
  p_fecha_hasta date,
  p_id_cliente integer,
  p_id_sucursal integer
);

CREATE OR REPLACE FUNCTION public.fin_obtener_libro_diario (
  p_fecha_desde date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_id_cliente integer DEFAULT NULL::integer,
  p_id_sucursal integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_hasta DATE;
    v_efectivo_id INT;
    v_ventas JSON;
    v_ventas_pagos JSON;
    v_cobranzas JSON;
    v_pagos_proveedor JSON;
    v_gastos JSON;
    v_depositos JSON;
    v_garantias JSON;
    v_observaciones JSON;
    v_totales JSON;
    v_dias JSON;
    v_resumenes JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_desde IS NULL THEN
        RETURN json_build_object('error', 'fechaDesde es obligatoria', 'registro', NULL);
    END IF;

    v_hasta := COALESCE(p_fecha_hasta, p_fecha_desde);

    IF v_hasta < p_fecha_desde THEN
        RETURN json_build_object('error', 'fechaHasta no puede ser menor que fechaDesde', 'registro', NULL);
    END IF;

    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_ventas
    FROM (
        SELECT
            c.id,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            c.serie,
            c.numero,
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            mp.nombre AS "medioPago",
            CASE WHEN UPPER(COALESCE(mp.nombre, '')) = 'CREDITO' THEN true ELSE false END AS "esCredito",
            c.total_importe AS "totalImporte",
            (
                SELECT string_agg(
                    COALESCE(d.descripcion, pr.nombre)
                    || CASE WHEN d.cantidad IS NOT NULL THEN ' × ' || gen_formato_cantidad(d.cantidad) ELSE '' END
                    || CASE WHEN um.nombre IS NOT NULL THEN ' ' || um.nombre ELSE '' END,
                    '; '
                )
                FROM ven_comprobante_detalle d
                LEFT JOIN pro_producto pr ON pr.id = d.id_producto
                LEFT JOIN gen_lista_opciones um ON um.id = COALESCE(d.id_unidad_medida, pr.id_unidad_medida)
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS "detalleProductos",
            EXISTS (
                SELECT 1
                FROM ven_comprobante ori
                JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
                WHERE ori.id = c.id_comprobante_origen
                  AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                  AND COALESCE(tip.descripcion, '') IN ('01', '03')
            ) AS "esConversionVsd"
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones mp ON mp.id = c.id_medio_pago
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t."idComprobante", t.item), '[]'::json)
    INTO v_ventas_pagos
    FROM (
        SELECT
            c.id AS "idComprobante",
            pg.id_pago AS "idPago",
            pg.item,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            pg.id_medio_pago AS "idMedioPago",
            COALESCE(mp.nombre, mpe.nombre) AS "medioPago",
            pg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            pg.numero_operacion AS "numeroOperacion",
            pg.monto,
            pg.origen,
            CASE
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_CREDITO')
                    THEN 'CREDITO'
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_EFECTIVO')
                    THEN 'EFECTIVO'
                ELSE 'OTROS'
            END AS grupo
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        LEFT JOIN gen_lista_opciones mp ON mp.id = pg.id_medio_pago
        LEFT JOIN gen_lista_opciones mpe ON mpe.id = v_efectivo_id
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pg.id_cuenta_bancaria
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          AND NOT EXISTS (
              SELECT 1
              FROM ven_comprobante ori
              JOIN gen_lista_opciones tori ON tori.id = ori.id_tipo_comprobante
              WHERE ori.id = c.id_comprobante_origen
                AND UPPER(COALESCE(tori.descripcion, '')) IN ('NV', 'VSD')
                AND COALESCE(tip.descripcion, '') IN ('01', '03')
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.id), '[]'::json)
    INTO v_cobranzas
    FROM (
        SELECT
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            cu.id_tercero AS "idCliente"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes cli ON cli.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'COBRAR'
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.clave), '[]'::json)
    INTO v_pagos_proveedor
    FROM (
        SELECT
            'P' || p.id AS clave,
            'CXP' AS origen,
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            cu.id_tercero AS "idProveedor",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ) AS proveedor,
            COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra) AS "idCompra",
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '') AS "compraSerieNumero"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN fin_cuenta pad ON pad.id = cu.id_cuenta_padre
        LEFT JOIN com_comprobante_compra cc
               ON cc.id = COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra)
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'PAGAR'
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        SELECT
            'C' || cc.id,
            'CONTADO',
            cc.id,
            cc.fecha,
            cc.total_importe,
            cc.id_medio_pago,
            mp.nombre,
            cc.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta),
            cc.numero_operacion,
            cc.glosa,
            NULL::INTEGER,
            cc.id_proveedor,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ),
            cc.id,
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '')
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones mp ON mp.id = cc.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cc.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cc.id_proveedor
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_cliente IS NULL OR cc.id_proveedor = p_id_cliente)
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.origen, t.id), '[]'::json)
    INTO v_gastos
    FROM (
        SELECT
            g.id,
            g.fecha,
            'CAJA'::text AS origen,
            g.concepto,
            g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            g.observacion
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN fin_caja_sesion sg ON sg.id = g.id_sesion AND sg.estado = 1
        WHERE g.estado = 1
          AND g.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sg.id_sucursal = p_id_sucursal)
        UNION ALL
        SELECT
            cc.id,
            cc.fecha,
            'COMPRA'::text AS origen,
            COALESCE(
                NULLIF(TRIM(cc.glosa), ''),
                NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), ''),
                'Gasto compra'
            ) AS concepto,
            cc.total_importe AS monto,
            NULL::integer AS "idMedioPago",
            NULL::varchar AS "medioPago",
            NULL::integer AS "idCuentaBancaria",
            NULL::varchar AS "cuentaBancaria",
            cc.glosa AS observacion
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_depositos
    FROM (
        SELECT
            d.id,
            d.fecha,
            d.monto,
            d.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            d.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            d.numero_operacion AS "numeroOperacion",
            d.observacion
        FROM fin_caja_deposito d
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = d.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = d.id_medio_pago
        LEFT JOIN fin_caja_sesion sd ON sd.id = d.id_sesion AND sd.estado = 1
        WHERE d.estado = 1
          AND d.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sd.id_sucursal = p_id_sucursal)
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_garantias
    FROM (
        SELECT
            gm.id,
            gm.fecha,
            UPPER(tm.nombre) AS tipo,
            gm.id_garantia AS "idGarantia",
            gm.monto,
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago) AS "idMedioPago",
            mp.nombre AS "medioPago",
            gm.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            gm.numero_operacion AS "numeroOperacion",
            g.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            gm.observacion
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        LEFT JOIN cli_clientes cli ON cli.id = g.id_cliente
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN gen_lista_opciones mp
               ON mp.id = COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago)
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = gm.id_cuenta_bancaria
        WHERE gm.estado = 1
          AND gm.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tm.nombre) IN ('COBRO', 'DEVOLUCION')
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          )
    ) t;

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_observaciones
    FROM (
        SELECT
            o.id,
            o.fecha,
            o.texto,
            u.nombre AS usuario,
            o.fecha_creacion AS "fechaCreacion"
        FROM fin_caja_observacion o
        LEFT JOIN auth_usuarios u ON u.id = o.id_usuario_creacion
        WHERE o.estado = 1
          AND o.fecha BETWEEN p_fecha_desde AND v_hasta
    ) t;

    SELECT json_build_object(
        'ventasContado', COALESCE(SUM((t.tot->>'ventasContado')::NUMERIC), 0),
        'ventasCredito', COALESCE(SUM((t.tot->>'ventasCredito')::NUMERIC), 0),
        'ventasMediosCaja', COALESCE(SUM((t.tot->>'ventasMediosCaja')::NUMERIC), 0),
        'ventasEfectivo', COALESCE(SUM((t.tot->>'ventasEfectivo')::NUMERIC), 0),
        'ventasOtrosMedios', COALESCE(SUM((t.tot->>'ventasOtrosMedios')::NUMERIC), 0),
        'cobranzas', COALESCE(SUM((t.tot->>'cobranzas')::NUMERIC), 0),
        'cobranzasMediosCaja', COALESCE(SUM((t.tot->>'cobranzasMediosCaja')::NUMERIC), 0),
        'cobranzasEfectivo', COALESCE(SUM((t.tot->>'cobranzasEfectivo')::NUMERIC), 0),
        'pagosProveedor', COALESCE(SUM((t.tot->>'pagosProveedor')::NUMERIC), 0),
        'pagosProveedorMediosCaja', COALESCE(SUM((t.tot->>'pagosProveedorMediosCaja')::NUMERIC), 0),
        'gastosCaja', COALESCE(SUM((t.tot->>'gastosCaja')::NUMERIC), 0),
        'gastosCajaMediosCaja', COALESCE(SUM((t.tot->>'gastosCajaMediosCaja')::NUMERIC), 0),
        'gastosCompra', COALESCE(SUM((t.tot->>'gastosCompra')::NUMERIC), 0),
        'gastos', COALESCE(SUM((t.tot->>'gastos')::NUMERIC), 0),
        'depositos', COALESCE(SUM((t.tot->>'depositos')::NUMERIC), 0),
        'garantiasCobro', COALESCE(SUM((t.tot->>'garantiasCobro')::NUMERIC), 0),
        'garantiasCobroMediosCaja', COALESCE(SUM((t.tot->>'garantiasCobroMediosCaja')::NUMERIC), 0),
        'garantiasDevolucion', COALESCE(SUM((t.tot->>'garantiasDevolucion')::NUMERIC), 0),
        'garantiasDevolucionMediosCaja', COALESCE(SUM((t.tot->>'garantiasDevolucionMediosCaja')::NUMERIC), 0)
    )
    INTO v_totales
    FROM (
        SELECT fin_caja_calcular_totales(d::date, p_id_sucursal) AS tot
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) t;

    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.fecha), '[]'::json)
    INTO v_dias
    FROM (
        SELECT
            d::date AS fecha,
            fin_caja_calcular_totales(d::date, p_id_sucursal) AS totales
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) x;

    SELECT json_agg(row_to_json(r) ORDER BY r.orden)
    INTO v_resumenes
    FROM (
        VALUES
            ('ventas_efectivo',    'Ventas en efectivo',   'ventasPagos', 'grupo',  'EFECTIVO',
             1,  (v_totales->>'ventasEfectivo')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'EFECTIVO'), 10),
            ('ventas_otros_medios','Ventas otros medios',  'ventasPagos', 'grupo',  'OTROS',
             1,  (v_totales->>'ventasOtrosMedios')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'OTROS'), 20),
            ('ventas_credito',     'Ventas a crédito',     'ventasPagos', 'grupo',  'CREDITO',
             0,  (v_totales->>'ventasCredito')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'CREDITO'), 30),
            ('cobranzas',          'Cobranzas',            'cobranzas',   NULL,     NULL,
             1,  (v_totales->>'cobranzas')::NUMERIC,
             json_array_length(v_cobranzas), 40),
            ('garantias_cobradas', 'Garantías cobradas',   'garantias',   'tipo',   'COBRO',
             1,  (v_totales->>'garantiasCobro')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'COBRO'), 50),
            ('garantias_devueltas','Garantías devueltas',  'garantias',   'tipo',   'DEVOLUCION',
             -1, (v_totales->>'garantiasDevolucion')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'DEVOLUCION'), 60),
            ('pagos_proveedor',    'Pagos a proveedores',  'pagosProveedor', NULL,  NULL,
             -1, (v_totales->>'pagosProveedor')::NUMERIC,
             json_array_length(v_pagos_proveedor), 65),
            ('gastos',             'Gastos',               'gastos',      NULL,     NULL,
             -1, (v_totales->>'gastos')::NUMERIC,
             json_array_length(v_gastos), 70),
            ('depositos',          'Depósitos a banco',    'depositos',   NULL,     NULL,
             -1, (v_totales->>'depositos')::NUMERIC,
             json_array_length(v_depositos), 80),
            ('observaciones',      'Observaciones',        'observaciones', NULL,   NULL,
             0,  NULL::NUMERIC,
             json_array_length(v_observaciones), 90)
    ) AS r(clave, etiqueta, coleccion, "filtroCampo", "filtroValor", signo, total, cantidad, orden);

    RETURN json_build_object(
        'registro', json_build_object(
            'fechaDesde', p_fecha_desde,
            'fechaHasta', v_hasta,
            'idCliente', p_id_cliente,
            'idSucursal', p_id_sucursal,
            'ventas', v_ventas,
            'ventasPagos', v_ventas_pagos,
            'cobranzas', v_cobranzas,
            'pagosProveedor', v_pagos_proveedor,
            'gastos', v_gastos,
            'depositos', v_depositos,
            'garantias', v_garantias,
            'observaciones', v_observaciones,
            'resumenes', v_resumenes,
            'totales', v_totales,
            'dias', v_dias
        )
    );
END;
$function$;

DROP FUNCTION IF EXISTS public.fin_saldos_por_tercero (
  p_tipo character varying,
  p_fecha_corte date,
  p_buscar character varying,
  p_solo_pendientes integer,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.fin_saldos_por_tercero (
  p_tipo character varying DEFAULT 'COBRAR'::character varying,
  p_fecha_corte date DEFAULT CURRENT_DATE,
  p_buscar character varying DEFAULT NULL::character varying,
  p_solo_pendientes integer DEFAULT 1,
  p_limite integer DEFAULT 50,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
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

DROP FUNCTION IF EXISTS public.gen_listar_condiciones_pago (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer
);

CREATE OR REPLACE FUNCTION public.gen_listar_condiciones_pago (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_condicion_pago cp
    WHERE cp.estado = 1
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(cp.codigo, p_busqueda)
          OR gen_texto_coincide(cp.nombre, p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cp.id,
            cp.codigo,
            cp.nombre,
            cp.dias_credito,
            cp.numero_cuotas,
            cp.dia_mes_pago,
            CASE
                WHEN COALESCE(cp.numero_cuotas, 0) > 1 THEN 'CUOTAS'
                WHEN COALESCE(cp.dias_credito, 0) > 0 THEN 'CREDITO'
                ELSE 'CONTADO'
            END AS modalidad,
            cp.estado,
            cp.fecha_creacion,
            cp.fecha_modificacion,
            cp.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cp.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_condicion_pago cp
        LEFT JOIN auth_usuarios uc ON cp.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cp.id_usuario_modificacion = um.id
        WHERE cp.estado = 1
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(cp.codigo, p_busqueda)
              OR gen_texto_coincide(cp.nombre, p_busqueda)
          )
        ORDER BY cp.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS public.pro_listar_catalogo_precios (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_tipo_catalogo integer,
  p_id_producto integer,
  p_id_proveedor integer,
  p_periodo character varying
);

CREATE OR REPLACE FUNCTION public.pro_listar_catalogo_precios (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_tipo_catalogo integer DEFAULT NULL::integer,
  p_id_producto integer DEFAULT NULL::integer,
  p_id_proveedor integer DEFAULT NULL::integer,
  p_periodo character varying DEFAULT NULL::character varying
) RETURNS json LANGUAGE plpgsql AS $function$
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

INSERT INTO
  fin_caja_sesion_evento (
    id_sesion,
    tipo,
    monto,
    diferencia,
    observacion,
    id_usuario,
    fecha_hora
  )
SELECT
  s.id,
  v.tipo,
  v.monto,
  v.diferencia,
  v.observacion,
  v.id_usuario,
  v.fecha_hora
FROM
  fin_caja_sesion s
  CROSS JOIN LATERAL (
    VALUES
      (
        1,
        'ABRIR',
        s.monto_inicial,
        NULL::numeric,
        s.observacion_apertura,
        s.id_usuario_apertura,
        s.fecha_apertura AT TIME ZONE 'America/Lima'
      ),
      (
        2,
        'CERRAR',
        s.monto_efectivo_contado,
        s.diferencia,
        s.observacion_cierre,
        s.id_usuario_cierre,
        s.fecha_cierre AT TIME ZONE 'America/Lima'
      )
  ) AS v (
    orden,
    tipo,
    monto,
    diferencia,
    observacion,
    id_usuario,
    fecha_hora
  )
WHERE
  (
    v.tipo = 'ABRIR'
    OR s.fecha_cierre IS NOT NULL
  )
  AND NOT EXISTS (
    SELECT
      1
    FROM
      fin_caja_sesion_evento e
    WHERE
      e.id_sesion = s.id
  )
ORDER BY
  s.id,
  v.orden;

COMMIT;
