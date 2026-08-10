-- Cierra el vínculo compra -> recarga en planta externa cuando la compra
-- ya quedó registrada. Reutiliza lo que ya existe en el módulo de balones:
--
-- 1) bal_actualizar_recarga_planta: cascada ya construida que, al recibir
--    p_id_comprobante_compra + p_fecha_llegada_almacen (+ ahora también
--    p_id_proveedor, por si la orden se creó sin proveedor conocido y
--    recién se confirma con esta compra), propaga lote/fecha a
--    bal_recarga_planta_detalle, actualiza cada bal_movimiento_recarga
--    (vía bal_actualizar_movimiento_recarga) y ESO marca cada balón como
--    LLENO (id_estado_contenido) con su id_producto_gas correspondiente.
--    También transiciona bal_recarga_planta.id_estado a CERRADO. Esto
--    siempre se hace: registrar la factura del proveedor es un hecho
--    real independiente de si los balones ya llegaron físicamente.
--
-- 2) p_guardar_balones_almacen (opcional, FALSE por defecto): registrar la
--    factura NO implica que los balones ya estén en el almacén (pueden
--    seguir en tránsito). Solo si viene en TRUE se hace, por cada balón
--    de la orden:
--      a) bal_actualizar_balon: fija id_almacen (el de esta compra) y
--         id_estado_balon = EN_ALMACEN.
--      b) bal_crear_movimiento: dejar registrado en el kardex general del
--         balón (bal_movimiento, distinto de bal_movimiento_recarga) un
--         movimiento ENTRADA_LLENADO por cilindro, referenciado a esta
--         orden de recarga.
--    Si viene en FALSE, ese ingreso queda pendiente para registrarse más
--    adelante desde el propio módulo de Recargas en planta.
CREATE OR REPLACE FUNCTION bal_finalizar_recarga_planta(
    p_id_recarga_planta        INTEGER,
    p_id_comprobante_compra    INTEGER,
    p_fecha_llegada_almacen    DATE,
    p_id_almacen               INTEGER,
    p_id_proveedor             INTEGER DEFAULT NULL,
    p_guardar_balones_almacen  BOOLEAN DEFAULT FALSE,
    p_id_usuario_auditoria     INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado             JSON;
    v_id_estado_en_almacen  INTEGER;
    v_id_tipo_entrada_llenado INTEGER;
    v_id_tipo_doc_ref_recarga INTEGER;
    v_det                   RECORD;
    v_mov                   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_recarga_planta WHERE id = p_id_recarga_planta AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La orden de recarga en planta externa no existe o está inactiva', 'registro', NULL);
    END IF;

    v_resultado := bal_actualizar_recarga_planta(
        p_id                    => p_id_recarga_planta,
        p_id_proveedor          => p_id_proveedor,
        p_id_almacen            => p_id_almacen,
        p_id_comprobante_compra => p_id_comprobante_compra,
        p_fecha_llegada_almacen => p_fecha_llegada_almacen,
        p_id_usuario_auditoria  => p_id_usuario_auditoria
    );

    IF v_resultado->>'error' IS NOT NULL THEN
        RETURN json_build_object('error', v_resultado->>'error', 'registro', NULL);
    END IF;

    IF p_guardar_balones_almacen THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_entrada_llenado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_LLENADO' AND lo.estado = 1
        LIMIT 1;

        SELECT lo.id INTO v_id_tipo_doc_ref_recarga
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
        LIMIT 1;

        -- Un movimiento de kardex (bal_movimiento) por cada balón de la orden.
        -- id_producto_gas ya quedó fijado por la cascada de arriba: por eso
        -- bal_actualizar_balon (que exige producto_gas) se llama después.
        FOR v_det IN
            SELECT d.id_balon
            FROM bal_recarga_planta_detalle d
            WHERE d.id_recarga_planta = p_id_recarga_planta
              AND d.estado = 1
        LOOP
            PERFORM bal_actualizar_balon(
                p_id                   => v_det.id_balon,
                p_id_almacen           => p_id_almacen,
                p_id_estado_balon      => v_id_estado_en_almacen,
                p_id_usuario_auditoria => p_id_usuario_auditoria
            );

            IF v_id_tipo_entrada_llenado IS NOT NULL THEN
                v_mov := bal_crear_movimiento(
                    p_id_balon              => v_det.id_balon,
                    p_id_tipo_movimiento    => v_id_tipo_entrada_llenado,
                    p_id_documento_ref      => p_id_recarga_planta,
                    p_id_tipo_documento_ref => v_id_tipo_doc_ref_recarga,
                    p_id_cliente            => p_id_proveedor,
                    p_id_almacen_destino    => p_id_almacen,
                    p_observacion           => 'Entrada por recarga en planta externa (orden #' || p_id_recarga_planta || ')',
                    p_id_usuario_auditoria  => p_id_usuario_auditoria
                );

                IF v_mov->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION 'No se pudo registrar el movimiento de entrada del balón %: %', v_det.id_balon, v_mov->>'error';
                END IF;
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object('id_recarga_planta', p_id_recarga_planta)
    );
END;
$function$;
