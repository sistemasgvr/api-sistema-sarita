CREATE OR REPLACE FUNCTION bal_actualizar_alquiler(
    p_id INTEGER,
    p_numero_alquiler VARCHAR DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_fecha_inicio DATE DEFAULT NULL,
    p_fecha_fin_pactada DATE DEFAULT NULL,
    p_fecha_fin_real DATE DEFAULT NULL,
    p_tarifa_diaria NUMERIC DEFAULT NULL,
    p_total_cobrado NUMERIC DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero := NULLIF(TRIM(p_numero_alquiler), '');

    IF v_numero IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_alquiler WHERE LOWER(TRIM(numero_alquiler)) = LOWER(v_numero) AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro alquiler con el número ' || v_numero, 'registro', NULL);
    END IF;

    UPDATE bal_alquiler
    SET
        numero_alquiler = COALESCE(v_numero, numero_alquiler),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_almacen = COALESCE(p_id_almacen, id_almacen),
        fecha_inicio = COALESCE(p_fecha_inicio, fecha_inicio),
        fecha_fin_pactada = COALESCE(p_fecha_fin_pactada, fecha_fin_pactada),
        fecha_fin_real = COALESCE(p_fecha_fin_real, fecha_fin_real),
        tarifa_diaria = COALESCE(p_tarifa_diaria, tarifa_diaria),
        total_cobrado = COALESCE(p_total_cobrado, total_cobrado),
        id_estado = COALESCE(p_id_estado, id_estado),
        observacion = COALESCE(p_observacion, observacion),
        id_comprobante_venta = COALESCE(p_id_comprobante_venta, id_comprobante_venta),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_alquiler(p_id);
END;
$function$;
