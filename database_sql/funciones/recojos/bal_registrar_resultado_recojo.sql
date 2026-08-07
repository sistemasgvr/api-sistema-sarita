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
    v_id_alquiler INTEGER;
    v_estado_actual VARCHAR;
    v_fecha_visita DATE;
    v_item JSON;
    v_id_pd INTEGER;
    v_id_ad INTEGER;
    v_resultado VARCHAR;
    v_nombre_contenido VARCHAR;
    v_nueva_fecha DATE;
    v_id_almacen INTEGER;
    v_obs VARCHAR(500);
    v_id_resultado INTEGER;
    v_id_contenido INTEGER;
    v_id_prestamo_det INTEGER;
    v_id_alquiler_det INTEGER;
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
    v_repro_detalles JSONB := '[]'::JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, r.id_prestamo, r.id_alquiler, er.nombre
    INTO v_id_cliente, v_id_prestamo, v_id_alquiler, v_estado_actual
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
        v_id_ad := COALESCE(
            NULLIF(v_item->>'idAlquilerDetalle', '')::INTEGER,
            NULLIF(v_item->>'id_alquiler_detalle', '')::INTEGER
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

        IF (v_id_pd IS NOT NULL)::INTEGER + (v_id_ad IS NOT NULL)::INTEGER <> 1 THEN
            RETURN json_build_object(
                'error', 'Cada detalle debe indicar id_prestamo_detalle o id_alquiler_detalle',
                'registro', NULL
            );
        END IF;

        IF v_id_pd IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM bal_recojo_detalle
            WHERE id_recojo = p_id AND id_prestamo_detalle = v_id_pd AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle de préstamo ' || v_id_pd || ' no pertenece a este recojo',
                'registro', NULL
            );
        END IF;

        IF v_id_ad IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM bal_recojo_detalle
            WHERE id_recojo = p_id AND id_alquiler_detalle = v_id_ad AND estado = 1
        ) THEN
            RETURN json_build_object(
                'error', 'El detalle de alquiler ' || v_id_ad || ' no pertenece a este recojo',
                'registro', NULL
            );
        END IF;

        IF v_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
            RETURN json_build_object(
                'error', 'Resultado inválido: ' || COALESCE(v_resultado, '(vacío)'),
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
                'error', 'No se encontró el resultado ' || v_resultado || ' en ResultadoRecojoDetalle',
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
          AND estado = 1
          AND (
              (v_id_pd IS NOT NULL AND id_prestamo_detalle = v_id_pd)
              OR (v_id_ad IS NOT NULL AND id_alquiler_detalle = v_id_ad)
          );

        IF v_resultado = 'RECOGIDO' THEN
            v_cnt_recogido := v_cnt_recogido + 1;
            IF v_id_pd IS NOT NULL THEN
                v_dev := bal_devolver_prestamo_detalle(
                    v_id_pd,
                    v_fecha_visita,
                    v_id_almacen,
                    p_id_usuario_auditoria,
                    COALESCE(v_nombre_contenido, 'VACIO'),
                    v_obs
                );
            ELSE
                v_dev := bal_devolver_alquiler_detalle(
                    v_id_ad,
                    v_fecha_visita,
                    v_id_almacen,
                    p_id_usuario_auditoria
                );
            END IF;
            IF v_dev->>'error' IS NOT NULL THEN
                RETURN json_build_object('error', v_dev->>'error', 'registro', NULL);
            END IF;
        ELSIF v_resultado = 'EXTENDIDO' THEN
            v_cnt_extendido := v_cnt_extendido + 1;
            IF v_id_pd IS NOT NULL THEN
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
            ELSE
                SELECT ad.id_alquiler, ad.id_balon
                INTO v_id_alquiler_det, v_id_balon
                FROM bal_alquiler_detalle ad
                WHERE ad.id = v_id_ad AND ad.estado = 1;

                UPDATE bal_alquiler
                SET
                    fecha_fin_pactada = v_nueva_fecha,
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_id_alquiler_det AND estado = 1;
            END IF;

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
                    'id_alquiler_detalle', v_id_ad,
                    'nueva_fecha_retorno', v_nueva_fecha,
                    'observacion', v_obs
                )
            );
        ELSE
            v_cnt_no_recogido := v_cnt_no_recogido + 1;
            v_pendientes_json := v_pendientes_json || jsonb_build_array(
                jsonb_build_object(
                    'id_prestamo_detalle', v_id_pd,
                    'id_alquiler_detalle', v_id_ad,
                    'nueva_fecha_retorno', v_fecha_visita + 1,
                    'observacion', v_obs,
                    'no_recogido', TRUE
                )
            );
        END IF;
    END LOOP;

    IF v_cnt_recogido = v_cnt_total THEN
        v_estado_header := 'EXITOSO';
    ELSIF v_cnt_no_recogido = v_cnt_total THEN
        v_estado_header := 'FALLIDO';
    ELSE
        v_estado_header := 'REPROGRAMADO';
    END IF;

    SELECT lo.id INTO v_id_estado_header
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecojo' AND lo.nombre = v_estado_header AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_header IS NULL THEN
        RETURN json_build_object(
            'error', 'No se encontró el estado ' || v_estado_header || ' en EstadoRecojo',
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

    IF v_estado_header = 'REPROGRAMADO'
       AND jsonb_array_length(v_pendientes_json) > 0 THEN
        SELECT MIN((elem->>'nueva_fecha_retorno')::DATE)
        INTO v_fecha_repro
        FROM jsonb_array_elements(v_pendientes_json) elem;

        v_fecha_repro := COALESCE(v_fecha_repro, v_fecha_visita + 1);

        SELECT COALESCE(
            jsonb_agg(
                CASE
                    WHEN NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL THEN
                        jsonb_build_object(
                            'id_prestamo_detalle', (elem->>'id_prestamo_detalle')::INTEGER,
                            'observacion', elem->>'observacion'
                        )
                    ELSE
                        jsonb_build_object(
                            'id_alquiler_detalle', (elem->>'id_alquiler_detalle')::INTEGER,
                            'observacion', elem->>'observacion'
                        )
                END
            ),
            '[]'::JSONB
        )
        INTO v_repro_detalles
        FROM jsonb_array_elements(v_pendientes_json) elem;

        v_nuevo := bal_crear_recojo(
            v_id_cliente,
            v_id_prestamo,
            v_id_alquiler,
            v_fecha_repro,
            NULL::TIME,
            NULL::INTEGER,
            'Reprogramado desde recojo #' || p_id,
            v_repro_detalles::JSON,
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
