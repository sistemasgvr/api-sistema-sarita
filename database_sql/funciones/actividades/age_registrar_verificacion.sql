-- Function: age_registrar_verificacion
-- Fase 6 (apunte 8.b.i.3) — verificación por escaneo de los ítems de una actividad.
--
-- Recibe los códigos leídos con la pistola y, para cada uno, busca el ítem cuyo
-- cilindro o producto le corresponde. Lo que no coincide se registra igual en la
-- bitácora con coincide = FALSE: saber que se escaneó algo ajeno es información,
-- no ruido que convenga descartar.
--
-- p_momento: 'SALIDA' | 'LLEGADA'.
-- p_codigos: ["BAL-OXM10-001", ...]
-- Los ítems no escaneados quedan como estaban (PENDIENTE si nunca se tocaron).
DROP FUNCTION IF EXISTS age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_codigos json, p_observacion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_codigos json DEFAULT NULL::json, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_momento        VARCHAR;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_codigo         VARCHAR;
    v_id_item        INTEGER;
    v_coincidencias  INTEGER := 0;
    v_ajenos         INTEGER := 0;
    v_no_escaneados  INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_momento := UPPER(TRIM(COALESCE(p_momento, '')));

    IF v_momento NOT IN ('SALIDA', 'LLEGADA') THEN
        RETURN json_build_object('error', 'El momento debe ser SALIDA o LLEGADA', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id_actividad AND estado = 1) THEN
        RETURN json_build_object('error', 'La actividad no existe o está anulada', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    IF v_id_ok IS NULL THEN
        RETURN json_build_object('error', 'Falta el catálogo EstadoVerificacionItem', 'registro', NULL);
    END IF;

    FOR v_codigo IN
        SELECT DISTINCT UPPER(TRIM(x#>>'{}'))
        FROM json_array_elements(COALESCE(p_codigos, '[]'::JSON)) AS a(x)
        WHERE NULLIF(TRIM(x#>>'{}'), '') IS NOT NULL
    LOOP
        -- Se busca por código de cilindro y, si no, por código de producto: en
        -- una entrega pueden viajar accesorios que no son balones.
        SELECT ai.id INTO v_id_item
        FROM age_actividad_item ai
        LEFT JOIN bal_balon b ON b.id = ai.id_balon
        LEFT JOIN pro_producto p ON p.id = ai.id_producto
        WHERE ai.id_actividad = p_id_actividad
          AND ai.estado = 1
          AND (
              UPPER(TRIM(COALESCE(b.codigo_balon, ''))) = v_codigo
              OR UPPER(TRIM(COALESCE(b.numero_serie, ''))) = v_codigo
              OR UPPER(TRIM(COALESCE(p.codigo, ''))) = v_codigo
              OR UPPER(TRIM(COALESCE(p.codigo_barra, ''))) = v_codigo
          )
        ORDER BY ai.item
        LIMIT 1;

        INSERT INTO age_actividad_verificacion (
            id_actividad, id_actividad_item, momento, codigo_escaneado, coincide,
            observacion, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            p_id_actividad, v_id_item, v_momento, v_codigo, v_id_item IS NOT NULL,
            p_observacion, p_id_usuario_auditoria, p_id_usuario_auditoria
        );

        IF v_id_item IS NOT NULL THEN
            IF v_momento = 'SALIDA' THEN
                UPDATE age_actividad_item
                SET id_estado_verificacion_salida =
                        CASE WHEN NULLIF(TRIM(COALESCE(p_observacion, '')), '') IS NULL
                             THEN v_id_ok ELSE COALESCE(v_id_observado, v_id_ok) END,
                    observacion_salida = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion_salida),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_item;
            ELSE
                UPDATE age_actividad_item
                SET id_estado_verificacion_llegada =
                        CASE WHEN NULLIF(TRIM(COALESCE(p_observacion, '')), '') IS NULL
                             THEN v_id_ok ELSE COALESCE(v_id_observado, v_id_ok) END,
                    observacion_llegada = COALESCE(NULLIF(TRIM(p_observacion), ''), observacion_llegada),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_item;
            END IF;
            v_coincidencias := v_coincidencias + 1;
        ELSE
            v_ajenos := v_ajenos + 1;
        END IF;

        v_id_item := NULL;
    END LOOP;

    -- Cuántos quedan sin verificar en este momento: es el dato que decide si la
    -- salida puede darse por cerrada.
    SELECT COUNT(*)::INT INTO v_no_escaneados
    FROM age_actividad_item ai
    JOIN gen_lista_opciones lo
      ON lo.id = CASE WHEN v_momento = 'SALIDA'
                      THEN ai.id_estado_verificacion_salida
                      ELSE ai.id_estado_verificacion_llegada END
    WHERE ai.id_actividad = p_id_actividad
      AND ai.estado = 1
      AND lo.nombre = 'PENDIENTE';

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'momento', v_momento,
            'coincidencias', v_coincidencias,
            'no_pertenecen', v_ajenos,
            'pendientes', v_no_escaneados,
            'completo', v_no_escaneados = 0
        )
    );
END;
$function$;
