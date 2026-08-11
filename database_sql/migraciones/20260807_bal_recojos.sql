-- ============================================================
-- Migración: Recojos de balones (visitas de recogida programadas)
-- Fecha: 2026-08-07
-- ============================================================

-- Listas
INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('EstadoRecojo', 'Estados de visita de recojo de cilindros en préstamo'),
        ('ResultadoRecojoDetalle', 'Resultado por cilindro en una visita de recojo'),
        ('MotivoFalloRecojo', 'Motivo de fallo / no recogido en visita de recojo')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PROGRAMADO', 'Visita de recojo programada'),
        ('EN_RUTA', 'Operario en ruta hacia el cliente'),
        ('EXITOSO', 'Todos los cilindros fueron recogidos'),
        ('FALLIDO', 'No se recogió ningún cilindro'),
        ('REPROGRAMADO', 'Visita parcial; se generó nueva programación'),
        ('CANCELADO', 'Visita cancelada')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoRecojo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('RECOGIDO', 'Cilindro recogido y devuelto al almacén'),
        ('NO_RECOGIDO', 'No se pudo recoger el cilindro en esta visita'),
        ('EXTENDIDO', 'Se extendió la fecha de retorno pactada')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'ResultadoRecojoDetalle'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('CLIENTE_AUSENTE', 'Cliente ausente en el domicilio'),
        ('SIN_ACCESO', 'Sin acceso al local / domicilio'),
        ('CILINDRO_NO_DISPONIBLE', 'Cilindro no disponible en el momento'),
        ('GAS_NO_USADO', 'Gas aún no utilizado / cliente pide mantener'),
        ('OTRO', 'Otro motivo')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'MotivoFalloRecojo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

-- Tablas
CREATE TABLE IF NOT EXISTS bal_recojo (
    id                       SERIAL PRIMARY KEY,
    id_cliente               INT NOT NULL REFERENCES cli_clientes(id),
    id_prestamo              INT NULL REFERENCES bal_prestamo(id),
    fecha_programada         DATE NOT NULL,
    hora_estimada            TIME NULL,
    fecha_visita             DATE NULL,
    id_usuario_responsable   INT NULL REFERENCES auth_usuarios(id),
    id_estado                INT REFERENCES gen_lista_opciones(id),
    id_motivo_fallo          INT REFERENCES gen_lista_opciones(id),
    observacion              VARCHAR(500),
    estado                   INT NOT NULL DEFAULT 1,
    id_usuario_creacion      INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion  INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS bal_recojo_detalle (
    id                       SERIAL PRIMARY KEY,
    id_recojo                INT NOT NULL REFERENCES bal_recojo(id),
    id_prestamo_detalle      INT NOT NULL REFERENCES bal_prestamo_detalle(id),
    id_resultado             INT REFERENCES gen_lista_opciones(id),
    id_estado_contenido      INT REFERENCES gen_lista_opciones(id),
    nueva_fecha_retorno      DATE NULL,
    id_almacen_destino       INT NULL REFERENCES gen_almacen(id),
    observacion              VARCHAR(500),
    estado                   INT NOT NULL DEFAULT 1,
    id_usuario_creacion      INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion  INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_recojo, id_prestamo_detalle)
);

CREATE INDEX IF NOT EXISTS idx_bal_recojo_cliente ON bal_recojo(id_cliente);
CREATE INDEX IF NOT EXISTS idx_bal_recojo_prestamo ON bal_recojo(id_prestamo);
CREATE INDEX IF NOT EXISTS idx_bal_recojo_fecha ON bal_recojo(fecha_programada);
CREATE INDEX IF NOT EXISTS idx_bal_recojo_estado ON bal_recojo(id_estado);
CREATE INDEX IF NOT EXISTS idx_bal_recojo_det_cab ON bal_recojo_detalle(id_recojo);
CREATE INDEX IF NOT EXISTS idx_bal_recojo_det_pd ON bal_recojo_detalle(id_prestamo_detalle);

-- Permisos
INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('recojos_balon.listar', 'Listar visitas de recojo de cilindros'),
        ('recojos_balon.ver', 'Ver detalle de visita de recojo'),
        ('recojos_balon.crear', 'Programar visitas de recojo'),
        ('recojos_balon.editar', 'Editar / registrar resultado de recojo'),
        ('recojos_balon.eliminar', 'Eliminar visitas de recojo')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'recojos_balon.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );

-- Firma ampliada de devolución (contenido + observación)
DROP FUNCTION IF EXISTS bal_devolver_prestamo_detalle(INTEGER, DATE, INTEGER, INTEGER);


-- >>> funciones\prestamos-detalle\bal_devolver_prestamo_detalle.sql

CREATE OR REPLACE FUNCTION bal_devolver_prestamo_detalle(
    p_id INTEGER,
    p_fecha_devolucion DATE DEFAULT CURRENT_DATE,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_nombre_estado_contenido VARCHAR DEFAULT 'VACIO',
    p_observacion VARCHAR DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_prestamo INTEGER;
    v_id_balon INTEGER;
    v_id_cliente INTEGER;
    v_id_almacen INTEGER;
    v_fecha_devolucion DATE;
    v_id_almacen_destino INTEGER;
    v_id_tipo_movimiento INTEGER;
    v_id_tipo_documento_ref INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_detalle_devuelto INTEGER;
    v_id_estado_cerrado INTEGER;
    v_id_estado_contenido INTEGER;
    v_obs_actual VARCHAR(500);
    v_obs_nueva VARCHAR(500);
    v_mov_result JSON;
    v_pendientes INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        pd.id_prestamo,
        pd.id_balon,
        pd.fecha_devolucion,
        pd.observacion,
        p.id_cliente,
        p.id_almacen
    INTO
        v_id_prestamo,
        v_id_balon,
        v_fecha_devolucion,
        v_obs_actual,
        v_id_cliente,
        v_id_almacen
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE pd.id = p_id
      AND pd.estado = 1;

    IF v_id_prestamo IS NULL THEN
        RETURN json_build_object(
            'error', 'El detalle de prÃ©stamo no existe o estÃ¡ inactivo',
            'registro', NULL
        );
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RETURN json_build_object(
            'error', 'El cilindro ya fue registrado como devuelto',
            'registro', NULL
        );
    END IF;

    v_id_almacen_destino := COALESCE(p_id_almacen_destino, v_id_almacen);

    IF v_id_balon IS NOT NULL AND v_id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el almacÃ©n de destino de la devoluciÃ³n',
            'registro', NULL
        );
    END IF;

    IF v_id_almacen_destino IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_destino AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El almacÃ©n de destino no existe o estÃ¡ inactivo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    IF v_id_balon IS NOT NULL AND v_id_estado_en_almacen IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontrÃ³ el estado EN_ALMACEN del cilindro. Revise el catÃ¡logo EstadoBalon.',
            'registro', NULL
        );
    END IF;

    v_id_estado_contenido := bal_id_estado_contenido(
        COALESCE(NULLIF(TRIM(p_nombre_estado_contenido), ''), 'VACIO')
    );

    SELECT lo.id INTO v_id_tipo_movimiento
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoMovBalon' AND lo.nombre = 'ENTRADA_DEVOLUCION' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_documento_ref
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'PRESTAMO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_detalle_devuelto
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_cerrado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'CERRADO' AND lo.estado = 1
    LIMIT 1;

    v_obs_nueva := NULLIF(TRIM(p_observacion), '');
    IF v_obs_nueva IS NOT NULL THEN
        IF NULLIF(TRIM(v_obs_actual), '') IS NULL THEN
            v_obs_actual := LEFT(v_obs_nueva, 500);
        ELSE
            v_obs_actual := LEFT(TRIM(v_obs_actual) || ' | ' || v_obs_nueva, 500);
        END IF;
    END IF;

    UPDATE bal_prestamo_detalle
    SET
        fecha_devolucion = COALESCE(p_fecha_devolucion, CURRENT_DATE),
        id_estado = COALESCE(v_id_estado_detalle_devuelto, id_estado),
        observacion = COALESCE(v_obs_actual, observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id
      AND estado = 1;

    -- Movimiento de inventario (opcional si falta el catÃ¡logo); el estado del balÃ³n
    -- SIEMPRE se actualiza al devolver.
    IF v_id_balon IS NOT NULL AND v_id_tipo_movimiento IS NOT NULL THEN
        v_mov_result := bal_crear_movimiento(
            v_id_balon,
            v_id_tipo_movimiento,
            v_id_prestamo,
            v_id_tipo_documento_ref,
            v_id_cliente,
            NULL::INTEGER,
            v_id_almacen_destino,
            NOW()::TIMESTAMP,
            'Entrada por devoluciÃ³n de prÃ©stamo'::VARCHAR,
            p_id_usuario_auditoria
        );

        IF v_mov_result->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_mov_result->>'error';
        END IF;
    END IF;

    IF v_id_balon IS NOT NULL THEN
        UPDATE bal_balon
        SET
            id_cliente_ubicacion = NULL,
            id_almacen = v_id_almacen_destino,
            id_estado_balon = v_id_estado_en_almacen,
            id_estado_contenido = COALESCE(v_id_estado_contenido, id_estado_contenido),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_balon
          AND estado = 1;
    END IF;

    SELECT COUNT(*) INTO v_pendientes
    FROM bal_prestamo_detalle
    WHERE id_prestamo = v_id_prestamo
      AND estado = 1
      AND fecha_devolucion IS NULL;

    IF v_pendientes = 0 THEN
        UPDATE bal_prestamo
        SET
            fecha_retorno_real = COALESCE(
                fecha_retorno_real,
                COALESCE(p_fecha_devolucion, CURRENT_DATE)
            ),
            id_estado = COALESCE(v_id_estado_cerrado, id_estado),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_prestamo
          AND estado = 1;
    END IF;

    RETURN bal_obtener_prestamo_detalle(p_id);
END;
$function$;




-- >>> funciones\recojos\bal_obtener_recojo.sql

CREATE OR REPLACE FUNCTION bal_obtener_recojo(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSONB;
    v_detalles JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT to_jsonb(t)
    INTO v_registro
    FROM (
        SELECT
            r.id,
            r.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            r.id_prestamo,
            pr.numero_prestamo,
            r.fecha_programada,
            r.hora_estimada,
            r.fecha_visita,
            r.id_usuario_responsable,
            ur.nombre AS nombre_usuario_responsable,
            r.id_estado,
            er.nombre AS nombre_estado,
            er.descripcion AS descripcion_estado,
            r.id_motivo_fallo,
            mf.nombre AS nombre_motivo_fallo,
            mf.descripcion AS descripcion_motivo_fallo,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion,
            r.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            r.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_recojo r
        LEFT JOIN cli_clientes c ON c.id = r.id_cliente
        LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
        LEFT JOIN auth_usuarios ur ON ur.id = r.id_usuario_responsable
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        LEFT JOIN gen_lista_opciones mf ON mf.id = r.id_motivo_fallo
        LEFT JOIN auth_usuarios uc ON uc.id = r.id_usuario_creacion
        LEFT JOIN auth_usuarios um ON um.id = r.id_usuario_modificacion
        WHERE r.id = p_id AND r.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.id), '[]'::JSON)
    INTO v_detalles
    FROM (
        SELECT
            rd.id,
            rd.id_recojo,
            rd.id_prestamo_detalle,
            pd.id_prestamo,
            pr.numero_prestamo,
            pd.id_balon,
            b.codigo_balon,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            rd.id_resultado,
            res.nombre AS nombre_resultado,
            res.descripcion AS descripcion_resultado,
            rd.id_estado_contenido,
            ec.nombre AS nombre_estado_contenido,
            rd.nueva_fecha_retorno,
            rd.id_almacen_destino,
            a.nombre AS nombre_almacen_destino,
            rd.observacion,
            rd.estado
        FROM bal_recojo_detalle rd
        INNER JOIN bal_prestamo_detalle pd ON pd.id = rd.id_prestamo_detalle
        INNER JOIN bal_prestamo pr ON pr.id = pd.id_prestamo
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        LEFT JOIN gen_lista_opciones res ON res.id = rd.id_resultado
        LEFT JOIN gen_lista_opciones ec ON ec.id = rd.id_estado_contenido
        LEFT JOIN gen_almacen a ON a.id = rd.id_almacen_destino
        WHERE rd.id_recojo = p_id AND rd.estado = 1
    ) d;

    RETURN json_build_object(
        'error', NULL,
        'registro', (v_registro || jsonb_build_object('detalles', COALESCE(v_detalles::JSONB, '[]'::JSONB)))::JSON
    );
END;
$function$;




-- >>> funciones\recojos\bal_listar_recojos.sql

CREATE OR REPLACE FUNCTION bal_listar_recojos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_estado_nombre VARCHAR DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_estado_nombre VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_estado_nombre := NULLIF(UPPER(TRIM(p_estado_nombre)), '');

    SELECT COUNT(*)
    INTO v_total
    FROM bal_recojo r
    LEFT JOIN cli_clientes c ON c.id = r.id_cliente
    LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.estado = 1
      AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
      AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
      AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
      AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
      AND (
          COALESCE(p_busqueda, '') = ''
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            r.id,
            r.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            r.id_prestamo,
            pr.numero_prestamo,
            r.fecha_programada,
            r.hora_estimada,
            r.fecha_visita,
            r.id_usuario_responsable,
            ur.nombre AS nombre_usuario_responsable,
            r.id_estado,
            er.nombre AS nombre_estado,
            r.id_motivo_fallo,
            mf.nombre AS nombre_motivo_fallo,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_recojo_detalle rd
                WHERE rd.id_recojo = r.id AND rd.estado = 1
            ) AS total_detalles,
            r.observacion,
            r.estado,
            r.fecha_creacion,
            r.fecha_modificacion
        FROM bal_recojo r
        LEFT JOIN cli_clientes c ON c.id = r.id_cliente
        LEFT JOIN bal_prestamo pr ON pr.id = r.id_prestamo
        LEFT JOIN auth_usuarios ur ON ur.id = r.id_usuario_responsable
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
        LEFT JOIN gen_lista_opciones mf ON mf.id = r.id_motivo_fallo
        WHERE r.estado = 1
          AND (p_id_cliente IS NULL OR r.id_cliente = p_id_cliente)
          AND (p_id_prestamo IS NULL OR r.id_prestamo = p_id_prestamo)
          AND (v_estado_nombre IS NULL OR er.nombre = v_estado_nombre)
          AND (p_fecha_desde IS NULL OR r.fecha_programada >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR r.fecha_programada <= p_fecha_hasta)
          AND (
              COALESCE(p_busqueda, '') = ''
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.nombres, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.numero_documento, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(er.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(r.observacion, ''), p_busqueda)
          )
        ORDER BY r.fecha_programada DESC NULLS LAST, r.id DESC
        LIMIT p_limite
        OFFSET COALESCE(p_offset, 0)
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;




-- >>> funciones\recojos\bal_crear_recojo.sql

CREATE OR REPLACE FUNCTION bal_crear_recojo(
    p_id_cliente INTEGER,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_fecha_programada DATE DEFAULT NULL,
    p_hora_estimada TIME DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT '[]',
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado INTEGER;
    v_id_estado_por_recoger INTEGER;
    v_item JSON;
    v_id_pd INTEGER;
    v_id_balon INTEGER;
    v_id_cliente_pd INTEGER;
    v_fecha_dev DATE;
    v_obs VARCHAR(500);
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'El cliente no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    IF p_fecha_programada IS NULL THEN
        RETURN json_build_object('error', 'La fecha programada es obligatoria', 'registro', NULL);
    END IF;

    IF p_detalles IS NULL OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
        RETURN json_build_object(
            'error', 'Debe indicar al menos un detalle de prÃ©stamo a recoger',
            'registro', NULL
        );
    END IF;

    IF p_id_prestamo IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_prestamo
            WHERE id = p_id_prestamo AND estado = 1 AND id_cliente = p_id_cliente
        ) THEN
            RETURN json_build_object(
                'error', 'El prÃ©stamo no existe, estÃ¡ inactivo o no pertenece al cliente',
                'registro', NULL
            );
        END IF;
    END IF;

    IF p_id_usuario_responsable IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth_usuarios WHERE id = p_id_usuario_responsable AND estado = TRUE
    ) THEN
        RETURN json_build_object(
            'error', 'El usuario responsable no existe o estÃ¡ inactivo',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = 'PROGRAMADO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontrÃ³ el estado PROGRAMADO. Revise el catÃ¡logo EstadoRecojo.',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_por_recoger
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'POR_RECOGER' AND lo.estado = 1
    LIMIT 1;

    INSERT INTO bal_recojo (
        id_cliente, id_prestamo, fecha_programada, hora_estimada,
        id_usuario_responsable, id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_id_prestamo, p_fecha_programada, p_hora_estimada,
        p_id_usuario_responsable, v_id_estado, NULLIF(TRIM(p_observacion), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles::JSONB)
    LOOP
        v_id_pd := COALESCE(
            NULLIF(v_item->>'idPrestamoDetalle', '')::INTEGER,
            NULLIF(v_item->>'id_prestamo_detalle', '')::INTEGER
        );
        v_obs := NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), '');

        IF v_id_pd IS NULL THEN
            RETURN json_build_object(
                'error', 'Detalle sin id_prestamo_detalle',
                'registro', NULL
            );
        END IF;

        SELECT pd.id_balon, p.id_cliente, pd.fecha_devolucion
        INTO v_id_balon, v_id_cliente_pd, v_fecha_dev
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
        WHERE pd.id = v_id_pd AND pd.estado = 1;

        IF v_id_cliente_pd IS NULL THEN
            RETURN json_build_object(
                'error', 'El detalle de prÃ©stamo ' || v_id_pd || ' no existe o estÃ¡ inactivo',
                'registro', NULL
            );
        END IF;

        IF v_id_cliente_pd <> p_id_cliente THEN
            RETURN json_build_object(
                'error', 'El detalle de prÃ©stamo ' || v_id_pd || ' no pertenece al cliente del recojo',
                'registro', NULL
            );
        END IF;

        IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM bal_prestamo_detalle
            WHERE id = v_id_pd AND id_prestamo = p_id_prestamo AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle ' || v_id_pd || ' no pertenece al prÃ©stamo indicado',
                'registro', NULL
            );
        END IF;

        IF v_fecha_dev IS NOT NULL THEN
            RETURN json_build_object(
                'error', 'El detalle de prÃ©stamo ' || v_id_pd || ' ya fue devuelto',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_recojo_detalle rd
            INNER JOIN bal_recojo r ON r.id = rd.id_recojo AND r.estado = 1
            INNER JOIN gen_lista_opciones er ON er.id = r.id_estado
            WHERE rd.id_prestamo_detalle = v_id_pd
              AND rd.estado = 1
              AND er.nombre IN ('PROGRAMADO', 'EN_RUTA')
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle ' || v_id_pd || ' ya tiene un recojo pendiente',
                'registro', NULL
            );
        END IF;

        INSERT INTO bal_recojo_detalle (
            id_recojo, id_prestamo_detalle, observacion,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            v_id, v_id_pd, v_obs,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        );

        IF v_id_balon IS NOT NULL AND v_id_estado_por_recoger IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_por_recoger,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_balon
              AND estado = 1;
        END IF;
    END LOOP;

    RETURN bal_obtener_recojo(v_id);
END;
$function$;




-- >>> funciones\recojos\bal_actualizar_recojo.sql

CREATE OR REPLACE FUNCTION bal_actualizar_recojo(
    p_id INTEGER,
    p_id_prestamo INTEGER DEFAULT NULL,
    p_fecha_programada DATE DEFAULT NULL,
    p_hora_estimada TIME DEFAULT NULL,
    p_id_usuario_responsable INTEGER DEFAULT NULL,
    p_estado_nombre VARCHAR DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_estado_actual VARCHAR;
    v_estado_nuevo VARCHAR;
    v_id_estado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, er.nombre
    INTO v_id_cliente, v_estado_actual
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado_actual NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se pueden editar recojos en estado PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo
        WHERE id = p_id_prestamo AND estado = 1 AND id_cliente = v_id_cliente
    ) THEN
        RETURN json_build_object(
            'error', 'El prÃ©stamo no existe, estÃ¡ inactivo o no pertenece al cliente',
            'registro', NULL
        );
    END IF;

    IF p_id_usuario_responsable IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM auth_usuarios WHERE id = p_id_usuario_responsable AND estado = TRUE
    ) THEN
        RETURN json_build_object(
            'error', 'El usuario responsable no existe o estÃ¡ inactivo',
            'registro', NULL
        );
    END IF;

    v_estado_nuevo := NULLIF(UPPER(TRIM(p_estado_nombre)), '');
    IF v_estado_nuevo IS NOT NULL THEN
        IF v_estado_nuevo NOT IN ('PROGRAMADO', 'EN_RUTA', 'CANCELADO') THEN
            RETURN json_build_object(
                'error', 'Estado no permitido en actualizaciÃ³n: ' || v_estado_nuevo,
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = v_estado_nuevo AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontrÃ³ el estado ' || v_estado_nuevo || ' en EstadoRecojo',
                'registro', NULL
            );
        END IF;
    END IF;

    UPDATE bal_recojo
    SET
        id_prestamo = COALESCE(p_id_prestamo, id_prestamo),
        fecha_programada = COALESCE(p_fecha_programada, fecha_programada),
        hora_estimada = COALESCE(p_hora_estimada, hora_estimada),
        id_usuario_responsable = COALESCE(p_id_usuario_responsable, id_usuario_responsable),
        id_estado = COALESCE(v_id_estado, id_estado),
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    RETURN bal_obtener_recojo(p_id);
END;
$function$;




-- >>> funciones\recojos\bal_eliminar_recojo.sql

CREATE OR REPLACE FUNCTION bal_eliminar_recojo(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_estado_prestado INTEGER;
    v_det RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre
    INTO v_estado
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'Recojo no encontrado');
    END IF;

    IF v_estado NOT IN ('PROGRAMADO', 'EN_RUTA', 'CANCELADO') THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'Solo se pueden eliminar recojos PROGRAMADO, EN_RUTA o CANCELADO'
        );
    END IF;

    SELECT lo.id INTO v_id_estado_prestado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
    LIMIT 1;

    -- Si el cilindro quedÃ³ POR_RECOGER por este recojo y sigue en prÃ©stamo, restaurar PRESTADO_CLIENTE.
    IF v_id_estado_prestado IS NOT NULL THEN
        FOR v_det IN
            SELECT pd.id_balon
            FROM bal_recojo_detalle rd
            INNER JOIN bal_prestamo_detalle pd ON pd.id = rd.id_prestamo_detalle AND pd.estado = 1
            INNER JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
            INNER JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND pd.fecha_devolucion IS NULL
              AND eb.nombre = 'POR_RECOGER'
        LOOP
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_prestado,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon;
        END LOOP;
    END IF;

    UPDATE bal_recojo_detalle
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_recojo = p_id AND estado = 1;

    UPDATE bal_recojo
    SET
        estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;




-- >>> funciones\recojos\bal_registrar_resultado_recojo.sql

CREATE OR REPLACE FUNCTION bal_registrar_resultado_recojo(
    p_id INTEGER,
    p_fecha_visita DATE DEFAULT NULL,
    p_id_motivo_fallo INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_detalles JSON DEFAULT '[]',
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_prestamo INTEGER;
    v_estado_actual VARCHAR;
    v_fecha_visita DATE;
    v_item JSON;
    v_id_pd INTEGER;
    v_resultado VARCHAR;
    v_nombre_contenido VARCHAR;
    v_nueva_fecha DATE;
    v_id_almacen INTEGER;
    v_obs VARCHAR(500);
    v_id_resultado INTEGER;
    v_id_contenido INTEGER;
    v_id_prestamo_det INTEGER;
    v_dev JSON;
    v_cnt_total INTEGER := 0;
    v_cnt_recogido INTEGER := 0;
    v_cnt_no_recogido INTEGER := 0;
    v_cnt_extendido INTEGER := 0;
    v_estado_header VARCHAR;
    v_id_estado_header INTEGER;
    v_id_motivo INTEGER;
    v_motivo_nombre VARCHAR;
    v_pendientes_json JSONB := '[]'::JSONB;
    v_fecha_repro DATE;
    v_nuevo JSON;
    v_id_estado_prestado INTEGER;
    v_id_balon INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, r.id_prestamo, er.nombre
    INTO v_id_cliente, v_id_prestamo, v_estado_actual
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado_actual NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se puede registrar resultado en recojos PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    IF p_detalles IS NULL OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
        RETURN json_build_object(
            'error', 'Debe indicar el resultado de al menos un detalle',
            'registro', NULL
        );
    END IF;

    v_fecha_visita := COALESCE(p_fecha_visita, CURRENT_DATE);

    -- Validar que todos los detalles del recojo reciban resultado
    SELECT COUNT(*)::INTEGER INTO v_cnt_total
    FROM bal_recojo_detalle
    WHERE id_recojo = p_id AND estado = 1;

    IF v_cnt_total <> jsonb_array_length(p_detalles::JSONB) THEN
        RETURN json_build_object(
            'error', 'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
            'registro', NULL
        );
    END IF;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_detalles::JSONB)
    LOOP
        v_id_pd := COALESCE(
            NULLIF(v_item->>'idPrestamoDetalle', '')::INTEGER,
            NULLIF(v_item->>'id_prestamo_detalle', '')::INTEGER
        );
        v_resultado := UPPER(TRIM(COALESCE(
            v_item->>'resultado',
            v_item->>'nombre_resultado',
            ''
        )));
        v_nombre_contenido := NULLIF(TRIM(COALESCE(
            v_item->>'nombreEstadoContenido',
            v_item->>'nombre_estado_contenido',
            ''
        )), '');
        v_nueva_fecha := COALESCE(
            NULLIF(v_item->>'nuevaFechaRetorno', '')::DATE,
            NULLIF(v_item->>'nueva_fecha_retorno', '')::DATE
        );
        v_id_almacen := COALESCE(
            NULLIF(v_item->>'idAlmacenDestino', '')::INTEGER,
            NULLIF(v_item->>'id_almacen_destino', '')::INTEGER
        );
        v_obs := NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), '');

        IF v_id_pd IS NULL THEN
            RETURN json_build_object('error', 'Detalle sin id_prestamo_detalle', 'registro', NULL);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM bal_recojo_detalle
            WHERE id_recojo = p_id AND id_prestamo_detalle = v_id_pd AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle ' || v_id_pd || ' no pertenece a este recojo',
                'registro', NULL
            );
        END IF;

        IF v_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
            RETURN json_build_object(
                'error', 'Resultado invÃ¡lido: ' || COALESCE(v_resultado, '(vacÃ­o)'),
                'registro', NULL
            );
        END IF;

        SELECT lo.id INTO v_id_resultado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'ResultadoRecojoDetalle' AND lo.nombre = v_resultado AND lo.estado = 1
        LIMIT 1;

        IF v_id_resultado IS NULL THEN
            RETURN json_build_object(
                'error', 'No se encontrÃ³ el resultado ' || v_resultado || ' en ResultadoRecojoDetalle',
                'registro', NULL
            );
        END IF;

        v_id_contenido := NULL;
        IF v_nombre_contenido IS NOT NULL THEN
            v_id_contenido := bal_id_estado_contenido(v_nombre_contenido);
        END IF;

        IF v_resultado = 'EXTENDIDO' THEN
            v_nueva_fecha := COALESCE(v_nueva_fecha, v_fecha_visita + 1);
        END IF;

        UPDATE bal_recojo_detalle
        SET
            id_resultado = v_id_resultado,
            id_estado_contenido = COALESCE(v_id_contenido, id_estado_contenido),
            nueva_fecha_retorno = CASE
                WHEN v_resultado = 'EXTENDIDO' THEN v_nueva_fecha
                ELSE nueva_fecha_retorno
            END,
            id_almacen_destino = COALESCE(v_id_almacen, id_almacen_destino),
            observacion = COALESCE(v_obs, observacion),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_recojo = p_id
          AND id_prestamo_detalle = v_id_pd
          AND estado = 1;

        IF v_resultado = 'RECOGIDO' THEN
            v_cnt_recogido := v_cnt_recogido + 1;
            v_dev := bal_devolver_prestamo_detalle(
                v_id_pd,
                v_fecha_visita,
                v_id_almacen,
                p_id_usuario_auditoria,
                COALESCE(v_nombre_contenido, 'VACIO'),
                v_obs
            );
            IF v_dev->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
            END IF;
        ELSIF v_resultado = 'EXTENDIDO' THEN
            v_cnt_extendido := v_cnt_extendido + 1;

            SELECT pd.id_prestamo, pd.id_balon
            INTO v_id_prestamo_det, v_id_balon
            FROM bal_prestamo_detalle pd
            WHERE pd.id = v_id_pd AND pd.estado = 1;

            UPDATE bal_prestamo_detalle
            SET
                fecha_vencimiento = v_nueva_fecha,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_pd AND estado = 1;

            UPDATE bal_prestamo
            SET
                fecha_retorno_pactada = v_nueva_fecha,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_prestamo_det AND estado = 1;

            -- Sigue en prÃ©stamo: si estaba POR_RECOGER, volver a PRESTADO_CLIENTE
            SELECT lo.id INTO v_id_estado_prestado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1
            LIMIT 1;

            IF v_id_balon IS NOT NULL AND v_id_estado_prestado IS NOT NULL THEN
                UPDATE bal_balon b
                SET
                    id_estado_balon = v_id_estado_prestado,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                FROM gen_lista_opciones eb
                WHERE b.id = v_id_balon
                  AND b.estado = 1
                  AND eb.id = b.id_estado_balon
                  AND eb.nombre = 'POR_RECOGER';
            END IF;

            v_pendientes_json := v_pendientes_json || jsonb_build_array(
                jsonb_build_object(
                    'id_prestamo_detalle', v_id_pd,
                    'nueva_fecha_retorno', v_nueva_fecha,
                    'observacion', v_obs
                )
            );
        ELSE
            -- NO_RECOGIDO
            v_cnt_no_recogido := v_cnt_no_recogido + 1;
            v_pendientes_json := v_pendientes_json || jsonb_build_array(
                jsonb_build_object(
                    'id_prestamo_detalle', v_id_pd,
                    'nueva_fecha_retorno', v_fecha_visita + 1,
                    'observacion', v_obs,
                    'no_recogido', TRUE
                )
            );
        END IF;
    END LOOP;

    -- Determinar estado cabecera
    IF v_cnt_recogido = v_cnt_total THEN
        v_estado_header := 'EXITOSO';
    ELSIF v_cnt_no_recogido = v_cnt_total THEN
        v_estado_header := 'FALLIDO';
    ELSE
        -- EXTENDIDO (con o sin otros) o mixto RECOGIDO + pendientes
        v_estado_header := 'REPROGRAMADO';
    END IF;

    SELECT lo.id INTO v_id_estado_header
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = v_estado_header AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_header IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontrÃ³ el estado ' || v_estado_header || ' en EstadoRecojo',
            'registro', NULL
        );
    END IF;

    v_id_motivo := p_id_motivo_fallo;
    IF v_id_motivo IS NOT NULL THEN
        SELECT lo.nombre INTO v_motivo_nombre
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE lo.id = v_id_motivo
          AND l.nombre = 'MotivoFalloRecojo'
          AND lo.estado = 1;

        IF v_motivo_nombre IS NULL THEN
            RETURN json_build_object(
                'error', 'El motivo de fallo no existe o no pertenece a MotivoFalloRecojo',
                'registro', NULL
            );
        END IF;
    END IF;

    IF v_estado_header = 'FALLIDO' AND v_id_motivo IS NULL THEN
        RETURN json_build_object(
            'error', 'Debe indicar el motivo de fallo cuando el recojo es FALLIDO',
            'registro', NULL
        );
    END IF;

    UPDATE bal_recojo
    SET
        fecha_visita = v_fecha_visita,
        id_estado = v_id_estado_header,
        id_motivo_fallo = CASE
            WHEN v_estado_header IN ('FALLIDO', 'REPROGRAMADO') AND v_cnt_no_recogido > 0
                THEN COALESCE(v_id_motivo, id_motivo_fallo)
            WHEN v_estado_header = 'FALLIDO' THEN v_id_motivo
            ELSE id_motivo_fallo
        END,
        observacion = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    -- Auto-crear nuevo PROGRAMADO para pendientes (EXTENDIDO y/o NO_RECOGIDO)
    IF v_estado_header = 'REPROGRAMADO'
       AND jsonb_array_length(v_pendientes_json) > 0 THEN
        SELECT MIN((elem->>'nueva_fecha_retorno')::DATE)
        INTO v_fecha_repro
        FROM jsonb_array_elements(v_pendientes_json) elem;

        v_fecha_repro := COALESCE(v_fecha_repro, v_fecha_visita + 1);

        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id_prestamo_detalle', (elem->>'id_prestamo_detalle')::INTEGER,
                    'observacion', elem->>'observacion'
                )
            ),
            '[]'::JSONB
        )
        INTO v_pendientes_json
        FROM jsonb_array_elements(v_pendientes_json) elem;

        v_nuevo := bal_crear_recojo(
            v_id_cliente,
            v_id_prestamo,
            v_fecha_repro,
            NULL::TIME,
            NULL::INTEGER,
            'Reprogramado desde recojo #' || p_id,
            v_pendientes_json::JSON,
            p_id_usuario_auditoria
        );

        IF v_nuevo->>'error' IS NOT NULL THEN
            RETURN json_build_object(
                'error',
                'Resultado registrado pero no se pudo reprogramar: ' || (v_nuevo->>'error'),
                'registro', NULL
            );
        END IF;
    END IF;

    RETURN bal_obtener_recojo(p_id);
END;
$function$;




