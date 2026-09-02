-- Único punto de verdad para el código TipoDocumentoRef que corresponde a un comprobante
-- de venta, usado tanto al crear/actualizar movimientos (inv_registrar_movimiento) como al
-- revertirlos (inv_revertir_por_documento). Antes esta lógica estaba copiada inline en más de
-- 10 sitios entre ven_crear_comprobante.sql y ven_actualizar_comprobante.sql, con copias
-- desactualizadas que no cubrían '08' (NOTA_DEBITO) ni 'NV'/'VSD' (NOTA_VENTA) — eso hacía que
-- crear/editar una Nota de Venta o Nota de Débito etiquetara el movimiento como 'FACTURA' en
-- algunos casos, y como el código correcto en otros, rompiendo la reversión.
CREATE OR REPLACE FUNCTION ven_resolver_tipo_documento_ref(
    p_codigo_tipo_comprobante VARCHAR,
    p_nombre_tipo_venta VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE plpgsql
STABLE
AS $function$
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
