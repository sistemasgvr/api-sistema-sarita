-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_crear_movimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.772Z
DROP FUNCTION IF EXISTS pro_crear_movimiento(p_fecha date, p_id_producto integer, p_id_almacen integer, p_id_tipo_movimiento integer, p_cantidad numeric, p_id_documento_ref integer, p_id_tipo_documento_ref integer, p_glosa character varying, p_id_usuario_auditoria integer, p_forzar_ajuste_stock boolean, p_id_almacen_destino integer, p_sentido_ajuste character varying);

CREATE OR REPLACE FUNCTION pro_crear_movimiento(p_fecha date, p_id_producto integer, p_id_almacen integer, p_id_tipo_movimiento integer, p_cantidad numeric, p_id_documento_ref integer DEFAULT NULL::integer, p_id_tipo_documento_ref integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_forzar_ajuste_stock boolean DEFAULT false, p_id_almacen_destino integer DEFAULT NULL::integer, p_sentido_ajuste character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_stock INTEGER;
    v_id_stock_dest INTEGER;
    v_stock_anterior NUMERIC(12,4);
    v_stock_nuevo NUMERIC(12,4);
    v_stock_dest_ant NUMERIC(12,4);
    v_cantidad NUMERIC(12,4);
    v_afecta_stock BOOLEAN;
    v_nombre_tipo_movimiento VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha del movimiento es obligatoria', 'registro', NULL);
    END IF;

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_movimiento AND estado = 1) THEN
        RETURN json_build_object('error', 'El tipo de movimiento indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    SELECT
        COALESCE(p.afecta_stock, FALSE),
        REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
        COALESCE(p.es_gas, FALSE)
    INTO v_afecta_stock, v_nombre_unidad, v_es_gas
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = p_id_producto;

    IF COALESCE(p_forzar_ajuste_stock, FALSE) THEN
        v_afecta_stock := TRUE;
    END IF;

    IF NOT COALESCE(v_es_gas, FALSE)
       AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
       AND p_cantidad <> TRUNC(p_cantidad)
    THEN
        RETURN json_build_object(
            'error', 'La cantidad debe ser entera (unidad de medida UNID)',
            'registro', NULL
        );
    END IF;

    SELECT nombre INTO v_nombre_tipo_movimiento
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_movimiento;

    v_cantidad := ABS(p_cantidad);
    v_es_traslado := UPPER(COALESCE(v_nombre_tipo_movimiento, '')) = 'TRASLADO';
    v_es_salida := v_nombre_tipo_movimiento ILIKE '%SALIDA%';

    IF UPPER(COALESCE(v_nombre_tipo_movimiento, '')) = 'AJUSTE'
       AND UPPER(TRIM(COALESCE(p_sentido_ajuste, ''))) = 'MENOS'
    THEN
        v_es_salida := TRUE;
    END IF;

    IF v_es_traslado THEN
        IF p_id_almacen_destino IS NULL THEN
            RETURN json_build_object('error', 'El traslado requiere almacén de destino', 'registro', NULL);
        END IF;
        IF p_id_almacen_destino = p_id_almacen THEN
            RETURN json_build_object('error', 'El almacén de destino debe ser distinto al de origen', 'registro', NULL);
        END IF;
        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1) THEN
            RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'registro', NULL);
        END IF;
        v_es_salida := TRUE;
    END IF;

    v_stock_anterior := 0;
    v_stock_nuevo := 0;

    IF v_afecta_stock THEN
        SELECT id, stock INTO v_id_stock, v_stock_anterior
        FROM pro_stock
        WHERE id_almacen = p_id_almacen
          AND id_producto = p_id_producto
          AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            INSERT INTO pro_stock (
                id_almacen, id_producto, stock, stock_minimo,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id_almacen, p_id_producto, 0, 0,
                p_id_usuario_auditoria, p_id_usuario_auditoria
            )
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
        SET stock = v_stock_nuevo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_stock;

        IF v_es_traslado THEN
            SELECT id, stock INTO v_id_stock_dest, v_stock_dest_ant
            FROM pro_stock
            WHERE id_almacen = p_id_almacen_destino
              AND id_producto = p_id_producto
              AND estado = 1
            FOR UPDATE;

            IF v_id_stock_dest IS NULL THEN
                INSERT INTO pro_stock (
                    id_almacen, id_producto, stock, stock_minimo,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id_almacen_destino, p_id_producto, 0, 0,
                    p_id_usuario_auditoria, p_id_usuario_auditoria
                )
                RETURNING id, stock INTO v_id_stock_dest, v_stock_dest_ant;
            END IF;

            UPDATE pro_stock
            SET stock = COALESCE(v_stock_dest_ant, 0) + v_cantidad,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_stock_dest;
        END IF;
    END IF;

    INSERT INTO pro_movimientos (
        fecha, id_producto, id_almacen, id_tipo_movimiento, cantidad,
        stock_anterior, stock_nuevo, id_documento_ref, id_tipo_documento_ref,
        glosa, id_almacen_destino,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_fecha, p_id_producto, p_id_almacen, p_id_tipo_movimiento, v_cantidad,
        CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
        CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
        p_id_documento_ref, p_id_tipo_documento_ref, p_glosa, p_id_almacen_destino,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_movimiento(v_id);
END;
$function$
