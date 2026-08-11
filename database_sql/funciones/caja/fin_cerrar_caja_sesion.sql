CREATE OR REPLACE FUNCTION fin_cerrar_caja_sesion(
    p_id INT,
    p_monto_efectivo_contado NUMERIC,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario INT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_sesion RECORD;
    v_estado_cerrada INT;
    v_totales JSON;
    v_esperado NUMERIC(14,4);
    v_diferencia NUMERIC(14,4);
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT lo.id INTO v_estado_cerrada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCaja' AND lo.nombre = 'CERRADA'
    LIMIT 1;

    SELECT s.*, est.nombre AS estado_nombre
    INTO v_sesion
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.id = p_id AND s.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Sesión de caja no encontrada', 'registro', NULL);
    END IF;

    IF UPPER(COALESCE(v_sesion.estado_nombre, '')) = 'CERRADA' THEN
        RETURN json_build_object('error', 'La caja ya está cerrada', 'registro', NULL);
    END IF;

    IF p_monto_efectivo_contado IS NULL OR p_monto_efectivo_contado < 0 THEN
        RETURN json_build_object('error', 'Indique el efectivo contado (arqueo)', 'registro', NULL);
    END IF;

    v_totales := fin_caja_calcular_totales(v_sesion.fecha, v_sesion.id_sucursal);
    v_esperado := COALESCE(v_sesion.monto_inicial, 0)
        + COALESCE((v_totales->>'ventasMediosCaja')::NUMERIC, 0)
        + COALESCE((v_totales->>'cobranzasMediosCaja')::NUMERIC, 0)
        - COALESCE((v_totales->>'depositos')::NUMERIC, 0)
        - COALESCE((v_totales->>'gastosCaja')::NUMERIC, 0);
    v_diferencia := COALESCE(p_monto_efectivo_contado, 0) - v_esperado;

    UPDATE fin_caja_sesion
    SET id_estado = v_estado_cerrada,
        monto_efectivo_contado = p_monto_efectivo_contado,
        monto_esperado = v_esperado,
        diferencia = v_diferencia,
        observacion_cierre = NULLIF(TRIM(p_observacion), ''),
        fecha_cierre = NOW(),
        id_usuario_cierre = p_id_usuario,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id;

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
            s.id_usuario_cierre AS "idUsuarioCierre",
            v_totales AS totales
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
