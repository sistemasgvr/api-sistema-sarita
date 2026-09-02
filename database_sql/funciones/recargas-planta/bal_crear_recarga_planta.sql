-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_recarga_planta
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.537Z
DROP FUNCTION IF EXISTS bal_crear_recarga_planta(p_fecha_salida date, p_id_proveedor integer, p_id_almacen integer, p_id_guia_salida integer, p_serie_guia_salida character varying, p_numero_guia_salida character varying, p_observacion character varying, p_confirmar_salida boolean, p_detalles json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_recarga_planta(p_fecha_salida date, p_id_proveedor integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_guia_salida integer DEFAULT NULL::integer, p_serie_guia_salida character varying DEFAULT NULL::character varying, p_numero_guia_salida character varying DEFAULT NULL::character varying, p_observacion character varying DEFAULT NULL::character varying, p_confirmar_salida boolean DEFAULT true, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_numero VARCHAR(30);
    v_id_estado INTEGER;
    v_estado_nombre VARCHAR := CASE WHEN COALESCE(p_confirmar_salida, TRUE) THEN 'ENVIADO' ELSE 'BORRADOR' END;
    v_serie VARCHAR(10);
    v_numero_guia VARCHAR(15);
    v_proveedor INTEGER;
    v_almacen INTEGER;
    v_item JSON;
    v_id_balon INTEGER;
    v_id_producto INTEGER;
    v_capacidad NUMERIC;
    v_id_um INTEGER;
    v_id_det INTEGER;
    v_mov JSON;
    v_id_mov INTEGER;
    v_es_empresa BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_salida IS NULL THEN
        RETURN json_build_object('error', 'La fecha de salida es obligatoria', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
        RETURN json_build_object('error', 'Debe indicar al menos un cilindro en el detalle', 'registro', NULL);
    END IF;

    v_serie := NULLIF(TRIM(p_serie_guia_salida), '');
    v_numero_guia := NULLIF(TRIM(p_numero_guia_salida), '');
    v_proveedor := p_id_proveedor;
    v_almacen := p_id_almacen;

    IF p_id_guia_salida IS NOT NULL THEN
        IF NOT EXISTS (SELECT 1 FROM gre_guia_remision WHERE id = p_id_guia_salida AND estado = 1) THEN
            RETURN json_build_object('error', 'La guía de remisión de salida no existe', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_recarga_planta rp
            LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
            WHERE rp.id_guia_salida = p_id_guia_salida
              AND rp.estado = 1
              AND COALESCE(est.nombre, '') NOT IN ('ANULADO')
        ) THEN
            RETURN json_build_object(
                'error',
                'Ya existe una orden de recarga activa vinculada a esa guía de remisión',
                'registro',
                NULL
            );
        END IF;

        -- Con FK a la GRE la guía es la única fuente: no se copian serie/número
        -- (las lecturas los resuelven por JOIN). El texto libre queda reservado
        -- para órdenes cuya guía no existe como documento en el sistema.
        v_serie := NULL;
        v_numero_guia := NULL;

        SELECT
            COALESCE(v_proveedor, g.id_destinatario, g.id_cliente),
            COALESCE(v_almacen, g.id_almacen)
        INTO v_proveedor, v_almacen
        FROM gre_guia_remision g
        WHERE g.id = p_id_guia_salida;
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = v_estado_nombre AND lo.estado = 1
    LIMIT 1;

    INSERT INTO bal_recarga_planta (
        numero, fecha_salida, id_proveedor, id_almacen,
        id_guia_salida, serie_guia_salida, numero_guia_salida,
        id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        NULL, p_fecha_salida, v_proveedor, v_almacen,
        p_id_guia_salida, v_serie, v_numero_guia,
        v_id_estado, NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    v_numero := 'RP-' || TO_CHAR(p_fecha_salida, 'YYYYMMDD') || '-' || LPAD(v_id::TEXT, 4, '0');
    UPDATE bal_recarga_planta SET numero = v_numero WHERE id = v_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles::JSONB)
    LOOP
        v_id_balon := NULLIF(v_item->>'idBalon', '')::INTEGER;
        IF v_id_balon IS NULL THEN
            v_id_balon := NULLIF(v_item->>'id_balon', '')::INTEGER;
        END IF;

        IF v_id_balon IS NULL THEN
            RETURN json_build_object('error', 'Detalle sin cilindro', 'registro', NULL);
        END IF;

        SELECT COALESCE(prop.nombre, '') = 'EMPRESA'
        INTO v_es_empresa
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones prop ON prop.id = b.id_propietario
        WHERE b.id = v_id_balon AND b.estado = 1;

        IF NOT COALESCE(v_es_empresa, FALSE) THEN
            RETURN json_build_object(
                'error',
                'Solo cilindros de propiedad EMPRESA pueden ir a planta externa',
                'registro',
                NULL
            );
        END IF;

        v_id_producto := COALESCE(
            NULLIF(v_item->>'idProducto', '')::INTEGER,
            NULLIF(v_item->>'id_producto', '')::INTEGER
        );
        v_capacidad := COALESCE(
            NULLIF(v_item->>'capacidad', '')::NUMERIC,
            NULLIF(v_item->>'capacidad', '')::NUMERIC
        );
        v_id_um := COALESCE(
            NULLIF(v_item->>'idUnidadMedida', '')::INTEGER,
            NULLIF(v_item->>'id_unidad_medida', '')::INTEGER
        );

        IF v_id_producto IS NULL OR v_capacidad IS NULL OR v_id_um IS NULL THEN
            SELECT
                COALESCE(v_id_producto, b.id_producto_gas),
                COALESCE(v_capacidad, tb.capacidad),
                COALESCE(v_id_um, tb.id_unidad_medida)
            INTO v_id_producto, v_capacidad, v_id_um
            FROM bal_balon b
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            WHERE b.id = v_id_balon;
        END IF;

        INSERT INTO bal_recarga_planta_detalle (
            id_recarga_planta, id_balon, id_producto, capacidad, id_unidad_medida,
            observacion, id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            v_id, v_id_balon, v_id_producto, v_capacidad, v_id_um,
            NULLIF(TRIM(v_item->>'observacion'), ''),
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_det;

        IF COALESCE(p_confirmar_salida, TRUE) THEN
            v_mov := bal_crear_movimiento_recarga(
                p_fecha_salida,
                v_id_balon,
                v_id_producto,
                v_capacidad,
                v_id_um,
                v_serie,
                v_numero_guia,
                NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
                v_proveedor,
                NULLIF(TRIM(p_observacion), ''),
                v_almacen,
                NULL,
                p_id_usuario_auditoria
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_mov->>'error', 'registro', NULL);
            END IF;

            v_id_mov := (v_mov->'registro'->>'id')::INTEGER;

            UPDATE bal_recarga_planta_detalle
            SET id_movimiento_recarga = v_id_mov
            WHERE id = v_id_det;

            UPDATE bal_movimiento_recarga
            SET id_recarga_planta = v_id
            WHERE id = v_id_mov;
        END IF;
    END LOOP;

    RETURN bal_obtener_recarga_planta(v_id);
END;
$function$
