DROP FUNCTION IF EXISTS act_listar_activo_imagenes(
    INTEGER,
    INTEGER,
    INTEGER
);

CREATE OR REPLACE FUNCTION act_listar_activo_imagenes(
    p_id_activo INTEGER,
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_activo IS NULL THEN
        RETURN json_build_object(
            'error', 'El id_activo es obligatorio',
            'registros', '[]'::JSON,
            'total', 0
        );
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM act_activo_imagen ai
    WHERE ai.estado = 1
      AND ai.id_activo = p_id_activo;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            ai.id,
            ai.id_activo,
            ai.id_archivo,
            a.nombre_original,
            a.nombre_almacenado,
            a.ruta,
            a.bucket,
            a.mime_type,
            a.extension,
            a.tamanio_bytes,
            ai.orden,
            ai.es_principal,
            ai.estado,
            ai.fecha_creacion,
            ai.fecha_modificacion,
            ai.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ai.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM act_activo_imagen ai
        INNER JOIN gen_archivo a ON ai.id_archivo = a.id
        LEFT JOIN auth_usuarios uc ON ai.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ai.id_usuario_modificacion = um.id
        WHERE ai.estado = 1
          AND ai.id_activo = p_id_activo
        ORDER BY ai.es_principal DESC, ai.orden ASC, ai.id ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
