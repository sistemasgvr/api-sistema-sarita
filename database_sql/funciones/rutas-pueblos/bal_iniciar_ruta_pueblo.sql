-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_iniciar_ruta_pueblo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.557Z
DROP FUNCTION IF EXISTS bal_iniciar_ruta_pueblo(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_iniciar_ruta_pueblo(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_id_almacen INTEGER;
    v_id_estado_ruta INTEGER;
    v_det RECORD;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT er.nombre, r.id_almacen
    INTO v_estado, v_id_almacen
    FROM bal_ruta_pueblo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    IF v_estado IS NULL THEN
        RETURN json_build_object('error', 'Ruta no encontrada', 'registro', NULL);
    END IF;

    IF v_estado <> 'ABIERTA' THEN
        RETURN json_build_object('error', 'Solo se puede iniciar una ruta ABIERTA', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM bal_ruta_pueblo_detalle WHERE id_ruta_pueblo = p_id AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La ruta no tiene cilindros', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_ruta
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRutaPueblo' AND lo.nombre = 'EN_RUTA' AND lo.estado = 1
    LIMIT 1;

    FOR v_det IN
        SELECT d.id_balon, d.lb_salida
        FROM bal_ruta_pueblo_detalle d
        WHERE d.id_ruta_pueblo = p_id AND d.estado = 1
    LOOP
        v_mov := bal_registrar_salida_documento(
            v_det.id_balon,
            'TRASLADO_LIMA',
            p_id,
            'RUTA_PUEBLO',
            NULL,
            v_id_almacen,
            'EN_RUTA_LIMA',
            TRUE,
            NULL,
            format('Salida ruta pueblos #%s · %.4f lb', p_id, v_det.lb_salida),
            p_id_usuario_auditoria
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'Cilindro %: %', v_det.id_balon, v_mov->>'error';
        END IF;

        UPDATE bal_balon
        SET
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_det.id_balon AND estado = 1;
    END LOOP;

    UPDATE bal_ruta_pueblo
    SET
        id_estado = v_id_estado_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN bal_obtener_ruta_pueblo(p_id);
END;
$function$
