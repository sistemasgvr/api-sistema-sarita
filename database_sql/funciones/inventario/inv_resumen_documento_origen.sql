DROP FUNCTION IF EXISTS public.inv_resumen_documento_origen (
  p_codigo_tipo_documento character varying,
  p_id_documento integer,
  p_naturaleza character varying,
  p_id_documento_detalle integer,
  p_id_producto integer,
  p_id_balon integer
);

CREATE OR REPLACE FUNCTION public.inv_resumen_documento_origen (
  p_codigo_tipo_documento character varying,
  p_id_documento integer,
  p_naturaleza character varying,
  p_id_documento_detalle integer DEFAULT NULL::integer,
  p_id_producto integer DEFAULT NULL::integer,
  p_id_balon integer DEFAULT NULL::integer,
  OUT codigo_documento_origen character varying,
  OUT importe_linea numeric,
  OUT total_documento numeric,
  OUT moneda_documento character varying
) RETURNS record LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_tipo VARCHAR := UPPER(TRIM(p_codigo_tipo_documento));
    v_id_venta INTEGER;
    v_id_compra INTEGER;
    v_codigo VARCHAR;
BEGIN
    IF p_id_documento IS NULL OR COALESCE(v_tipo, '') = '' THEN
        RETURN;
    END IF;

    IF v_tipo IN ('FACTURA', 'BOLETA', 'NOTA_CREDITO', 'NOTA_DEBITO', 'NOTA_VENTA')
       OR (v_tipo = 'RECARGA' AND p_naturaleza = 'PRODUCTO') THEN
        v_id_venta := p_id_documento;
    ELSIF v_tipo IN ('COMPRA', 'DEVOLUCION') THEN
        v_id_compra := p_id_documento;
    ELSIF v_tipo = 'CAMBIO_VSD' THEN
        SELECT o.id_comprobante INTO v_id_venta
        FROM ven_vsd_operacion o
        WHERE o.id = p_id_documento;
    ELSIF v_tipo = 'RECARGA' THEN
        SELECT
            r.id_comprobante,
            r.id_comprobante_compra,
            COALESCE(
                NULLIF(CONCAT_WS('-', r.serie_factura, r.numero_factura), ''),
                NULLIF(CONCAT_WS('-', r.serie_guia_salida, r.numero_guia_salida), '')
            )
        INTO v_id_venta, v_id_compra, v_codigo
        FROM bal_movimiento_recarga r
        WHERE r.id = p_id_documento;
    ELSIF v_tipo IN ('GRE', 'ORDEN_SALIDA', 'RECARGA_PLANTA') THEN
        SELECT COALESCE(NULLIF(CONCAT_WS('-', d.serie, d.numero_sunat), ''), d.numero)
        INTO v_codigo
        FROM doc_salida d
        WHERE d.id = p_id_documento;
    ELSIF v_tipo = 'PRESTAMO' THEN
        SELECT p.numero_prestamo INTO v_codigo
        FROM bal_prestamo p
        WHERE p.id = p_id_documento;
    ELSIF v_tipo = 'ALQUILER' THEN
        SELECT a.numero_alquiler, a.total_cobrado
        INTO v_codigo, total_documento
        FROM bal_alquiler a
        WHERE a.id = p_id_documento;
    ELSIF v_tipo = 'MANTENIMIENTO' THEN
        SELECT m.costo INTO total_documento
        FROM bal_mantenimiento m
        WHERE m.id = p_id_documento;
    END IF;

    IF v_id_venta IS NOT NULL THEN
        SELECT
            COALESCE(NULLIF(CONCAT_WS('-', c.serie, c.numero), ''), v_codigo),
            c.total_importe,
            COALESCE(mon.descripcion, mon.nombre)
        INTO v_codigo, total_documento, moneda_documento
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones mon ON mon.id = c.id_moneda
        WHERE c.id = v_id_venta;

        IF p_naturaleza = 'PRODUCTO' THEN
            SELECT d.importe INTO importe_linea
            FROM ven_comprobante_detalle d
            WHERE d.id = p_id_documento_detalle
              AND d.id_comprobante = v_id_venta
              AND d.id_producto = p_id_producto
              AND d.estado = 1;
        ELSE
            -- Los balones no guardan id_documento_detalle: se ubica la línea por serie, salvo
            -- que esa línea ya esté atribuida al movimiento de producto (gas) del mismo documento.
            SELECT SUM(d.importe) INTO importe_linea
            FROM ven_comprobante_detalle d
            WHERE d.id_comprobante = v_id_venta
              AND d.id_balon = p_id_balon
              AND d.estado = 1
              AND NOT EXISTS (
                  SELECT 1
                  FROM inv_movimiento x
                  WHERE x.id_documento_origen = v_id_venta
                    AND x.id_documento_detalle = d.id
                    AND x.id_producto = d.id_producto
                    AND x.naturaleza = 'PRODUCTO'
                    AND x.estado = 1
              );
        END IF;
    ELSIF v_id_compra IS NOT NULL THEN
        SELECT
            COALESCE(NULLIF(CONCAT_WS('-', c.serie, c.numero), ''), v_codigo),
            c.total_importe,
            COALESCE(mon.descripcion, mon.nombre)
        INTO v_codigo, total_documento, moneda_documento
        FROM com_comprobante_compra c
        LEFT JOIN gen_lista_opciones mon ON mon.id = c.id_moneda
        WHERE c.id = v_id_compra;

        IF p_naturaleza = 'PRODUCTO' THEN
            SELECT d.importe INTO importe_linea
            FROM com_comprobante_compra_detalle d
            WHERE d.id = p_id_documento_detalle
              AND d.id_comprobante = v_id_compra
              AND d.id_producto = p_id_producto
              AND d.estado = 1;
        END IF;
    END IF;

    codigo_documento_origen := COALESCE(NULLIF(TRIM(v_codigo), ''), '#' || p_id_documento);
END;
$function$;
