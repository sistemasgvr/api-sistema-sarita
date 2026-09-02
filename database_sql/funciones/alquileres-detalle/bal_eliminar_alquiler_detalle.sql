-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_eliminar_alquiler_detalle
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.544Z
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
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            v_mov := inv_registrar_movimiento(
                p_naturaleza                => 'BALON',
                p_codigo_tipo_movimiento    => 'ENTRADA_DEVOLUCION',
                p_fecha                     => NOW(),
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
$function$
