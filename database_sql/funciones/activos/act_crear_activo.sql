DROP FUNCTION IF EXISTS act_crear_activo(
    INTEGER,
    VARCHAR,
    DATE,
    NUMERIC,
    INTEGER,
    VARCHAR,
    VARCHAR,
    VARCHAR,
    INTEGER,
    VARCHAR,
    INTEGER
);

CREATE OR REPLACE FUNCTION act_crear_activo(
    p_id_tipo                     INTEGER DEFAULT NULL,
    p_descripcion                 VARCHAR DEFAULT NULL,
    p_fecha_compra                DATE DEFAULT NULL,
    p_importe                     NUMERIC DEFAULT NULL,
    p_id_sucursal                 INTEGER DEFAULT NULL,
    p_marca                       VARCHAR DEFAULT NULL,
    p_modelo                      VARCHAR DEFAULT NULL,
    p_numero_serie                VARCHAR DEFAULT NULL,
    p_id_trabajador_responsable   INTEGER DEFAULT NULL,
    p_imagen_principal_ruta       VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria        INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    BEGIN
        INSERT INTO act_activos (
            id_tipo, descripcion, fecha_compra, importe,
            id_sucursal, marca, modelo, numero_serie,
            id_trabajador_responsable, imagen_principal_ruta,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_id_tipo, p_descripcion, p_fecha_compra, p_importe,
            p_id_sucursal, p_marca, p_modelo, p_numero_serie,
            p_id_trabajador_responsable, p_imagen_principal_ruta,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo, sucursal o responsable no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el activo: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN act_obtener_activo(v_id);
END;
$function$;
