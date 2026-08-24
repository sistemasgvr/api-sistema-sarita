DROP FUNCTION IF EXISTS tra_actualizar_trabajador(
    INTEGER,
    VARCHAR,
    VARCHAR,
    VARCHAR,
    INTEGER,
    VARCHAR,
    VARCHAR,
    VARCHAR,
    NUMERIC,
    NUMERIC,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    DATE,
    DATE,
    DATE,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    VARCHAR
);

CREATE OR REPLACE FUNCTION tra_actualizar_trabajador(
    p_id                    INTEGER,
    p_nombres               VARCHAR DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_direccion             VARCHAR DEFAULT NULL,
    p_referencia            VARCHAR DEFAULT NULL,
    p_latitud               NUMERIC DEFAULT NULL,
    p_longitud              NUMERIC DEFAULT NULL,
    p_id_pais               INTEGER DEFAULT NULL,
    p_id_departamento       INTEGER DEFAULT NULL,
    p_id_provincia          INTEGER DEFAULT NULL,
    p_id_distrito           INTEGER DEFAULT NULL,
    p_fecha_nacimiento      DATE    DEFAULT NULL,
    p_fecha_inicio          DATE    DEFAULT NULL,
    p_fecha_cese            DATE    DEFAULT NULL,
    p_id_area               INTEGER DEFAULT NULL,
    p_id_cargo              INTEGER DEFAULT NULL,
    p_id_usuario_vinculo    INTEGER DEFAULT NULL,
    p_id_chofer             INTEGER DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL,
    p_correo                VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_existe INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_existe FROM tra_trabajadores WHERE id = p_id AND estado IN (0, 1);
    IF v_existe = 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'No existe un trabajador con id ' || p_id);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM tra_trabajadores
        WHERE numero_documento = p_numero_documento AND id <> p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro trabajador registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        UPDATE tra_trabajadores
        SET
            nombres               = COALESCE(p_nombres, nombres),
            apellido_paterno      = COALESCE(p_apellido_paterno, apellido_paterno),
            apellido_materno      = COALESCE(p_apellido_materno, apellido_materno),
            id_tipo_documento     = COALESCE(p_id_tipo_documento, id_tipo_documento),
        numero_documento          = COALESCE(p_numero_documento, numero_documento),
        correo                    = COALESCE(p_correo, correo),
            direccion             = COALESCE(p_direccion, direccion),
            referencia            = COALESCE(p_referencia, referencia),
            latitud               = COALESCE(p_latitud, latitud),
            longitud              = COALESCE(p_longitud, longitud),
            id_pais               = COALESCE(p_id_pais, id_pais),
            id_departamento       = COALESCE(p_id_departamento, id_departamento),
            id_provincia          = COALESCE(p_id_provincia, id_provincia),
            id_distrito           = COALESCE(p_id_distrito, id_distrito),
            fecha_nacimiento      = COALESCE(p_fecha_nacimiento, fecha_nacimiento),
            fecha_inicio          = COALESCE(p_fecha_inicio, fecha_inicio),
            fecha_cese            = COALESCE(p_fecha_cese, fecha_cese),
            id_area               = COALESCE(p_id_area, id_area),
            id_cargo              = COALESCE(p_id_cargo, id_cargo),
            id_usuario            = COALESCE(p_id_usuario_vinculo, id_usuario),
            id_chofer             = COALESCE(p_id_chofer, id_chofer),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion    = NOW()
        WHERE id = p_id AND estado IN (0, 1);

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo, ubicación, usuario o chofer no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el trabajador: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN tra_obtener_trabajador(p_id);
END;
$function$;
