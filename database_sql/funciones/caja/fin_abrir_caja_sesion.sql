CREATE OR REPLACE FUNCTION fin_abrir_caja_sesion(
    p_fecha DATE,
    p_monto_inicial NUMERIC,
    p_id_sucursal INT DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado_abierta INT;
    v_existente RECORD;
    v_abierta RECORD;
    v_id INT;
    v_registro JSON;
    v_hora_txt TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_abierta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'ABIERTA'
    LIMIT 1;

    IF v_estado_abierta IS NULL THEN
        RETURN json_build_object('error', 'No existe estado de caja ABIERTA', 'registro', NULL);
    END IF;

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha es obligatoria', 'registro', NULL);
    END IF;

    IF COALESCE(p_monto_inicial, 0) < 0 THEN
        RETURN json_build_object('error', 'El monto inicial no puede ser negativo', 'registro', NULL);
    END IF;

    -- Una sola sesión por fecha + sucursal (abierta o cerrada).
    SELECT s.* INTO v_existente
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        v_hora_txt := to_char(v_existente.fecha_apertura AT TIME ZONE 'America/Lima', 'DD/MM/YYYY HH24:MI');
        RETURN json_build_object(
            'error', format(
                'Ya existe una sesión de caja para esa fecha (abierta el %s). No se puede repetir la misma fecha.',
                COALESCE(v_hora_txt, to_char(p_fecha, 'DD/MM/YYYY'))
            ),
            'registro', NULL
        );
    END IF;

    -- No abrir otra si ya hay una caja ABIERTA en la misma sucursal (otra fecha).
    SELECT s.* INTO v_abierta
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.id_estado = v_estado_abierta
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        v_hora_txt := to_char(v_abierta.fecha_apertura AT TIME ZONE 'America/Lima', 'DD/MM/YYYY HH24:MI');
        RETURN json_build_object(
            'error', format(
                'Ya hay una caja ABIERTA del %s (apertura %s). Ciérrala antes de abrir otra.',
                to_char(v_abierta.fecha, 'DD/MM/YYYY'),
                COALESCE(v_hora_txt, '—')
            ),
            'registro', NULL
        );
    END IF;

    BEGIN
        INSERT INTO fin_caja_sesion (
            fecha, id_sucursal, id_estado, monto_inicial,
            observacion_apertura, fecha_apertura, id_usuario_apertura,
            id_usuario_creacion
        ) VALUES (
            p_fecha, p_id_sucursal, v_estado_abierta, COALESCE(p_monto_inicial, 0),
            NULLIF(TRIM(p_observacion), ''), NOW(), p_id_usuario,
            p_id_usuario
        )
        RETURNING id INTO v_id;
    EXCEPTION
        WHEN unique_violation THEN
            RETURN json_build_object(
                'error', 'Ya existe una sesión de caja para esa fecha / sucursal. No se puede repetir.',
                'registro', NULL
            );
    END;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            s.id,
            s.fecha,
            s.id_sucursal AS "idSucursal",
            suc.nombre AS "nombreSucursal",
            s.id_estado AS "idEstado",
            est.nombre AS "estadoCaja",
            s.monto_inicial AS "montoInicial",
            s.monto_efectivo_contado AS "montoEfectivoContado",
            s.monto_esperado AS "montoEsperado",
            s.diferencia,
            s.observacion_apertura AS "observacionApertura",
            s.observacion_cierre AS "observacionCierre",
            s.fecha_apertura AS "fechaApertura",
            s.fecha_cierre AS "fechaCierre",
            s.id_usuario_apertura AS "idUsuarioApertura",
            s.id_usuario_cierre AS "idUsuarioCierre"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = v_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
