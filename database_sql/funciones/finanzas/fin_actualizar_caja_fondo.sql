-- Corrige el fondo inicial de una sesión de caja ABIERTA y deja el ajuste en la bitácora
DROP FUNCTION IF EXISTS public.fin_actualizar_caja_fondo (
  p_id integer,
  p_monto_inicial numeric,
  p_observacion character varying,
  p_id_usuario integer
);

CREATE OR REPLACE FUNCTION public.fin_actualizar_caja_fondo (
  p_id integer,
  p_monto_inicial numeric,
  p_observacion character varying DEFAULT NULL::character varying,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_sesion RECORD;
    v_estado_nombre VARCHAR;
    v_anterior NUMERIC(12,2);
    v_nuevo NUMERIC(12,2);
    v_detalle VARCHAR(500);
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_monto_inicial IS NULL OR p_monto_inicial < 0 THEN
        RETURN json_build_object('error', 'El fondo no puede ser negativo', 'registro', NULL);
    END IF;

    -- Bloquea la fila para que un cierre simultáneo no arquee con el fondo anterior.
    SELECT s.* INTO v_sesion
    FROM fin_caja_sesion s
    WHERE s.id = p_id AND s.estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Sesión de caja no encontrada', 'registro', NULL);
    END IF;

    SELECT lo.nombre INTO v_estado_nombre
    FROM gen_lista_opciones lo
    WHERE lo.id = v_sesion.id_estado;

    IF UPPER(COALESCE(v_estado_nombre, '')) <> 'ABIERTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede editar el fondo con la caja abierta. Para cambiarlo, reabre la caja.',
            'registro', NULL
        );
    END IF;

    v_anterior := ROUND(COALESCE(v_sesion.monto_inicial, 0), 2);
    v_nuevo := ROUND(p_monto_inicial, 2);

    IF v_nuevo = v_anterior THEN
        RETURN json_build_object('error', 'El fondo no cambió', 'registro', NULL);
    END IF;

    UPDATE fin_caja_sesion
    SET monto_inicial = v_nuevo,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    v_detalle := LEFT(
        TRIM(format(
            'Fondo anterior S/ %s. %s',
            to_char(v_anterior, 'FM999999990.00'),
            COALESCE(TRIM(p_observacion), '')
        )),
        500
    );

    INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, observacion, id_usuario)
    VALUES (p_id, 'AJUSTE_FONDO', v_nuevo, v_detalle, p_id_usuario);

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
            s.observacion_apertura AS "observacionApertura",
            s.fecha_apertura AS "fechaApertura",
            s.id_usuario_apertura AS "idUsuarioApertura"
        FROM fin_caja_sesion s
        LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
        LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
        WHERE s.id = p_id
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
