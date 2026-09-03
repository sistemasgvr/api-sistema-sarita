-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_revertir_salidas_guia_remision
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.606Z
DROP FUNCTION IF EXISTS bal_revertir_salidas_guia_remision(p_id_guia integer, p_ids_conservar integer[], p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_revertir_salidas_guia_remision(p_id_guia integer, p_ids_conservar integer[] DEFAULT NULL::integer[], p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_result JSON;
    v_revertidos INTEGER;
    v_mov JSON;
    v_balones INTEGER[];
    v_tipos VARCHAR[];
    v_clientes INTEGER[];
    v_almacenes_origen INTEGER[];
    v_almacenes_destino INTEGER[];
    v_i INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Capturar el tipo/cliente/almacén original de los balones a conservar ANTES de
    -- revertir, para poder re-registrarlos igual a como estaban (no siempre es
    -- SALIDA_PRESTAMO: puede ser TRASLADO_LIMA, SALIDA_PLANTA_EXTERNA, etc.).
    IF p_ids_conservar IS NOT NULL AND array_length(p_ids_conservar, 1) > 0 THEN
        SELECT
            array_agg(m.id_balon ORDER BY m.id),
            array_agg(tm.nombre ORDER BY m.id),
            array_agg(m.id_cliente ORDER BY m.id),
            array_agg(m.id_almacen_origen ORDER BY m.id),
            array_agg(m.id_almacen_destino ORDER BY m.id)
        INTO v_balones, v_tipos, v_clientes, v_almacenes_origen, v_almacenes_destino
        FROM inv_movimiento m
        INNER JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        INNER JOIN gen_lista_opciones tdo ON tdo.id = m.id_tipo_documento_origen
        WHERE m.estado = 1
          AND m.naturaleza = 'BALON'
          AND tdo.nombre = 'GRE'
          AND m.id_documento_origen = p_id_guia
          AND m.id_balon = ANY (p_ids_conservar);
    END IF;

    -- Revertir todos los inv_movimiento de esta GRE
    v_result := inv_revertir_por_documento(
        'GRE',
        p_id_guia,
        p_id_usuario_auditoria
    );

    v_revertidos := COALESCE((v_result->>'revertidos')::INTEGER, 0);

    -- Re-registrar los conservados con su tipo/cliente/almacén original
    IF v_balones IS NOT NULL THEN
        FOR v_i IN 1 .. array_length(v_balones, 1)
        LOOP
            v_mov := inv_registrar_movimiento(
                p_naturaleza                => 'BALON',
                p_codigo_tipo_movimiento    => v_tipos[v_i],
                p_fecha                     => LOCALTIMESTAMP,
                p_id_balon                  => v_balones[v_i],
                p_cantidad                  => 1,
                p_id_almacen_origen         => v_almacenes_origen[v_i],
                p_id_almacen_destino        => v_almacenes_destino[v_i],
                p_id_cliente                => v_clientes[v_i],
                p_codigo_tipo_documento_origen => 'GRE',
                p_id_documento_origen       => p_id_guia,
                p_glosa                     => 'Re-registro conservado de GRE',
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );
            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;
        END LOOP;
    END IF;

    RETURN json_build_object('ok', TRUE, 'revertidos', v_revertidos, 'error', NULL);
END;
$function$
