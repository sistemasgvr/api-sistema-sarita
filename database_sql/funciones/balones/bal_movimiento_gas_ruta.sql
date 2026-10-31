-- Gas de una ruta manual: un movimiento por cilindro y etapa, en m³, sin convertir libras.
CREATE OR REPLACE FUNCTION public.bal_movimiento_gas_ruta(
    p_id_detalle integer, p_es_retorno boolean, p_id_usuario_auditoria integer DEFAULT NULL
) RETURNS void LANGUAGE plpgsql AS $function$
DECLARE
    v_d RECORD;
    v_cantidad NUMERIC;
    v_mov JSON;
BEGIN
    -- INACTIVO 2026-10-31: Ruta pueblos es un registro histórico sin efecto en inventario.
    -- Conservar este bloque para una futura reactivación coordinada y conciliada.
    --     SELECT d.id, d.id_ruta_pueblo, d.id_producto_gas, d.m3_salida, d.m3_retorno,
    --            r.id_almacen, r.control_gas_manual, b.codigo_balon,
    --            p.nombre AS producto, p.es_gas, p.afecta_stock, p.estado AS estado_producto,
    --            UPPER(TRIM(um.nombre)) AS unidad
    --     INTO v_d
    --     FROM bal_ruta_pueblo_detalle d
    --     JOIN bal_ruta_pueblo r ON r.id = d.id_ruta_pueblo AND r.estado = 1
    --     JOIN bal_balon b ON b.id = d.id_balon
    --     LEFT JOIN pro_producto p ON p.id = d.id_producto_gas
    --     LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    --     WHERE d.id = p_id_detalle AND d.estado = 1;
    --     IF NOT FOUND OR NOT v_d.control_gas_manual THEN
    --         RAISE EXCEPTION 'El detalle % no pertenece a una ruta con control manual de gas', p_id_detalle;
    --     END IF;
    --     IF v_d.id_producto_gas IS NULL OR v_d.estado_producto IS DISTINCT FROM 1
    --        OR v_d.es_gas IS DISTINCT FROM TRUE OR v_d.afecta_stock IS DISTINCT FROM TRUE
    --        OR COALESCE(v_d.unidad, '') NOT IN ('MT3', 'M3', 'M³') THEN
    --         RAISE EXCEPTION 'Cilindro %: el producto gas debe estar activo, afectar stock y tener unidad m³.', v_d.codigo_balon;
    --     END IF;
    --     v_cantidad := CASE WHEN p_es_retorno THEN v_d.m3_retorno ELSE v_d.m3_salida END;
    --     IF v_cantidad IS NULL OR v_cantidad < 0 OR v_cantidad::TEXT IN ('NaN', 'Infinity', '-Infinity') THEN
    --         RAISE EXCEPTION 'Cilindro %: faltan los m³ manuales de %',
    --             v_d.codigo_balon, CASE WHEN p_es_retorno THEN 'retorno' ELSE 'salida' END;
    --     END IF;
    --     IF v_cantidad = 0 THEN RETURN; END IF;
    --     v_mov := inv_registrar_movimiento(
    --         p_naturaleza => 'PRODUCTO',
    --         p_codigo_tipo_movimiento => CASE WHEN p_es_retorno THEN 'ENTRADA_RETORNO_RUTA_PUEBLO' ELSE 'SALIDA_RUTA_PUEBLO' END::VARCHAR,
    --         p_id_producto => v_d.id_producto_gas,
    --         p_cantidad => v_cantidad,
    --         p_id_almacen_origen => v_d.id_almacen,
    --         p_codigo_tipo_documento_origen => 'RUTA_PUEBLO',
    --         p_id_documento_origen => v_d.id_ruta_pueblo,
    --         p_id_documento_detalle => v_d.id,
    --         p_glosa => format('%s ruta pueblos #%s · cilindro %s · %s m³ manuales de %s',
    --             CASE WHEN p_es_retorno THEN 'Retorno' ELSE 'Salida' END,
    --             v_d.id_ruta_pueblo, v_d.codigo_balon, v_cantidad, v_d.producto)::VARCHAR,
    --         p_id_usuario_auditoria => p_id_usuario_auditoria
    --     );
    --     IF v_mov->>'error' IS NOT NULL THEN
    --         RAISE EXCEPTION 'Cilindro % (%): %', v_d.codigo_balon, v_d.producto, v_mov->>'error';
    --     END IF;
    RETURN;
END;
$function$;
