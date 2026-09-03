-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_crear_desde_venta
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_crear_desde_venta(p_id_venta integer, p_id_destinatario integer, p_fecha_traslado date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_crear_desde_venta(p_id_venta integer, p_id_destinatario integer DEFAULT NULL::integer, p_fecha_traslado date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_venta RECORD;
    v_id_sucursal INTEGER;
    v_resultado JSON;
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT vc.* INTO v_venta FROM ven_comprobante vc WHERE vc.id = p_id_venta AND vc.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La venta indicada no existe o está anulada', 'registro', NULL);
    END IF;

    IF v_venta.id_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'La venta no tiene almacén; no se puede emitir una orden de salida',
            'registro', NULL
        );
    END IF;

    v_id_sucursal := COALESCE(
        v_venta.id_sucursal,
        (SELECT a.id_sucursal FROM gen_almacen a WHERE a.id = v_venta.id_almacen)
    );

    v_resultado := doc_crear_salida(
        p_codigo_tipo_orden    => 'ORDEN_SALIDA_VENTA',
        p_id_sucursal          => v_id_sucursal,
        p_id_almacen           => v_venta.id_almacen,
        p_id_venta             => p_id_venta,
        p_id_cliente           => v_venta.id_cliente,
        p_id_destinatario      => COALESCE(p_id_destinatario, v_venta.id_cliente),
        p_fecha                => v_venta.fecha,
        p_fecha_traslado       => COALESCE(p_fecha_traslado, v_venta.fecha),
        p_observaciones        => format('Orden de salida de la venta %s-%s', v_venta.serie, v_venta.numero),
        p_id_usuario_auditoria => p_id_usuario_auditoria
    );

    IF v_resultado->>'error' IS NOT NULL THEN
        RETURN v_resultado;
    END IF;

    v_id := (v_resultado->'registro'->>'id')::INTEGER;

    -- Se genera de inmediato: no mueve inventario (lo hizo la venta), así que no hay
    -- nada que el usuario deba revisar antes de cerrarla.
    RETURN doc_generar_salida(v_id, p_id_usuario_auditoria);
END;
$function$;
