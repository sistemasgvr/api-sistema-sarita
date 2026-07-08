CREATE OR REPLACE FUNCTION bal_crear_mantenimiento(
    p_id_balon INTEGER,
    p_fecha_ingreso DATE,
    p_id_tipo_mantenimiento INTEGER DEFAULT NULL,
    p_fecha_salida DATE DEFAULT NULL,
    p_descripcion VARCHAR DEFAULT NULL,
    p_costo NUMERIC DEFAULT 0,
    p_es_externo BOOLEAN DEFAULT FALSE,
    p_id_proveedor INTEGER DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_comprobante_venta INTEGER DEFAULT NULL,
    p_id_comprobante_compra INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_vigencia_ph_anios INTEGER DEFAULT NULL,
    p_id_organo_inspector INTEGER DEFAULT NULL,
    p_organo_inspector_no_aplica BOOLEAN DEFAULT NULL,
    p_numero_certificado_ph VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_ingreso IS NULL THEN
        RETURN json_build_object('error', 'La fecha de ingreso es obligatoria', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO bal_mantenimiento (
        id_balon, id_tipo_mantenimiento, fecha_ingreso, fecha_salida,
        descripcion, costo, es_externo, id_proveedor, id_estado,
        id_comprobante_venta, id_comprobante_compra, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_balon, p_id_tipo_mantenimiento, p_fecha_ingreso, p_fecha_salida,
        p_descripcion, COALESCE(p_costo, 0), COALESCE(p_es_externo, FALSE), p_id_proveedor, p_id_estado,
        p_id_comprobante_venta, p_id_comprobante_compra, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    PERFORM bal_sync_ph_desde_mantenimiento(
        v_id,
        p_id_usuario_auditoria,
        p_vigencia_ph_anios,
        p_id_organo_inspector,
        p_organo_inspector_no_aplica,
        p_numero_certificado_ph
    );

    RETURN bal_obtener_mantenimiento(v_id);
END;
$function$;
