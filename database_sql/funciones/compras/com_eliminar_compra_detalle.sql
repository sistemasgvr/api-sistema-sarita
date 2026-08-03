-- Elimina (baja lógica) una línea de compra.
-- Si la línea ingresó stock (afecta_stock snapshot), genera SALIDA de reversa.

CREATE OR REPLACE FUNCTION com_eliminar_compra_detalle(
    p_id_detalle             INTEGER,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_id_tipo_salida      INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_stock_actual        NUMERIC(12,4);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        d.id,
        d.id_comprobante,
        d.id_producto,
        d.cantidad,
        d.afecta_stock,
        COALESCE(d.id_almacen, c.id_almacen) AS id_almacen,
        c.serie,
        c.numero
    INTO v_detalle
    FROM com_comprobante_compra_detalle d
    JOIN com_comprobante_compra c ON c.id = d.id_comprobante
    WHERE d.id = p_id_detalle AND d.estado = 1 AND c.estado = 1
    FOR UPDATE OF d, c;

    IF v_detalle.id IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_detalle);
    END IF;

    v_serie := v_detalle.serie;
    v_numero := v_detalle.numero;

    IF v_detalle.afecta_stock THEN
        SELECT stock INTO v_stock_actual
        FROM pro_stock
        WHERE id_producto = v_detalle.id_producto
          AND id_almacen = v_detalle.id_almacen
          AND estado = 1
        FOR UPDATE;

        v_stock_actual := COALESCE(v_stock_actual, 0);

        IF v_stock_actual < v_detalle.cantidad THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id_detalle,
                'error', format(
                    'No se puede quitar la línea: stock insuficiente para revertir el ingreso (disponible %s, requiere %s).',
                    v_stock_actual,
                    v_detalle.cantidad
                )
            );
        END IF;

        SELECT glo.id INTO v_id_tipo_salida
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'SALIDA' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_ref
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'DEVOLUCION' AND glo.estado = 1;

        IF v_id_tipo_salida IS NULL OR v_id_tipo_doc_ref IS NULL THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id_detalle,
                'error', 'Faltan configurar las opciones SALIDA (TipoMovInv) o DEVOLUCION (TipoDocumentoRef)'
            );
        END IF;

        v_result_movimiento := pro_crear_movimiento(
            p_fecha                 => CURRENT_DATE,
            p_id_producto           => v_detalle.id_producto,
            p_id_almacen            => v_detalle.id_almacen,
            p_id_tipo_movimiento    => v_id_tipo_salida,
            p_cantidad              => v_detalle.cantidad,
            p_id_documento_ref      => v_detalle.id,
            p_id_tipo_documento_ref => v_id_tipo_doc_ref,
            p_glosa                 => 'Reversa por eliminación de línea compra ' || v_serie || '-' || v_numero,
            p_id_usuario_auditoria  => p_id_usuario_auditoria,
            p_forzar_ajuste_stock   => TRUE
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RETURN json_build_object(
                'eliminado', FALSE,
                'id', p_id_detalle,
                'error', v_result_movimiento->>'error'
            );
        END IF;
    END IF;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_detalle;

    UPDATE com_comprobante_compra
    SET afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_detalle.id_comprobante
              AND afecta_stock = TRUE
              AND estado = 1
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = v_detalle.id_comprobante;

    PERFORM com_recalcular_totales_compra(v_detalle.id_comprobante, p_id_usuario_auditoria);

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_detalle);
END;
$function$;