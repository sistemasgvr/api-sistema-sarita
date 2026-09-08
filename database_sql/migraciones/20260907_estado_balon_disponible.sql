-- ============================================================================
-- 20260907_estado_balon_disponible
--
-- El estado 'EN_ALMACEN' de la lista EstadoBalon fue renombrado en la BD a
-- 'DISPONIBLE' (id 389, "Cuando el cilindro tiene un id almacen de la empresa").
-- Las 28 funciones de abajo seguían buscando el nombre viejo, así que sus
-- lookups devolvían NULL: las devoluciones dejaban el cilindro sin estado y los
-- listados de stock no encontraban nada.
--
-- Esta migración vuelve a crear esas 28 funciones con el nombre nuevo. El cuerpo
-- es idéntico al de database_sql/funciones/ (verificado contra la BD antes del
-- cambio): lo único que varía es EN_ALMACEN -> DISPONIBLE.
--
-- NO se toca ninguna fila de datos. El catálogo ya está renombrado en la BD.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260907_estado_balon_disponible.sql
-- ============================================================================

-- Corta la migración si el catálogo no tiene el estado nuevo.
DO $migracion_guard$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    ) THEN
        RAISE EXCEPTION 'Falta la opción DISPONIBLE en el catálogo EstadoBalon: no se aplica la migración';
    END IF;
END;
$migracion_guard$;



-- ============================================================
-- database_sql/funciones/alquileres-detalle/bal_actualizar_alquiler_detalle.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.943Z
DROP FUNCTION IF EXISTS bal_actualizar_alquiler_detalle(p_id integer, p_id_balon integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_alquiler_detalle(p_id integer, p_id_balon integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon_actual INTEGER;
    v_fecha_devolucion DATE;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT ad.id_alquiler, ad.id_balon, ad.fecha_devolucion, al.id_cliente, al.id_almacen
    INTO v_id_alquiler, v_id_balon_actual, v_fecha_devolucion, v_id_cliente, v_id_almacen
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id AND ad.estado = 1;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_balon IS NOT NULL AND p_id_balon <> v_id_balon_actual THEN
        IF v_fecha_devolucion IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'No se puede cambiar el cilindro de un detalle ya devuelto',
                'registro', NULL
            );
        END IF;

        IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1) THEN
            RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = p_id_balon
              AND COALESCE(eb.nombre, '') IN ('DADO_DE_BAJA', 'ROBO')
        ) THEN
            RETURN json_build_object(
                'error', 'No se puede alquilar un cilindro dado de baja o reportado como robo',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1 FROM bal_alquiler_detalle
            WHERE id_alquiler = v_id_alquiler AND id_balon = p_id_balon AND id <> p_id AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = p_id_balon
              AND ad.id <> p_id
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro ya tiene un alquiler activo sin devolver',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = p_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro está prestado actualmente; no se puede alquilar',
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NULL THEN
            RETURN json_build_object(
                'error', 'Faltan estados ALQUILADO / DISPONIBLE en el catálogo EstadoBalon',
                'registro', NULL
            );
        END IF;

        IF v_id_almacen IS NULL THEN
            RETURN json_build_object(
                'error', 'El alquiler no tiene almacén para devolver el cilindro anterior',
                'registro', NULL
            );
        END IF;

        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
            p_fecha                     => LOCALTIMESTAMP,
            p_id_balon                  => v_id_balon_actual,
            p_cantidad                  => 1,
            p_id_almacen_destino        => v_id_almacen,
            p_id_cliente                => v_id_cliente,
            p_codigo_tipo_documento_origen => 'ALQUILER',
            p_id_documento_origen       => v_id_alquiler,
            p_glosa                     => 'Retorno por cambio de cilindro en alquiler',
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov->>'error';
        END IF;

        -- inv_registrar_movimiento ya deja el balón devuelto en DISPONIBLE/v_id_almacen
        -- (mapeo ENTRADA_DEVOLUCION), no hace falta repetirlo aquí.

        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'SALIDA_ALQUILER',
            p_fecha                     => LOCALTIMESTAMP,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_origen         => v_id_almacen,
            p_id_cliente                => v_id_cliente,
            p_codigo_tipo_documento_origen => 'ALQUILER',
            p_id_documento_origen       => v_id_alquiler,
            p_glosa                     => 'Salida por cambio de cilindro en alquiler',
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov->>'error';
        END IF;

        -- inv_registrar_movimiento ya deja el balón nuevo en ALQUILADO/v_id_cliente
        -- (mapeo SALIDA_ALQUILER), no hace falta repetirlo aquí.

    END IF;

    UPDATE bal_alquiler_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/alquileres-detalle/bal_devolver_alquiler_detalle.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_devolver_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date, p_id_almacen_destino integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_devolver_alquiler_detalle(p_id integer, p_fecha_devolucion date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_finalizado INTEGER;
    v_mov_result JSON;
    v_pendientes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ad.id_alquiler,
        ad.id_balon,
        ad.fecha_devolucion,
        al.id_cliente,
        al.id_almacen
    INTO
        v_id_alquiler,
        v_id_balon,
        v_fecha_devolucion,
        v_id_cliente,
        v_id_almacen
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id
      AND ad.estado = 1;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de alquiler no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    IF v_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el almacén de destino de la devolución',
            'registro', NULL
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El almacén de destino no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    UPDATE bal_alquiler_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    v_mov_result := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
        p_fecha                     => LOCALTIMESTAMP,
        p_id_balon                  => v_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_destino        => v_id_almacen_destino,
        p_id_cliente                => v_id_cliente,
        p_codigo_tipo_documento_origen => 'ALQUILER',
        p_id_documento_origen       => v_id_alquiler,
        p_glosa                     => 'Entrada por devolución de alquiler',
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );

    IF v_mov_result->>'error' IS NOT NULL THEN
        RAISE EXCEPTION '%', v_mov_result->>'error';
    END IF;

    -- Custodia: vuelve a almacén. Contenido: se asume vacío (envase usado que regresa).
    UPDATE bal_balon
    SET
        id_cliente_ubicacion = NULL,
        id_almacen = v_id_almacen_destino,
        id_estado_balon = v_id_estado_en_almacen,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = v_id_balon
      AND estado = 1;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_alquiler_detalle
    WHERE id_alquiler = v_id_alquiler
      AND estado = 1
      AND fecha_devolucion IS NULL;

    -- No cerrar si aún falta devolver el regulador/accesorio
    IF v_pendientes = 0
       AND NOT EXISTS (
           SELECT 1
           FROM bal_alquiler a
           WHERE a.id = v_id_alquiler
             AND a.estado = 1
             AND COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
             AND a.fecha_devolucion_regulador IS NULL
       )
    THEN
        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, COALESCE(p_fecha_devolucion, CURRENT_DATE)),
            id_estado = COALESCE(v_id_estado_finalizado, id_estado),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_alquiler
          AND estado = 1;
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/alquileres-detalle/bal_eliminar_alquiler_detalle.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_eliminar_alquiler_detalle(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_alquiler_detalle(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_id_alquiler INTEGER;
    v_id_cliente INTEGER;
    v_fecha_devolucion DATE;
    v_id_estado_en_almacen INTEGER;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        ad.id_balon,
        ad.fecha_devolucion,
        ad.id_alquiler,
        al.id_almacen,
        al.id_cliente
    INTO
        v_id_balon,
        v_fecha_devolucion,
        v_id_alquiler,
        v_id_almacen,
        v_id_cliente
    FROM bal_alquiler_detalle ad
    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
    WHERE ad.id = p_id
      AND ad.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    UPDATE bal_alquiler_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si el cilindro seguía pendiente de devolución, liberarlo a almacén.
    IF v_id_balon IS NOT NULL AND v_fecha_devolucion IS NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            v_mov := inv_registrar_movimiento(
                p_naturaleza                => 'BALON',
                p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
                p_fecha                     => LOCALTIMESTAMP,
                p_id_balon                  => v_id_balon,
                p_cantidad                  => 1,
                p_id_almacen_destino        => v_id_almacen,
                p_id_cliente                => v_id_cliente,
                p_codigo_tipo_documento_origen => 'ALQUILER',
                p_id_documento_origen       => v_id_alquiler,
                p_glosa                     => 'Entrada por quitar cilindro del alquiler',
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;

            UPDATE bal_balon
            SET
                id_cliente_ubicacion = NULL,
                id_almacen = COALESCE(v_id_almacen, id_almacen),
                id_estado_balon = v_id_estado_en_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1;
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/balones/bal_asignar_origenes_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_asignar_origenes_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
DROP FUNCTION IF EXISTS bal_asignar_origenes_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric, p_id_almacen integer, p_id_balon_preferido integer);

CREATE OR REPLACE FUNCTION bal_asignar_origenes_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric, p_id_almacen integer DEFAULT NULL::integer, p_id_balon_preferido integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_requerida NUMERIC;
    v_total_disponible NUMERIC := 0;
    v_origenes JSONB := '[]'::JSONB;
    v_id_balon_origen INTEGER;
    v_codigo_balon_origen VARCHAR;
    v_unidad_gas VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto_gas IS NULL THEN
        RETURN json_build_object('error', 'El producto gas es obligatorio', 'origenes', '[]'::JSON);
    END IF;

    v_requerida := COALESCE(p_capacidad_requerida, 0);
    IF v_requerida <= 0 THEN
        RETURN json_build_object('error', 'La capacidad requerida debe ser mayor a cero', 'origenes', '[]'::JSON);
    END IF;

    IF p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El almacén es obligatorio para validar el stock de gas', 'origenes', '[]'::JSON);
    END IF;

    v_total_disponible := inv_stock_producto(p_id_producto_gas, p_id_almacen);

    -- La unidad la define el producto (decisión 3 del plan), no se asume m³.
    SELECT UPPER(TRIM(COALESCE(um.nombre, '')))
    INTO v_unidad_gas
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = p_id_producto_gas;

    IF v_total_disponible < v_requerida THEN
        RETURN json_build_object(
            'error',
            format(
                'Stock insuficiente de gas en almacén (disponible: %s %s, requerido: %s %s)',
                gen_formato_cantidad(v_total_disponible),
                COALESCE(NULLIF(v_unidad_gas, ''), 'UND'),
                gen_formato_cantidad(v_requerida),
                COALESCE(NULLIF(v_unidad_gas, ''), 'UND')
            ),
            'origenes', '[]'::JSON,
            'total_disponible', v_total_disponible,
            'requerido', v_requerida
        );
    END IF;

    -- Balón de referencia: el preferido si es válido, si no el EMPRESA/DISPONIBLE más
    -- antiguo del mismo gas (solo para trazabilidad, no reparte m³ real por cilindro).
    IF p_id_balon_preferido IS NOT NULL THEN
        SELECT b.id, b.codigo_balon INTO v_id_balon_origen, v_codigo_balon_origen
        FROM bal_balon b
        WHERE b.id = p_id_balon_preferido AND b.estado = 1;
    END IF;

    IF v_id_balon_origen IS NULL THEN
        SELECT b.id, b.codigo_balon INTO v_id_balon_origen, v_codigo_balon_origen
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.estado = 1
          AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
          AND COALESCE(eb.nombre, '') = 'DISPONIBLE'
          AND b.id_producto_gas = p_id_producto_gas
          AND b.id_almacen = p_id_almacen
        ORDER BY b.fecha_creacion ASC NULLS LAST, b.id ASC
        LIMIT 1;
    END IF;

    IF v_id_balon_origen IS NOT NULL THEN
        v_origenes := jsonb_build_array(
            jsonb_build_object(
                'id_balon', v_id_balon_origen,
                'codigo_balon', v_codigo_balon_origen,
                'cantidad', v_requerida,
                'orden', 1
            )
        );
    END IF;

    RETURN json_build_object(
        'origenes', v_origenes,
        'requerido', v_requerida,
        'total_disponible', v_total_disponible,
        'id_balon_origen_principal', v_id_balon_origen,
        'etiqueta', CASE
            WHEN v_codigo_balon_origen IS NOT NULL THEN
                v_codigo_balon_origen || ' (' || gen_formato_cantidad(v_requerida)
                || ' ' || COALESCE(NULLIF(v_unidad_gas, ''), 'UND') || ')'
            ELSE NULL
        END
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/balones/bal_listar_balones_origen_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_balones_origen_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.947Z
DROP FUNCTION IF EXISTS bal_listar_balones_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric, p_id_almacen integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION bal_listar_balones_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric DEFAULT NULL::numeric, p_id_almacen integer DEFAULT NULL::integer, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto_gas IS NULL THEN
        RETURN json_build_object(
            'error', 'El producto gas es obligatorio',
            'registros', '[]'::JSON,
            'total', 0
        );
    END IF;

    WITH candidatos AS (
        SELECT
            b.id,
            b.codigo_balon,
            b.numero_serie,
            b.id_almacen,
            a.nombre AS nombre_almacen,
            b.id_producto_gas,
            p.nombre AS nombre_producto,
            b.id_tipo_balon,
            tb.nombre AS nombre_tipo_balon,
            tb.capacidad AS capacidad_tipo,
            b.fecha_creacion
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_almacen a ON a.id = b.id_almacen
        LEFT JOIN pro_producto p ON p.id = b.id_producto_gas
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.estado = 1
          AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
          AND COALESCE(eb.nombre, '') = 'DISPONIBLE'
          AND b.id_producto_gas = p_id_producto_gas
          AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
        -- Sin filtro por capacidad: el gas se controla en el stock global del almacén
        -- (pro_stock), no por cilindro. El balón origen es solo trazabilidad.
    )
    SELECT
        (SELECT COUNT(*) FROM candidatos),
        (
            SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
            FROM (
                SELECT
                    id,
                    codigo_balon,
                    numero_serie,
                    id_almacen,
                    nombre_almacen,
                    id_producto_gas,
                    nombre_producto,
                    id_tipo_balon,
                    nombre_tipo_balon,
                    capacidad_tipo,
                    capacidad_disponible,
                    fecha_creacion
                FROM candidatos
                ORDER BY fecha_creacion ASC NULLS LAST, id ASC
                LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                OFFSET GREATEST(COALESCE(p_offset, 0), 0)
            ) t
        )
    INTO v_total, v_registros;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/balones/bal_listar_balones.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_balones
-- Overloads: 3
-- Generated: 2026-09-03T16:50:38.946Z
DROP FUNCTION IF EXISTS bal_listar_balones(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_balon integer, p_id_almacen integer, p_id_estado_balon integer, p_id_cliente_ubicacion integer, p_id_marca_cilindro integer, p_ph_vencida boolean, p_ph_por_vencer_dias integer, p_id_cliente_relacionado integer, p_solo_bajas boolean, p_familia_gas character varying, p_id_propietario integer, p_id_producto_gas integer, p_solo_llenos_fuera boolean, p_id_planta integer, p_tipo_valvula character varying);

CREATE OR REPLACE FUNCTION bal_listar_balones(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_marca_cilindro integer DEFAULT NULL::integer, p_ph_vencida boolean DEFAULT NULL::boolean, p_ph_por_vencer_dias integer DEFAULT NULL::integer, p_id_cliente_relacionado integer DEFAULT NULL::integer, p_solo_bajas boolean DEFAULT NULL::boolean, p_familia_gas character varying DEFAULT NULL::character varying, p_id_propietario integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_solo_llenos_fuera boolean DEFAULT NULL::boolean, p_id_planta integer DEFAULT NULL::integer, p_tipo_valvula character varying DEFAULT NULL::character varying)
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
            'en_almacen', COUNT(*) FILTER (WHERE eb.nombre = 'DISPONIBLE'),
            'llenos', COUNT(*) FILTER (WHERE eb.nombre = 'DISPONIBLE'),
            'vacios', COUNT(*) FILTER (WHERE eb.nombre = 'DISPONIBLE')
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
                OR EXISTS (SELECT 1 FROM bal_alquiler_detalle ad WHERE ad.id_balon = b.id AND ad.estado = 1)
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
              OR gen_texto_coincide(COALESCE(cu.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cu.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(cp.razon_social, ''), p_busqueda)
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

DROP FUNCTION IF EXISTS bal_listar_balones(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_balon integer, p_id_almacen integer, p_id_estado_balon integer, p_id_cliente_ubicacion integer, p_id_marca_cilindro integer, p_ph_vencida boolean, p_ph_por_vencer_dias integer, p_id_cliente_relacionado integer);

CREATE OR REPLACE FUNCTION bal_listar_balones(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_marca_cilindro integer DEFAULT NULL::integer, p_ph_vencida boolean DEFAULT NULL::boolean, p_ph_por_vencer_dias integer DEFAULT NULL::integer, p_id_cliente_relacionado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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

DROP FUNCTION IF EXISTS bal_listar_balones(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_balon integer, p_id_almacen integer, p_id_estado_balon integer, p_id_cliente_ubicacion integer, p_id_marca_cilindro integer, p_ph_vencida boolean, p_ph_por_vencer_dias integer);

CREATE OR REPLACE FUNCTION bal_listar_balones(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_estado_balon integer DEFAULT NULL::integer, p_id_cliente_ubicacion integer DEFAULT NULL::integer, p_id_marca_cilindro integer DEFAULT NULL::integer, p_ph_vencida boolean DEFAULT NULL::boolean, p_ph_por_vencer_dias integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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


-- ============================================================
-- database_sql/funciones/balones/bal_restaurar_balon.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_restaurar_balon
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.950Z
DROP FUNCTION IF EXISTS bal_restaurar_balon(p_id_balon integer, p_id_usuario_auditoria integer, p_observacion character varying, p_id_almacen integer);

CREATE OR REPLACE FUNCTION bal_restaurar_balon(p_id_balon integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_almacen integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_actual VARCHAR;
    v_id_estado_actual INTEGER;
    v_id_estado_almacen INTEGER;
    v_id_baja INTEGER;
    v_id_motivo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT b.id_estado_balon, eb.nombre
    INTO v_id_estado_actual, v_estado_actual
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF v_estado_actual IS NULL OR v_estado_actual NOT IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error',
            'Solo se pueden reactivar cilindros dados de baja o reportados como robo',
            'registro', NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_baja_balon
        WHERE id_balon = p_id_balon AND estado = 1 AND estado_aprobacion = 'PENDIENTE'
    ) THEN
        RETURN json_build_object(
            'error',
            'Hay una solicitud de baja pendiente. Resuélvala antes de reactivar.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1;

    IF v_id_estado_almacen IS NULL THEN
        RETURN json_build_object('error', 'No está configurado el estado DISPONIBLE', 'registro', NULL);
    END IF;

    SELECT bb.id, bb.id_motivo_baja
    INTO v_id_baja, v_id_motivo
    FROM bal_baja_balon bb
    WHERE bb.id_balon = p_id_balon
      AND bb.estado = 1
      AND bb.estado_aprobacion = 'APROBADA'
    ORDER BY bb.fecha_autorizacion DESC NULLS LAST, bb.id DESC
    LIMIT 1;

    IF v_id_baja IS NOT NULL THEN
        UPDATE bal_baja_balon
        SET
            estado_aprobacion = 'REACTIVADA',
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_baja;
    END IF;

    UPDATE bal_balon
    SET
        id_estado_balon = v_id_estado_almacen,
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    PERFORM bal_registrar_estado_historial(
        p_id_balon,
        'REACTIVACION',
        v_id_baja,
        v_id_motivo,
        v_id_estado_actual,
        v_id_estado_almacen,
        COALESCE(NULLIF(TRIM(p_observacion), ''), 'Cilindro reactivado / reintegrado al parque'),
        p_id_usuario_auditoria,
        NOW()
    );

    RETURN bal_obtener_balon(p_id_balon);
END;
$function$;


-- ============================================================
-- database_sql/funciones/balones/bal_sugerir_balon_origen_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_sugerir_balon_origen_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.950Z
DROP FUNCTION IF EXISTS bal_sugerir_balon_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric, p_id_almacen integer);

CREATE OR REPLACE FUNCTION bal_sugerir_balon_origen_recarga(p_id_producto_gas integer, p_capacidad_requerida numeric DEFAULT NULL::numeric, p_id_almacen integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_asignacion JSON;
    v_principal JSON;
BEGIN
    IF COALESCE(p_capacidad_requerida, 0) > 0 THEN
        v_asignacion := bal_asignar_origenes_recarga(
            p_id_producto_gas,
            p_capacidad_requerida,
            p_id_almacen,
            NULL
        );

        IF v_asignacion->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_asignacion->>'error', 'registro', NULL);
        END IF;

        v_principal := (v_asignacion->'origenes')->0;
        IF v_principal IS NULL OR v_principal::TEXT = 'null' THEN
            RETURN json_build_object(
                'error',
                'No hay balón empresa LLENO del mismo gas con stock en almacén',
                'registro',
                NULL
            );
        END IF;

        RETURN json_build_object(
            'registro', json_build_object(
                'id', (v_principal->>'id_balon')::INTEGER,
                'codigo_balon', v_principal->>'codigo_balon',
                'capacidad_disponible', (v_principal->>'capacidad_disponible')::NUMERIC,
                'capacidad_tipo', (v_principal->>'capacidad_tipo')::NUMERIC,
                'nombre_almacen', v_principal->>'nombre_almacen',
                'asignacion_etiqueta', v_asignacion->>'etiqueta',
                'origenes', v_asignacion->'origenes'
            )
        );
    END IF;

    -- Sin capacidad: primer balón con stock (FIFO)
    RETURN (
        SELECT json_build_object(
            'registro', row_to_json(t)
        )
        FROM (
            SELECT
                b.id,
                b.codigo_balon,
                tb.capacidad AS capacidad_tipo,
                a.nombre AS nombre_almacen
            FROM bal_balon b
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_almacen a ON a.id = b.id_almacen
            LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.estado = 1
              AND COALESCE(prop.nombre, '') IN ('EMPRESA', 'PROPIA')
              AND COALESCE(eb.nombre, '') = 'DISPONIBLE'
              AND b.id_producto_gas = p_id_producto_gas
              AND (p_id_almacen IS NULL OR b.id_almacen = p_id_almacen)
            -- Sin filtro por capacidad: el balón origen es solo trazabilidad; la
            -- disponibilidad real la valida bal_asignar_origenes_recarga contra pro_stock.
            ORDER BY b.fecha_creacion ASC NULLS LAST, b.id ASC
            LIMIT 1
        ) t
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_revertir_cilindros_recarga_compra.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_revertir_cilindros_recarga_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS com_revertir_cilindros_recarga_compra(p_id_recarga_planta integer, p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION com_revertir_cilindros_recarga_compra(p_id_recarga_planta integer, p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_det RECORD;
    v_estado VARCHAR;
    v_id_recarga_ext INTEGER;
    v_id_tipo_doc_compra INTEGER;
    v_id_tipo_doc_recarga INTEGER;
BEGIN
    SELECT lo.id INTO v_id_recarga_ext
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    FOR v_det IN
        SELECT d.id_balon
        FROM doc_salida_detalle d
        WHERE d.id_doc_salida = p_id_recarga_planta
          AND d.estado = 1
    LOOP
        SELECT eb.nombre INTO v_estado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = v_det.id_balon AND b.estado = 1;

        IF COALESCE(v_estado, '') NOT IN ('DISPONIBLE', 'EN_RECARGA_EXTERNA') THEN
            RAISE EXCEPTION
                'No se puede anular la compra: el cilindro % ya no está en almacén ni en recarga externa (estado %).',
                v_det.id_balon,
                COALESCE(v_estado, 'sin estado');
        END IF;

        IF COALESCE(v_estado, '') = 'DISPONIBLE' AND v_id_recarga_ext IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_recarga_ext,
                id_almacen = NULL,
                id_usuario_modificacion = p_id_usuario,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon AND estado = 1;
        END IF;
    END LOOP;

    -- Entradas de cilindro ya repuntadas a COMPRA: reapuntar solo naturaleza BALON
    -- (no tocar INGRESO de producto; com_anular_compra lo compensa con SALIDA)
    -- para poder revertirlas con inv_revertir_por_documento('RECARGA', orden).
    IF v_id_tipo_doc_compra IS NOT NULL AND v_id_tipo_doc_recarga IS NOT NULL THEN
        UPDATE inv_movimiento m
        SET
            id_documento_origen = p_id_recarga_planta,
            id_tipo_documento_origen = v_id_tipo_doc_recarga,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE m.estado = 1
          AND m.naturaleza = 'BALON'
          AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
          AND m.id_documento_origen = p_id_comprobante
          AND m.id_balon IN (
              SELECT d.id_balon
              FROM doc_salida_detalle d
              WHERE d.id_doc_salida = p_id_recarga_planta
                AND d.estado = 1
          )
          AND m.id_tipo_movimiento IN (
              SELECT lo.id
              FROM gen_lista_opciones lo
              INNER JOIN gen_lista l ON l.id = lo.id_lista
              WHERE l.nombre = 'TipoMovBalon'
                AND lo.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
                AND lo.estado = 1
          );
    END IF;

    -- Revierte entradas aún bajo RECARGA (orden) y las que acabamos de reapuntar.
    PERFORM inv_revertir_por_documento('RECARGA', p_id_recarga_planta, p_id_usuario);

    -- inv_revertir deja cilindros en DISPONIBLE; al anular compra deben volver a EN_RECARGA_EXTERNA.
    IF v_id_recarga_ext IS NOT NULL THEN
        UPDATE bal_balon b
        SET
            id_estado_balon = v_id_recarga_ext,
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.estado = 1
          AND b.id IN (
              SELECT d.id_balon
              FROM doc_salida_detalle d
              WHERE d.id_doc_salida = p_id_recarga_planta
                AND d.estado = 1
          );
    END IF;
END;
$function$;


-- ============================================================
-- database_sql/funciones/comprobantes/ven_aplicar_efectos_pos.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_aplicar_efectos_pos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
--
-- Actualizada por database_sql/migraciones/20260905_pos_garantia_cuenta_y_catalogos.sql:
-- la garantia (de prestamo y de alquiler) se crea con su cuenta bancaria y su
-- numero de operacion, que antes nunca llegaban a ven_crear_garantia.
DROP FUNCTION IF EXISTS ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_item JSON;
    v_arr JSON;
    v_result JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_id_baja INTEGER;
    v_garantia JSON;
    v_periodo JSON;
    v_id_producto INTEGER;
    v_id_prestamo_detalle INTEGER;
    v_arr_detalles JSONB := '[]'::JSONB;
    v_garantia_balon JSON;
    v_id_balon_garantia INTEGER;
    v_id_propietario_garantia INTEGER;
    v_vigencia_ph_garantia INTEGER;
    v_fecha_ultima_ph_garantia DATE;
    v_fecha_proxima_ph_garantia DATE;
    v_observacion_balon_garantia VARCHAR;
    v_mov_garantia JSON;
    v_id_estado_balon_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL OR p_efectos IS NULL OR p_efectos::TEXT IN ('null', '{}', '[]') THEN
        RETURN;
    END IF;

    SELECT id_cliente, serie, numero
    INTO v_id_cliente, v_serie, v_numero
    FROM ven_comprobante
    WHERE id = p_id_comprobante AND estado = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante no existe o está inactivo';
    END IF;

    -- Recargas mostrador
    v_arr := CASE WHEN json_typeof(p_efectos->'recargas') = 'array' THEN p_efectos->'recargas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_vincular_recarga_cliente_comprobante(
            p_id_comprobante,
            v_id_cliente,
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idProducto', '')::INTEGER,
            NULLIF(v_item->>'capacidad', '')::NUMERIC,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'idBalonOrigen', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Préstamos de cilindro (+ garantía opcional)
    v_arr := CASE WHEN json_typeof(p_efectos->'prestamos') = 'array' THEN p_efectos->'prestamos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        IF NULLIF(v_item->>'idPrestamoRenovar', '') IS NOT NULL THEN
            -- Fase 4 (apunte 1.c.ix): renovación — cierra el préstamo indicado
            -- (canjeando el cilindro si hay uno disponible, o extendiéndolo con
            -- el mismo) y abre uno nuevo encadenado, ligado a ESTA venta. Por
            -- defecto reutiliza la garantía (dinero y/o cilindro) del préstamo
            -- anterior; si mantenerGarantiaPrestamo es false, el bloque de
            -- garantia/garantiaBalon más abajo registra una nueva.
            v_result := bal_renovar_prestamo(
                p_id_prestamo                => (v_item->>'idPrestamoRenovar')::INTEGER,
                p_id_balon_nuevo             => NULLIF(v_item->>'idBalon', '')::INTEGER,
                p_id_usuario                 => p_id_usuario,
                p_id_comprobante_venta_nuevo => p_id_comprobante,
                p_mantener_garantia          => COALESCE((v_item->>'mantenerGarantiaPrestamo')::BOOLEAN, TRUE)
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo := (v_result->'registro'->>'id')::INTEGER;
            IF v_id_prestamo IS NULL THEN
                RAISE EXCEPTION 'No se pudo renovar el préstamo';
            END IF;

            SELECT pd.id INTO v_id_prestamo_detalle
            FROM bal_prestamo_detalle pd
            WHERE pd.id_prestamo = v_id_prestamo
              AND pd.rol = 'ENTREGADO'
              AND pd.estado = 1
            ORDER BY pd.id DESC
            LIMIT 1;
        ELSE
            v_result := bal_crear_prestamo(
                NULLIF(v_item->>'idTipoPrestamo', '')::INTEGER,
                NULL,
                v_id_cliente,
                NULL,
                NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                NULLIF(v_item->>'fechaSalida', '')::DATE,
                NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
                NULL,
                NULLIF(TRIM(COALESCE(v_item->>'titulo', '')), ''),
                NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
                NULLIF(v_item->>'idEstado', '')::INTEGER,
                p_id_comprobante,
                NULL,
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo := (v_result->'registro'->>'id')::INTEGER;
            IF v_id_prestamo IS NULL THEN
                RAISE EXCEPTION 'No se pudo crear el préstamo POS';
            END IF;

            v_result := bal_crear_prestamo_detalle(
                v_id_prestamo,
                NULLIF(v_item->>'idBalon', '')::INTEGER,
                NULLIF(v_item->>'idProducto', '')::INTEGER,
                NULL,
                NULLIF(COALESCE(v_item->>'fechaEntregado', v_item->>'fechaSalida'), '')::DATE,
                NULLIF(COALESCE(v_item->>'fechaPrestamo', v_item->>'fechaSalida'), '')::DATE,
                30,
                NULLIF(COALESCE(v_item->>'fechaVencimiento', v_item->>'fechaRetornoPactada'), '')::DATE,
                NULL, NULL, NULL, NULL, NULL,
                NULLIF(v_item->>'idEstadoDetalle', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_item->>'observacionDetalle', '')), ''),
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo_detalle := (v_result->'registro'->>'id')::INTEGER;
        END IF;

        -- Auto-recojo: el préstamo ya tiene fecha de retorno pactada, por lo que se
        -- programa el recojo sin pasar por la pantalla de programación manual.
        -- El cilindro se queda PRESTADO_CLIENTE hasta que el chófer inicia la ruta.
        IF v_id_prestamo_detalle IS NOT NULL
           AND NULLIF(v_item->>'idBalon', '') IS NOT NULL
           AND NULLIF(v_item->>'fechaRetornoPactada', '') IS NOT NULL
        THEN
            v_arr_detalles := jsonb_build_array(
                jsonb_build_object(
                    'idPrestamoDetalle', v_id_prestamo_detalle,
                    'observacion', 'Recojo automático generado al vender el préstamo'
                )
            );

            v_result := bal_crear_recojo(
                v_id_cliente,
                v_id_prestamo,
                NULL,
                NULL,
                NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
                NULL::TIME,
                NULL::INTEGER,
                'Recojo automático generado al vender el préstamo',
                v_arr_detalles::JSON,
                p_id_usuario,
                FALSE
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                v_id_prestamo,
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                NULL,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER,
                NULLIF(v_garantia->>'idCuentaBancaria', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_garantia->>'numeroOperacion', '')), '')
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        -- Fase 4 (apunte 1.c.viii) — préstamo con garantía de balón: el cliente deja
        -- su propio cilindro como colateral y se lleva uno de Sarita recargado.
        -- Distinto de v_garantia (dinero): aquí se registra un balón físico nuevo,
        -- de propietario CLIENTE (el envase sigue siendo suyo y se le devuelve),
        -- con su propia fila de detalle (rol GARANTIA) enlazada al mismo préstamo
        -- que ya tiene el detalle ENTREGADO creado arriba. Es esa fila —y no el
        -- propietario— la que dice que lo tenemos en garantía y de qué préstamo.
        v_garantia_balon := v_item->'garantiaBalon';
        IF json_typeof(v_garantia_balon) = 'object'
           AND NULLIF(v_garantia_balon->>'codigoBalon', '') IS NOT NULL
        THEN
            v_vigencia_ph_garantia := COALESCE(
                NULLIF(v_garantia_balon->>'vigenciaPruebaHidrostaticaAnios', '')::INTEGER, 5
            );
            v_fecha_ultima_ph_garantia := NULLIF(v_garantia_balon->>'fechaUltimaPruebaHidrostatica', '')::DATE;
            v_fecha_proxima_ph_garantia := CASE
                WHEN v_fecha_ultima_ph_garantia IS NOT NULL
                THEN (v_fecha_ultima_ph_garantia + (v_vigencia_ph_garantia || ' years')::INTERVAL)::DATE
                ELSE NULL
            END;

            v_observacion_balon_garantia := NULLIF(TRIM(COALESCE(v_garantia_balon->>'observacion', '')), '');
            IF v_fecha_proxima_ph_garantia IS NOT NULL AND v_fecha_proxima_ph_garantia < CURRENT_DATE THEN
                v_observacion_balon_garantia := TRIM(
                    COALESCE(v_observacion_balon_garantia || ' — ', '')
                    || 'Prueba hidrostática vencida al recibir en garantía ('
                    || TO_CHAR(v_fecha_proxima_ph_garantia, 'DD/MM/YYYY') || ')'
                );
            END IF;

            SELECT lo.id INTO v_id_propietario_garantia
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'CLIENTE' AND lo.estado = 1
            LIMIT 1;

            IF v_id_propietario_garantia IS NULL THEN
                RAISE EXCEPTION 'Falta la opción CLIENTE en el catálogo PropietarioBalon';
            END IF;

            SELECT lo.id INTO v_id_estado_balon_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            v_result := bal_crear_balon(
                p_codigo_balon                          => TRIM(v_garantia_balon->>'codigoBalon'),
                p_fecha_registro                        => CURRENT_DATE,
                p_id_almacen                             => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_propietario                        => v_id_propietario_garantia,
                p_id_cliente_propietario                => v_id_cliente,
                p_id_tipo_balon                         => NULLIF(v_garantia_balon->>'idTipoBalon', '')::INTEGER,
                p_id_producto_gas                       => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_id_estado_balon                       => v_id_estado_balon_almacen,
                p_fecha_ultima_prueba_hidrostatica      => v_fecha_ultima_ph_garantia,
                p_vigencia_prueba_hidrostatica_anios    => v_vigencia_ph_garantia,
                p_fecha_proxima_prueba_hidrostatica     => v_fecha_proxima_ph_garantia,
                p_observacion                            => v_observacion_balon_garantia,
                p_numero_serie                          => NULLIF(v_garantia_balon->>'numeroSerie', ''),
                p_id_usuario_auditoria                  => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_balon_garantia := (v_result->'registro'->>'id')::INTEGER;

            IF v_id_balon_garantia IS NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el cilindro de garantía';
            END IF;

            v_mov_garantia := inv_registrar_movimiento(
                p_naturaleza                    => 'BALON',
                p_codigo_tipo_movimiento        => 'ENTRADA_GARANTIA',
                p_id_balon                      => v_id_balon_garantia,
                p_cantidad                      => 1,
                p_id_almacen_destino            => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_cliente                    => v_id_cliente,
                p_codigo_tipo_documento_origen  => 'PRESTAMO',
                p_id_documento_origen           => v_id_prestamo,
                p_glosa                         => 'Cilindro dejado en garantía por el cliente',
                p_id_usuario_auditoria          => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_mov_garantia);

            v_result := bal_crear_prestamo_detalle(
                p_id_prestamo            => v_id_prestamo,
                p_id_balon               => v_id_balon_garantia,
                p_id_producto            => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_observacion            => 'Cilindro recibido en garantía',
                p_id_usuario_auditoria   => p_id_usuario,
                p_rol                    => 'GARANTIA'
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- GRE solo si el usuario lo pidió (opt-in). Sin flag no se emite.
    IF COALESCE(
        NULLIF(p_efectos->>'generarGre', '')::BOOLEAN,
        NULLIF(p_efectos->>'generar_gre', '')::BOOLEAN,
        FALSE
    ) THEN
        PERFORM ven_pos_crear_guia_remision(p_id_comprobante, p_id_usuario);
    END IF;

    -- Alquiler de regulador/accesorio (+ periodo + garantía)
    v_arr := CASE WHEN json_typeof(p_efectos->'alquileres') = 'array' THEN p_efectos->'alquileres' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_alquiler(
            NULL,
            v_id_cliente,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(v_item->>'fechaInicio', '')::DATE,
            NULLIF(v_item->>'fechaFinPactada', '')::DATE,
            NULL,
            COALESCE(NULLIF(v_item->>'tarifaDiaria', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item->>'totalCobrado', '')::NUMERIC, 0),
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_comprobante,
            NULLIF(v_item->>'idProductoRegulador', '')::INTEGER,
            NULLIF(v_item->>'idProductoStock', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_alquiler := (v_result->'registro'->>'id')::INTEGER;
        IF v_id_alquiler IS NULL THEN
            RAISE EXCEPTION 'No se pudo crear el alquiler POS';
        END IF;

        v_periodo := v_item->'periodo';
        IF json_typeof(v_periodo) = 'object' THEN
            v_result := bal_registrar_alquiler_periodo(
                v_id_alquiler,
                NULLIF(v_periodo->>'fechaInicio', '')::DATE,
                NULLIF(v_periodo->>'fechaFin', '')::DATE,
                COALESCE(NULLIF(v_periodo->>'monto', '')::NUMERIC, 0),
                NULLIF(v_periodo->>'idProducto', '')::INTEGER,
                p_id_comprobante,
                NULLIF(TRIM(COALESCE(v_periodo->>'observacion', '')), ''),
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_id_producto := COALESCE(
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULLIF(v_item->>'idProductoRegulador', '')::INTEGER
            );
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                NULL,
                v_id_producto,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                v_id_alquiler,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER,
                NULLIF(v_garantia->>'idCuentaBancaria', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_garantia->>'numeroOperacion', '')), '')
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- Mantenimientos
    v_arr := CASE WHEN json_typeof(p_efectos->'mantenimientos') = 'array' THEN p_efectos->'mantenimientos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_mantenimiento(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'fechaIngreso', '')::DATE,
            NULLIF(v_item->>'idTipoMantenimiento', '')::INTEGER,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
            COALESCE(NULLIF(v_item->>'costo', '')::NUMERIC, 0),
            FALSE,
            NULL,
            NULL,
            p_id_comprobante,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_usuario,
            NULL,
            NULL,
            NULL,
            NULL
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Baja por venta de cilindro
    v_arr := CASE WHEN json_typeof(p_efectos->'bajas') = 'array' THEN p_efectos->'bajas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_dar_baja_balon(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idMotivoBaja', '')::INTEGER,
            p_id_usuario,
            NULL,
            NULL,
            v_id_cliente,
            p_id_comprobante,
            v_serie,
            v_numero,
            NULLIF(v_item->>'montoVenta', '')::NUMERIC,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'fechaBaja', '')::DATE,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_baja := (v_result->'registro'->>'id')::INTEGER;

        IF COALESCE((v_item->>'aprobar')::BOOLEAN, FALSE) AND v_id_baja IS NOT NULL THEN
            v_result := bal_aprobar_baja_balon(
                v_id_baja,
                p_id_usuario,
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;
END;
$function$;


-- ============================================================
-- database_sql/funciones/comprobantes/ven_cerrar_custodia_comprobante.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_cerrar_custodia_comprobante
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
DROP FUNCTION IF EXISTS ven_cerrar_custodia_comprobante(p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_cerrar_custodia_comprobante(p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle RECORD;
    v_recarga RECORD;
    v_alquiler RECORD;
    v_alq_det RECORD;
    v_guia RECORD;
    v_mant RECORD;
    v_result JSON;
    v_id_en_almacen INTEGER;
    v_id_estado_final INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    -- Préstamos: devolver cilindros pendientes y cerrar cabecera
    FOR v_prestamo IN
        SELECT id FROM bal_prestamo
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        FOR v_detalle IN
            SELECT id FROM bal_prestamo_detalle
            WHERE estado = 1 AND id_prestamo = v_prestamo.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_prestamo_detalle(
                v_detalle.id,
                CURRENT_DATE,
                NULL,
                p_id_usuario,
                'VACIO',
                'Devolución automática por anulación/NC del comprobante'
            );
            PERFORM ven_raise_si_error(v_result);
        END LOOP;
    END LOOP;

    -- Recargas mostrador: devolver el gas a pro_stock y soltar el balón (inv_movimiento)
    FOR v_recarga IN
        SELECT id, id_balon
        FROM bal_movimiento_recarga
        WHERE estado = 1 AND id_comprobante = p_id_comprobante
    LOOP
        v_result := inv_revertir_por_documento('RECARGA', v_recarga.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);

        UPDATE bal_movimiento_recarga
        SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
        WHERE id = v_recarga.id AND estado = 1;
    END LOOP;

    -- Alquileres: reingreso de regulador y cilindros de detalle
    FOR v_alquiler IN
        SELECT id FROM bal_alquiler
        WHERE estado = 1 AND id_comprobante_venta = p_id_comprobante
    LOOP
        v_result := bal_devolver_regulador_alquiler(
            v_alquiler.id,
            CURRENT_DATE,
            'BUENO',
            'Devolución automática por anulación/NC del comprobante',
            NULL,
            p_id_usuario
        );
        IF v_result->>'error' IS NOT NULL
           AND v_result->>'error' NOT ILIKE '%no tiene regulador%'
        THEN
            PERFORM ven_raise_si_error(v_result);
        END IF;

        FOR v_alq_det IN
            SELECT id FROM bal_alquiler_detalle
            WHERE estado = 1 AND id_alquiler = v_alquiler.id AND fecha_devolucion IS NULL
        LOOP
            v_result := bal_devolver_alquiler_detalle(v_alq_det.id, CURRENT_DATE, NULL, p_id_usuario);
            PERFORM ven_raise_si_error(v_result);
        END LOOP;

        SELECT lo.id INTO v_id_estado_final
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_alquiler
        SET
            fecha_fin_real = COALESCE(fecha_fin_real, CURRENT_DATE),
            id_estado = COALESCE(v_id_estado_final, id_estado),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_alquiler.id AND estado = 1;
    END LOOP;

    -- GRE PENDIENTE que referencia este CPE
    FOR v_guia IN
        SELECT DISTINCT g.id
        FROM doc_salida g
        INNER JOIN doc_salida_referencia r ON r.id_doc_salida = g.id AND r.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        LEFT JOIN gen_lista_opciones es ON es.id = g.id_estado_sunat
        WHERE g.estado = 1
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
          AND COALESCE(UPPER(es.nombre), 'PENDIENTE') <> 'ACEPTADO'
    LOOP
        v_result := gre_eliminar_guia_remision(v_guia.id, p_id_usuario);
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Mantenimiento no finalizado ligado al CPE
    FOR v_mant IN
        SELECT m.id, m.id_balon, em.nombre AS nombre_estado
        FROM bal_mantenimiento m
        LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
        WHERE m.estado = 1 AND m.id_comprobante_venta = p_id_comprobante
    LOOP
        IF UPPER(COALESCE(v_mant.nombre_estado, '')) = 'FINALIZADO' THEN
            CONTINUE;
        END IF;

        UPDATE bal_mantenimiento
        SET
            estado = 0,
            id_comprobante_venta = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_mant.id AND estado = 1;

        SELECT lo.id INTO v_id_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon b
        SET
            id_estado_balon = COALESCE(v_id_en_almacen, b.id_estado_balon),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.id = v_mant.id_balon
          AND b.estado = 1
          AND EXISTS (
              SELECT 1 FROM gen_lista_opciones eb
              WHERE eb.id = b.id_estado_balon
                AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
          );
    END LOOP;

    -- Garantía sin reembolsos: se da de baja el cobro documental (el efectivo iba en el CPE)
    UPDATE ven_garantia_movimiento gm
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE gm.estado = 1
      AND gm.id_comprobante = p_id_comprobante
      AND NOT EXISTS (
          SELECT 1
          FROM ven_garantia_movimiento d
          INNER JOIN gen_lista_opciones td ON td.id = d.id_tipo_movimiento
          WHERE d.id_garantia = gm.id_garantia
            AND d.estado = 1
            AND UPPER(td.nombre) = 'DEVOLUCION'
      );

    UPDATE ven_garantia g
    SET estado = 0, id_usuario_modificacion = p_id_usuario, fecha_modificacion = NOW()
    WHERE g.estado = 1
      AND COALESCE(g.monto_devuelto, 0) = 0
      AND NOT EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm
          WHERE gm.id_garantia = g.id AND gm.estado = 1
      )
      AND EXISTS (
          SELECT 1 FROM ven_garantia_movimiento gm0
          WHERE gm0.id_garantia = g.id AND gm0.id_comprobante = p_id_comprobante
      );
END;
$function$;


-- ============================================================
-- database_sql/funciones/dashboard/balones/dash_balones_en_almacen.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_balones_en_almacen
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS dash_balones_en_almacen(p_id_cliente integer);

CREATE OR REPLACE FUNCTION dash_balones_en_almacen(p_id_cliente integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_id_estado INT;
  v_result JSON;
BEGIN
  SET TIME ZONE 'America/Lima';

  SELECT glo.id INTO v_id_estado
  FROM gen_lista_opciones glo
  JOIN gen_lista gl ON gl.id = glo.id_lista
  WHERE gl.nombre = 'EstadoBalon' AND glo.nombre = 'DISPONIBLE'
  LIMIT 1;

  SELECT json_build_object(
    'cantidad', COUNT(*),
    'detalle', COALESCE(json_agg(
      json_build_object(
        'idBalon', b.id,
        'codigoBalon', b.codigo_balon,
        'tipoBalon', tb.nombre,
        'idAlmacen', b.id_almacen,
        'almacen', a.nombre
      )
    ), '[]'::json)
  )
  INTO v_result
  FROM bal_balon b
  LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
  LEFT JOIN gen_almacen a ON a.id = b.id_almacen
  WHERE b.id_estado_balon = v_id_estado
    AND b.estado = 1
    AND (p_id_cliente IS NULL OR b.id_cliente_ubicacion = p_id_cliente);

  RETURN v_result;
END;
$function$;


-- ============================================================
-- database_sql/funciones/inventario-movimientos/inv_eliminar_movimiento.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_eliminar_movimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS inv_eliminar_movimiento(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION inv_eliminar_movimiento(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov inv_movimiento%ROWTYPE;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_estado_en_almacen INTEGER;
    v_id_almacen_stock INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_mov FROM inv_movimiento WHERE id = p_id AND estado = 1 FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_mov.id_documento_origen IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede anular un movimiento vinculado a un documento; anula el documento origen'
        );
    END IF;

    SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
    v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
    IF v_es_traslado THEN
        v_es_salida := TRUE;
    ELSIF v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL THEN
        v_es_salida := v_mov.stock_nuevo < v_mov.stock_anterior;
    ELSE
        v_es_salida := COALESCE(inv_signo_tipo_movimiento(v_mov.id_tipo_movimiento), 1) < 0;
    END IF;

    IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
        -- PRODUCTO siempre mueve el almacén origen. BALON+gas puede haber movido el destino
        -- (p.ej. ENTRADA_LLENADO), según la misma resolución que usó inv_registrar_movimiento.
        IF v_mov.naturaleza = 'PRODUCTO' THEN
            v_id_almacen_stock := v_mov.id_almacen_origen;
        ELSE
            v_id_almacen_stock := COALESCE(
                CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                v_mov.id_almacen_origen,
                v_mov.id_almacen_destino
            );
        END IF;

        SELECT id, stock INTO v_id_stock, v_stock_actual
        FROM pro_stock
        WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el registro de stock para revertir el movimiento');
        END IF;

        v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
        IF v_stock_revertido < 0 THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el movimiento porque revertiría un stock negativo');
        END IF;

        UPDATE pro_stock
        SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_id_stock;

        IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el stock de destino para revertir el traslado');
            END IF;

            v_stock_revertido := v_stock_actual - v_mov.cantidad;
            IF v_stock_revertido < 0 THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el traslado porque el destino ya no tiene esa cantidad');
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;
        END IF;
    END IF;

    IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_balon
        SET
            id_estado_balon = COALESCE(v_mov.id_estado_balon_anterior, v_id_estado_en_almacen, id_estado_balon),
            id_cliente_ubicacion = CASE
                WHEN v_mov.id_estado_balon_anterior IS NOT NULL THEN v_mov.id_cliente_ubicacion_anterior
                ELSE NULL
            END,
            id_almacen = COALESCE(
                v_mov.id_almacen_anterior,
                v_mov.id_almacen_origen,
                v_mov.id_almacen_destino,
                id_almacen
            ),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_mov.id_balon AND estado = 1;
    END IF;

    UPDATE inv_movimiento
    SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/inventario-movimientos/inv_registrar_movimiento.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_registrar_movimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone, p_id_producto integer, p_id_balon integer, p_cantidad numeric, p_id_almacen_origen integer, p_id_almacen_destino integer, p_id_cliente integer, p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_glosa character varying, p_id_usuario_auditoria integer, p_id_movimiento_padre integer, p_sentido_ajuste character varying, p_forzar boolean, p_id_documento_detalle integer);

CREATE OR REPLACE FUNCTION inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone DEFAULT now(), p_id_producto integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_cantidad numeric DEFAULT 0, p_id_almacen_origen integer DEFAULT NULL::integer, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_codigo_tipo_documento_origen character varying DEFAULT NULL::character varying, p_id_documento_origen integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_movimiento_padre integer DEFAULT NULL::integer, p_sentido_ajuste character varying DEFAULT NULL::character varying, p_forzar boolean DEFAULT false, p_id_documento_detalle integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_naturaleza VARCHAR;
    v_id_tipo_mov INTEGER;
    v_nombre_tipo_mov VARCHAR;
    v_id_tipo_doc INTEGER;
    v_id_existente INTEGER;
    v_cantidad NUMERIC(12,4);
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_signo INTEGER;
    v_id INTEGER;
    -- rama PRODUCTO
    v_afecta_stock BOOLEAN;
    v_id_unidad_medida INTEGER;
    v_id_stock INTEGER;
    v_id_stock_dest INTEGER;
    v_stock_anterior NUMERIC(12,4);
    v_stock_nuevo NUMERIC(12,4);
    v_stock_dest_ant NUMERIC(12,4);
    -- rama BALON
    v_nombre_estado_actual VARCHAR;
    v_codigo_estado_destino VARCHAR;
    v_cliente_destino INTEGER;
    v_limpiar_almacen BOOLEAN;
    v_codigo_contenido VARCHAR;
    v_id_estado_balon INTEGER;
    v_id_almacen_balon INTEGER;
    v_id_estado_anterior INTEGER;
    v_id_cliente_anterior INTEGER;
    v_id_almacen_anterior INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_naturaleza := UPPER(TRIM(COALESCE(p_naturaleza, '')));
    IF v_naturaleza NOT IN ('PRODUCTO', 'BALON') THEN
        RETURN json_build_object('error', 'naturaleza debe ser PRODUCTO o BALON', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'PRODUCTO' AND p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'id_producto es obligatorio para naturaleza PRODUCTO', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'BALON' AND p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'id_balon es obligatorio para naturaleza BALON', 'registro', NULL);
    END IF;

    IF p_codigo_tipo_movimiento IS NULL OR TRIM(p_codigo_tipo_movimiento) = '' THEN
        RETURN json_build_object('error', 'El tipo de movimiento es obligatorio', 'registro', NULL);
    END IF;

    SELECT lo.id, lo.nombre INTO v_id_tipo_mov, v_nombre_tipo_mov
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = UPPER(TRIM(p_codigo_tipo_movimiento))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_mov IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_movimiento))),
            'registro', NULL
        );
    END IF;

    IF p_codigo_tipo_documento_origen IS NOT NULL AND TRIM(p_codigo_tipo_documento_origen) <> '' THEN
        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_documento_origen))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_doc IS NULL THEN
            RETURN json_build_object(
                'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(p_codigo_tipo_documento_origen))),
                'registro', NULL
            );
        END IF;
    END IF;
    IF p_id_documento_origen IS NOT NULL AND v_id_tipo_doc IS NOT NULL AND NOT COALESCE(p_forzar, FALSE) THEN
        SELECT m.id INTO v_id_existente
        FROM inv_movimiento m
        WHERE m.estado = 1
          AND m.naturaleza = v_naturaleza
          AND m.id_tipo_documento_origen = v_id_tipo_doc
          AND m.id_documento_origen = p_id_documento_origen
          AND COALESCE(m.id_documento_detalle, -1) = COALESCE(p_id_documento_detalle, -1)
          AND m.id_tipo_movimiento = v_id_tipo_mov
          AND (v_naturaleza <> 'PRODUCTO' OR m.id_producto = p_id_producto)
          AND (v_naturaleza <> 'BALON' OR m.id_balon = p_id_balon)
        ORDER BY m.id
        LIMIT 1;

        IF v_id_existente IS NOT NULL THEN
            RETURN (inv_obtener_movimiento(v_id_existente)::JSONB || jsonb_build_object('creado', FALSE))::JSON;
        END IF;
    END IF;

    v_cantidad := ABS(COALESCE(p_cantidad, 0));
    v_es_traslado := (v_naturaleza = 'PRODUCTO' AND UPPER(v_nombre_tipo_mov) = 'TRASLADO');
    v_signo := inv_signo_tipo_movimiento(v_id_tipo_mov);

    IF UPPER(v_nombre_tipo_mov) = 'AJUSTE' THEN
        IF UPPER(TRIM(COALESCE(p_sentido_ajuste, ''))) NOT IN ('MAS', 'MENOS') THEN
            RETURN json_build_object('error', 'El ajuste requiere sentido MAS o MENOS', 'registro', NULL);
        END IF;
        v_es_salida := UPPER(TRIM(p_sentido_ajuste)) = 'MENOS';
    ELSIF v_signo IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no tiene signo configurado', v_nombre_tipo_mov),
            'registro', NULL
        );
    ELSE
        v_es_salida := v_signo < 0 OR v_es_traslado;
    END IF;

    IF v_naturaleza = 'PRODUCTO' THEN
        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
            RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF p_id_almacen_origen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_origen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(afecta_stock, FALSE), id_unidad_medida
        INTO v_afecta_stock, v_id_unidad_medida
        FROM pro_producto WHERE id = p_id_producto;

        IF v_es_traslado THEN
            IF p_id_almacen_destino IS NULL THEN
                RETURN json_build_object('error', 'El traslado requiere almacén de destino', 'registro', NULL);
            END IF;
            IF p_id_almacen_destino = p_id_almacen_origen THEN
                RETURN json_build_object('error', 'El almacén de destino debe ser distinto al de origen', 'registro', NULL);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1) THEN
                RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'registro', NULL);
            END IF;
        END IF;

        v_stock_anterior := 0;
        v_stock_nuevo := 0;

        IF v_afecta_stock THEN
            SELECT id, stock INTO v_id_stock, v_stock_anterior
            FROM pro_stock
            WHERE id_almacen = p_id_almacen_origen AND id_producto = p_id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                VALUES (p_id_almacen_origen, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                RETURNING id, stock INTO v_id_stock, v_stock_anterior;
            END IF;

            IF v_es_salida THEN
                v_stock_nuevo := v_stock_anterior - v_cantidad;
            ELSE
                v_stock_nuevo := v_stock_anterior + v_cantidad;
            END IF;

            IF v_stock_nuevo < 0 THEN
                RETURN json_build_object('error', 'Stock insuficiente para registrar la salida', 'registro', NULL);
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;

            IF v_es_traslado THEN
                SELECT id, stock INTO v_id_stock_dest, v_stock_dest_ant
                FROM pro_stock
                WHERE id_almacen = p_id_almacen_destino AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock_dest IS NULL THEN
                    INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                    VALUES (p_id_almacen_destino, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                    RETURNING id, stock INTO v_id_stock_dest, v_stock_dest_ant;
                END IF;

                UPDATE pro_stock
                SET stock = COALESCE(v_stock_dest_ant, 0) + v_cantidad,
                    id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock_dest;
            END IF;
        END IF;

        INSERT INTO inv_movimiento (
            fecha, id_tipo_movimiento, naturaleza, id_producto, cantidad, id_unidad_medida,
            id_almacen_origen, id_almacen_destino, id_cliente,
            id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
            stock_anterior, stock_nuevo, glosa,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'PRODUCTO', p_id_producto, v_cantidad, v_id_unidad_medida,
            p_id_almacen_origen, p_id_almacen_destino, p_id_cliente,
            p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
            CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
            CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
            p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

        RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
    END IF;
    SELECT eb.nombre, b.id_almacen, b.id_estado_balon, b.id_cliente_ubicacion
    INTO v_nombre_estado_actual, v_id_almacen_balon, v_id_estado_anterior, v_id_cliente_anterior
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1
    FOR UPDATE OF b;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF COALESCE(v_nombre_estado_actual, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error', 'No se puede registrar movimiento de un cilindro dado de baja o reportado como robo',
            'registro', NULL
        );
    END IF;

    v_id_almacen_anterior := v_id_almacen_balon;
    v_limpiar_almacen := FALSE;
    v_codigo_contenido := NULL;
    v_cliente_destino := NULL;
    CASE v_nombre_tipo_mov
        WHEN 'SALIDA_PRESTAMO' THEN
            v_codigo_estado_destino := 'PRESTADO_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ALQUILER' THEN
            v_codigo_estado_destino := 'ALQUILADO'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_VENTA' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ENTREGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_MANTENIMIENTO' THEN
            v_codigo_estado_destino := 'EN_MANTENIMIENTO'; v_cliente_destino := p_id_cliente;
        WHEN 'SALIDA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'EN_RECARGA_EXTERNA'; v_limpiar_almacen := TRUE; v_codigo_contenido := 'VACIO';
        WHEN 'ENTRADA_DEVOLUCION', 'ENTRADA_MANTENIMIENTO', 'RETORNO_LIMA' THEN
            v_codigo_estado_destino := 'DISPONIBLE';
        WHEN 'ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'DISPONIBLE'; v_codigo_contenido := 'LLENO';
        WHEN 'RECARGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'TRASLADO_LIMA' THEN
            v_codigo_estado_destino := 'EN_RUTA_LIMA'; v_limpiar_almacen := TRUE;
        ELSE
            v_codigo_estado_destino := NULL;
    END CASE;

    IF v_codigo_estado_destino IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_balon
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = v_codigo_estado_destino AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_balon IS NULL THEN
            RETURN json_build_object('error', format('Estado %s no configurado', v_codigo_estado_destino), 'registro', NULL);
        END IF;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_balon,
            id_cliente_ubicacion = CASE WHEN v_cliente_destino IS NOT NULL THEN v_cliente_destino ELSE NULL END,
            id_almacen = CASE
                WHEN v_limpiar_almacen THEN NULL
                ELSE COALESCE(p_id_almacen_destino, p_id_almacen_origen, id_almacen)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    -- Si el movimiento del balón también mueve gas, se refleja en pro_stock del gas.
    v_stock_anterior := NULL;
    v_stock_nuevo := NULL;
    IF p_id_producto IS NOT NULL AND v_cantidad > 0 THEN
        DECLARE
            v_id_almacen_gas INTEGER;
        BEGIN
            v_id_almacen_gas := COALESCE(
                CASE WHEN v_es_salida THEN p_id_almacen_origen ELSE p_id_almacen_destino END,
                p_id_almacen_origen, p_id_almacen_destino, v_id_almacen_balon
            );

            IF v_id_almacen_gas IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_anterior
                FROM pro_stock
                WHERE id_almacen = v_id_almacen_gas AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NULL THEN
                    INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                    VALUES (v_id_almacen_gas, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                    RETURNING id, stock INTO v_id_stock, v_stock_anterior;
                END IF;

                IF v_es_salida THEN
                    v_stock_nuevo := v_stock_anterior - v_cantidad;
                ELSE
                    v_stock_nuevo := v_stock_anterior + v_cantidad;
                END IF;

                IF v_stock_nuevo < 0 THEN
                    RETURN json_build_object('error', 'Stock de gas insuficiente para registrar la salida', 'registro', NULL);
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
            END IF;
        END;
    END IF;

    SELECT id_unidad_medida INTO v_id_unidad_medida FROM pro_producto WHERE id = p_id_producto;

    INSERT INTO inv_movimiento (
        fecha, id_tipo_movimiento, naturaleza, id_producto, id_balon, cantidad, id_unidad_medida,
        id_almacen_origen, id_almacen_destino, id_cliente,
        id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
        stock_anterior, stock_nuevo, id_estado_balon_snapshot,
        id_estado_balon_anterior, id_cliente_ubicacion_anterior, id_almacen_anterior,
        glosa, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'BALON', p_id_producto, p_id_balon, v_cantidad, v_id_unidad_medida,
        p_id_almacen_origen, p_id_almacen_destino, COALESCE(v_cliente_destino, p_id_cliente),
        p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
        v_stock_anterior, v_stock_nuevo, v_id_estado_balon,
        v_id_estado_anterior, v_id_cliente_anterior, v_id_almacen_anterior,
        p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
END;
$function$;


-- ============================================================
-- database_sql/funciones/inventario-movimientos/inv_revertir_por_documento.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_revertir_por_documento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
DROP FUNCTION IF EXISTS inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer, p_id_documento_detalle integer);

CREATE OR REPLACE FUNCTION inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_documento_detalle integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_mov RECORD;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_almacen_stock INTEGER;
    v_count INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_documento_origen IS NULL THEN
        RETURN json_build_object('revertidos', 0, 'error', 'id_documento_origen es obligatorio');
    END IF;

    SELECT lo.id INTO v_id_tipo_doc
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef'
      AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, '')))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc IS NULL THEN
        RETURN json_build_object(
            'revertidos', 0,
            'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, ''))))
        );
    END IF;

    FOR v_mov IN
        SELECT * FROM inv_movimiento
        WHERE estado = 1
          AND id_tipo_documento_origen = v_id_tipo_doc
          AND id_documento_origen = p_id_documento_origen
          AND (p_id_documento_detalle IS NULL OR id_documento_detalle = p_id_documento_detalle)
        ORDER BY id DESC
        FOR UPDATE
    LOOP
        SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
        v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
        IF v_es_traslado THEN
            v_es_salida := TRUE;
        ELSIF v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL THEN
            v_es_salida := v_mov.stock_nuevo < v_mov.stock_anterior;
        ELSE
            v_es_salida := COALESCE(inv_signo_tipo_movimiento(v_mov.id_tipo_movimiento), 1) < 0;
        END IF;

        -- Revertir stock (producto, o gas cargado por un movimiento de balón).
        IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
            -- PRODUCTO siempre mueve el almacén origen. BALON+gas puede haber movido el destino
            -- (p.ej. ENTRADA_LLENADO), según la misma resolución que usó inv_registrar_movimiento.
            IF v_mov.naturaleza = 'PRODUCTO' THEN
                v_id_almacen_stock := v_mov.id_almacen_origen;
            ELSE
                v_id_almacen_stock := COALESCE(
                    CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                    v_mov.id_almacen_origen,
                    v_mov.id_almacen_destino
                );
            END IF;

            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NOT NULL THEN
                v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
                IF v_stock_revertido >= 0 THEN
                    UPDATE pro_stock
                    SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                    WHERE id = v_id_stock;
                END IF;
            END IF;

            IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_actual
                FROM pro_stock
                WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NOT NULL THEN
                    v_stock_revertido := v_stock_actual - v_mov.cantidad;
                    IF v_stock_revertido >= 0 THEN
                        UPDATE pro_stock
                        SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                        WHERE id = v_id_stock;
                    END IF;
                END IF;
            END IF;
        END IF;

        -- Restaurar custodia previa del balón (no forzar DISPONIBLE a ciegas).
        IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon
            SET
                id_estado_balon = COALESCE(v_mov.id_estado_balon_anterior, v_id_estado_en_almacen, id_estado_balon),
                id_cliente_ubicacion = CASE
                    WHEN v_mov.id_estado_balon_anterior IS NOT NULL THEN v_mov.id_cliente_ubicacion_anterior
                    ELSE NULL
                END,
                id_almacen = COALESCE(
                    v_mov.id_almacen_anterior,
                    v_mov.id_almacen_origen,
                    v_mov.id_almacen_destino,
                    id_almacen
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_mov.id_balon AND estado = 1;
        END IF;

        UPDATE inv_movimiento
        SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_mov.id;

        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object('revertidos', v_count);
END;
$function$;


-- ============================================================
-- database_sql/funciones/mantenimientos/bal_eliminar_mantenimiento.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_eliminar_mantenimiento(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_mantenimiento(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_comprobante_venta INTEGER;
    v_id_comprobante_compra INTEGER;
    v_id_balon INTEGER;
    v_id_almacen INTEGER;
    v_nombre_estado VARCHAR;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        m.id_comprobante_venta,
        m.id_comprobante_compra,
        m.id_balon,
        em.nombre,
        b.id_almacen
    INTO
        v_id_comprobante_venta,
        v_id_comprobante_compra,
        v_id_balon,
        v_nombre_estado,
        v_id_almacen
    FROM bal_mantenimiento m
    LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
    LEFT JOIN bal_balon b ON b.id = m.id_balon AND b.estado = 1
    WHERE m.id = p_id AND m.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_id_comprobante_venta IS NOT NULL OR v_id_comprobante_compra IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene un comprobante vinculado'
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_balon_ph_historial WHERE id_mantenimiento = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el mantenimiento porque tiene historial de P.H. asociado'
        );
    END IF;

    UPDATE bal_mantenimiento
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Si no estaba finalizado, restaurar custodia previa (alquiler / préstamo / almacén).
    IF v_id_balon IS NOT NULL AND UPPER(COALESCE(v_nombre_estado, '')) <> 'FINALIZADO' THEN
        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = v_id_balon
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'ALQUILADO' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon b
            SET
                id_estado_balon = COALESCE(v_id_estado_en_almacen, b.id_estado_balon),
                id_almacen = NULL,
                id_cliente_ubicacion = (
                    SELECT al.id_cliente
                    FROM bal_alquiler_detalle ad
                    INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler
                    WHERE ad.id_balon = v_id_balon
                      AND ad.estado = 1
                      AND ad.fecha_devolucion IS NULL
                    ORDER BY ad.id DESC
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1 FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              );
        ELSIF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = v_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon b
            SET
                id_estado_balon = COALESCE(v_id_estado_en_almacen, b.id_estado_balon),
                id_almacen = NULL,
                id_cliente_ubicacion = (
                    SELECT p2.id_cliente
                    FROM bal_prestamo_detalle pd
                    INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo
                    WHERE pd.id_balon = v_id_balon
                      AND pd.estado = 1
                      AND pd.fecha_devolucion IS NULL
                    ORDER BY pd.id DESC
                    LIMIT 1
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE b.id = v_id_balon
              AND b.estado = 1
              AND EXISTS (
                  SELECT 1 FROM gen_lista_opciones eb
                  WHERE eb.id = b.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
              );
        ELSE
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_en_almacen IS NOT NULL THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_id_estado_en_almacen,
                    id_almacen = COALESCE(id_almacen, v_id_almacen),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_balon
                  AND estado = 1
                  AND EXISTS (
                      SELECT 1
                      FROM gen_lista_opciones eb
                      WHERE eb.id = bal_balon.id_estado_balon
                        AND UPPER(COALESCE(eb.nombre, '')) = 'EN_MANTENIMIENTO'
                  )
                  AND NOT EXISTS (
                      SELECT 1
                      FROM bal_mantenimiento m2
                      LEFT JOIN gen_lista_opciones em2 ON em2.id = m2.id_estado
                      WHERE m2.id_balon = v_id_balon
                        AND m2.id <> p_id
                        AND m2.estado = 1
                        AND UPPER(COALESCE(em2.nombre, '')) <> 'FINALIZADO'
                  );
            END IF;
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/mantenimientos/bal_finalizar_mantenimiento.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_finalizar_mantenimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
DROP FUNCTION IF EXISTS bal_finalizar_mantenimiento(p_id integer, p_fecha_salida date, p_id_almacen_destino integer, p_observacion character varying, p_id_usuario_auditoria integer, p_vigencia_ph_anios integer, p_id_organo_inspector integer, p_organo_inspector_no_aplica boolean, p_numero_certificado_ph character varying);

CREATE OR REPLACE FUNCTION bal_finalizar_mantenimiento(p_id integer, p_fecha_salida date DEFAULT CURRENT_DATE, p_id_almacen_destino integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_vigencia_ph_anios integer DEFAULT NULL::integer, p_id_organo_inspector integer DEFAULT NULL::integer, p_organo_inspector_no_aplica boolean DEFAULT NULL::boolean, p_numero_certificado_ph character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_id_producto INTEGER;
    v_id_alquiler INTEGER;
    v_id_almacen INTEGER;
    v_id_cliente_ubicacion INTEGER;
    v_id_cliente_propietario INTEGER;
    v_id_cliente_comprobante INTEGER;
    v_id_cliente_destino INTEGER;
    v_nombre_propietario VARCHAR;
    v_nombre_estado VARCHAR;
    v_es_servicio_cliente BOOLEAN;
    v_id_almacen_destino INTEGER;
    v_id_estado_finalizado INTEGER;
    v_id_estado_destino INTEGER;
    v_mov_result JSON;
    v_obs_movimiento VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        m.id_balon,
        m.id_producto,
        m.id_alquiler,
        em.nombre,
        COALESCE(m.id_almacen, b.id_almacen),
        b.id_cliente_ubicacion,
        b.id_cliente_propietario,
        UPPER(COALESCE(prop.nombre, '')),
        cv.id_cliente
    INTO
        v_id_balon,
        v_id_producto,
        v_id_alquiler,
        v_nombre_estado,
        v_id_almacen,
        v_id_cliente_ubicacion,
        v_id_cliente_propietario,
        v_nombre_propietario,
        v_id_cliente_comprobante
    FROM bal_mantenimiento m
    LEFT JOIN bal_balon b ON b.id = m.id_balon AND b.estado = 1
    LEFT JOIN gen_lista_opciones em ON em.id = m.id_estado
    LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
    LEFT JOIN ven_comprobante cv ON cv.id = m.id_comprobante_venta AND cv.estado = 1
    WHERE m.id = p_id
      AND m.estado = 1;

    IF v_id_balon IS NULL AND v_id_producto IS NULL THEN
        RETURN json_build_object(
            'error', 'El mantenimiento no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF UPPER(COALESCE(v_nombre_estado, '')) = 'FINALIZADO' THEN
        RETURN json_build_object(
            'error', 'El mantenimiento ya está finalizado',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_finalizado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoMantenimiento' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_finalizado IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado FINALIZADO de mantenimiento',
            'registro', NULL
        );
    END IF;

    UPDATE bal_mantenimiento
    SET
        fecha_salida = COALESCE(p_fecha_salida, CURRENT_DATE),
        id_estado = v_id_estado_finalizado,
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    -- Regulador/accesorio (producto): reingreso a stock al finalizar reparación
    IF v_id_producto IS NOT NULL THEN
        v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

        IF v_id_almacen_destino IS NULL THEN
            RETURN json_build_object(
                'error', 'Debe indicar el almacén de destino del reingreso del regulador',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1 FROM pro_producto
            WHERE id = v_id_producto
              AND estado = 1
              AND COALESCE(afecta_stock, FALSE) = TRUE
        ) THEN
            v_mov_result := inv_registrar_movimiento(
                p_naturaleza                => 'PRODUCTO',
                p_codigo_tipo_movimiento    => 'INGRESO',
                p_fecha                     => COALESCE(p_fecha_salida, CURRENT_DATE),
                p_id_producto               => v_id_producto,
                p_cantidad                  => 1,
                p_id_almacen_origen         => v_id_almacen_destino,
                p_codigo_tipo_documento_origen => 'MANTENIMIENTO',
                p_id_documento_origen       => p_id,
                p_glosa                     => COALESCE(
                    NULLIF(TRIM(p_observacion), ''),
                    'Reingreso regulador tras mantenimiento #' || p_id
                ),
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );

            IF v_mov_result->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_mov_result->>'error', 'registro', NULL);
            END IF;
        END IF;

        IF v_id_alquiler IS NOT NULL THEN
            UPDATE bal_alquiler
            SET
                stock_regulador_reingresado = TRUE,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_alquiler AND estado = 1;
        END IF;

        RETURN bal_obtener_mantenimiento(p_id);
    END IF;

    v_es_servicio_cliente := (
        v_nombre_propietario = 'CLIENTE'
        OR v_id_cliente_ubicacion IS NOT NULL
    );

    -- Inventario empresa: sin dueño cliente ni ubicación en cliente → reingreso a almacén
    -- (el comprobante de venta solo indica cobro del servicio, no cambia la custodia del envase)

    IF v_es_servicio_cliente THEN
        v_id_cliente_destino := COALESCE(
            v_id_cliente_ubicacion,
            v_id_cliente_propietario,
            v_id_cliente_comprobante
        );

        IF v_nombre_propietario = 'CLIENTE' THEN
            SELECT lo.id INTO v_id_estado_destino
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_PODER_CLIENTE' AND lo.estado = 1
            LIMIT 1;
        ELSE
            -- Envase de empresa que estaba prestado / con el cliente
            SELECT lo.id INTO v_id_estado_destino
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
            LIMIT 1;
        END IF;

        IF v_id_estado_destino IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontró el estado destino del cilindro (EN_PODER_CLIENTE / PRESTADO_CLIENTE). Revise el catálogo EstadoBalon.',
                'registro', NULL
            );
        END IF;

        v_obs_movimiento := COALESCE(
            NULLIF(TRIM(p_observacion), ''),
            'Entrega al cliente tras servicio de mantenimiento'
        );

        v_mov_result := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'SALIDA_ENTREGA_CLIENTE',
            p_fecha                     => COALESCE(p_fecha_salida, CURRENT_DATE),
            p_id_balon                  => v_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_origen         => v_id_almacen,
            p_id_cliente                => v_id_cliente_destino,
            p_codigo_tipo_documento_origen => 'MANTENIMIENTO',
            p_id_documento_origen       => p_id,
            p_glosa                     => v_obs_movimiento,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;

        -- Custodia al cliente. Tras mant. sale vacío; residual no aplica fuera de planta.
        UPDATE bal_balon
        SET
            id_almacen = NULL,
            id_cliente_ubicacion = v_id_cliente_destino,
            id_estado_balon = v_id_estado_destino,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon
          AND estado = 1;

    ELSE
        -- Inventario empresa: reingreso a almacén
        v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

        IF v_id_almacen_destino IS NULL THEN
            RETURN json_build_object(
                'error', 'Debe indicar el almacén de destino del reingreso',
                'registro', NULL
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_destino AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El almacén de destino no existe o está inactivo',
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_estado_destino
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_destino IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
                'registro', NULL
            );
        END IF;

        v_obs_movimiento := COALESCE(
            NULLIF(TRIM(p_observacion), ''),
            'Entrada por finalización de mantenimiento'
        );

        v_mov_result := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_MANTENIMIENTO',
            p_fecha                     => COALESCE(p_fecha_salida, CURRENT_DATE),
            p_id_balon                  => v_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_destino        => v_id_almacen_destino,
            p_codigo_tipo_documento_origen => 'MANTENIMIENTO',
            p_id_documento_origen       => p_id,
            p_glosa                     => v_obs_movimiento,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;

        -- Reingreso a almacén vacío (tras PH/reparación no se asume recarga).
        UPDATE bal_balon
        SET
            id_cliente_ubicacion = NULL,
            id_almacen = v_id_almacen_destino,
            id_estado_balon = v_id_estado_destino,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon
          AND estado = 1;
    END IF;

    PERFORM bal_sync_ph_desde_mantenimiento(
        p_id,
        p_id_usuario_auditoria,
        p_vigencia_ph_anios,
        p_id_organo_inspector,
        p_organo_inspector_no_aplica,
        p_numero_certificado_ph
    );

    RETURN bal_obtener_mantenimiento(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/movimientos-recarga/bal_actualizar_movimiento_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_movimiento_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.943Z
DROP FUNCTION IF EXISTS bal_actualizar_movimiento_recarga(p_id integer, p_fecha_salida_almacen date, p_id_producto integer, p_capacidad numeric, p_id_unidad_medida integer, p_serie_guia_salida character varying, p_numero_guia_salida character varying, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_serie_factura character varying, p_numero_factura character varying, p_id_comprobante integer, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_proveedor integer, p_observacion character varying, p_id_almacen integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_movimiento_recarga(p_id integer, p_fecha_salida_almacen date DEFAULT NULL::date, p_id_producto integer DEFAULT NULL::integer, p_capacidad numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_serie_guia_salida character varying DEFAULT NULL::character varying, p_numero_guia_salida character varying DEFAULT NULL::character varying, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_serie_factura character varying DEFAULT NULL::character varying, p_numero_factura character varying DEFAULT NULL::character varying, p_id_comprobante integer DEFAULT NULL::integer, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_proveedor integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_almacen integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_fecha_llegada_antes DATE;
    v_fecha_llegada DATE;
    v_id_producto INTEGER;
    v_id_almacen INTEGER;
    v_id_proveedor INTEGER;
    v_capacidad_tipo NUMERIC;
    v_id_estado_en_almacen INTEGER;
    v_id_documento_ref INTEGER;
    v_id_compra INTEGER;
    v_mov JSON;
    v_obs VARCHAR;
    v_ya_tiene_entrada BOOLEAN;
    v_capacidad NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'El comprobante de compra indicado no existe o está inactivo',
            'registro',
            NULL
        );
    END IF;

    SELECT fecha_llegada_almacen
    INTO v_fecha_llegada_antes
    FROM bal_movimiento_recarga
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE bal_movimiento_recarga
    SET
        fecha_salida_almacen = COALESCE(p_fecha_salida_almacen, fecha_salida_almacen),
        id_producto = COALESCE(p_id_producto, id_producto),
        capacidad = COALESCE(p_capacidad, capacidad),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        serie_guia_salida = COALESCE(p_serie_guia_salida, serie_guia_salida),
        numero_guia_salida = COALESCE(p_numero_guia_salida, numero_guia_salida),
        serie_guia_ingreso = COALESCE(p_serie_guia_ingreso, serie_guia_ingreso),
        numero_guia_ingreso = COALESCE(p_numero_guia_ingreso, numero_guia_ingreso),
        serie_factura = COALESCE(p_serie_factura, serie_factura),
        numero_factura = COALESCE(p_numero_factura, numero_factura),
        id_comprobante = COALESCE(p_id_comprobante, id_comprobante),
        id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        lote = CASE
            WHEN p_lote IS NOT NULL THEN NULLIF(TRIM(p_lote), '')
            ELSE lote
        END,
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        observacion = COALESCE(p_observacion, observacion),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1
    RETURNING id_balon, fecha_llegada_almacen, id_producto, id_almacen, id_proveedor, observacion, capacidad
    INTO v_id_balon, v_fecha_llegada, v_id_producto, v_id_almacen, v_id_proveedor, v_obs, v_capacidad;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_fecha_llegada IS NOT NULL AND v_id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NULL THEN
            RETURN json_build_object(
                'error',
                'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
                'registro',
                NULL
            );
        END IF;

        SELECT COALESCE(tb.capacidad, p_capacidad, 0)
        INTO v_capacidad_tipo
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        WHERE b.id = v_id_balon;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_en_almacen,
            id_almacen = COALESCE(v_id_almacen, id_almacen),
            id_producto_gas = COALESCE(v_id_producto, id_producto_gas),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon AND estado = 1;

        -- Primera vez que se registra llegada: movimiento de entrada.
        -- Si ya hay compra vinculada, el documento de referencia es COMPRA (no GRE/RECARGA).
        IF v_fecha_llegada_antes IS NULL THEN
            SELECT COALESCE(p_id_comprobante_compra, id_comprobante_compra)
            INTO v_id_compra
            FROM bal_movimiento_recarga
            WHERE id = p_id;

            IF v_id_compra IS NOT NULL THEN
                v_id_documento_ref := v_id_compra;
            ELSE
                v_id_documento_ref := p_id;
            END IF;

            SELECT EXISTS (
                SELECT 1
                FROM inv_movimiento m
                INNER JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
                WHERE m.estado = 1
                  AND m.naturaleza = 'BALON'
                  AND m.id_balon = v_id_balon
                  AND tm.nombre = 'ENTRADA_PLANTA_EXTERNA'
                  AND (
                    m.id_documento_origen = p_id
                    OR (v_id_compra IS NOT NULL AND m.id_documento_origen = v_id_compra)
                  )
            ) INTO v_ya_tiene_entrada;

            IF NOT COALESCE(v_ya_tiene_entrada, FALSE) THEN
                v_mov := inv_registrar_movimiento(
                    p_naturaleza                => 'BALON',
                    p_codigo_tipo_movimiento    => 'ENTRADA_PLANTA_EXTERNA',
                    p_fecha                     => v_fecha_llegada,
                    p_id_producto               => v_id_producto,
                    p_id_balon                  => v_id_balon,
                    p_cantidad                  => COALESCE(v_capacidad, 1),
                    p_id_almacen_destino        => v_id_almacen,
                    p_id_cliente                => v_id_proveedor,
                    p_codigo_tipo_documento_origen => CASE
                        WHEN v_id_compra IS NOT NULL THEN 'COMPRA'
                        ELSE 'RECARGA'
                    END,
                    p_id_documento_origen       => v_id_documento_ref,
                    p_glosa                     => COALESCE(
                        NULLIF(TRIM(v_obs), ''),
                        CASE
                            WHEN v_id_compra IS NOT NULL THEN 'Retorno planta externa (compra #' || v_id_compra || ')'
                            ELSE 'Retorno planta externa'
                        END
                    ),
                    p_id_usuario_auditoria      => p_id_usuario_auditoria
                );
                IF v_mov->>'error' IS NOT NULL THEN
                    RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
                END IF;
            END IF;
        ELSIF p_id_comprobante_compra IS NOT NULL THEN
            -- Compra vinculada después de la entrada: reapunta el kardex a COMPRA.
            v_mov := inv_repuntar_documento(
                p_codigo_tipo_documento_origen_actual => 'RECARGA',
                p_id_documento_origen_actual          => p_id,
                p_codigo_tipo_documento_origen_nuevo  => 'COMPRA',
                p_id_documento_origen_nuevo           => p_id_comprobante_compra,
                p_id_usuario_auditoria                => p_id_usuario_auditoria
            );
        END IF;
    END IF;

    -- Idempotente: solo inserta en bal_balon_ph_historial si hay P.H. y aún no hay fila para este movimiento.
    PERFORM bal_sync_ph_desde_recarga(p_id, p_id_usuario_auditoria);

    RETURN bal_obtener_movimiento_recarga(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/movimientos-recarga/bal_crear_movimiento_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_movimiento_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
DROP FUNCTION IF EXISTS bal_crear_movimiento_recarga(p_fecha_salida_almacen date, p_id_balon integer, p_id_producto integer, p_capacidad numeric, p_id_unidad_medida integer, p_serie_guia_salida character varying, p_numero_guia_salida character varying, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_serie_factura character varying, p_numero_factura character varying, p_id_comprobante integer, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_proveedor integer, p_observacion character varying, p_id_almacen integer, p_id_comprobante_compra integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_movimiento_recarga(p_fecha_salida_almacen date, p_id_balon integer, p_id_producto integer DEFAULT NULL::integer, p_capacidad numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_serie_guia_salida character varying DEFAULT NULL::character varying, p_numero_guia_salida character varying DEFAULT NULL::character varying, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_serie_factura character varying DEFAULT NULL::character varying, p_numero_factura character varying DEFAULT NULL::character varying, p_id_comprobante integer DEFAULT NULL::integer, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_proveedor integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_almacen integer DEFAULT NULL::integer, p_id_comprobante_compra integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_tipo_recarga INTEGER;
    v_es_empresa BOOLEAN;
    v_capacidad_tipo NUMERIC;
    v_id_estado_recarga_externa INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_tipo_doc_recarga INTEGER;
    v_id_tipo_salida INTEGER;
    v_id_tipo_entrada INTEGER;
    v_mov JSON;
    v_obs VARCHAR;
    v_id_producto_gas_balon INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_salida_almacen IS NULL THEN
        RETURN json_build_object('error', 'La fecha de salida de almacén es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- Capacidad del tipo convertida a la unidad del producto-gas (canónica de pro_stock).
    SELECT
        COALESCE(prop.nombre, '') = 'EMPRESA',
        COALESCE(bal_capacidad_balon_en_unidad_gas(b.id), p_capacidad, 0)
    INTO v_es_empresa, v_capacidad_tipo
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
    WHERE b.id = p_id_balon;

    IF NOT COALESCE(v_es_empresa, FALSE) THEN
        RETURN json_build_object(
            'error',
            'La recarga en planta externa solo aplica a balones de propiedad EMPRESA',
            'registro',
            NULL
        );
    END IF;

    IF p_id_comprobante_compra IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante_compra AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'El comprobante de compra indicado no existe o está inactivo',
            'registro',
            NULL
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoRecarga' AND lo.nombre = 'PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_recarga_externa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_salida
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'SALIDA_PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_recarga_externa IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado EN_RECARGA_EXTERNA del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
            'registro',
            NULL
        );
    END IF;

    IF v_id_tipo_salida IS NULL OR v_id_tipo_entrada IS NULL THEN
        RETURN json_build_object(
            'error',
            'No se encontraron los tipos SALIDA_PLANTA_EXTERNA / ENTRADA_PLANTA_EXTERNA. Revise el catálogo TipoMovBalon.',
            'registro',
            NULL
        );
    END IF;

    INSERT INTO bal_movimiento_recarga (
        fecha_salida_almacen, id_balon, id_tipo_recarga, id_producto, capacidad, id_unidad_medida,
        serie_guia_salida, numero_guia_salida, serie_guia_ingreso, numero_guia_ingreso,
        serie_factura, numero_factura, id_comprobante, id_comprobante_compra, fecha_llegada_almacen,
        lote, fecha_vencimiento_lote, fecha_prueba_hidrostatica, id_proveedor,
        observacion, id_almacen,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_fecha_salida_almacen, p_id_balon, v_id_tipo_recarga, p_id_producto, p_capacidad, p_id_unidad_medida,
        p_serie_guia_salida, p_numero_guia_salida, p_serie_guia_ingreso, p_numero_guia_ingreso,
        p_serie_factura, p_numero_factura, p_id_comprobante, p_id_comprobante_compra, p_fecha_llegada_almacen,
        p_lote, p_fecha_vencimiento_lote, p_fecha_prueba_hidrostatica, p_id_proveedor,
        p_observacion, p_id_almacen,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_obs := COALESCE(NULLIF(TRIM(p_observacion), ''), 'Recarga planta externa');

    -- Libro de movimientos: salida a planta.
    v_mov := inv_registrar_movimiento(
        p_naturaleza                => 'BALON',
        p_codigo_tipo_movimiento    => 'SALIDA_PLANTA_EXTERNA',
        p_fecha                     => p_fecha_salida_almacen::TIMESTAMP,
        p_id_producto               => NULL,
        p_id_balon                  => p_id_balon,
        p_cantidad                  => 1,
        p_id_almacen_origen         => p_id_almacen,
        p_id_almacen_destino        => NULL,
        p_id_cliente                => p_id_proveedor,
        p_codigo_tipo_documento_origen => 'RECARGA',
        p_id_documento_origen       => v_id,
        p_glosa                     => v_obs,
        p_id_usuario_auditoria      => p_id_usuario_auditoria
    );
    IF v_mov->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
    END IF;

    IF p_fecha_llegada_almacen IS NOT NULL THEN
        -- inv_registrar_movimiento ya actualizó id_estado_balon a DISPONIBLE.
        -- Solo fijamos id_producto_gas.
        UPDATE bal_balon
        SET
            id_producto_gas = COALESCE(p_id_producto, id_producto_gas),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1
        RETURNING id_producto_gas INTO v_id_producto_gas_balon;

        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_PLANTA_EXTERNA',
            p_fecha                     => p_fecha_llegada_almacen::TIMESTAMP,
            p_id_producto               => v_id_producto_gas_balon,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => COALESCE(p_capacidad, NULLIF(v_capacidad_tipo, 0), 1),
            p_id_almacen_origen         => NULL,
            p_id_almacen_destino        => p_id_almacen,
            p_id_cliente                => p_id_proveedor,
            p_codigo_tipo_documento_origen => 'RECARGA',
            p_id_documento_origen       => v_id,
            p_glosa                     => v_obs,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );
        IF v_mov->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
        END IF;
    ELSE
        -- inv_registrar_movimiento (SALIDA_PLANTA_EXTERNA) ya puso EN_RECARGA_EXTERNA + limpió almacén.
        NULL;
    END IF;

    RETURN bal_obtener_movimiento_recarga(v_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/movimientos-recarga/bal_eliminar_movimiento_recarga.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_movimiento_recarga
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_eliminar_movimiento_recarga(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_eliminar_movimiento_recarga(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_balon INTEGER;
    v_fecha_llegada DATE;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1 FROM bal_balon_ph_historial WHERE id_movimiento_recarga = p_id AND estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar la recarga porque tiene historial de P.H. asociado'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_movimiento_recarga
        WHERE id = p_id AND estado = 1 AND id_comprobante IS NOT NULL
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar la recarga porque tiene un comprobante asociado'
        );
    END IF;

    SELECT id_balon, fecha_llegada_almacen
    INTO v_id_balon, v_fecha_llegada
    FROM bal_movimiento_recarga
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Revertir kardex unificado ligado a este documento de recarga.
    PERFORM inv_revertir_por_documento('RECARGA', p_id, p_id_usuario_auditoria);

    UPDATE bal_movimiento_recarga
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF v_id_balon IS NOT NULL AND v_fecha_llegada IS NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_en_almacen,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1
              AND EXISTS (
                  SELECT 1
                  FROM gen_lista_opciones eb
                  WHERE eb.id = bal_balon.id_estado_balon
                    AND UPPER(COALESCE(eb.nombre, '')) = 'EN_RECARGA_EXTERNA'
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM bal_movimiento_recarga mr
                  WHERE mr.id_balon = v_id_balon
                    AND mr.id <> p_id
                    AND mr.estado = 1
                    AND mr.fecha_llegada_almacen IS NULL
              );
        END IF;
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/prestamos/bal_prestamo_aplicar_retorno_cilindro.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_prestamo_aplicar_retorno_cilindro
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
DROP FUNCTION IF EXISTS bal_prestamo_aplicar_retorno_cilindro(p_id_balon integer, p_id_prestamo integer, p_id_cliente integer, p_id_almacen_destino integer, p_nombre_contenido character varying, p_observacion character varying, p_id_usuario_auditoria integer, p_crear_movimiento boolean);

CREATE OR REPLACE FUNCTION bal_prestamo_aplicar_retorno_cilindro(p_id_balon integer, p_id_prestamo integer, p_id_cliente integer DEFAULT NULL::integer, p_id_almacen_destino integer DEFAULT NULL::integer, p_nombre_contenido character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_crear_movimiento boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado VARCHAR;
    v_id_almacen INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_contenido VARCHAR;
    v_capacidad NUMERIC;
    v_mov JSON;
    v_en_campo BOOLEAN := FALSE;
BEGIN
    IF p_id_balon IS NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    SELECT eb.nombre, b.id_almacen, tb.capacidad
    INTO v_nombre_estado, v_id_almacen, v_capacidad
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    v_en_campo := COALESCE(v_nombre_estado, '') IN (
        'PRESTADO_CLIENTE', 'POR_RECOGER', 'EN_PODER_CLIENTE', 'EN_RUTA_LIMA'
    ) OR (COALESCE(v_nombre_estado, '') = 'DISPONIBLE' AND v_id_almacen IS NULL);

    -- Ya está en almacén (p. ej. volvió por otro flujo): no pisar contenido/stock.
    IF COALESCE(v_nombre_estado, '') = 'DISPONIBLE' AND v_id_almacen IS NOT NULL THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    -- Custodia de otro proceso (alquiler / recarga / taller): solo se cierra el préstamo.
    IF COALESCE(v_nombre_estado, '') IN (
        'ALQUILADO', 'EN_MANTENIMIENTO', 'EN_RECARGA_EXTERNA', 'DADO_DE_BAJA', 'ROBO'
    ) THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    IF NOT v_en_campo AND COALESCE(v_nombre_estado, '') <> '' THEN
        RETURN json_build_object('ok', TRUE, 'skipped', TRUE);
    END IF;

    IF p_id_almacen_destino IS NULL THEN
        RETURN json_build_object('error', 'Debe indicar el almacén de destino de la devolución', 'ok', FALSE);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'ok', FALSE);
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado DISPONIBLE del cilindro. Revise el catálogo EstadoBalon.',
            'ok', FALSE
        );
    END IF;

    IF p_crear_movimiento THEN
        v_mov := inv_registrar_movimiento(
            p_naturaleza                => 'BALON',
            p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
            p_fecha                     => LOCALTIMESTAMP,
            p_id_balon                  => p_id_balon,
            p_cantidad                  => 1,
            p_id_almacen_destino        => p_id_almacen_destino,
            p_id_cliente                => p_id_cliente,
            p_codigo_tipo_documento_origen => 'PRESTAMO',
            p_id_documento_origen       => p_id_prestamo,
            p_glosa                     => COALESCE(NULLIF(TRIM(p_observacion), ''), 'Entrada por devolución de préstamo'),
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_mov->>'error', 'ok', FALSE);
        END IF;
    END IF;

    UPDATE bal_balon
    SET
        id_cliente_ubicacion = NULL,
        id_almacen = p_id_almacen_destino,
        id_estado_balon = v_id_estado_en_almacen,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_balon AND estado = 1;

    RETURN json_build_object('ok', TRUE, 'skipped', FALSE);
END;
$function$;


-- ============================================================
-- database_sql/funciones/prestamos/bal_prestamo_aplicar_salida_cilindro.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_prestamo_aplicar_salida_cilindro
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
DROP FUNCTION IF EXISTS bal_prestamo_aplicar_salida_cilindro(p_id_prestamo integer, p_id_balon integer, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_prestamo_aplicar_salida_cilindro(p_id_prestamo integer, p_id_balon integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_comprobante INTEGER;
    v_id_almacen_origen INTEGER;
    v_nombre_estado VARCHAR;
    v_id_estado_prestado INTEGER;
    v_codigo_tipo_comp VARCHAR;
    v_id_documento_ref INTEGER;
    v_codigo_tipo_doc_ref VARCHAR;
    v_mov JSON;
    v_custodia BOOLEAN := FALSE;
BEGIN
    IF p_id_prestamo IS NULL OR p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'Préstamo y cilindro son obligatorios', 'ok', FALSE);
    END IF;

    SELECT p.id_cliente, p.id_comprobante_venta
    INTO v_id_cliente, v_id_comprobante
    FROM bal_prestamo p
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    SELECT b.id_almacen, eb.nombre
    INTO v_id_almacen_origen, v_nombre_estado
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'ok', FALSE);
    END IF;

    IF COALESCE(v_nombre_estado, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error', 'No se puede prestar un cilindro dado de baja o reportado como robo',
            'ok', FALSE
        );
    END IF;

    IF COALESCE(v_nombre_estado, '') IN (
        'ALQUILADO', 'EN_MANTENIMIENTO', 'EN_RECARGA_EXTERNA', 'POR_RECOGER', 'EN_PODER_CLIENTE'
    ) THEN
        RETURN json_build_object(
            'error',
            format('El cilindro está %s; no se puede prestar', LOWER(REPLACE(v_nombre_estado, '_', ' '))),
            'ok', FALSE
        );
    END IF;

    SELECT lo.id INTO v_id_estado_prestado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_prestado IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado PRESTADO_CLIENTE del cilindro. Revise el catálogo EstadoBalon.',
            'ok', FALSE
        );
    END IF;

    IF v_id_comprobante IS NOT NULL THEN
        SELECT lo.descripcion INTO v_codigo_tipo_comp
        FROM ven_comprobante c
        INNER JOIN gen_lista_opciones lo ON lo.id = c.id_tipo_comprobante
        WHERE c.id = v_id_comprobante AND c.estado = 1;

        v_id_documento_ref := v_id_comprobante;
        v_codigo_tipo_doc_ref := CASE
            WHEN v_codigo_tipo_comp = '01' THEN 'FACTURA'
            WHEN v_codigo_tipo_comp = '03' THEN 'BOLETA'
            WHEN v_codigo_tipo_comp IN ('NV', 'VSD') THEN 'NOTA_VENTA'
            ELSE 'FACTURA'
        END;
    ELSE
        v_id_documento_ref := p_id_prestamo;
        v_codigo_tipo_doc_ref := 'PRESTAMO';
    END IF;

    v_mov := bal_registrar_salida_documento(
        p_id_balon,
        'SALIDA_PRESTAMO',
        v_id_documento_ref,
        v_codigo_tipo_doc_ref,
        v_id_cliente,
        v_id_almacen_origen,
        'PRESTADO_CLIENTE',
        TRUE,
        NULL,
        COALESCE(NULLIF(TRIM(p_observacion), ''), 'Salida automática por préstamo'),
        p_id_usuario_auditoria
    );

    IF v_mov->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_mov->>'error', 'ok', FALSE);
    END IF;

    IF COALESCE(v_nombre_estado, '') IN ('DISPONIBLE', '', 'PRESTADO_CLIENTE', 'EN_RUTA_LIMA')
       OR v_nombre_estado IS NULL
    THEN
        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_prestado,
            id_cliente_ubicacion = COALESCE(v_id_cliente, id_cliente_ubicacion),
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    IF COALESCE(v_nombre_estado, '') = 'DISPONIBLE' THEN
        v_custodia := TRUE;
    END IF;

    RETURN json_build_object('ok', TRUE, 'custodia_actualizada', v_custodia);
END;
$function$;


-- ============================================================
-- database_sql/funciones/prestamos/bal_renovar_prestamo.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_renovar_prestamo
-- Overloads: 1
--
-- Actualizada por database_sql/migraciones/20260905_bal_renovar_prestamo_cilindro_comprometido.sql:
-- la busqueda de cilindro de canje descarta los que tienen un detalle de
-- prestamo abierto (por ejemplo, los recibidos en garantia).
DROP FUNCTION IF EXISTS bal_renovar_prestamo(p_id_prestamo integer, p_id_balon_nuevo integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION bal_renovar_prestamo(p_id_prestamo integer, p_id_balon_nuevo integer DEFAULT NULL::integer, p_id_usuario integer DEFAULT NULL::integer, p_id_comprobante_venta_nuevo integer DEFAULT NULL::integer, p_mantener_garantia boolean DEFAULT true)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle_entregado RECORD;
    v_id_detalle_garantia INTEGER;
    v_id_balon_swap INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_detalle_devuelto INTEGER;
    v_id_estado_prestamo_activo INTEGER;
    v_result JSON;
    v_id_prestamo_nuevo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT p.*
    INTO v_prestamo
    FROM bal_prestamo p
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT pd.*
    INTO v_detalle_entregado
    FROM bal_prestamo_detalle pd
    WHERE pd.id_prestamo = p_id_prestamo
      AND pd.rol = 'ENTREGADO'
      AND pd.estado = 1
      AND pd.fecha_devolucion IS NULL
    ORDER BY pd.id DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'El préstamo no tiene un cilindro entregado activo para renovar',
            'registro', NULL
        );
    END IF;

    SELECT pd.id INTO v_id_detalle_garantia
    FROM bal_prestamo_detalle pd
    WHERE pd.id_prestamo = p_id_prestamo
      AND pd.rol = 'GARANTIA'
      AND pd.estado = 1
      AND pd.fecha_devolucion IS NULL
    ORDER BY pd.id DESC
    LIMIT 1;

    -- Balón nuevo: el que pasó el cajero, o el primero disponible de las
    -- mismas características (mismo tipo + gas) en el almacén del préstamo.
    IF p_id_balon_nuevo IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF NOT EXISTS (
            SELECT 1 FROM bal_balon b
            WHERE b.id = p_id_balon_nuevo AND b.estado = 1 AND b.id_estado_balon = v_id_estado_en_almacen
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro indicado no está disponible en almacén',
                'registro', NULL
            );
        END IF;

        -- Mismo criterio que la busqueda automatica, pero con un mensaje que
        -- explica el caso en vez del generico de bal_crear_prestamo_detalle.
        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd_ocupado
            INNER JOIN bal_prestamo p_ocupado
                ON p_ocupado.id = pd_ocupado.id_prestamo AND p_ocupado.estado = 1
            WHERE pd_ocupado.id_balon = p_id_balon_nuevo
              AND pd_ocupado.estado = 1
              AND pd_ocupado.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro indicado está comprometido en otro préstamo '
                         || '(por ejemplo, recibido en garantía). Elige otro o devuélvelo primero.',
                'registro', NULL
            );
        END IF;
        v_id_balon_swap := p_id_balon_nuevo;
    ELSE
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        SELECT b.id INTO v_id_balon_swap
        FROM bal_balon b
        INNER JOIN bal_balon origen ON origen.id = v_detalle_entregado.id_balon
        WHERE b.estado = 1
          AND b.id_estado_balon = v_id_estado_en_almacen
          AND b.id <> origen.id
          AND b.id_tipo_balon = origen.id_tipo_balon
          AND COALESCE(b.id_producto_gas, -1) = COALESCE(origen.id_producto_gas, -1)
          AND (v_prestamo.id_almacen IS NULL OR b.id_almacen = v_prestamo.id_almacen)
          -- Un cilindro con detalle de prestamo abierto no esta libre aunque
          -- figure DISPONIBLE: el caso tipico es el que el propio cliente dejo
          -- en garantia, que esta fisicamente en la empresa pero comprometido
          -- (rol GARANTIA). Sin este filtro la renovacion lo elegia como
          -- reemplazo y moria en bal_crear_prestamo_detalle con "El cilindro ya
          -- tiene un prestamo activo sin devolver" — es decir, un cliente que
          -- dejo su balon no podia renovar.
          AND NOT EXISTS (
              SELECT 1
              FROM bal_prestamo_detalle pd_ocupado
              INNER JOIN bal_prestamo p_ocupado
                  ON p_ocupado.id = pd_ocupado.id_prestamo AND p_ocupado.estado = 1
              WHERE pd_ocupado.id_balon = b.id
                AND pd_ocupado.estado = 1
                AND pd_ocupado.fecha_devolucion IS NULL
          )
        ORDER BY b.fecha_registro ASC NULLS LAST, b.id ASC
        LIMIT 1;
    END IF;

    -- 1. Cierra el detalle ENTREGADO del préstamo anterior.
    IF v_id_balon_swap IS NOT NULL THEN
        -- Canje: el cilindro viejo vuelve físicamente al almacén.
        v_result := bal_devolver_prestamo_detalle(
            v_detalle_entregado.id,
            CURRENT_DATE,
            v_prestamo.id_almacen,
            p_id_usuario,
            'VACIO',
            'Renovado — cilindro reemplazado'
        );
        IF v_result->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_result->>'error', 'registro', NULL);
        END IF;
    ELSE
        -- Extensión: el cilindro nunca cambia de custodia, solo se cierra el
        -- detalle administrativamente (sin pasar por bal_prestamo_aplicar_retorno_cilindro,
        -- que devolvería el balón al almacén — aquí el cliente lo sigue teniendo).
        SELECT lo.id INTO v_id_estado_detalle_devuelto
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_prestamo_detalle
        SET fecha_devolucion = CURRENT_DATE,
            id_estado = v_id_estado_detalle_devuelto,
            observacion = TRIM(COALESCE(observacion || ' — ', '') || 'Renovado sin cambio de cilindro'),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_detalle_entregado.id;
    END IF;

    -- 2. Préstamo nuevo, encadenado al anterior.
    SELECT lo.id INTO v_id_estado_prestamo_activo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'ACTIVO' AND lo.estado = 1
    LIMIT 1;

    v_result := bal_crear_prestamo(
        p_id_tipo_prestamo      => v_prestamo.id_tipo_prestamo,
        p_id_cliente            => v_prestamo.id_cliente,
        p_id_proveedor          => v_prestamo.id_proveedor,
        p_id_almacen            => v_prestamo.id_almacen,
        p_fecha_salida          => CURRENT_DATE,
        p_titulo                => 'Renovación · ' || COALESCE(v_prestamo.titulo, v_prestamo.numero_prestamo),
        p_observacion           => 'Renovación del préstamo ' || COALESCE(v_prestamo.numero_prestamo, p_id_prestamo::text),
        p_id_estado             => v_id_estado_prestamo_activo,
        p_id_comprobante_venta  => COALESCE(p_id_comprobante_venta_nuevo, v_prestamo.id_comprobante_venta),
        p_id_usuario_auditoria  => p_id_usuario
    );
    PERFORM ven_raise_si_error(v_result);
    v_id_prestamo_nuevo := (v_result->'registro'->>'id')::INTEGER;

    IF v_id_prestamo_nuevo IS NULL THEN
        RAISE EXCEPTION 'No se pudo crear el préstamo de renovación';
    END IF;

    UPDATE bal_prestamo
    SET id_prestamo_origen = p_id_prestamo
    WHERE id = v_id_prestamo_nuevo;

    -- 3. Detalle ENTREGADO del préstamo nuevo — balón nuevo (canje) o el mismo
    -- (extensión). bal_prestamo_aplicar_salida_cilindro ya tolera un balón que
    -- sigue PRESTADO_CLIENTE (no exige que esté DISPONIBLE), así que funciona
    -- igual en los dos casos.
    v_result := bal_crear_prestamo_detalle(
        p_id_prestamo            => v_id_prestamo_nuevo,
        p_id_balon               => COALESCE(v_id_balon_swap, v_detalle_entregado.id_balon),
        p_id_producto            => v_detalle_entregado.id_producto,
        p_fecha_entregado        => CURRENT_DATE,
        p_fecha_prestamo         => CURRENT_DATE,
        p_observacion            => CASE
            WHEN v_id_balon_swap IS NOT NULL THEN 'Cilindro de reemplazo por renovación'
            ELSE 'Mismo cilindro, préstamo renovado'
        END,
        p_id_usuario_auditoria   => p_id_usuario,
        p_rol                    => 'ENTREGADO'
    );
    PERFORM ven_raise_si_error(v_result);

    -- 4. Garantía del préstamo anterior — por defecto se reutiliza (dinero y/o
    -- cilindro), sin tocar su custodia. Si p_mantener_garantia es false, se deja
    -- tal cual en el préstamo anterior (ya cerrado) y el llamador es responsable
    -- de registrar una garantía nueva para el préstamo nuevo si corresponde.
    IF p_mantener_garantia THEN
        IF v_id_detalle_garantia IS NOT NULL THEN
            UPDATE bal_prestamo_detalle
            SET id_prestamo = v_id_prestamo_nuevo,
                id_usuario_modificacion = p_id_usuario,
                fecha_modificacion = NOW()
            WHERE id = v_id_detalle_garantia;
        END IF;

        UPDATE ven_garantia
        SET id_prestamo = v_id_prestamo_nuevo
        WHERE id_prestamo = p_id_prestamo AND estado = 1;
    END IF;

    -- 5. Cierra el préstamo anterior (ya no le queda detalle pendiente).
    PERFORM bal_prestamo_cerrar_si_completo(
        p_id_prestamo          => p_id_prestamo,
        p_id_usuario_auditoria => p_id_usuario
    );

    RETURN bal_obtener_prestamo(v_id_prestamo_nuevo);
END;
$function$;


-- ============================================================
-- database_sql/funciones/recargas-planta/bal_finalizar_recarga_planta.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_finalizar_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.946Z
DROP FUNCTION IF EXISTS bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer, p_guardar_balones_almacen boolean, p_id_usuario_auditoria integer);

-- p_lote / p_fecha_vencimiento_lote / p_fecha_prueba_hidrostatica: antes los
-- llenaba bal_actualizar_recarga_planta (eliminada en la unificación a
-- doc_salida). Es el mismo paso del flujo — registrar el retorno — así que
-- se agregan aquí en vez de crear otra función.
CREATE OR REPLACE FUNCTION bal_finalizar_recarga_planta(p_id_recarga_planta integer, p_id_comprobante_compra integer, p_fecha_llegada_almacen date, p_id_almacen integer, p_id_proveedor integer DEFAULT NULL::integer, p_guardar_balones_almacen boolean DEFAULT false, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_estado_en_almacen INTEGER;
    v_id_documento_ref INTEGER;
    v_codigo_doc VARCHAR;
    v_det RECORD;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM doc_salida WHERE id = p_id_recarga_planta AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'La orden de recarga en planta externa no existe o está anulada',
            'registro', NULL
        );
    END IF;

    -- Datos del retorno sobre el propio documento.
    UPDATE doc_salida
    SET id_comprobante_compra = COALESCE(p_id_comprobante_compra, id_comprobante_compra),
        fecha_llegada_almacen = COALESCE(p_fecha_llegada_almacen, fecha_llegada_almacen),
        fecha_retorno = COALESCE(p_fecha_llegada_almacen, fecha_retorno),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_proveedor = COALESCE(p_id_proveedor, id_proveedor),
        lote = COALESCE(p_lote, lote),
        fecha_vencimiento_lote = COALESCE(p_fecha_vencimiento_lote, fecha_vencimiento_lote),
        fecha_prueba_hidrostatica = COALESCE(p_fecha_prueba_hidrostatica, fecha_prueba_hidrostatica),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_recarga_planta;

    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        -- Con factura vinculada el documento de referencia es la compra; si no, la orden.
        IF p_id_comprobante_compra IS NOT NULL THEN
            v_id_documento_ref := p_id_comprobante_compra;
            v_codigo_doc := 'COMPRA';
        ELSE
            v_id_documento_ref := p_id_recarga_planta;
            v_codigo_doc := 'ORDEN_SALIDA';
        END IF;

        FOR v_det IN
            SELECT
                d.id AS id_detalle,
                d.id_balon,
                COALESCE(d.id_producto, b.id_producto_gas) AS id_producto,
                inv_convertir_a_unidad_producto(
                    COALESCE(d.id_producto, b.id_producto_gas),
                    d.cantidad,
                    d.id_unidad_medida
                ) AS cantidad
            FROM doc_salida_detalle d
            LEFT JOIN bal_balon b ON b.id = d.id_balon
            WHERE d.id_doc_salida = p_id_recarga_planta
              AND d.estado = 1
              AND d.id_balon IS NOT NULL
        LOOP
            PERFORM bal_actualizar_balon(
                p_id                   => v_det.id_balon,
                p_id_almacen           => p_id_almacen,
                p_id_estado_balon      => v_id_estado_en_almacen,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );

            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => 'BALON',
                p_codigo_tipo_movimiento       => 'ENTRADA_PLANTA_EXTERNA',
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => v_det.id_producto,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => COALESCE(v_det.cantidad, 1),
                p_id_almacen_destino           => p_id_almacen,
                p_id_cliente                   => p_id_proveedor,
                p_codigo_tipo_documento_origen => v_codigo_doc,
                p_id_documento_origen          => v_id_documento_ref,
                p_glosa                        => format(
                    'Entrada por recarga en planta externa (orden #%s)', p_id_recarga_planta
                ),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_det.id_detalle
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar la entrada del balón %: %',
                    v_det.id_balon, v_mov->>'error';
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object('error', NULL, 'registro', json_build_object(
        'id_recarga_planta', p_id_recarga_planta
    ));
END;
$function$;


-- ============================================================
-- database_sql/funciones/recojos/bal_registrar_resultado_recojo.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_registrar_resultado_recojo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
DROP FUNCTION IF EXISTS bal_registrar_resultado_recojo(p_id integer, p_fecha_visita date, p_id_motivo_fallo integer, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer, p_regulador json);

CREATE OR REPLACE FUNCTION bal_registrar_resultado_recojo(p_id integer, p_fecha_visita date DEFAULT NULL::date, p_id_motivo_fallo integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_regulador json DEFAULT NULL::json)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_id_recarga_planta INTEGER;
    v_estado_actual VARCHAR;
    v_fecha_visita DATE;
    v_item JSON;
    v_id_pd INTEGER;
    v_id_ad INTEGER;
    v_id_b INTEGER;
    v_resultado VARCHAR;
    v_nombre_contenido VARCHAR;
    v_nueva_fecha DATE;
    v_id_almacen INTEGER;
    v_obs VARCHAR(500);
    v_id_resultado INTEGER;
    v_id_prestamo_det INTEGER;
    v_id_alquiler_det INTEGER;
    v_dev JSON;
    v_cnt_total INTEGER := 0;
    v_cnt_recogido INTEGER := 0;
    v_cnt_no_recogido INTEGER := 0;
    v_cnt_extendido INTEGER := 0;
    v_cnt_efectivo INTEGER := 0;
    v_cnt_cubiertos INTEGER := 0;
    v_estado_header VARCHAR;
    v_id_estado_header INTEGER;
    v_id_motivo INTEGER;
    v_motivo_nombre VARCHAR;
    v_pendientes_json JSONB := '[]'::JSONB;
    v_fecha_repro DATE;
    v_nuevo JSON;
    v_id_estado_prestado INTEGER;
    v_id_balon INTEGER;
    v_repro_detalles JSONB := '[]'::JSONB;
    v_cantidad_restante NUMERIC(10,4);
    v_capacidad_tipo NUMERIC(10,4);
    v_id_producto_gas_recojo INTEGER;
    v_lb_restante NUMERIC(10,4);
    v_peso_bruto_lb NUMERIC(10,4);
    v_presion_psi NUMERIC(10,4);
    v_tiene_regulador BOOLEAN := FALSE;
    v_procesa_regulador BOOLEAN := FALSE;
    v_reg JSONB;
    v_reg_resultado VARCHAR;
    v_reg_condicion VARCHAR;
    v_reg_nueva_fecha DATE;
    v_reg_obs VARCHAR(500);
    v_id_resultado_reg INTEGER;
    v_id_condicion_reg INTEGER;
    v_cil_pendientes INTEGER;
    v_seen_pd INTEGER[] := '{}';
    v_seen_ad INTEGER[] := '{}';
    v_seen_b INTEGER[] := '{}';
    v_ya_devuelto DATE;
    v_pass INTEGER;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, r.id_prestamo, r.id_alquiler, r.id_recarga_planta, er.nombre
    INTO v_id_cliente, v_id_prestamo, v_id_alquiler, v_id_recarga_planta, v_estado_actual
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado_actual NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se puede registrar resultado en recojos PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    v_fecha_visita := COALESCE(p_fecha_visita, CURRENT_DATE);

    SELECT COUNT(*)::INTEGER INTO v_cnt_total
    FROM bal_recojo_detalle
    WHERE id_recojo = p_id AND estado = 1;

    IF v_id_alquiler IS NOT NULL THEN
        SELECT COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
        INTO v_tiene_regulador
        FROM bal_alquiler a
        WHERE a.id = v_id_alquiler AND a.estado = 1;
    END IF;

    v_reg := CASE
        WHEN p_regulador IS NULL OR p_regulador::TEXT IN ('null', '') THEN NULL
        ELSE p_regulador::JSONB
    END;

    -- Compat: recojo solo regulador enviando un ítem en detalles sin ids de cilindro
    IF v_tiene_regulador
       AND v_reg IS NULL
       AND v_cnt_total = 0
       AND jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 1
       AND COALESCE(
           NULLIF((p_detalles::JSONB -> 0)->>'idPrestamoDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_prestamo_detalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'idAlquilerDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_alquiler_detalle', '')
       ) IS NULL
    THEN
        v_reg := p_detalles::JSONB -> 0;
    END IF;

    -- Regulador solo si visita accesorio-only o el cliente envió p_regulador
    v_procesa_regulador := (v_cnt_total = 0 AND v_tiene_regulador) OR (v_reg IS NOT NULL);

    IF v_cnt_total = 0 THEN
        IF NOT v_tiene_regulador THEN
            RETURN json_build_object(
                'error', 'Este recojo no tiene detalles ni regulador asociado',
                'registro', NULL
            );
        END IF;
    ELSE
        IF p_detalles IS NULL
           OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
            RETURN json_build_object(
                'error', 'Debe indicar el resultado de al menos un detalle',
                'registro', NULL
            );
        END IF;

        IF v_cnt_total <> jsonb_array_length(p_detalles::JSONB) THEN
            RETURN json_build_object(
                'error',
                'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
                'registro', NULL
            );
        END IF;
    END IF;

    v_id_motivo := p_id_motivo_fallo;
    IF v_id_motivo IS NOT NULL THEN
        SELECT lo.nombre INTO v_motivo_nombre
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE lo.id = v_id_motivo
          AND l.nombre = 'MotivoFalloRecojo'
          AND lo.estado = 1;

        IF v_motivo_nombre IS NULL THEN
            RETURN json_build_object(
                'error', 'El motivo de fallo no existe o no pertenece a MotivoFalloRecojo',
                'registro', NULL
            );
        END IF;
    END IF;

    -- Pass 1: validar cilindros. Antes del pass 2: regulador + FALLIDO + reprogram.
    -- Pass 2: mutar stock / fechas.
    FOR v_pass IN 1..2 LOOP
        v_seen_pd := '{}';
        v_seen_ad := '{}';
        IF v_pass = 1 THEN
            v_cnt_recogido := 0;
            v_cnt_no_recogido := 0;
            v_cnt_extendido := 0;
            v_pendientes_json := '[]'::JSONB;
        END IF;

        IF v_pass = 2 THEN
            IF v_procesa_regulador THEN
                IF v_reg IS NULL OR COALESCE(NULLIF(TRIM(COALESCE(
                    v_reg->>'resultado', v_reg->>'nombre_resultado', ''
                )), ''), '') = '' THEN
                    RETURN json_build_object(
                        'error', 'Debe indicar el resultado del regulador/accesorio',
                        'registro', NULL
                    );
                END IF;

                v_reg_resultado := UPPER(TRIM(COALESCE(
                    v_reg->>'resultado',
                    v_reg->>'nombre_resultado',
                    ''
                )));
                v_reg_condicion := UPPER(TRIM(COALESCE(
                    v_reg->>'condicion',
                    v_reg->>'nombreCondicion',
                    v_reg->>'nombre_condicion',
                    ''
                )));
                v_reg_nueva_fecha := COALESCE(
                    NULLIF(v_reg->>'nuevaFechaRetorno', '')::DATE,
                    NULLIF(v_reg->>'nueva_fecha_retorno', '')::DATE
                );
                v_reg_obs := NULLIF(TRIM(COALESCE(v_reg->>'observacion', '')), '');

                IF v_reg_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
                    RETURN json_build_object(
                        'error', 'Resultado de regulador inválido: ' || COALESCE(v_reg_resultado, '(vacío)'),
                        'registro', NULL
                    );
                END IF;

                SELECT lo.id INTO v_id_resultado_reg
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON l.id = lo.id_lista
                WHERE l.nombre = 'ResultadoRecojoDetalle'
                  AND lo.nombre = v_reg_resultado
                  AND lo.estado = 1
                LIMIT 1;

                IF v_id_resultado_reg IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se encontró el resultado ' || v_reg_resultado || ' en ResultadoRecojoDetalle',
                        'registro', NULL
                    );
                END IF;

                IF v_reg_resultado = 'RECOGIDO' THEN
                    IF v_reg_condicion NOT IN ('BUENO', 'PARA_REPARAR') THEN
                        RETURN json_build_object(
                            'error', 'Debe indicar si el regulador está BUENO o PARA_REPARAR',
                            'registro', NULL
                        );
                    END IF;

                    SELECT lo.id INTO v_id_condicion_reg
                    FROM gen_lista_opciones lo
                    INNER JOIN gen_lista l ON l.id = lo.id_lista
                    WHERE l.nombre = 'CondicionRegulador'
                      AND lo.nombre = v_reg_condicion
                      AND lo.estado = 1
                    LIMIT 1;

                    IF v_id_condicion_reg IS NULL THEN
                        RETURN json_build_object(
                            'error', 'No se encontró la condición ' || v_reg_condicion || ' en CondicionRegulador',
                            'registro', NULL
                        );
                    END IF;

                    v_cnt_recogido := v_cnt_recogido + 1;
                ELSIF v_reg_resultado = 'EXTENDIDO' THEN
                    v_cnt_extendido := v_cnt_extendido + 1;
                ELSE
                    v_cnt_no_recogido := v_cnt_no_recogido + 1;
                    v_pendientes_json := v_pendientes_json || jsonb_build_array(
                        jsonb_build_object(
                            'solo_regulador', TRUE,
                            'nueva_fecha_retorno', v_fecha_visita + 1,
                            'observacion', v_reg_obs,
                            'no_recogido', TRUE
                        )
                    );
                END IF;
            END IF;

            v_cnt_efectivo := v_cnt_total + CASE WHEN v_procesa_regulador THEN 1 ELSE 0 END;

            IF v_cnt_efectivo = 0 THEN
                RETURN json_build_object(
                    'error', 'No hay ítems para registrar en este recojo',
                    'registro', NULL
                );
            END IF;

            IF v_cnt_no_recogido = v_cnt_efectivo THEN
                v_estado_header := 'FALLIDO';
            ELSIF v_cnt_no_recogido > 0 THEN
                v_estado_header := 'REPROGRAMADO';
            ELSE
                v_estado_header := 'EXITOSO';
            END IF;

            SELECT lo.id INTO v_id_estado_header
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = v_estado_header AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_header IS NULL THEN
                RETURN json_build_object(
                    'error', 'No se encontró el estado ' || v_estado_header || ' en EstadoRecojo',
                    'registro', NULL
                );
            END IF;

            IF v_estado_header = 'FALLIDO' AND v_id_motivo IS NULL THEN
                RETURN json_build_object(
                    'error', 'Debe indicar el motivo de fallo cuando el recojo es FALLIDO',
                    'registro', NULL
                );
            END IF;

            IF v_cnt_no_recogido > 0 THEN
                SELECT MIN((elem->>'nueva_fecha_retorno')::DATE)
                INTO v_fecha_repro
                FROM jsonb_array_elements(v_pendientes_json) elem;

                v_fecha_repro := COALESCE(v_fecha_repro, v_fecha_visita + 1);

                SELECT COALESCE(
                    jsonb_agg(
                        CASE
                            WHEN NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_prestamo_detalle', (elem->>'id_prestamo_detalle')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            WHEN NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_alquiler_detalle', (elem->>'id_alquiler_detalle')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            WHEN NULLIF(elem->>'id_balon', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_balon', (elem->>'id_balon')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            ELSE NULL
                        END
                    ) FILTER (WHERE COALESCE(elem->>'solo_regulador', 'false') <> 'true'
                              AND (
                                  NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL
                                  OR NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL
                                  OR NULLIF(elem->>'id_balon', '') IS NOT NULL
                              )),
                    '[]'::JSONB
                )
                INTO v_repro_detalles
                FROM jsonb_array_elements(v_pendientes_json) elem;

                IF v_id_cliente IS NULL OR v_fecha_repro IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se puede reprogramar el recojo: faltan cliente o fecha',
                        'registro', NULL
                    );
                END IF;

                IF v_id_recarga_planta IS NULL
                   AND COALESCE(jsonb_array_length(v_repro_detalles), 0) = 0
                   AND v_id_alquiler IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se puede reprogramar el recojo: no hay pendientes válidos',
                        'registro', NULL
                    );
                END IF;
            END IF;
        END IF;

        FOR v_item IN
            SELECT * FROM jsonb_array_elements(
                CASE WHEN v_cnt_total = 0 THEN '[]'::JSONB ELSE p_detalles::JSONB END
            )
        LOOP
            v_id_pd := COALESCE(
                NULLIF(v_item->>'idPrestamoDetalle', '')::INTEGER,
                NULLIF(v_item->>'id_prestamo_detalle', '')::INTEGER
            );
            v_id_ad := COALESCE(
                NULLIF(v_item->>'idAlquilerDetalle', '')::INTEGER,
                NULLIF(v_item->>'id_alquiler_detalle', '')::INTEGER
            );
            v_id_b := COALESCE(
                NULLIF(v_item->>'idBalon', '')::INTEGER,
                NULLIF(v_item->>'id_balon', '')::INTEGER
            );
            v_resultado := UPPER(TRIM(COALESCE(
                v_item->>'resultado',
                v_item->>'nombre_resultado',
                ''
            )));
            v_nombre_contenido := NULLIF(TRIM(COALESCE(
                v_item->>'nombreEstadoContenido',
                v_item->>'nombre_estado_contenido',
                ''
            )), '');
            v_nueva_fecha := COALESCE(
                NULLIF(v_item->>'nuevaFechaRetorno', '')::DATE,
                NULLIF(v_item->>'nueva_fecha_retorno', '')::DATE
            );
            v_id_almacen := COALESCE(
                NULLIF(v_item->>'idAlmacenDestino', '')::INTEGER,
                NULLIF(v_item->>'id_almacen_destino', '')::INTEGER
            );
            v_obs := NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), '');
            v_cantidad_restante := COALESCE(
                NULLIF(v_item->>'cantidadRestante', '')::NUMERIC,
                NULLIF(v_item->>'cantidad_restante', '')::NUMERIC
            );
            v_lb_restante := COALESCE(
                NULLIF(v_item->>'lbRetorno', '')::NUMERIC,
                NULLIF(v_item->>'lb_retorno', '')::NUMERIC
            );
            v_peso_bruto_lb := COALESCE(
                NULLIF(v_item->>'pesoBrutoLb', '')::NUMERIC,
                NULLIF(v_item->>'peso_bruto_lb', '')::NUMERIC
            );
            v_presion_psi := COALESCE(
                NULLIF(v_item->>'presionActual', '')::NUMERIC,
                NULLIF(v_item->>'presion_actual', '')::NUMERIC,
                NULLIF(v_item->>'presionPsi', '')::NUMERIC,
                NULLIF(v_item->>'presion_psi', '')::NUMERIC
            );

            IF (v_id_pd IS NOT NULL)::INTEGER + (v_id_ad IS NOT NULL)::INTEGER + (v_id_b IS NOT NULL)::INTEGER <> 1 THEN
                RETURN json_build_object(
                    'error', 'Cada detalle debe indicar id_prestamo_detalle, id_alquiler_detalle o id_balon',
                    'registro', NULL
                );
            END IF;

            IF v_id_pd IS NOT NULL THEN
                IF v_id_pd = ANY(v_seen_pd) THEN
                    RETURN json_build_object(
                        'error', 'Detalle de préstamo duplicado: ' || v_id_pd,
                        'registro', NULL
                    );
                END IF;
                v_seen_pd := array_append(v_seen_pd, v_id_pd);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_prestamo_detalle = v_id_pd AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El detalle de préstamo ' || v_id_pd || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_id_ad IS NOT NULL THEN
                IF v_id_ad = ANY(v_seen_ad) THEN
                    RETURN json_build_object(
                        'error', 'Detalle de alquiler duplicado: ' || v_id_ad,
                        'registro', NULL
                    );
                END IF;
                v_seen_ad := array_append(v_seen_ad, v_id_ad);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_alquiler_detalle = v_id_ad AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El detalle de alquiler ' || v_id_ad || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_id_b IS NOT NULL THEN
                IF v_id_b = ANY(v_seen_b) THEN
                    RETURN json_build_object(
                        'error', 'Balón duplicado en el recojo: ' || v_id_b,
                        'registro', NULL
                    );
                END IF;
                v_seen_b := array_append(v_seen_b, v_id_b);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_balon = v_id_b AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El balón ' || v_id_b || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
                RETURN json_build_object(
                    'error', 'Resultado inválido: ' || COALESCE(v_resultado, '(vacío)'),
                    'registro', NULL
                );
            END IF;

            SELECT lo.id INTO v_id_resultado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'ResultadoRecojoDetalle' AND lo.nombre = v_resultado AND lo.estado = 1
            LIMIT 1;

            IF v_id_resultado IS NULL THEN
                RETURN json_build_object(
                    'error', 'No se encontró el resultado ' || v_resultado || ' en ResultadoRecojoDetalle',
                    'registro', NULL
                );
            END IF;



            IF v_resultado = 'EXTENDIDO' THEN
                v_nueva_fecha := COALESCE(v_nueva_fecha, v_fecha_visita + 1);
            END IF;

            IF v_resultado = 'RECOGIDO' THEN
                IF v_id_pd IS NOT NULL THEN
                    SELECT pd.id_balon, tb.capacidad
                    INTO v_id_balon, v_capacidad_tipo
                    FROM bal_prestamo_detalle pd
                    JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE pd.id = v_id_pd AND pd.estado = 1;
                ELSIF v_id_ad IS NOT NULL THEN
                    SELECT ad.id_balon, tb.capacidad
                    INTO v_id_balon, v_capacidad_tipo
                    FROM bal_alquiler_detalle ad
                    JOIN bal_balon b ON b.id = ad.id_balon AND b.estado = 1
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE ad.id = v_id_ad AND ad.estado = 1;
                ELSE
                    v_id_balon := v_id_b;
                    SELECT tb.capacidad
                    INTO v_capacidad_tipo
                    FROM bal_balon b
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE b.id = v_id_b AND b.estado = 1;
                END IF;

                IF v_cantidad_restante IS NULL THEN
                    IF UPPER(COALESCE(v_nombre_contenido, 'VACIO')) = 'VACIO' THEN
                        v_cantidad_restante := 0;
                    ELSIF UPPER(COALESCE(v_nombre_contenido, '')) = 'LLENO' THEN
                        v_cantidad_restante := v_capacidad_tipo;
                    END IF;
                ELSIF v_cantidad_restante < 0 THEN
                    RETURN json_build_object(
                        'error', 'La cantidad restante no puede ser negativa',
                        'registro', NULL
                    );
                ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante > v_capacidad_tipo THEN
                    RETURN json_build_object(
                        'error',
                        'La cantidad restante (' || v_cantidad_restante
                            || ') supera la capacidad del cilindro (' || v_capacidad_tipo || ')',
                        'registro', NULL
                    );
                END IF;

                IF v_nombre_contenido IS NULL AND v_cantidad_restante IS NOT NULL THEN
                    IF v_cantidad_restante <= 0 THEN
                        v_nombre_contenido := 'VACIO';
                    ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante >= v_capacidad_tipo THEN
                        v_nombre_contenido := 'LLENO';
                    ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante < v_capacidad_tipo THEN
                        v_nombre_contenido := 'SEMILLLENO';
                    ELSE
                        v_nombre_contenido := 'DESCONOCIDO';
                    END IF;
                END IF;
            ELSE
                v_cantidad_restante := NULL;
                v_id_balon := NULL;
            END IF;

            IF v_pass = 1 THEN
                IF v_resultado = 'RECOGIDO' THEN
                    v_cnt_recogido := v_cnt_recogido + 1;
                ELSIF v_resultado = 'EXTENDIDO' THEN
                    v_cnt_extendido := v_cnt_extendido + 1;
                ELSE
                    v_cnt_no_recogido := v_cnt_no_recogido + 1;
                    v_pendientes_json := v_pendientes_json || jsonb_build_array(
                        jsonb_build_object(
                            'id_prestamo_detalle', v_id_pd,
                            'id_alquiler_detalle', v_id_ad,
                            'id_balon', v_id_b,
                            'nueva_fecha_retorno', v_fecha_visita + 1,
                            'observacion', v_obs,
                            'no_recogido', TRUE
                        )
                    );
                END IF;
            ELSE
                UPDATE bal_recojo_detalle
                SET
                    id_resultado = v_id_resultado,
                    cantidad_restante = CASE
                        WHEN v_resultado = 'RECOGIDO' THEN v_cantidad_restante
                        ELSE cantidad_restante
                    END,
                    nueva_fecha_retorno = CASE
                        WHEN v_resultado = 'EXTENDIDO' THEN v_nueva_fecha
                        ELSE nueva_fecha_retorno
                    END,
                    id_almacen_destino = COALESCE(v_id_almacen, id_almacen_destino),
                    observacion = COALESCE(v_obs, observacion),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id_recojo = p_id
                  AND estado = 1
                  AND (
                      (v_id_pd IS NOT NULL AND id_prestamo_detalle = v_id_pd)
                      OR (v_id_ad IS NOT NULL AND id_alquiler_detalle = v_id_ad)
                  );

                IF v_resultado = 'RECOGIDO' THEN
                    v_dev := NULL;
                    IF v_id_pd IS NOT NULL THEN
                        SELECT pd.fecha_devolucion INTO v_ya_devuelto
                        FROM bal_prestamo_detalle pd
                        WHERE pd.id = v_id_pd AND pd.estado = 1;
                    ELSIF v_id_ad IS NOT NULL THEN
                        SELECT ad.fecha_devolucion INTO v_ya_devuelto
                        FROM bal_alquiler_detalle ad
                        WHERE ad.id = v_id_ad AND ad.estado = 1;
                    ELSE
                        v_ya_devuelto := NULL;
                    END IF;

                    IF v_ya_devuelto IS NULL THEN
                        IF v_id_pd IS NOT NULL THEN
                            v_dev := bal_devolver_prestamo_detalle(
                                v_id_pd,
                                v_fecha_visita,
                                v_id_almacen,
                                p_id_usuario_auditoria,
                                COALESCE(v_nombre_contenido, 'VACIO'),
                                v_obs
                            );
                        ELSIF v_id_ad IS NOT NULL THEN
                            v_dev := bal_devolver_alquiler_detalle(
                                v_id_ad,
                                v_fecha_visita,
                                v_id_almacen,
                                p_id_usuario_auditoria
                            );
                        ELSE
                            -- Recarga en planta externa: ingreso físico del balón al almacén
                            PERFORM bal_actualizar_balon(
                                p_id                   => v_id_balon,
                                p_id_almacen           => v_id_almacen,
                                p_id_estado_balon      => v_id_estado_en_almacen,
                                p_id_usuario_auditoria => p_id_usuario_auditoria
                            );

                            IF v_id_recarga_planta IS NOT NULL THEN
                                SELECT id_producto_gas INTO v_id_producto_gas_recojo
                                FROM bal_balon WHERE id = v_id_balon;

                                v_dev := inv_registrar_movimiento(
                                    p_naturaleza                => 'BALON',
                                    p_codigo_tipo_movimiento    => 'ENTRADA_LLENADO',
                                    p_fecha                     => LOCALTIMESTAMP,
                                    p_id_producto               => v_id_producto_gas_recojo,
                                    p_id_balon                  => v_id_balon,
                                    p_cantidad                  => COALESCE(v_cantidad_restante, NULLIF(v_capacidad_tipo, 0), 1),
                                    p_id_almacen_destino        => v_id_almacen,
                                    p_id_cliente                => v_id_cliente,
                                    p_codigo_tipo_documento_origen => 'RECARGA',
                                    p_id_documento_origen       => v_id_recarga_planta,
                                    p_glosa                     => 'Entrada por recojo de recarga en planta (orden #'
                                        || v_id_recarga_planta || ')',
                                    p_id_usuario_auditoria      => p_id_usuario_auditoria
                                );
                                IF v_dev->>'error' IS NOT NULL THEN
                                    RAISE EXCEPTION 'No se pudo registrar el movimiento de entrada del balón %: %',
                                        v_id_balon, v_dev->>'error';
                                END IF;
                            END IF;
                        END IF;
                        IF v_dev->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_dev->>'error';
                        END IF;
                    END IF;

                    IF v_id_balon IS NOT NULL AND (
                        v_peso_bruto_lb IS NOT NULL
                        OR v_lb_restante IS NOT NULL
                        OR v_cantidad_restante IS NOT NULL
                    ) THEN
                        NULL;
                    END IF;
                ELSIF v_resultado = 'EXTENDIDO' THEN
                    IF v_id_pd IS NOT NULL THEN
                        SELECT pd.id_prestamo, pd.id_balon
                        INTO v_id_prestamo_det, v_id_balon
                        FROM bal_prestamo_detalle pd
                        WHERE pd.id = v_id_pd AND pd.estado = 1;

                        UPDATE bal_prestamo_detalle
                        SET
                            fecha_vencimiento = v_nueva_fecha,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_pd AND estado = 1;

                        UPDATE bal_prestamo
                        SET
                            fecha_retorno_pactada = v_nueva_fecha,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_prestamo_det AND estado = 1;
                    ELSE
                        SELECT ad.id_alquiler, ad.id_balon
                        INTO v_id_alquiler_det, v_id_balon
                        FROM bal_alquiler_detalle ad
                        WHERE ad.id = v_id_ad AND ad.estado = 1;

                        UPDATE bal_alquiler
                        SET
                            fecha_fin_pactada = v_nueva_fecha,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_alquiler_det AND estado = 1;
                    END IF;

                    SELECT lo.id INTO v_id_estado_prestado
                    FROM gen_lista_opciones lo
                    INNER JOIN gen_lista l ON l.id = lo.id_lista
                    WHERE l.nombre = 'EstadoBalon'
                      AND lo.nombre = CASE WHEN v_id_ad IS NOT NULL THEN 'ALQUILADO' ELSE 'PRESTADO_CLIENTE' END
                      AND lo.estado = 1
                    LIMIT 1;

                    IF v_id_balon IS NOT NULL AND v_id_estado_prestado IS NOT NULL THEN
                        UPDATE bal_balon b
                        SET
                            id_estado_balon = v_id_estado_prestado,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        FROM gen_lista_opciones eb
                        WHERE b.id = v_id_balon
                          AND b.estado = 1
                          AND eb.id = b.id_estado_balon
                          AND eb.nombre = 'POR_RECOGER';
                    END IF;
                END IF;
            END IF;
        END LOOP;

        IF v_pass = 1 AND v_cnt_total > 0 THEN
            SELECT COUNT(*)::INTEGER INTO v_cnt_cubiertos
            FROM bal_recojo_detalle rd
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND (
                  (rd.id_prestamo_detalle IS NOT NULL AND rd.id_prestamo_detalle = ANY(v_seen_pd))
                  OR (rd.id_alquiler_detalle IS NOT NULL AND rd.id_alquiler_detalle = ANY(v_seen_ad))
                  OR (rd.id_balon IS NOT NULL AND rd.id_balon = ANY(v_seen_b))
              );

            IF v_cnt_cubiertos <> v_cnt_total THEN
                RETURN json_build_object(
                    'error',
                    'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
                    'registro', NULL
                );
            END IF;
        END IF;
    END LOOP;

    -- Mutación de regulador (después de validar todo el payload)
    IF v_procesa_regulador THEN
        IF v_reg_resultado = 'RECOGIDO' THEN
            v_dev := bal_devolver_regulador_alquiler(
                v_id_alquiler,
                v_fecha_visita,
                v_reg_condicion,
                v_reg_obs,
                p_id,
                p_id_usuario_auditoria
            );

            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
        ELSIF v_reg_resultado = 'EXTENDIDO' THEN
            v_reg_nueva_fecha := COALESCE(v_reg_nueva_fecha, v_fecha_visita + 1);

            UPDATE bal_alquiler
            SET
                fecha_fin_pactada = v_reg_nueva_fecha,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_alquiler AND estado = 1;
        END IF;
    END IF;

    UPDATE bal_recojo
    SET
        fecha_visita = v_fecha_visita,
        id_estado = v_id_estado_header,
        id_motivo_fallo = CASE
            WHEN v_estado_header IN ('FALLIDO', 'REPROGRAMADO') AND v_cnt_no_recogido > 0
                THEN COALESCE(v_id_motivo, id_motivo_fallo)
            WHEN v_estado_header = 'FALLIDO' THEN v_id_motivo
            ELSE id_motivo_fallo
        END,
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_resultado_regulador = COALESCE(v_id_resultado_reg, id_resultado_regulador),
        id_condicion_regulador = COALESCE(v_id_condicion_reg, id_condicion_regulador),
        nueva_fecha_retorno_regulador = CASE
            WHEN v_reg_resultado = 'EXTENDIDO' THEN v_reg_nueva_fecha
            ELSE nueva_fecha_retorno_regulador
        END,
        observacion_regulador = COALESCE(v_reg_obs, observacion_regulador),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF v_id_alquiler IS NOT NULL AND v_reg_resultado = 'RECOGIDO' THEN
        SELECT COUNT(*)::INTEGER INTO v_cil_pendientes
        FROM bal_alquiler_detalle ad
        WHERE ad.id_alquiler = v_id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL;

        IF v_cil_pendientes = 0 THEN
            SELECT lo.id INTO v_id_estado_prestado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_prestado IS NOT NULL THEN
                v_dev := bal_actualizar_alquiler(
                    v_id_alquiler,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::DATE,
                    NULL::DATE,
                    v_fecha_visita,
                    NULL::NUMERIC,
                    NULL::NUMERIC,
                    v_id_estado_prestado,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    p_id_usuario_auditoria
                );

                IF v_dev->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION '%', v_dev->>'error';
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_cnt_no_recogido > 0 THEN
        v_nuevo := bal_crear_recojo(
            v_id_cliente,
            CASE
                WHEN COALESCE(jsonb_array_length(v_repro_detalles), 0) = 0 THEN NULL
                ELSE v_id_prestamo
            END,
            v_id_alquiler,
            v_id_recarga_planta,
            v_fecha_repro,
            NULL::TIME,
            NULL::INTEGER,
            'Reprogramado desde recojo #' || p_id,
            COALESCE(v_repro_detalles, '[]'::JSONB)::JSON,
            p_id_usuario_auditoria
        );

        IF v_nuevo->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo reprogramar el recojo: %', v_nuevo->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_recojo(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/rutas-pueblos/bal_actualizar_ruta_pueblo.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_ruta_pueblo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
DROP FUNCTION IF EXISTS bal_actualizar_ruta_pueblo(p_id integer, p_fecha date, p_id_almacen integer, p_id_usuario_responsable integer, p_id_chofer integer, p_factor_lb_m3 numeric, p_tolerancia_m3 numeric, p_observacion character varying, p_estado_nombre character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_ruta_pueblo(p_id integer, p_fecha date DEFAULT NULL::date, p_id_almacen integer DEFAULT NULL::integer, p_id_usuario_responsable integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_factor_lb_m3 numeric DEFAULT NULL::numeric, p_tolerancia_m3 numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_estado_nombre character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_estado INTEGER;
    v_estado_nuevo VARCHAR;
    v_id_almacen INTEGER;
    v_det RECORD;
    v_mov JSON;
    v_sync JSON;
    v_estado_balon VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.id_almacen
    INTO v_estado, v_id_almacen
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado IN ('CERRADA', 'CANCELADA') THEN
        RETURN json_build_object('error', 'No se puede editar una ruta cerrada o cancelada', 'registro', NULL);
    END IF;

    v_estado_nuevo := NULLIF(UPPER(TRIM(COALESCE(p_estado_nombre, ''))), '');
    IF v_estado_nuevo IS NOT NULL THEN
        IF v_estado_nuevo NOT IN ('CANCELADA') THEN
            RETURN json_build_object(
                'error',
                'Use iniciar / retorno / cerrar para cambiar de estado; solo CANCELADA vía actualizar',
                'registro',
                NULL
            );
        END IF;
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'CANCELADA' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado IS NULL THEN
            RETURN json_build_object('error', 'Estado CANCELADA no configurado', 'registro', NULL);
        END IF;

        -- Si ya salió a ruta: devolver a almacén los cilindros sin retorno registrado.
        IF v_estado = 'EN_RUTA' THEN
            FOR v_det IN
                SELECT d.id_balon, d.lb_salida
                FROM bal_ruta_pueblo_detalle d
                WHERE d.id_ruta_pueblo = p_id
                  AND d.estado = 1
                  AND d.lb_retorno IS NULL
            LOOP
                SELECT eb.nombre
                INTO v_estado_balon
                FROM bal_balon b
                LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                WHERE b.id = v_det.id_balon AND b.estado = 1;

                IF v_estado_balon IS NULL THEN
                    RAISE EXCEPTION 'Cilindro % no existe o está inactivo', v_det.id_balon;
                END IF;

                -- Solo revertir si sigue en tránsito de esta ruta
                IF v_estado_balon = 'EN_RUTA_LIMA' THEN
                    v_mov := bal_registrar_salida_documento(
                        v_det.id_balon,
                        'RETORNO_LIMA',
                        p_id,
                        'RUTA_PUEBLO',
                        NULL,
                        NULL,
                        'DISPONIBLE',
                        FALSE,
                        v_id_almacen,
                        format(
                            'Cancelación ruta pueblos #%s · restaura %.4f lb de salida',
                            p_id,
                            v_det.lb_salida
                        ),
                        p_id_usuario_auditoria
                    );

                    IF v_mov->>'error' IS NOT NULL THEN
                        RAISE EXCEPTION 'Cilindro %: %', v_det.id_balon, v_mov->>'error';
                    END IF;

                    UPDATE bal_balon
                    SET
                        id_almacen = v_id_almacen,
                        id_cliente_ubicacion = NULL,
                        id_estado_balon = (
                            SELECT lo.id
                            FROM gen_lista_opciones lo
                            INNER JOIN gen_lista l ON l.id = lo.id_lista
                            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
                            LIMIT 1
                        ),
                        id_usuario_modificacion = p_id_usuario_auditoria,
                        fecha_modificacion = NOW()
                    WHERE id = v_det.id_balon AND estado = 1;


                END IF;
            END LOOP;
        END IF;
    END IF;

    UPDATE bal_ruta_pueblo
    SET
        fecha = COALESCE(p_fecha, fecha),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        id_usuario_responsable = COALESCE(p_id_usuario_responsable, id_usuario_responsable),
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        factor_lb_m3 = COALESCE(NULLIF(p_factor_lb_m3, 0), factor_lb_m3),
        tolerancia_m3 = COALESCE(NULLIF(p_tolerancia_m3, 0), tolerancia_m3),
        id_estado = COALESCE(v_id_estado, id_estado),
        observacion = CASE
            WHEN p_observacion IS NULL THEN observacion
            ELSE NULLIF(TRIM(p_observacion), '')
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/rutas-pueblos/bal_crear_ruta_pueblo.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_ruta_pueblo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.945Z
DROP FUNCTION IF EXISTS bal_crear_ruta_pueblo(p_fecha date, p_id_almacen integer, p_id_usuario_responsable integer, p_id_chofer integer, p_factor_lb_m3 numeric, p_tolerancia_m3 numeric, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_ruta_pueblo(p_fecha date DEFAULT NULL::date, p_id_almacen integer DEFAULT NULL::integer, p_id_usuario_responsable integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_factor_lb_m3 numeric DEFAULT NULL::numeric, p_tolerancia_m3 numeric DEFAULT NULL::numeric, p_observacion character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_lb_salida NUMERIC;
    v_sellado BOOLEAN;
    v_item INTEGER := 0;
    v_balones INTEGER[] := ARRAY[]::INTEGER[];
    v_estado_balon VARCHAR;
    v_id_almacen_balon INTEGER;
    v_factor NUMERIC;
    v_tolerancia NUMERIC;
    v_cap_m3 NUMERIC;
    v_cap_lb NUMERIC;
    v_factor_tipo NUMERIC;
    v_factores NUMERIC[] := ARRAY[]::NUMERIC[];
    v_nombre_tipo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_almacen IS NULL THEN
        RETURN json_build_object('error', 'El almacén es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1) THEN
        RETURN json_build_object('error', 'Almacén inválido', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe registrar al menos un cilindro con libras de salida', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'ABIERTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Estado ABIERTA no configurado', 'registro', NULL);
    END IF;

    -- Tolerancia: parámetro opcional o default de empresa
    SELECT COALESCE(
        NULLIF(p_tolerancia_m3, 0),
        e.tolerancia_m3_ruta_pueblo,
        0.5000
    )
    INTO v_tolerancia
    FROM gen_empresa e
    WHERE e.estado = 1
    ORDER BY e.id
    LIMIT 1;

    IF v_tolerancia IS NULL THEN
        v_tolerancia := COALESCE(NULLIF(p_tolerancia_m3, 0), 0.5000);
    END IF;

    -- Validar cilindros y derivar factor por tipo (capacidad m³ / capacidad lb)
    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_item := v_item + 1;
        v_id_balon := COALESCE(
            (v_detalle->>'idBalon')::INTEGER,
            (v_detalle->>'id_balon')::INTEGER
        );
        v_lb_salida := COALESCE(
            (v_detalle->>'lbSalida')::NUMERIC,
            (v_detalle->>'lb_salida')::NUMERIC
        );

        IF v_id_balon IS NULL THEN
            RAISE EXCEPTION 'Ítem %: cilindro obligatorio', v_item;
        END IF;

        IF v_lb_salida IS NULL OR v_lb_salida < 0 THEN
            RAISE EXCEPTION 'Ítem %: libras de salida inválidas', v_item;
        END IF;

        IF v_id_balon = ANY (v_balones) THEN
            RAISE EXCEPTION 'El cilindro % está duplicado en la ruta', v_id_balon;
        END IF;
        v_balones := array_append(v_balones, v_id_balon);

        SELECT eb.nombre, b.id_almacen, tb.capacidad, tb.capacidad_lb, tb.nombre
        INTO v_estado_balon, v_id_almacen_balon, v_cap_m3, v_cap_lb, v_nombre_tipo
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
        WHERE b.id = v_id_balon AND b.estado = 1;

        IF v_estado_balon IS NULL THEN
            RAISE EXCEPTION 'Cilindro % no existe o está inactivo', v_id_balon;
        END IF;

        IF v_estado_balon NOT IN ('DISPONIBLE') THEN
            RAISE EXCEPTION 'Cilindro % debe estar en almacén (estado actual: %)', v_id_balon, v_estado_balon;
        END IF;

        IF v_id_almacen_balon IS DISTINCT FROM p_id_almacen THEN
            RAISE EXCEPTION 'Cilindro % no está en el almacén de la ruta', v_id_balon;
        END IF;

        IF v_cap_m3 IS NULL OR v_cap_m3 <= 0 OR v_cap_lb IS NULL OR v_cap_lb <= 0 THEN
            RAISE EXCEPTION
                'El tipo "%" del cilindro % no tiene capacidad m³ y lb configuradas. Edítalo en Tipos de balón.',
                COALESCE(v_nombre_tipo, '(sin tipo)'),
                v_id_balon;
        END IF;

        IF v_lb_salida > v_cap_lb THEN
            RAISE EXCEPTION
                'Cilindro %: libras de salida (%.4f) no pueden superar la capacidad lb del tipo "%" (%.4f)',
                v_id_balon,
                v_lb_salida,
                COALESCE(v_nombre_tipo, '(sin tipo)'),
                v_cap_lb;
        END IF;

        v_factor_tipo := ROUND(v_cap_m3 / v_cap_lb, 6);
        v_factores := array_append(v_factores, v_factor_tipo);

        IF EXISTS (
            SELECT 1
            FROM bal_ruta_pueblo_detalle d
            INNER JOIN bal_ruta_pueblo r ON r.id = d.id_ruta_pueblo AND r.estado = 1
            INNER JOIN gen_lista_opciones er ON er.id = r.id_estado
            WHERE d.id_balon = v_id_balon
              AND d.estado = 1
              AND er.nombre IN ('ABIERTA', 'EN_RUTA')
        ) THEN
            RAISE EXCEPTION 'Cilindro % ya está en otra ruta abierta/en tránsito', v_id_balon;
        END IF;
    END LOOP;

    -- Snapshot del factor: parámetro explícito o promedio de tipos de la ruta
    IF NULLIF(p_factor_lb_m3, 0) IS NOT NULL THEN
        v_factor := p_factor_lb_m3;
    ELSE
        SELECT ROUND(AVG(f), 6) INTO v_factor
        FROM unnest(v_factores) AS f;
    END IF;

    INSERT INTO bal_ruta_pueblo (
        fecha, id_almacen, id_usuario_responsable, id_chofer,
        factor_lb_m3, tolerancia_m3, id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        COALESCE(p_fecha, CURRENT_DATE),
        p_id_almacen,
        p_id_usuario_responsable,
        p_id_chofer,
        v_factor,
        v_tolerancia,
        v_id_estado,
        NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_balon := COALESCE(
            (v_detalle->>'idBalon')::INTEGER,
            (v_detalle->>'id_balon')::INTEGER
        );
        v_lb_salida := COALESCE(
            (v_detalle->>'lbSalida')::NUMERIC,
            (v_detalle->>'lb_salida')::NUMERIC
        );
        v_sellado := COALESCE(
            (v_detalle->>'sellado')::BOOLEAN,
            FALSE
        );

        INSERT INTO bal_ruta_pueblo_detalle (
            id_ruta_pueblo, id_balon, sellado, lb_salida, observacion,
            id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id,
            v_id_balon,
            v_sellado,
            v_lb_salida,
            NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        );
    END LOOP;

    RETURN bal_obtener_ruta_pueblo(v_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/rutas-pueblos/bal_registrar_retorno_ruta_pueblo.sql
-- ============================================================

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_registrar_retorno_ruta_pueblo
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.949Z
DROP FUNCTION IF EXISTS bal_registrar_retorno_ruta_pueblo(p_id integer, p_detalles json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_registrar_retorno_ruta_pueblo(p_id integer, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_almacen INTEGER;
    v_factor_ruta NUMERIC;
    v_factor NUMERIC;
    v_detalle JSON;
    v_id_balon INTEGER;
    v_lb_retorno NUMERIC;
    v_id_det INTEGER;
    v_lb_salida NUMERIC;
    v_lb_retorno_existente NUMERIC;
    v_m3_delta NUMERIC;
    v_restante_m3 NUMERIC;
    v_mov JSON;
    v_cap_m3 NUMERIC;
    v_cap_lb NUMERIC;
    v_sync JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.id_almacen, r.factor_lb_m3
    INTO v_estado, v_id_almacen, v_factor_ruta
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado NOT IN ('EN_RUTA', 'ABIERTA') THEN
        RETURN json_build_object('error', 'Solo se registra retorno en rutas ABIERTA o EN_RUTA', 'registro', NULL);
    END IF;

    -- Si aún ABIERTA, iniciar primero (salida física)
    IF v_estado = 'ABIERTA' THEN
        PERFORM bal_iniciar_ruta_pueblo(p_id, p_id_usuario_auditoria);
        SELECT er.nombre, r.id_almacen, r.factor_lb_m3
        INTO v_estado, v_id_almacen, v_factor_ruta
        FROM bal_ruta_pueblo r
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        WHERE r.id = p_id AND r.estado = 1;
    END IF;

    IF p_detalles IS NULL OR json_typeof(p_detalles) <> 'array' OR json_array_length(p_detalles) = 0 THEN
        RETURN json_build_object('error', 'Debe indicar libras de retorno por cilindro', 'registro', NULL);
    END IF;

    FOR v_detalle IN SELECT value FROM json_array_elements(p_detalles)
    LOOP
        v_id_balon := COALESCE(
            (v_detalle->>'idBalon')::INTEGER,
            (v_detalle->>'id_balon')::INTEGER
        );
        v_lb_retorno := COALESCE(
            (v_detalle->>'lbRetorno')::NUMERIC,
            (v_detalle->>'lb_retorno')::NUMERIC
        );

        IF v_id_balon IS NULL OR v_lb_retorno IS NULL OR v_lb_retorno < 0 THEN
            RAISE EXCEPTION 'Cada ítem requiere idBalon y lbRetorno ≥ 0';
        END IF;

        SELECT d.id, d.lb_salida, d.lb_retorno
        INTO v_id_det, v_lb_salida, v_lb_retorno_existente
        FROM bal_ruta_pueblo_detalle d
        WHERE d.id_ruta_pueblo = p_id
          AND d.id_balon = v_id_balon
          AND d.estado = 1;

        IF v_id_det IS NULL THEN
            RAISE EXCEPTION 'Cilindro % no pertenece a esta ruta', v_id_balon;
        END IF;

        -- Idempotente: no reprocesar cilindros ya retornados
        IF v_lb_retorno_existente IS NOT NULL THEN
            CONTINUE;
        END IF;

        IF v_lb_retorno > v_lb_salida THEN
            RAISE EXCEPTION 'Cilindro %: lb retorno (%.4f) no puede superar lb salida (%.4f)',
                v_id_balon, v_lb_retorno, v_lb_salida;
        END IF;

        -- Factor por tipo del cilindro; fallback al snapshot de la ruta
        SELECT tb.capacidad, tb.capacidad_lb
        INTO v_cap_m3, v_cap_lb
        FROM bal_balon b
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon AND tb.estado = 1
        WHERE b.id = v_id_balon AND b.estado = 1;

        IF v_cap_m3 IS NOT NULL AND v_cap_m3 > 0 AND v_cap_lb IS NOT NULL AND v_cap_lb > 0 THEN
            v_factor := ROUND(v_cap_m3 / v_cap_lb, 6);
        ELSE
            v_factor := COALESCE(v_factor_ruta, 0.317400);
        END IF;

        v_m3_delta := ROUND((v_lb_salida - v_lb_retorno) * v_factor, 4);
        v_restante_m3 := ROUND(v_lb_retorno * v_factor, 4);

        UPDATE bal_ruta_pueblo_detalle
        SET
            lb_retorno = v_lb_retorno,
            m3_delta = v_m3_delta,
            observacion = COALESCE(
                NULLIF(TRIM(COALESCE(v_detalle->>'observacion', '')), ''),
                observacion
            ),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_det;

        -- Retorno a almacén con residual (CY4: no forzar vacío)
        v_mov := bal_registrar_salida_documento(
            v_id_balon,
            'RETORNO_LIMA',
            p_id,
            'RUTA_PUEBLO',
            NULL,
            NULL,
            'DISPONIBLE',
            FALSE,
            v_id_almacen,
            format('Retorno ruta pueblos #%s · %.4f lb residual', p_id, v_lb_retorno),
            p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            -- Si ya existe movimiento retorno idempotente, igual actualizamos balón
            NULL;
        END IF;

        UPDATE bal_balon
        SET
            id_almacen = v_id_almacen,
            id_cliente_ubicacion = NULL,
            id_estado_balon = (
                SELECT lo.id
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON l.id = lo.id_lista
                WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
                LIMIT 1
            ),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon AND estado = 1;


    END LOOP;

    UPDATE bal_ruta_pueblo
    SET
        m3_calculado = (
            SELECT COALESCE(SUM(d.m3_delta), 0)
            FROM bal_ruta_pueblo_detalle d
            WHERE d.id_ruta_pueblo = p_id AND d.estado = 1 AND d.lb_retorno IS NOT NULL
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;
