-- Devuelve el tipo de documento de inventario según el tipo de comprobante y venta
DROP FUNCTION IF EXISTS public.ven_resolver_tipo_documento_ref (
  p_codigo_tipo_comprobante character varying,
  p_nombre_tipo_venta character varying
);

CREATE OR REPLACE FUNCTION public.ven_resolver_tipo_documento_ref (
  p_codigo_tipo_comprobante character varying,
  p_nombre_tipo_venta character varying DEFAULT NULL::character varying
) RETURNS character varying LANGUAGE plpgsql STABLE AS $function$
BEGIN
    RETURN CASE
        WHEN p_nombre_tipo_venta = 'VENTA_GAS' THEN 'RECARGA'
        WHEN p_codigo_tipo_comprobante = '01' THEN 'FACTURA'
        WHEN p_codigo_tipo_comprobante = '03' THEN 'BOLETA'
        WHEN p_codigo_tipo_comprobante = '07' THEN 'NOTA_CREDITO'
        WHEN p_codigo_tipo_comprobante = '08' THEN 'NOTA_DEBITO'
        WHEN p_codigo_tipo_comprobante IN ('NV', 'VSD') THEN 'NOTA_VENTA'
        ELSE 'FACTURA'
    END;
END;
$function$;
