-- ============================================================
-- Migración: Fase 7 — compra de cilindros + badge "sin comprobante"
-- Fecha: 2026-09-08
--
-- 1) Catálogo TipoMovBalon gana ENTRADA_COMPRA: comprar un cilindro es una
--    entrada de inventario propia, distinta del retorno de planta.
--
-- 2) com_registrar_balones_compra (nueva): da de alta en bal_balon los
--    cilindros comprados y registra un inv_movimiento por cada uno
--    (apunte 4.b.iv: un movimiento por acción física).
--
-- 3) com_listar_compras expone `tiene_comprobante` y acepta el filtro
--    p_sin_comprobante, para el badge y el filtro de la lista (apunte 4.b.iii).
--    El parámetro va al final de la firma para no romper llamadas posicionales.
--
-- No cambia ninguna tabla.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260908_f7_compras_balones_y_comprobante.sql
-- ============================================================

-- ENTRADA_COMPRA va en las dos listas: TipoMovBalon es el catálogo que se
-- muestra en pantalla, pero inv_registrar_movimiento resuelve el tipo contra
-- TipoMovInvUnificado — sin la fila ahí el movimiento se rechaza.
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (VALUES ('ENTRADA_COMPRA', 'Entrada por compra')) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMovBalon'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (VALUES ('ENTRADA_COMPRA', 'Entrada de balon por compra')) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMovInvUnificado'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );



-- ============================================================
-- database_sql/funciones/compras/com_registrar_balones_compra.sql
-- ============================================================

-- Function: com_registrar_balones_compra
-- Fase 7 — compra de cilindros: los da de alta en el libro y mueve inventario.
--
-- Comprar un balón no es como comprar un producto: el cilindro tiene identidad
-- propia, así que además de la línea de compra hay que crearlo en bal_balon y
-- registrar su ENTRADA_COMPRA en inv_movimiento. Un movimiento por cilindro,
-- no uno por línea (apunte 4.b.iv).
--
-- p_balones: [{ codigo_balon, numero_serie, id_tipo_balon, id_producto_gas,
--               id_marca_cilindro, fecha_fabricacion,
--               fecha_ultima_prueba_hidrostatica, precio_unitario }]
DROP FUNCTION IF EXISTS com_registrar_balones_compra(p_id_comprobante integer, p_balones jsonb, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_registrar_balones_compra(p_id_comprobante integer, p_balones jsonb DEFAULT NULL::jsonb, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_compra            RECORD;
    v_linea             JSONB;
    v_codigo            VARCHAR;
    v_id_balon          INTEGER;
    v_id_propietario    INTEGER;
    v_id_estado         INTEGER;
    v_id_referencia     INTEGER;
    v_res               JSON;
    v_creados           INTEGER := 0;
    v_ids               INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_balones IS NULL OR jsonb_array_length(p_balones) = 0 THEN
        RETURN json_build_object('error', NULL, 'registro', json_build_object('creados', 0, 'id_balones', '[]'::JSON));
    END IF;

    SELECT c.id, c.fecha, c.serie, c.numero, c.id_almacen, c.id_proveedor
    INTO v_compra
    FROM com_comprobante_compra c
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF v_compra.id IS NULL THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    -- Un cilindro comprado entra como propio y disponible en el almacén de la compra.
    SELECT lo.id INTO v_id_propietario
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'EMPRESA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1 LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Falta el estado DISPONIBLE en el catálogo EstadoBalon', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_referencia
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'ReferenciaCilindro' AND lo.nombre = 'ALMACEN' AND lo.estado = 1 LIMIT 1;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(p_balones)
    LOOP
        v_codigo := NULLIF(TRIM(v_linea->>'codigo_balon'), '');

        IF v_codigo IS NULL THEN
            RETURN json_build_object('error', 'Cada cilindro comprado necesita su código', 'registro', NULL);
        END IF;

        IF EXISTS (SELECT 1 FROM bal_balon WHERE UPPER(TRIM(codigo_balon)) = UPPER(v_codigo) AND estado = 1) THEN
            RETURN json_build_object(
                'error', format('El cilindro %s ya existe en el libro', v_codigo),
                'registro', NULL
            );
        END IF;

        v_res := bal_crear_balon(
            p_codigo_balon                     => v_codigo,
            p_fecha_registro                   => v_compra.fecha,
            p_id_almacen                       => v_compra.id_almacen,
            p_id_propietario                   => v_id_propietario,
            p_id_referencia                    => v_id_referencia,
            p_id_tipo_balon                    => (v_linea->>'id_tipo_balon')::INTEGER,
            p_id_producto_gas                  => (v_linea->>'id_producto_gas')::INTEGER,
            p_id_estado_balon                  => v_id_estado,
            p_fecha_ultima_prueba_hidrostatica => (v_linea->>'fecha_ultima_prueba_hidrostatica')::DATE,
            p_fecha_fabricacion                => (v_linea->>'fecha_fabricacion')::DATE,
            p_observacion                      => format(
                'Alta por compra %s',
                NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), '')
            ),
            p_numero_serie                     => NULLIF(TRIM(v_linea->>'numero_serie'), ''),
            p_id_marca_cilindro                => (v_linea->>'id_marca_cilindro')::INTEGER,
            p_id_usuario_auditoria             => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            RETURN json_build_object('error', v_res->>'error', 'registro', NULL);
        END IF;

        v_id_balon := (v_res->'registro'->>'id')::INTEGER;

        IF v_id_balon IS NULL THEN
            RETURN json_build_object(
                'error', format('No se pudo crear el cilindro %s', v_codigo),
                'registro', NULL
            );
        END IF;

        -- A partir de acá el cilindro ya existe en el libro: si el movimiento
        -- falla se levanta excepción para que la transacción entera se deshaga
        -- y no quede un balón dado de alta sin su entrada de inventario.
        v_res := inv_registrar_movimiento(
            p_naturaleza                   => 'BALON',
            p_codigo_tipo_movimiento       => 'ENTRADA_COMPRA',
            p_fecha                        => v_compra.fecha,
            p_id_balon                     => v_id_balon,
            p_cantidad                     => 1,
            p_id_almacen_destino           => v_compra.id_almacen,
            p_id_cliente                   => v_compra.id_proveedor,
            p_codigo_tipo_documento_origen => 'COMPRA',
            p_id_documento_origen          => p_id_comprobante,
            p_glosa                        => format('Ingreso del cilindro %s por compra', v_codigo),
            p_id_usuario_auditoria         => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo registrar la entrada del cilindro %: %',
                v_codigo, v_res->>'error';
        END IF;

        v_ids := v_ids || v_id_balon;
        v_creados := v_creados + 1;
    END LOOP;

    UPDATE com_comprobante_compra
    SET afecta_inventario = TRUE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('creados', v_creados, 'id_balones', array_to_json(v_ids))
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_listar_compras.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_listar_compras
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS com_listar_compras(p_busqueda character varying, p_limite integer, p_offset integer, p_id_proveedor integer, p_id_almacen integer, p_fecha_desde date, p_fecha_hasta date, p_estado integer, p_id_tipo_registro integer, p_id_categoria_gasto integer);
DROP FUNCTION IF EXISTS com_listar_compras(p_busqueda character varying, p_limite integer, p_offset integer, p_id_proveedor integer, p_id_almacen integer, p_fecha_desde date, p_fecha_hasta date, p_estado integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_sin_comprobante boolean);

CREATE OR REPLACE FUNCTION com_listar_compras(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_proveedor integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_estado integer DEFAULT NULL::integer, p_id_tipo_registro integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_sin_comprobante boolean DEFAULT NULL::boolean)
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
          OR LOWER(COALESCE(pr.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
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
              OR LOWER(COALESCE(pr.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
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
