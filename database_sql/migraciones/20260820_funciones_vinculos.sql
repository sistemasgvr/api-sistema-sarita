CREATE OR REPLACE FUNCTION auth_obtener_usuario_por_correo(p_correo VARCHAR)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            u.id,
            u.nombre,
            u.correo,
            u.contrasena,
            u.estado,
            u.id_trabajador,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', r.id,
                    'nombre', r.nombre
                )), '[]'::JSON)
                FROM auth_usuarios_roles ur
                INNER JOIN auth_roles r ON ur.id_rol = r.id
                WHERE ur.id_usuario = u.id AND ur.estado = TRUE AND r.estado = TRUE
            ) AS roles
        FROM auth_usuarios u
        WHERE LOWER(u.correo) = LOWER(p_correo) AND u.estado = TRUE
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
CREATE OR REPLACE FUNCTION auth_crear_usuario(
    p_nombre VARCHAR,
    p_correo VARCHAR,
    p_contrasena VARCHAR,
    p_id_trabajador INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_trabajador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE id = p_id_trabajador AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El trabajador indicado no existe.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM auth_usuarios WHERE LOWER(correo) = LOWER(p_correo) AND estado = TRUE) THEN
        RETURN json_build_object('error', 'El correo ya está registrado', 'registro', NULL);
    END IF;

    IF p_id_trabajador IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios WHERE id_trabajador = p_id_trabajador AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El trabajador ya tiene un usuario de acceso.', 'registro', NULL);
    END IF;

    INSERT INTO auth_usuarios (nombre, correo, contrasena, id_trabajador)
    VALUES (p_nombre, LOWER(p_correo), p_contrasena, p_id_trabajador)
    RETURNING id INTO v_id;

    RETURN auth_obtener_usuario(v_id);
END;
$function$;
CREATE OR REPLACE FUNCTION auth_actualizar_usuario(
    p_id INTEGER,
    p_nombre VARCHAR DEFAULT NULL,
    p_correo VARCHAR DEFAULT NULL,
    p_contrasena VARCHAR DEFAULT NULL,
    p_id_trabajador INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_correo IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios
        WHERE LOWER(correo) = LOWER(p_correo) AND id <> p_id AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El correo ya está registrado', 'registro', NULL);
    END IF;

    IF p_id_trabajador IS NOT NULL AND EXISTS (
        SELECT 1 FROM auth_usuarios
        WHERE id_trabajador = p_id_trabajador AND id <> p_id AND estado = TRUE
    ) THEN
        RETURN json_build_object('error', 'El trabajador ya tiene otro usuario de acceso.', 'registro', NULL);
    END IF;

    UPDATE auth_usuarios
    SET
        nombre = COALESCE(p_nombre, nombre),
        correo = COALESCE(LOWER(p_correo), correo),
        contrasena = COALESCE(p_contrasena, contrasena),
        id_trabajador = COALESCE(p_id_trabajador, id_trabajador),
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = TRUE;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN auth_obtener_usuario(p_id);
END;
$function$;
CREATE OR REPLACE FUNCTION auth_obtener_usuario(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            u.id,
            u.nombre,
            u.correo,
            u.estado,
            u.id_trabajador,
            u.fecha_creacion,
            u.fecha_modificacion,
            (
                SELECT COALESCE(json_agg(json_build_object(
                    'id', r.id,
                    'nombre', r.nombre,
                    'descripcion', r.descripcion
                )), '[]'::JSON)
                FROM auth_usuarios_roles ur
                INNER JOIN auth_roles r ON ur.id_rol = r.id
                WHERE ur.id_usuario = u.id AND ur.estado = TRUE AND r.estado = TRUE
            ) AS roles
        FROM auth_usuarios u
        WHERE u.id = p_id AND u.estado = TRUE
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
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
            id_area, id_cargo,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_nombres, p_apellido_paterno, p_apellido_materno,
        p_id_tipo_documento, p_numero_documento, p_correo,
        p_direccion, p_referencia, p_latitud, p_longitud,
            p_id_pais, p_id_departamento, p_id_provincia, p_id_distrito,
            p_fecha_nacimiento, p_fecha_inicio, p_fecha_cese,
            p_id_area, p_id_cargo,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_trabajador;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo o ubicación no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el trabajador: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN tra_obtener_trabajador(v_id_trabajador);
END;
$function$;
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
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion    = NOW()
        WHERE id = p_id AND estado IN (0, 1);

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo o ubicación no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el trabajador: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN tra_obtener_trabajador(p_id);
END;
$function$;
CREATE OR REPLACE FUNCTION tra_obtener_trabajador(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            t.id,
            t.nombres,
            t.apellido_paterno,
            t.apellido_materno,
            t.id_tipo_documento,
            td.nombre  AS nombre_tipo_documento,
    t.numero_documento,
    t.correo,
    t.direccion,
            t.referencia,
            t.latitud,
            t.longitud,
            t.id_pais,
            p.nombre   AS nombre_pais,
            t.id_departamento,
            d.nombre   AS nombre_departamento,
            t.id_provincia,
            pr.nombre  AS nombre_provincia,
            t.id_distrito,
            dis.nombre AS nombre_distrito,
            t.fecha_nacimiento,
            CASE
                WHEN t.fecha_nacimiento IS NULL THEN NULL
                ELSE DATE_PART('year', AGE(CURRENT_DATE, t.fecha_nacimiento))::INT
            END AS edad,
            t.fecha_inicio,
            t.fecha_cese,
            t.id_area,
            a.nombre   AS nombre_area,
            t.id_cargo,
            c.nombre   AS nombre_cargo,
            au.id      AS id_usuario,
            au.nombre  AS nombre_usuario_vinculo,
            (au.id IS NOT NULL) AS es_usuario,
            ch.id      AS id_chofer,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer,
            (ch.id IS NOT NULL) AS es_chofer,
            t.estado,
            t.fecha_creacion,
            t.fecha_modificacion,
            t.id_usuario_creacion,
            uc.nombre  AS nombre_usuario_creacion,
            t.id_usuario_modificacion,
            um.nombre  AS nombre_usuario_modificacion
        FROM tra_trabajadores t
        LEFT JOIN gen_lista_opciones td ON t.id_tipo_documento = td.id
        LEFT JOIN gen_pais p            ON t.id_pais = p.id
        LEFT JOIN gen_departamento d    ON t.id_departamento = d.id
        LEFT JOIN gen_provincia pr      ON t.id_provincia = pr.id
        LEFT JOIN gen_distrito dis      ON t.id_distrito = dis.id
        LEFT JOIN gen_lista_opciones a  ON t.id_area = a.id
        LEFT JOIN gen_lista_opciones c  ON t.id_cargo = c.id
        LEFT JOIN auth_usuarios au      ON au.id_trabajador = t.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch         ON ch.id_trabajador = t.id AND ch.estado = 1
        LEFT JOIN auth_usuarios uc      ON t.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um      ON t.id_usuario_modificacion = um.id
        WHERE t.id = p_id AND t.estado IN (0, 1)
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
DROP FUNCTION IF EXISTS tra_listar_trabajadores(
    INTEGER,
    VARCHAR,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    BOOLEAN
);

CREATE OR REPLACE FUNCTION tra_listar_trabajadores(
    p_estado        INTEGER DEFAULT NULL,   -- 1 activos, 0 cesados, NULL = todos
    p_buscar        VARCHAR DEFAULT '',
    p_id_area       INTEGER DEFAULT NULL,
    p_id_cargo      INTEGER DEFAULT NULL,
    p_limite        INTEGER DEFAULT 10,
    p_offset        INTEGER DEFAULT 0,
    p_solo_sin_usuario BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM tra_trabajadores t
    LEFT JOIN auth_usuarios au ON au.id_trabajador = t.id AND au.estado = TRUE
    WHERE (p_estado IS NULL OR t.estado = p_estado)
      AND (p_id_area IS NULL OR t.id_area = p_id_area)
      AND (p_id_cargo IS NULL OR t.id_cargo = p_id_cargo)
      AND (NOT p_solo_sin_usuario OR au.id IS NULL)
      AND (
          p_buscar = ''
          OR gen_texto_coincide(t.nombres, p_buscar)
          OR gen_texto_coincide(COALESCE(t.apellido_paterno, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(t.apellido_materno, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(t.numero_documento, ''), p_buscar)
      );

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            t.id,
            t.nombres,
            t.apellido_paterno,
            t.apellido_materno,
            t.id_tipo_documento,
            td.nombre  AS nombre_tipo_documento,
    t.numero_documento,
    t.correo,
    t.direccion,
            t.referencia,
            t.latitud,
            t.longitud,
            t.id_pais,
            t.id_departamento,
            t.id_provincia,
            t.id_distrito,
            t.fecha_nacimiento,
            CASE
                WHEN t.fecha_nacimiento IS NULL THEN NULL
                ELSE DATE_PART('year', AGE(CURRENT_DATE, t.fecha_nacimiento))::INT
            END AS edad,
            t.fecha_inicio,
            t.fecha_cese,
            t.id_area,
            a.nombre   AS nombre_area,
            t.id_cargo,
            c.nombre   AS nombre_cargo,
            au.id      AS id_usuario,
            au.nombre  AS nombre_usuario_vinculo,
            (au.id IS NOT NULL) AS es_usuario,
            ch.id      AS id_chofer,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer,
            (ch.id IS NOT NULL) AS es_chofer,
            t.estado,
            t.fecha_creacion,
            t.fecha_modificacion
        FROM tra_trabajadores t
        LEFT JOIN gen_lista_opciones td ON t.id_tipo_documento = td.id
        LEFT JOIN gen_lista_opciones a  ON t.id_area = a.id
        LEFT JOIN gen_lista_opciones c  ON t.id_cargo = c.id
        LEFT JOIN auth_usuarios au      ON au.id_trabajador = t.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch         ON ch.id_trabajador = t.id AND ch.estado = 1
        WHERE (p_estado IS NULL OR t.estado = p_estado)
          AND (p_id_area IS NULL OR t.id_area = p_id_area)
          AND (p_id_cargo IS NULL OR t.id_cargo = p_id_cargo)
          AND (NOT p_solo_sin_usuario OR au.id IS NULL)
          AND (
              p_buscar = ''
              OR gen_texto_coincide(t.nombres, p_buscar)
              OR gen_texto_coincide(COALESCE(t.apellido_paterno, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(t.apellido_materno, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(t.numero_documento, ''), p_buscar)
          )
        ORDER BY t.nombres ASC
        LIMIT p_limite
        OFFSET p_offset
    ) r;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
CREATE OR REPLACE FUNCTION tra_eliminar_trabajador(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE tra_trabajadores
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    -- Borrado lógico del usuario de acceso vinculado (si existe)
    UPDATE auth_usuarios
    SET estado = FALSE,
        fecha_modificacion = NOW()
    WHERE id_trabajador = p_id
      AND estado = TRUE;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;
DROP FUNCTION IF EXISTS gen_crear_chofer(VARCHAR, INTEGER, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, VARCHAR, DATE, DATE, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION gen_crear_chofer(
    p_nombres               VARCHAR,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_id_trabajador         INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    -- licencia
    p_codigo_licencia       VARCHAR DEFAULT NULL,
    p_fecha_emision         DATE    DEFAULT NULL,
    p_fecha_vencimiento     DATE    DEFAULT NULL,
    p_id_tipo_licencia      INTEGER DEFAULT NULL,
    p_id_categoria_licencia INTEGER DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_chofer INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL AND p_id_trabajador IS NULL THEN
        RETURN json_build_object('error', 'El chofer de flota propia debe vincularse a un trabajador.', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NOT NULL AND p_id_trabajador IS NOT NULL THEN
        RETURN json_build_object('error', 'Un chofer de cliente no puede vincularse a un trabajador de la empresa.', 'registro', NULL);
    END IF;

    IF p_id_cliente IS NOT NULL AND p_nombres IS NULL THEN
        RETURN json_build_object('error', 'El nombre es obligatorio para choferes de cliente.', 'registro', NULL);
    END IF;

    IF p_id_trabajador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE id = p_id_trabajador AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El trabajador indicado no existe.', 'registro', NULL);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_chofer WHERE numero_documento = p_numero_documento AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe un chofer registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        INSERT INTO gen_chofer (
            id_cliente, id_trabajador, apellido_paterno, apellido_materno, nombres,
            id_tipo_documento, numero_documento, telefono,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_id_cliente, p_id_trabajador, p_apellido_paterno, p_apellido_materno, p_nombres,
            p_id_tipo_documento, p_numero_documento, p_telefono,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_chofer;

        -- Licencia (opcional al crear el chofer)
        IF p_codigo_licencia IS NOT NULL THEN
            INSERT INTO gen_licencia (
                id_tipo_licencia, id_categoria_licencia, id_chofer, codigo,
                fecha_emision, fecha_vencimiento,
                id_usuario_creacion, id_usuario_modificacion
            )
            VALUES (
                p_id_tipo_licencia, p_id_categoria_licencia, v_id_chofer, p_codigo_licencia,
                p_fecha_emision, p_fecha_vencimiento,
                p_id_usuario_auditoria, p_id_usuario_auditoria
            );
        END IF;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados (documento o código de licencia)', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de cliente, tipo o categoría no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el chofer: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN gen_obtener_chofer(v_id_chofer);
END;
$function$;
/* DROP FUNCTION IF EXISTS gen_crear_chofer(
   VARCHAR,
   INTEGER,
   VARCHAR,
   VARCHAR,
   INTEGER,
   VARCHAR,
   VARCHAR,
   VARCHAR,
   INTEGER
);
CREATE OR REPLACE FUNCTION gen_crear_chofer(
    p_nombres               VARCHAR,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_chofer (
        id_cliente, apellido_paterno, apellido_materno, nombres,
        id_tipo_documento, numero_documento,telefono,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_apellido_paterno, p_apellido_materno, p_nombres,
        p_id_tipo_documento, p_numero_documento, p_telefono,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_chofer(v_id);
END;
$function$;
 */DROP FUNCTION IF EXISTS gen_actualizar_chofer(INTEGER, INTEGER, VARCHAR, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, VARCHAR, DATE, DATE, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION gen_actualizar_chofer(
    p_id                    INTEGER,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_id_trabajador         INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_nombres               VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    p_codigo_licencia       VARCHAR DEFAULT NULL,
    p_fecha_emision         DATE    DEFAULT NULL,
    p_fecha_vencimiento     DATE    DEFAULT NULL,
    p_id_tipo_licencia      INTEGER DEFAULT NULL,
    p_id_categoria_licencia INTEGER DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_licencia INTEGER;
    v_id_cliente_actual INTEGER;
    v_id_trabajador_actual INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_cliente, id_trabajador INTO v_id_cliente_actual, v_id_trabajador_actual
    FROM gen_chofer WHERE id = p_id AND estado = 1;

    IF v_id_cliente_actual IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'No existe un chofer con id ' || p_id);
    END IF;

    IF p_id_trabajador IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM tra_trabajadores WHERE id = p_id_trabajador AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El trabajador indicado no existe.', 'registro', NULL);
    END IF;

    IF (COALESCE(p_id_cliente, v_id_cliente_actual) IS NULL) AND (p_id_trabajador IS NULL) AND v_id_trabajador_actual IS NULL THEN
        RETURN json_build_object('error', 'El chofer de flota propia debe vincularse a un trabajador.', 'registro', NULL);
    END IF;

    IF (COALESCE(p_id_cliente, v_id_cliente_actual) IS NOT NULL) AND (COALESCE(p_id_trabajador, v_id_trabajador_actual) IS NOT NULL) THEN
        RETURN json_build_object('error', 'Un chofer de cliente no puede vincularse a un trabajador de la empresa.', 'registro', NULL);
    END IF;

    IF p_numero_documento IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_chofer WHERE numero_documento = p_numero_documento AND id <> p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro chofer registrado con el documento ' || p_numero_documento, 'registro', NULL);
    END IF;

    BEGIN
        UPDATE gen_chofer
        SET
            id_cliente = COALESCE(p_id_cliente, id_cliente),
            id_trabajador = COALESCE(p_id_trabajador, id_trabajador),
            apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
            apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
            nombres = COALESCE(p_nombres, nombres),
            id_tipo_documento = COALESCE(p_id_tipo_documento, id_tipo_documento),
            numero_documento = COALESCE(p_numero_documento, numero_documento),
            telefono = COALESCE(p_telefono, telefono),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id AND estado = 1;

        IF p_codigo_licencia IS NOT NULL OR p_fecha_emision IS NOT NULL OR p_fecha_vencimiento IS NOT NULL
           OR p_id_tipo_licencia IS NOT NULL OR p_id_categoria_licencia IS NOT NULL THEN

            SELECT id INTO v_id_licencia
            FROM gen_licencia
            WHERE id_chofer = p_id AND estado = 1
            ORDER BY fecha_emision DESC, id DESC
            LIMIT 1;

            IF v_id_licencia IS NOT NULL THEN
                UPDATE gen_licencia SET
                    codigo                  = COALESCE(p_codigo_licencia, codigo),
                    fecha_emision           = COALESCE(p_fecha_emision, fecha_emision),
                    fecha_vencimiento       = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
                    id_tipo_licencia        = COALESCE(p_id_tipo_licencia, id_tipo_licencia),
                    id_categoria_licencia   = COALESCE(p_id_categoria_licencia, id_categoria_licencia),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion      = NOW()
                WHERE id = v_id_licencia;
            ELSIF p_codigo_licencia IS NOT NULL AND p_fecha_emision IS NOT NULL AND p_fecha_vencimiento IS NOT NULL THEN
                INSERT INTO gen_licencia (
                    id_tipo_licencia, id_categoria_licencia, id_chofer, codigo,
                    fecha_emision, fecha_vencimiento,
                    id_usuario_creacion, id_usuario_modificacion
                )
                VALUES (
                    p_id_tipo_licencia, p_id_categoria_licencia, p_id, p_codigo_licencia,
                    p_fecha_emision, p_fecha_vencimiento,
                    p_id_usuario_auditoria, p_id_usuario_auditoria
                );
            END IF;
        END IF;

    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object('error', 'Ya existe un registro con datos duplicados', 'registro', NULL);
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de tipo o categoría no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el chofer: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN gen_obtener_chofer(p_id);
END;
$function$;
/* DROP FUNCTION IF EXISTS gen_actualizar_chofer(
   INTEGER,
   INTEGER,
   VARCHAR,
   VARCHAR,
   VARCHAR,
   INTEGER,
   VARCHAR,
   VARCHAR,
   INTEGER
);
CREATE OR REPLACE FUNCTION gen_actualizar_chofer(
    p_id                    INTEGER,
    p_id_cliente            INTEGER DEFAULT NULL,
    p_apellido_paterno      VARCHAR DEFAULT NULL,
    p_apellido_materno      VARCHAR DEFAULT NULL,
    p_nombres               VARCHAR DEFAULT NULL,
    p_id_tipo_documento     INTEGER DEFAULT NULL,
    p_numero_documento      VARCHAR DEFAULT NULL,
    p_telefono              VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria  INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    UPDATE gen_chofer
    SET
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        apellido_paterno = COALESCE(p_apellido_paterno, apellido_paterno),
        apellido_materno = COALESCE(p_apellido_materno, apellido_materno),
        nombres = COALESCE(p_nombres, nombres),
        id_tipo_documento = COALESCE(p_id_tipo_documento, id_tipo_documento),
        numero_documento = COALESCE(p_numero_documento, numero_documento),
        telefono = COALESCE(p_telefono, telefono),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_chofer(p_id);
END;
$function$;
 */CREATE OR REPLACE FUNCTION gen_obtener_chofer(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            ch.id_trabajador,
            (ch.id_trabajador IS NOT NULL) AS es_chofer_empresa,
            COALESCE(tr.apellido_paterno, ch.apellido_paterno) AS apellido_paterno,
            COALESCE(tr.apellido_materno, ch.apellido_materno) AS apellido_materno,
            COALESCE(tr.nombres, ch.nombres) AS nombres,
            COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) AS id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            COALESCE(tr.numero_documento, ch.numero_documento) AS numero_documento,
            ch.telefono,

            -- Licencia vigente (la más reciente activa)
            lic.id                    AS id_licencia,
            lic.codigo                AS codigo_licencia,
            lic.fecha_emision,
            lic.fecha_vencimiento,
            lic.id_tipo_licencia,
            tl.nombre                 AS nombre_tipo_licencia,
            lic.id_categoria_licencia,
            cl.nombre                 AS nombre_categoria_licencia,

            ch.estado,
            ch.fecha_creacion,
            ch.fecha_modificacion,
            ch.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ch.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_chofer ch
        LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
        LEFT JOIN gen_lista_opciones td ON COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id

        LEFT JOIN LATERAL (
            SELECT gl.*
            FROM gen_licencia gl
            WHERE gl.id_chofer = ch.id
              AND gl.estado = 1
            ORDER BY gl.fecha_emision DESC, gl.id DESC
            LIMIT 1
        ) lic ON TRUE
        LEFT JOIN gen_lista_opciones tl ON lic.id_tipo_licencia = tl.id
        LEFT JOIN gen_lista_opciones cl ON lic.id_categoria_licencia = cl.id

        WHERE ch.id = p_id AND ch.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
/* CREATE OR REPLACE FUNCTION gen_obtener_chofer(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            ch.apellido_paterno,
            ch.apellido_materno,
            ch.nombres,
            ch.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            ch.numero_documento,
            ch.telefono,
            ch.estado,
            ch.fecha_creacion,
            ch.fecha_modificacion,
            ch.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ch.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_chofer ch
        LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
        LEFT JOIN gen_lista_opciones td ON ch.id_tipo_documento = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id
        WHERE ch.id = p_id AND ch.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
 */DROP FUNCTION IF EXISTS gen_listar_choferes(
    INT,
    VARCHAR,
    INTEGER,
    INTEGER,
    INTEGER
);
CREATE OR REPLACE FUNCTION gen_listar_choferes(
    p_solo_activos INT DEFAULT NULL,
    p_buscar VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_chofer ch
    LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
    LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
    WHERE (p_solo_activos IS NULL OR ch.estado = p_solo_activos)
      AND (
          p_id_cliente IS NULL
          OR ch.id_cliente = p_id_cliente
          OR (p_id_cliente = -1 AND ch.id_cliente IS NULL)
      )
      AND (
          p_buscar = ''
          OR gen_texto_coincide(COALESCE(tr.nombres, ch.nombres), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.apellido_paterno, ch.apellido_paterno), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.apellido_materno, ch.apellido_materno), p_buscar)
          OR gen_texto_coincide(COALESCE(tr.numero_documento, ch.numero_documento), p_buscar)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            ch.id,
            ch.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            ch.id_trabajador,
            (ch.id_trabajador IS NOT NULL) AS es_chofer_empresa,
            COALESCE(tr.apellido_paterno, ch.apellido_paterno) AS apellido_paterno,
            COALESCE(tr.apellido_materno, ch.apellido_materno) AS apellido_materno,
            COALESCE(tr.nombres, ch.nombres) AS nombres,
            COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) AS id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            COALESCE(tr.numero_documento, ch.numero_documento) AS numero_documento,
            ch.telefono,
            ch.estado,
            ch.fecha_creacion,
            ch.fecha_modificacion,
            ch.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            ch.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_chofer ch
        LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = ch.id_trabajador
        LEFT JOIN gen_lista_opciones td ON COALESCE(tr.id_tipo_documento, ch.id_tipo_documento) = td.id
        LEFT JOIN auth_usuarios uc ON ch.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON ch.id_usuario_modificacion = um.id
        WHERE (p_solo_activos IS NULL OR ch.estado = p_solo_activos)
          AND (
              p_id_cliente IS NULL
              OR ch.id_cliente = p_id_cliente
              OR (p_id_cliente = -1 AND ch.id_cliente IS NULL)
          )
          AND (
              p_buscar = ''
              OR gen_texto_coincide(COALESCE(tr.nombres, ch.nombres), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.apellido_paterno, ch.apellido_paterno), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.apellido_materno, ch.apellido_materno), p_buscar)
              OR gen_texto_coincide(COALESCE(tr.numero_documento, ch.numero_documento), p_buscar)
          )
        ORDER BY COALESCE(tr.nombres, ch.nombres) ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

DROP FUNCTION IF EXISTS age_crear_actividad (
    VARCHAR,
    TEXT,
    DATE,
    TIME,
    TIME,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    VARCHAR,
    INTEGER,
    INTEGER,
    INTEGER,
    INTEGER,
    JSON
);

CREATE OR REPLACE FUNCTION age_crear_actividad(
    p_titulo VARCHAR,
    p_descripcion TEXT,
    p_fecha_programada DATE,
    p_hora_inicio_estimada TIME,
    p_hora_fin_estimada TIME,
    p_id_tipo_actividad INTEGER,
    p_id_prioridad INTEGER,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_trabajador_responsable INTEGER DEFAULT NULL,
    p_id_estado_actividad INTEGER DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_id_guia_remision INTEGER DEFAULT NULL,
    p_items JSON DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_tipo VARCHAR;
    v_cliente INTEGER;
    v_destinatario INTEGER;
    v_titulo VARCHAR;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_item JSON;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_cliente := p_id_cliente;
    v_titulo := NULLIF(TRIM(COALESCE(p_titulo, '')), '');

    IF p_id_comprobante IS NOT NULL THEN
        SELECT vc.id_cliente, vc.serie, vc.numero
        INTO v_cliente, v_serie, v_numero
        FROM ven_comprobante vc
        WHERE vc.id = p_id_comprobante AND vc.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('registro', NULL, 'error', 'El comprobante indicado no existe.');
        END IF;

        v_cliente := COALESCE(p_id_cliente, v_cliente);
        IF v_titulo IS NULL THEN
            v_titulo := TRIM(CONCAT('Reparto ', COALESCE(v_serie, ''), '-', COALESCE(v_numero, '')));
        END IF;

        IF EXISTS (
            SELECT 1
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE a.id_comprobante = p_id_comprobante
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'Este comprobante ya tiene un reparto / actividad vigente.');
        END IF;
    END IF;

    IF p_id_guia_remision IS NOT NULL THEN
        SELECT gr.id_cliente, gr.id_destinatario, gr.serie, gr.numero
        INTO v_cliente, v_destinatario, v_serie, v_numero
        FROM gre_guia_remision gr
        WHERE gr.id = p_id_guia_remision AND gr.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('registro', NULL, 'error', 'La guía de remisión indicada no existe.');
        END IF;

        v_cliente := COALESCE(p_id_cliente, v_cliente, v_destinatario);
        IF v_titulo IS NULL THEN
            v_titulo := TRIM(CONCAT('Reparto GRE ', COALESCE(v_serie, ''), '-', COALESCE(v_numero, '')));
        END IF;

        IF EXISTS (
            SELECT 1
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            WHERE a.id_guia_remision = p_id_guia_remision
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'Esta guía de remisión ya tiene un reparto / actividad vigente.');
        END IF;
    END IF;

    IF v_titulo IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'El título es obligatorio.');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_tipo_actividad
          AND o.estado = 1
          AND (l.nombre = 'TipoActividad' OR l.id = 48)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El tipo de actividad indicado no es válido.');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_prioridad
          AND o.estado = 1
          AND (l.nombre = 'PrioridadActividad' OR l.id = 50)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'La prioridad indicada no es válida.');
    END IF;

    IF p_id_estado_actividad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_estado_actividad
          AND o.estado = 1
          AND (l.nombre = 'EstadoActividad' OR l.id = 49)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El estado de actividad indicado no es válido.');
    END IF;

    IF p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF p_hora_inicio_estimada >= p_hora_fin_estimada THEN
            RETURN json_build_object('registro', NULL, 'error', 'La hora de inicio estimada debe ser menor a la hora de fin estimada.');
        END IF;
    END IF;

    SELECT UPPER(TRIM(nombre)) INTO v_tipo
    FROM gen_lista_opciones
    WHERE id = p_id_tipo_actividad;

    IF v_tipo = 'REPARTO' THEN
        IF p_id_trabajador_responsable IS NOT NULL THEN
            IF NOT EXISTS (
                SELECT 1 FROM tra_trabajadores t
                INNER JOIN gen_chofer c ON c.id_trabajador = t.id
                WHERE t.id = p_id_trabajador_responsable AND t.estado = 1 AND c.estado = 1 AND c.id_cliente IS NULL
            ) THEN
                RETURN json_build_object('error', 'El responsable debe ser un trabajador chofer de flota propia (repartidor).');
            END IF;
        END IF;
    END IF;

    IF p_id_trabajador_responsable IS NOT NULL AND p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM age_actividad
            WHERE id_trabajador_responsable = p_id_trabajador_responsable
              AND fecha_programada = p_fecha_programada
              AND estado = 1
              AND NOT EXISTS (
                  SELECT 1 FROM gen_lista_opciones ea
                  WHERE ea.id = age_actividad.id_estado_actividad
                    AND UPPER(TRIM(ea.nombre)) IN ('CANCELADA', 'CANCELADO')
              )
              AND (
                  (p_hora_inicio_estimada >= hora_inicio_estimada AND p_hora_inicio_estimada < hora_fin_estimada)
                  OR (p_hora_fin_estimada > hora_inicio_estimada AND p_hora_fin_estimada <= hora_fin_estimada)
                  OR (p_hora_inicio_estimada <= hora_inicio_estimada AND p_hora_fin_estimada >= hora_fin_estimada)
              )
        ) THEN
            RETURN json_build_object('error', 'El responsable (trabajador) ya tiene otra actividad asignada que se cruza en ese horario para la fecha seleccionada.');
        END IF;
    END IF;

    INSERT INTO age_actividad (
        titulo, descripcion, fecha_programada,
        hora_inicio_estimada, hora_fin_estimada,
        id_tipo_actividad, id_prioridad, id_cliente,
        id_trabajador_responsable, id_comprobante,
        id_guia_remision,
        id_estado_actividad, observaciones,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_titulo, p_descripcion, p_fecha_programada,
        p_hora_inicio_estimada, p_hora_fin_estimada,
        p_id_tipo_actividad, p_id_prioridad, v_cliente,
        p_id_trabajador_responsable, p_id_comprobante,
        p_id_guia_remision,
        p_id_estado_actividad, p_observaciones,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    IF p_items IS NOT NULL AND json_typeof(p_items) = 'array' THEN
        FOR v_item IN SELECT value FROM json_array_elements(p_items)
        LOOP
            v_n := v_n + 1;
            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                v_id,
                COALESCE((v_item->>'item')::INTEGER, v_n),
                COALESCE((v_item->>'idProducto')::INTEGER, (v_item->>'id_producto')::INTEGER),
                NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
                COALESCE((v_item->>'cantidad')::NUMERIC, 1),
                COALESCE((v_item->>'idBalon')::INTEGER, (v_item->>'id_balon')::INTEGER),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    ELSIF p_id_comprobante IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            v_id,
            d.item,
            d.id_producto,
            NULLIF(TRIM(COALESCE(d.descripcion, p.nombre, '')), ''),
            d.cantidad,
            d.id_balon,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON p.id = d.id_producto
        WHERE d.id_comprobante = p_id_comprobante AND d.estado = 1
        ORDER BY d.item;
    ELSIF p_id_guia_remision IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            v_id,
            d.item,
            d.id_producto,
            NULLIF(TRIM(COALESCE(d.descripcion, d.glosa, p.nombre, '')), ''),
            d.cantidad,
            d.id_balon,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM gre_guia_remision_detalle d
        LEFT JOIN pro_producto p ON p.id = d.id_producto
        WHERE d.id_guia_remision = p_id_guia_remision AND d.estado = 1
        ORDER BY d.item;
    END IF;

    RETURN age_obtener_actividad(v_id);
END;
$function$;DROP FUNCTION IF EXISTS age_actualizar_actividad(
    INTEGER, VARCHAR, TEXT, DATE, TIME, TIME, TIMESTAMP, INTEGER, INTEGER,
    INTEGER, INTEGER, INTEGER, VARCHAR, INTEGER, INTEGER, JSON
);

CREATE OR REPLACE FUNCTION age_actualizar_actividad(
    p_id INTEGER,
    p_titulo VARCHAR,
    p_descripcion TEXT,
    p_fecha_programada DATE,
    p_hora_inicio_estimada TIME,
    p_hora_fin_estimada TIME,
    p_fecha_hora_cierre TIMESTAMP,
    p_id_tipo_actividad INTEGER,
    p_id_prioridad INTEGER,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_trabajador_responsable INTEGER DEFAULT NULL,
    p_id_estado_actividad INTEGER DEFAULT NULL,
    p_observaciones VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_items JSON DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo VARCHAR;
    v_item JSON;
    v_n INTEGER := 0;
    v_hora_inicio TIME;
    v_hora_fin TIME;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT
        COALESCE(p_hora_inicio_estimada, hora_inicio_estimada),
        COALESCE(p_hora_fin_estimada, hora_fin_estimada)
    INTO v_hora_inicio, v_hora_fin
    FROM age_actividad
    WHERE id = p_id AND estado = 1;

    IF v_hora_inicio IS NOT NULL AND v_hora_fin IS NOT NULL THEN
        IF v_hora_inicio >= v_hora_fin THEN
            RETURN json_build_object('registro', NULL, 'error', 'La hora de inicio estimada debe ser menor a la hora de fin estimada.');
        END IF;
    END IF;

    IF p_id_tipo_actividad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_tipo_actividad
          AND o.estado = 1
          AND (l.nombre = 'TipoActividad' OR l.id = 48)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El tipo de actividad indicado no es válido.');
    END IF;

    IF p_id_prioridad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_prioridad
          AND o.estado = 1
          AND (l.nombre = 'PrioridadActividad' OR l.id = 50)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'La prioridad indicada no es válida.');
    END IF;

    IF p_id_estado_actividad IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        INNER JOIN gen_lista l ON l.id = o.id_lista
        WHERE o.id = p_id_estado_actividad
          AND o.estado = 1
          AND (l.nombre = 'EstadoActividad' OR l.id = 49)
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El estado de actividad indicado no es válido.');
    END IF;

    IF p_id_tipo_actividad IS NOT NULL THEN
        SELECT UPPER(TRIM(nombre)) INTO v_tipo
        FROM gen_lista_opciones
        WHERE id = p_id_tipo_actividad;

        IF v_tipo = 'REPARTO' THEN
            IF p_id_trabajador_responsable IS NOT NULL THEN
                IF NOT EXISTS (
                    SELECT 1 FROM tra_trabajadores t
                    INNER JOIN gen_chofer c ON c.id_trabajador = t.id
                    WHERE t.id = p_id_trabajador_responsable AND t.estado = 1 AND c.estado = 1 AND c.id_cliente IS NULL
                ) THEN
                    RETURN json_build_object('registro', NULL, 'error', 'El responsable debe ser un trabajador chofer de flota propia (repartidor).');
                END IF;
            END IF;
        END IF;
    END IF;

    IF p_id_trabajador_responsable IS NOT NULL AND p_hora_inicio_estimada IS NOT NULL AND p_hora_fin_estimada IS NOT NULL THEN
        IF EXISTS (
            SELECT 1
            FROM age_actividad
            WHERE id <> p_id
              AND id_trabajador_responsable = p_id_trabajador_responsable
              AND fecha_programada = p_fecha_programada
              AND estado = 1
              AND NOT EXISTS (
                  SELECT 1 FROM gen_lista_opciones ea
                  WHERE ea.id = age_actividad.id_estado_actividad
                    AND UPPER(TRIM(ea.nombre)) IN ('CANCELADA', 'CANCELADO')
              )
              AND (
                  (p_hora_inicio_estimada >= hora_inicio_estimada AND p_hora_inicio_estimada < hora_fin_estimada)
                  OR (p_hora_fin_estimada > hora_inicio_estimada AND p_hora_fin_estimada <= hora_fin_estimada)
                  OR (p_hora_inicio_estimada <= hora_inicio_estimada AND p_hora_fin_estimada >= hora_fin_estimada)
              )
        ) THEN
            RETURN json_build_object('registro', NULL, 'error', 'El responsable (trabajador) ya tiene otra actividad asignada que se cruza en ese horario para la fecha seleccionada.');
        END IF;
    END IF;

    UPDATE age_actividad
    SET
        titulo = COALESCE(p_titulo, titulo),
        descripcion = COALESCE(p_descripcion, descripcion),
        fecha_programada = COALESCE(p_fecha_programada, fecha_programada),
        hora_inicio_estimada = COALESCE(p_hora_inicio_estimada, hora_inicio_estimada),
        hora_fin_estimada = COALESCE(p_hora_fin_estimada, hora_fin_estimada),
        fecha_hora_cierre = COALESCE(p_fecha_hora_cierre, fecha_hora_cierre),
        id_tipo_actividad = COALESCE(p_id_tipo_actividad, id_tipo_actividad),
        id_prioridad = COALESCE(p_id_prioridad, id_prioridad),
        id_cliente = COALESCE(p_id_cliente, id_cliente),
        id_trabajador_responsable = COALESCE(p_id_trabajador_responsable, id_trabajador_responsable),
        id_comprobante = COALESCE(p_id_comprobante, id_comprobante),
        id_estado_actividad = COALESCE(p_id_estado_actividad, id_estado_actividad),
        observaciones = COALESCE(p_observaciones, observaciones),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF p_items IS NOT NULL AND json_typeof(p_items) = 'array' THEN
        UPDATE age_actividad_item
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_actividad = p_id AND estado = 1;

        FOR v_item IN SELECT value FROM json_array_elements(p_items)
        LOOP
            v_n := v_n + 1;
            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id,
                COALESCE((v_item->>'item')::INTEGER, v_n),
                COALESCE((v_item->>'idProducto')::INTEGER, (v_item->>'id_producto')::INTEGER),
                NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
                COALESCE((v_item->>'cantidad')::NUMERIC, 1),
                COALESCE((v_item->>'idBalon')::INTEGER, (v_item->>'id_balon')::INTEGER),
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            );
        END LOOP;
    END IF;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
DROP FUNCTION IF EXISTS age_asignar_responsable_actividad(INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION age_asignar_responsable_actividad(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_trabajador_responsable INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE age_actividad
    SET
        id_trabajador_responsable = p_id_trabajador_responsable,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;
DROP FUNCTION IF EXISTS age_obtener_actividad(INTEGER);

CREATE OR REPLACE FUNCTION age_obtener_actividad(
    p_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_registro JSON;
    v_items JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON)
    INTO v_items
    FROM (
        SELECT
            i.id,
            i.item,
            i.id_producto,
            COALESCE(p.nombre, i.descripcion) AS nombre_producto,
            i.descripcion,
            i.cantidad,
            i.id_balon,
            b.codigo_balon
        FROM age_actividad_item i
        LEFT JOIN pro_producto p ON p.id = i.id_producto
        LEFT JOIN bal_balon b ON b.id = i.id_balon
        WHERE i.id_actividad = p_id AND i.estado = 1
    ) t;

    SELECT row_to_json(t)
    INTO v_registro
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            dir.latitud AS latitud_cliente,
            dir.longitud AS longitud_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            act.id_guia_remision,
            gr.serie AS serie_guia_remision,
            gr.numero AS numero_guia_remision,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.estado,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            act.fecha_creacion,
            act.fecha_modificacion,
            v_items AS items
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud
            FROM cli_direcciones cd
            WHERE cd.id_cliente = act.id_cliente
              AND cd.estado = 1
            ORDER BY cd.es_principal DESC NULLS LAST, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch ON ch.id_trabajador = tr.id AND ch.estado = 1
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        LEFT JOIN gre_guia_remision gr ON act.id_guia_remision = gr.id
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
        WHERE act.id = p_id AND act.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
DROP FUNCTION IF EXISTS age_listar_actividades(VARCHAR, INTEGER, INTEGER, DATE, DATE, INTEGER, INTEGER, INTEGER, BOOLEAN);

CREATE OR REPLACE FUNCTION age_listar_actividades(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL,
    p_id_estado INTEGER DEFAULT NULL,
    p_id_tipo INTEGER DEFAULT NULL,
    p_id_prioridad INTEGER DEFAULT NULL,
    p_sin_responsable BOOLEAN DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM age_actividad act
    LEFT JOIN cli_clientes c ON act.id_cliente = c.id
    WHERE act.estado = 1
      AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
      AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
      AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
      AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
       AND (p_sin_responsable IS NULL OR (
           (p_sin_responsable AND act.id_trabajador_responsable IS NULL)
           OR (NOT p_sin_responsable AND act.id_trabajador_responsable IS NOT NULL)
       ))
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(act.titulo, p_busqueda)
          OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.fecha_hora_cierre,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            act.id_trabajador_responsable,
            TRIM(CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno)) AS nombre_trabajador_responsable,
            act.id_usuario_responsable,
            au.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            act.id_guia_remision,
            gr.serie AS serie_guia_remision,
            gr.numero AS numero_guia_remision,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.observaciones,
            act.fecha_creacion,
            act.fecha_modificacion,
            act.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            act.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta
            ON ta.id = act.id_tipo_actividad
           AND ta.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'TipoActividad' OR gl.id = 48)
        LEFT JOIN gen_lista_opciones pr
            ON pr.id = act.id_prioridad
           AND pr.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'PrioridadActividad' OR gl.id = 50)
        LEFT JOIN gen_lista_opciones ea
            ON ea.id = act.id_estado_actividad
           AND ea.id_lista IN (SELECT gl.id FROM gen_lista gl WHERE gl.nombre = 'EstadoActividad' OR gl.id = 49)
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN tra_trabajadores tr ON tr.id = act.id_trabajador_responsable
        LEFT JOIN auth_usuarios au ON au.id_trabajador = tr.id AND au.estado = TRUE
        LEFT JOIN gen_chofer ch ON ch.id_trabajador = tr.id AND ch.estado = 1
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        LEFT JOIN gre_guia_remision gr ON act.id_guia_remision = gr.id
        LEFT JOIN auth_usuarios uc ON act.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON act.id_usuario_modificacion = um.id
        WHERE act.estado = 1
          AND (p_fecha_desde IS NULL OR act.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR act.fecha_programada <= p_fecha_hasta)
          AND (p_id_estado IS NULL OR act.id_estado_actividad = p_id_estado)
          AND (p_id_tipo IS NULL OR act.id_tipo_actividad = p_id_tipo)
          AND (p_id_prioridad IS NULL OR act.id_prioridad = p_id_prioridad)
          AND (p_sin_responsable IS NULL OR (
              (p_sin_responsable AND act.id_usuario_responsable IS NULL AND act.id_chofer_responsable IS NULL)
              OR (NOT p_sin_responsable AND (act.id_usuario_responsable IS NOT NULL OR act.id_chofer_responsable IS NOT NULL))
          ))
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(act.titulo, p_busqueda)
              OR gen_texto_coincide(COALESCE(act.observaciones, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          )
        ORDER BY
            CASE
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('PENDIENTE', 'PROGRAMADA') THEN 0
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) IN ('CANCELADA', 'CANCELADO') THEN 2
                WHEN UPPER(TRIM(COALESCE(ea.nombre, ''))) = 'REALIZADA' THEN 3
                ELSE 1
            END ASC,
            act.fecha_programada DESC,
            act.hora_inicio_estimada DESC NULLS LAST,
            act.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
CREATE OR REPLACE FUNCTION age_sync_responsable_trabajador()
RETURNS TRIGGER AS $function$
BEGIN
  IF NEW.id_trabajador_responsable IS NOT NULL THEN
    SELECT c.id
    INTO NEW.id_chofer_responsable
    FROM gen_chofer c
    WHERE c.id_trabajador = NEW.id_trabajador_responsable
      AND c.id_cliente IS NULL
      AND c.estado = 1
    LIMIT 1;

    SELECT u.id
    INTO NEW.id_usuario_responsable
    FROM auth_usuarios u
    WHERE u.id_trabajador = NEW.id_trabajador_responsable
      AND u.estado = TRUE
    LIMIT 1;
  ELSE
    NEW.id_chofer_responsable := NULL;
    NEW.id_usuario_responsable := NULL;
  END IF;

  RETURN NEW;
END;
$function$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_age_sync_responsable ON age_actividad;

CREATE TRIGGER trg_age_sync_responsable
  BEFORE INSERT OR UPDATE ON age_actividad
  FOR EACH ROW
  EXECUTE FUNCTION age_sync_responsable_trabajador();
