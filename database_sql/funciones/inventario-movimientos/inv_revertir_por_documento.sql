-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_revertir_por_documento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
-- p_codigo_tipo_movimiento / p_naturaleza (2026-09-10): filtros opcionales
-- para revertir solo una parte de lo que movió un documento. Los necesita la
-- anulación de compras: la orden de planta tiene SALIDA_PLANTA_EXTERNA (ida) y
-- ENTRADA_PLANTA_EXTERNA (retorno) bajo el mismo origen ORDEN_SALIDA, y
-- revertir "todo el documento" deshacía también la ida. Van al final de la
-- firma para no romper las llamadas posicionales existentes.
DROP FUNCTION IF EXISTS inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer, p_id_documento_detalle integer);
DROP FUNCTION IF EXISTS inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer, p_id_documento_detalle integer, p_codigo_tipo_movimiento character varying, p_naturaleza character varying);

CREATE OR REPLACE FUNCTION inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_documento_detalle integer DEFAULT NULL::integer, p_codigo_tipo_movimiento character varying DEFAULT NULL::character varying, p_naturaleza character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_id_tipo_mov INTEGER;
    v_naturaleza VARCHAR;
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

    -- Filtro opcional por tipo de movimiento (TipoMovInvUnificado).
    IF NULLIF(TRIM(COALESCE(p_codigo_tipo_movimiento, '')), '') IS NOT NULL THEN
        SELECT lo.id INTO v_id_tipo_mov
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInvUnificado'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_movimiento))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_mov IS NULL THEN
            RETURN json_build_object(
                'revertidos', 0,
                'error', format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_movimiento)))
            );
        END IF;
    END IF;

    v_naturaleza := NULLIF(UPPER(TRIM(COALESCE(p_naturaleza, ''))), '');

    FOR v_mov IN
        SELECT * FROM inv_movimiento
        WHERE estado = 1
          AND id_tipo_documento_origen = v_id_tipo_doc
          AND id_documento_origen = p_id_documento_origen
          AND (p_id_documento_detalle IS NULL OR id_documento_detalle = p_id_documento_detalle)
          AND (v_id_tipo_mov IS NULL OR id_tipo_movimiento = v_id_tipo_mov)
          AND (v_naturaleza IS NULL OR naturaleza = v_naturaleza)
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
        -- Misma estrictitud que inv_eliminar_movimiento: si no se puede revertir
        -- el stock, NO soft-deletear el movimiento (RAISE → rollback).
        IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
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
                RAISE EXCEPTION
                    'No se encontró el registro de stock para revertir el movimiento %',
                    v_mov.id;
            END IF;

            v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
            IF v_stock_revertido < 0 THEN
                RAISE EXCEPTION
                    'No se puede revertir el movimiento % porque dejaría stock negativo',
                    v_mov.id;
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
                    RAISE EXCEPTION
                        'No se encontró el stock de destino para revertir el traslado %',
                        v_mov.id;
                END IF;

                v_stock_revertido := v_stock_actual - v_mov.cantidad;
                IF v_stock_revertido < 0 THEN
                    RAISE EXCEPTION
                        'No se puede revertir el traslado % porque el destino ya no tiene esa cantidad',
                        v_mov.id;
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
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
