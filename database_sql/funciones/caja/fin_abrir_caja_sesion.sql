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
    v_id INT;
    v_registro JSON;
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

    SELECT s.* INTO v_existente
    FROM fin_caja_sesion s
    WHERE s.estado = 1
      AND s.fecha = p_fecha
      AND COALESCE(s.id_sucursal, 0) = COALESCE(p_id_sucursal, 0)
    LIMIT 1;

    IF FOUND THEN
        RETURN json_build_object(
            'error', 'Ya existe una sesión de caja para esa fecha / sucursal',
            'registro', NULL
        );
    END IF;

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
