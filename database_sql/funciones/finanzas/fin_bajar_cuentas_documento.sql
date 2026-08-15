CREATE OR REPLACE FUNCTION fin_bajar_cuentas_documento(
    p_id_usuario INTEGER,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_padre INTEGER;
BEGIN
    FOR v_id_padre IN
        SELECT fc.id
        FROM fin_cuenta fc
        WHERE fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
          AND (
              (p_id_comprobante_venta IS NOT NULL AND fc.id_comprobante_venta = p_id_comprobante_venta)
              OR (p_id_comprobante_compra IS NOT NULL AND fc.id_comprobante_compra = p_id_comprobante_compra)
          )
    LOOP
        UPDATE fin_cuenta
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_id_padre
           OR id_cuenta_padre = v_id_padre;
    END LOOP;
END;
$function$;
