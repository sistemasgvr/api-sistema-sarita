-- Function: doc_crear_desde_venta
--
-- Al confirmar que la venta es para envío, los cilindros que salen quedan en
-- estado PENDIENTE_ENVIO: siguen siendo nuestros y siguen en el almacén, pero
-- ya están comprometidos y no deben ofrecerse para otra entrega.
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
    v_id_estado_pendiente_envio INTEGER;
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

    -- Los cilindros de la venta pasan a PENDIENTE_ENVIO.
    --
    -- Se toman de ven_comprobante_detalle, que es exactamente lo que sale por la
    -- puerta: el cilindro que el cliente deja en garantía no está ahí (vive en
    -- bal_prestamo_detalle con rol GARANTIA), así que se queda con su estado y no
    -- se marca por error como pendiente de envío.
    --
    -- No pasa por inv_registrar_movimiento a propósito: esto no mueve inventario
    -- —el movimiento lo hizo la venta— sino que marca una situación logística
    -- sobre el mismo cilindro, en el mismo almacén y con el mismo dueño.
    SELECT lo.id INTO v_id_estado_pendiente_envio
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_pendiente_envio IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_estado_pendiente_envio,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM ven_comprobante_detalle d
        WHERE d.id_comprobante = p_id_venta
          AND d.estado = 1
          AND d.id_balon = b.id
          AND b.estado = 1
          AND b.id_estado_balon IS DISTINCT FROM v_id_estado_pendiente_envio
          -- Un cilindro de baja o robado no "sale": no se le cambia el estado.
          AND UPPER(COALESCE(
                (SELECT lo2.nombre FROM gen_lista_opciones lo2 WHERE lo2.id = b.id_estado_balon),
                ''
              )) NOT IN ('DADO_DE_BAJA', 'ROBO');
    END IF;

    -- Se genera de inmediato: no mueve inventario (lo hizo la venta), así que no hay
    -- nada que el usuario deba revisar antes de cerrarla.
    RETURN doc_generar_salida(v_id, p_id_usuario_auditoria);
END;
$function$;
