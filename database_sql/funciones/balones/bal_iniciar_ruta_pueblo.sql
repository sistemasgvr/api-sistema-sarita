-- Inicia el registro histórico de una ruta; no mueve stock ni cilindros.
DROP FUNCTION IF EXISTS public.bal_iniciar_ruta_pueblo (p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.bal_iniciar_ruta_pueblo (
  p_id integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_estado VARCHAR;
    v_manual BOOLEAN;
    v_id_almacen INTEGER;
    v_id_estado_ruta INTEGER;
    v_det RECORD;
    v_mov JSON;
    v_det_prod RECORD;
    v_stock_record RECORD;
    v_stock_anterior NUMERIC;
    v_stock_nuevo NUMERIC;
    v_id_unidad_medida INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.id_almacen, r.control_gas_manual
    INTO v_estado, v_id_almacen, v_manual
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1
    FOR UPDATE OF r;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado <> 'ABIERTA' THEN
        RETURN json_build_object('error', 'Solo se puede iniciar una ruta ABIERTA', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_ruta_pueblo_detalle WHERE id_ruta_pueblo = p_id AND estado = 1
    ) AND NOT EXISTS (
        SELECT 1 FROM bal_ruta_pueblo_detalle_producto WHERE id_ruta_pueblo = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La ruta no tiene cilindros ni productos', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_ruta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'EN_RUTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_ruta IS NULL THEN RAISE EXCEPTION 'Estado EN_RUTA no configurado'; END IF;

    -- INACTIVO 2026-10-31: Ruta pueblos es un registro histórico sin efecto en inventario.
    -- Conservar este bloque para una futura reactivación coordinada y conciliada.
    --     IF v_manual THEN
    --         PERFORM bal_validar_capacidad_salida_ruta(d.id_balon, d.m3_salida)
    --         FROM bal_ruta_pueblo_detalle d WHERE d.id_ruta_pueblo = p_id AND d.estado = 1;
    --         -- Revalidar y bloquear el saldo actual: puede haber cambiado desde la creación.
    --         PERFORM bal_validar_stock_salida_ruta(p_id, TRUE);
    --     END IF;
    --
    --     FOR v_det IN
    --         SELECT d.id, d.id_balon, d.lb_salida, d.m3_salida, d.id_producto_gas
    --         FROM bal_ruta_pueblo_detalle d
    --         WHERE d.id_ruta_pueblo = p_id AND d.estado = 1
    --     LOOP
    --         IF v_manual THEN
    --             PERFORM 1 FROM bal_balon b LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    --             JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    --             WHERE b.id = v_det.id_balon AND b.estado = 1 AND b.id_almacen = v_id_almacen AND eb.nombre = 'DISPONIBLE'
    --               AND COALESCE(b.id_producto_gas, tb.id_gas) = v_det.id_producto_gas
    --             FOR UPDATE OF b;
    --             IF NOT FOUND THEN
    --                 RAISE EXCEPTION 'El cilindro % ya no está disponible en el almacén de la ruta o cambió de producto gas', v_det.id_balon;
    --             END IF;
    --             PERFORM bal_movimiento_gas_ruta(v_det.id, FALSE, p_id_usuario_auditoria);
    --         END IF;
    --         v_mov := bal_registrar_salida_documento(
    --             v_det.id_balon,
    --             'TRASLADO_LIMA',
    --             p_id,
    --             'RUTA_PUEBLO',
    --             NULL,
    --             v_id_almacen,
    --             'EN_RUTA_LIMA',
    --             TRUE,
    --             NULL,
    --             format('Salida ruta pueblos #%s · %s lb', p_id, v_det.lb_salida),
    --             p_id_usuario_auditoria
    --         );
    --
    --         IF v_mov->>'error' IS NOT NULL THEN
    --             RAISE EXCEPTION 'Cilindro %: %', v_det.id_balon, v_mov->>'error';
    --         END IF;
    --
    --         UPDATE bal_balon
    --         SET
    --             id_usuario_modificacion = p_id_usuario_auditoria,
    --             fecha_modificacion = NOW()
    --         WHERE id = v_det.id_balon AND estado = 1;
    --     END LOOP;
    --
    --     FOR v_det_prod IN
    --         SELECT dp.id_producto, dp.cantidad, p.nombre AS producto_nombre, p.afecta_stock
    --         FROM bal_ruta_pueblo_detalle_producto dp
    --         INNER JOIN pro_producto p ON p.id = dp.id_producto
    --         WHERE dp.id_ruta_pueblo = p_id AND dp.estado = 1
    --     LOOP
    --         IF COALESCE(v_det_prod.afecta_stock, FALSE) THEN
    --             SELECT s.id, COALESCE(s.stock, 0) AS stock, pm.id_unidad_medida AS id_unidad_medida
    --             INTO v_stock_record
    --             FROM pro_stock s
    --             INNER JOIN pro_producto pm ON pm.id = s.id_producto
    --             WHERE s.id_almacen = v_id_almacen
    --               AND s.id_producto = v_det_prod.id_producto
    --               AND s.estado = 1
    --             FOR UPDATE;
    --
    --             IF v_stock_record IS NULL THEN
    --                 RAISE EXCEPTION 'Producto "%" no tiene stock en el almacén de la ruta',
    --                     v_det_prod.producto_nombre;
    --             END IF;
    --
    --             IF v_stock_record.stock < v_det_prod.cantidad THEN
    --                 RAISE EXCEPTION 'Producto "%": stock insuficiente (% disponible, % requerido)',
    --                     v_det_prod.producto_nombre, v_stock_record.stock, v_det_prod.cantidad;
    --             END IF;
    --
    --             v_stock_anterior := v_stock_record.stock;
    --             v_stock_nuevo := v_stock_anterior - v_det_prod.cantidad;
    --             v_id_unidad_medida := v_stock_record.id_unidad_medida;
    --
    --             UPDATE pro_stock
    --             SET stock = v_stock_nuevo,
    --                 id_usuario_modificacion = p_id_usuario_auditoria,
    --                 fecha_modificacion = NOW()
    --             WHERE id = v_stock_record.id;
    --
    --             INSERT INTO inv_movimiento (
    --                 fecha, id_tipo_movimiento, naturaleza, id_producto, cantidad,
    --                 id_unidad_medida, id_almacen_origen, id_documento_origen,
    --                 id_tipo_documento_origen, stock_anterior, stock_nuevo, glosa,
    --                 id_usuario_creacion, id_usuario_modificacion
    --             )
    --             SELECT
    --                 NOW(),
    --                 lo.id,
    --                 'PRODUCTO',
    --                 v_det_prod.id_producto,
    --                 v_det_prod.cantidad,
    --                 v_id_unidad_medida,
    --                 v_id_almacen,
    --                 p_id,
    --                 tdlo.id,
    --                 v_stock_anterior,
    --                 v_stock_nuevo,
    --                 format('Salida ruta pueblos #%s · %s ud de %s', p_id, v_det_prod.cantidad, v_det_prod.producto_nombre),
    --                 p_id_usuario_auditoria,
    --                 p_id_usuario_auditoria
    --             FROM gen_lista_opciones lo
    --             INNER JOIN gen_lista l ON l.id = lo.id_lista
    --             LEFT JOIN gen_lista_opciones tdlo ON tdlo.nombre = 'RUTA_PUEBLO'
    --                 AND tdlo.id_lista = (SELECT id FROM gen_lista WHERE nombre = 'TipoDocumentoRef' LIMIT 1)
    --             WHERE l.nombre = 'TipoMovInvUnificado' AND lo.nombre = 'TRASLADO' AND lo.estado = 1
    --             LIMIT 1;
    --         END IF;
    --     END LOOP;
    --
    UPDATE bal_ruta_pueblo
    SET
        id_estado = v_id_estado_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$;
