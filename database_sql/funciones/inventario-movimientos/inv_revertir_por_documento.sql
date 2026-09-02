-- Revierte todos los inv_movimiento activos ligados a un documento origen
-- (stock de producto/gas + custodia de balón), y los da de baja lógica.
CREATE OR REPLACE FUNCTION inv_revertir_por_documento(
    p_codigo_tipo_documento_origen VARCHAR,
    p_id_documento_origen INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
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
        ORDER BY id
        FOR UPDATE
    LOOP
        SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
        v_es_salida := (v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo < v_mov.stock_anterior)
                       OR (v_nombre_tipo_mov ILIKE '%SALIDA%');
        v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
        IF v_es_traslado THEN
            v_es_salida := TRUE;
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

        -- Revertir custodia de balón a EN_ALMACEN.
        IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_en_almacen IS NOT NULL THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_id_estado_en_almacen,
                    id_cliente_ubicacion = NULL,
                    id_almacen = COALESCE(v_mov.id_almacen_origen, v_mov.id_almacen_destino, id_almacen),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_mov.id_balon AND estado = 1;
            END IF;
        END IF;

        UPDATE inv_movimiento
        SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_mov.id;

        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object('revertidos', v_count);
END;
$function$;
