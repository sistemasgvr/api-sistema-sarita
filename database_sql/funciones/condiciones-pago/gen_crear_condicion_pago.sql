CREATE OR REPLACE FUNCTION gen_crear_condicion_pago(
    p_codigo VARCHAR,
    p_nombre VARCHAR,
    p_dias_credito INTEGER DEFAULT 0,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_condicion_pago (
        codigo,
        nombre,
        dias_credito,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_codigo,
        p_nombre,
        p_dias_credito,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_condicion_pago(v_id);
END;
$function$;
