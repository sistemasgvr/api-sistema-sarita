CREATE OR REPLACE FUNCTION bal_actualizar_alquiler_detalle(
    p_id INTEGER,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_alquiler INTEGER;
    v_id_balon_actual INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_alquiler, id_balon INTO v_id_alquiler, v_id_balon_actual
    FROM bal_alquiler_detalle
    WHERE id = p_id AND estado = 1;

    IF v_id_alquiler IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_id_balon IS NOT NULL AND p_id_balon <> v_id_balon_actual THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El balón indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_balon b
            LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
            WHERE b.id = p_id_balon
              AND COALESCE(eb.nombre, '') IN ('DADO_DE_BAJA', 'ROBO')
        ) THEN
            RETURN json_build_object(
                'error',
                'No se puede alquilar un cilindro dado de baja o reportado como robo',
                'registro',
                NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1 FROM bal_alquiler_detalle
            WHERE id_alquiler = v_id_alquiler AND id_balon = p_id_balon AND id <> p_id AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El balón ya está registrado en este alquiler', 'registro', NULL);
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = p_id_balon
              AND ad.id <> p_id
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error',
                'El cilindro ya tiene un alquiler activo sin devolver',
                'registro',
                NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = p_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error',
                'El cilindro está prestado actualmente; no se puede alquilar',
                'registro',
                NULL
            );
        END IF;
    END IF;

    UPDATE bal_alquiler_detalle
    SET
        id_balon = COALESCE(p_id_balon, id_balon),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_alquiler_detalle(p_id);
END;
$function$;
