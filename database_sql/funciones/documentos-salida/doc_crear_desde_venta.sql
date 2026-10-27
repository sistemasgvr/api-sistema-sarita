-- Crea un documento de salida a partir de un comprobante de venta
DROP FUNCTION IF EXISTS public.doc_crear_desde_venta (
  p_id_venta integer,
  p_id_destinatario integer,
  p_fecha_traslado date,
  p_id_usuario_auditoria integer,
  p_id_empresa integer
);

CREATE OR REPLACE FUNCTION public.doc_crear_desde_venta (
  p_id_venta integer,
  p_id_destinatario integer DEFAULT NULL::integer,
  p_fecha_traslado date DEFAULT NULL::date,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_id_empresa integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_venta RECORD;
    v_id_sucursal INTEGER;
    v_resultado JSON;
    v_id INTEGER;
    v_id_estado_pendiente_envio INTEGER;
    v_hay_balones_os BOOLEAN;
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

    SELECT EXISTS (
        SELECT 1
        FROM ven_comprobante_detalle d
        WHERE d.id_comprobante = p_id_venta
          AND d.estado = 1
          AND d.id_balon IS NOT NULL
          AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
        UNION ALL
        SELECT 1
        FROM bal_prestamo pr
        INNER JOIN bal_prestamo_detalle pd
            ON pd.id_prestamo = pr.id AND pd.estado = 1
        WHERE pr.id_comprobante_venta = p_id_venta
          AND pr.estado = 1
          AND pd.rol = 'ENTREGADO'
          AND pd.id_balon IS NOT NULL
    ) INTO v_hay_balones_os;

    SELECT lo.id INTO v_id_estado_pendiente_envio
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND UPPER(lo.nombre) = 'PENDIENTE_ENVIO' AND lo.estado = 1
    LIMIT 1;

    IF v_hay_balones_os AND v_id_estado_pendiente_envio IS NULL THEN
        RETURN json_build_object(
            'error', 'Falta el estado PENDIENTE_ENVIO en el catálogo EstadoBalon',
            'registro', NULL
        );
    END IF;

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
        p_id_usuario_auditoria => p_id_usuario_auditoria,
        p_id_empresa => p_id_empresa
    );

    IF v_resultado->>'error' IS NOT NULL THEN
        RETURN v_resultado;
    END IF;

    v_id := (v_resultado->'registro'->>'id')::INTEGER;

    IF v_id_estado_pendiente_envio IS NOT NULL THEN
        UPDATE bal_balon b
        SET id_estado_balon = v_id_estado_pendiente_envio,
            id_almacen = COALESCE(b.id_almacen, v_venta.id_almacen),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE b.estado = 1
          AND b.id_estado_balon IS DISTINCT FROM v_id_estado_pendiente_envio
          AND UPPER(COALESCE(
                (SELECT lo2.nombre FROM gen_lista_opciones lo2 WHERE lo2.id = b.id_estado_balon),
                ''
              )) NOT IN ('DADO_DE_BAJA', 'ROBO')
          AND b.id IN (
              SELECT d.id_balon
              FROM ven_comprobante_detalle d
              WHERE d.id_comprobante = p_id_venta
                AND d.estado = 1
                AND d.id_balon IS NOT NULL
                AND COALESCE(d.descripcion, '') !~* 'garant[ií]a'
              UNION
              SELECT pd.id_balon
              FROM bal_prestamo pr
              INNER JOIN bal_prestamo_detalle pd
                  ON pd.id_prestamo = pr.id AND pd.estado = 1
              WHERE pr.id_comprobante_venta = p_id_venta
                AND pr.estado = 1
                AND pd.rol = 'ENTREGADO'
                AND pd.id_balon IS NOT NULL
          );
    END IF;

    RETURN doc_generar_salida(v_id, p_id_usuario_auditoria);
END;
$function$;
