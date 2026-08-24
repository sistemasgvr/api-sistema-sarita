DROP FUNCTION IF EXISTS tra_crear_trabajador(
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

CREATE OR REPLACE FUNCTION tra_crear_trabajador(
    p_nombres               VARCHAR,
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
    v_id_trabajador INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE numero_documento = p_numero_documento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe un trabajador registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO tra_trabajadores (
            nombres, apellido_paterno, apellido_materno,
        id_tipo_documento, numero_documento, correo,
        direccion, referencia, latitud, longitud,
            id_pais, id_departamento, id_provincia, id_distrito,
            fecha_nacimiento, fecha_inicio, fecha_cese,
            id_area, id_cargo, id_usuario, id_chofer,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_nombres, p_apellido_paterno, p_apellido_materno,
        p_id_tipo_documento, p_numero_documento, p_correo,
        p_direccion, p_referencia, p_latitud, p_longitud,
            p_id_pais, p_id_departamento, p_id_provincia, p_id_distrito,
            p_fecha_nacimiento, p_fecha_inicio, p_fecha_cese,
            p_id_area, p_id_cargo, p_id_usuario_vinculo, p_id_chofer,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_trabajador;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo, ubicación, usuario o chofer no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el trabajador: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN tra_obtener_trabajador(v_id_trabajador);
END;
$function$;
