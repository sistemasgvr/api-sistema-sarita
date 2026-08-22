DROP FUNCTION IF EXISTS act_actualizar_activo(
    INTEGER,
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

CREATE OR REPLACE FUNCTION act_actualizar_activo(
    p_id                           INTEGER,
    p_id_tipo                      INTEGER DEFAULT NULL,
    p_descripcion                  VARCHAR DEFAULT NULL,
    p_fecha_compra                 DATE DEFAULT NULL,
    p_importe                      NUMERIC DEFAULT NULL,
    p_id_sucursal                  INTEGER DEFAULT NULL,
    p_marca                        VARCHAR DEFAULT NULL,
    p_modelo                       VARCHAR DEFAULT NULL,
    p_numero_serie                 VARCHAR DEFAULT NULL,
    p_id_trabajador_responsable    INTEGER DEFAULT NULL,
    p_imagen_principal_ruta        VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria         INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_existe INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_existe FROM act_activos WHERE id = p_id AND estado IN (0, 1);
    IF v_existe = 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'No existe un activo con id ' || p_id);
    END IF;

    BEGIN
        UPDATE act_activos
        SET
            id_tipo                     = COALESCE(p_id_tipo, id_tipo),
            descripcion                 = COALESCE(p_descripcion, descripcion),
            fecha_compra                = COALESCE(p_fecha_compra, fecha_compra),
            importe                     = COALESCE(p_importe, importe),
            id_sucursal                 = COALESCE(p_id_sucursal, id_sucursal),
            marca                       = COALESCE(p_marca, marca),
            modelo                      = COALESCE(p_modelo, modelo),
            numero_serie                = COALESCE(p_numero_serie, numero_serie),
            id_trabajador_responsable   = COALESCE(p_id_trabajador_responsable, id_trabajador_responsable),
            imagen_principal_ruta       = COALESCE(p_imagen_principal_ruta, imagen_principal_ruta),
            id_usuario_modificacion     = p_id_usuario_auditoria,
            fecha_modificacion          = NOW()
        WHERE id = p_id AND estado IN (0, 1);

    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo, sucursal o responsable no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el activo: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN act_obtener_activo(p_id);
END;
$function$;
