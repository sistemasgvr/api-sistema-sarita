CREATE OR REPLACE FUNCTION gen_obtener_notificacion(
    p_id INTEGER,
    p_id_usuario INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT json_build_object(
        'id', n.id,
        'id_usuario', n.id_usuario,
        'codigo_tipo', n.codigo_tipo,
        'titulo', n.titulo,
        'mensaje', n.mensaje,
        'payload', n.payload,
        'id_referencia', n.id_referencia,
        'tipo_referencia', n.tipo_referencia,
        'clave_dedupe', n.clave_dedupe,
        'leida', n.leida,
        'fecha_lectura', n.fecha_lectura,
        'fecha_creacion', n.fecha_creacion,
        'fecha_modificacion', n.fecha_modificacion
    )
    INTO v_registro
    FROM gen_notificacion n
    WHERE n.id = p_id
      AND n.estado = 1
      AND (p_id_usuario IS NULL OR n.id_usuario = p_id_usuario);

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
