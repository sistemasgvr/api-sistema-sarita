-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_registrar_resultado_recojo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.599Z
DROP FUNCTION IF EXISTS bal_registrar_resultado_recojo(p_id integer, p_fecha_visita date, p_id_motivo_fallo integer, p_observacion character varying, p_detalles json, p_id_usuario_auditoria integer, p_regulador json);

CREATE OR REPLACE FUNCTION bal_registrar_resultado_recojo(p_id integer, p_fecha_visita date DEFAULT NULL::date, p_id_motivo_fallo integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_detalles json DEFAULT '[]'::json, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_regulador json DEFAULT NULL::json)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_id_recarga_planta INTEGER;
    v_estado_actual VARCHAR;
    v_fecha_visita DATE;
    v_item JSON;
    v_id_pd INTEGER;
    v_id_ad INTEGER;
    v_id_b INTEGER;
    v_resultado VARCHAR;
    v_nombre_contenido VARCHAR;
    v_nueva_fecha DATE;
    v_id_almacen INTEGER;
    v_obs VARCHAR(500);
    v_id_resultado INTEGER;
    v_id_prestamo_det INTEGER;
    v_id_alquiler_det INTEGER;
    v_dev JSON;
    v_cnt_total INTEGER := 0;
    v_cnt_recogido INTEGER := 0;
    v_cnt_no_recogido INTEGER := 0;
    v_cnt_extendido INTEGER := 0;
    v_cnt_efectivo INTEGER := 0;
    v_cnt_cubiertos INTEGER := 0;
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
    v_cantidad_restante NUMERIC(10,4);
    v_capacidad_tipo NUMERIC(10,4);
    v_id_producto_gas_recojo INTEGER;
    v_lb_restante NUMERIC(10,4);
    v_peso_bruto_lb NUMERIC(10,4);
    v_presion_psi NUMERIC(10,4);
    v_tiene_regulador BOOLEAN := FALSE;
    v_procesa_regulador BOOLEAN := FALSE;
    v_reg JSONB;
    v_reg_resultado VARCHAR;
    v_reg_condicion VARCHAR;
    v_reg_nueva_fecha DATE;
    v_reg_obs VARCHAR(500);
    v_id_resultado_reg INTEGER;
    v_id_condicion_reg INTEGER;
    v_cil_pendientes INTEGER;
    v_seen_pd INTEGER[] := '{}';
    v_seen_ad INTEGER[] := '{}';
    v_seen_b INTEGER[] := '{}';
    v_ya_devuelto DATE;
    v_pass INTEGER;
    v_id_estado_en_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT r.id_cliente, r.id_prestamo, r.id_alquiler, r.id_recarga_planta, er.nombre
    INTO v_id_cliente, v_id_prestamo, v_id_alquiler, v_id_recarga_planta, v_estado_actual
    FROM bal_recojo r
    LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado
    WHERE r.id = p_id AND r.estado = 1;

    SELECT lo.id INTO v_id_estado_en_almacen
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
    LIMIT 1;

    IF v_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'Recojo no encontrado', 'registro', NULL);
    END IF;

    IF v_estado_actual NOT IN ('PROGRAMADO', 'EN_RUTA') THEN
        RETURN json_build_object(
            'error', 'Solo se puede registrar resultado en recojos PROGRAMADO o EN_RUTA',
            'registro', NULL
        );
    END IF;

    v_fecha_visita := COALESCE(p_fecha_visita, CURRENT_DATE);

    SELECT COUNT(*)::INTEGER INTO v_cnt_total
    FROM bal_recojo_detalle
    WHERE id_recojo = p_id AND estado = 1;

    IF v_id_alquiler IS NOT NULL THEN
        SELECT COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
        INTO v_tiene_regulador
        FROM bal_alquiler a
        WHERE a.id = v_id_alquiler AND a.estado = 1;
    END IF;

    v_reg := CASE
        WHEN p_regulador IS NULL OR p_regulador::TEXT IN ('null', '') THEN NULL
        ELSE p_regulador::JSONB
    END;

    -- Compat: recojo solo regulador enviando un ítem en detalles sin ids de cilindro
    IF v_tiene_regulador
       AND v_reg IS NULL
       AND v_cnt_total = 0
       AND jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 1
       AND COALESCE(
           NULLIF((p_detalles::JSONB -> 0)->>'idPrestamoDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_prestamo_detalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'idAlquilerDetalle', ''),
           NULLIF((p_detalles::JSONB -> 0)->>'id_alquiler_detalle', '')
       ) IS NULL
    THEN
        v_reg := p_detalles::JSONB -> 0;
    END IF;

    -- Regulador solo si visita accesorio-only o el cliente envió p_regulador
    v_procesa_regulador := (v_cnt_total = 0 AND v_tiene_regulador) OR (v_reg IS NOT NULL);

    IF v_cnt_total = 0 THEN
        IF NOT v_tiene_regulador THEN
            RETURN json_build_object(
                'error', 'Este recojo no tiene detalles ni regulador asociado',
                'registro', NULL
            );
        END IF;
    ELSE
        IF p_detalles IS NULL
           OR jsonb_array_length(COALESCE(p_detalles::JSONB, '[]'::JSONB)) = 0 THEN
            RETURN json_build_object(
                'error', 'Debe indicar el resultado de al menos un detalle',
                'registro', NULL
            );
        END IF;

        IF v_cnt_total <> jsonb_array_length(p_detalles::JSONB) THEN
            RETURN json_build_object(
                'error',
                'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
                'registro', NULL
            );
        END IF;
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

    -- Pass 1: validar cilindros. Antes del pass 2: regulador + FALLIDO + reprogram.
    -- Pass 2: mutar stock / fechas.
    FOR v_pass IN 1..2 LOOP
        v_seen_pd := '{}';
        v_seen_ad := '{}';
        IF v_pass = 1 THEN
            v_cnt_recogido := 0;
            v_cnt_no_recogido := 0;
            v_cnt_extendido := 0;
            v_pendientes_json := '[]'::JSONB;
        END IF;

        IF v_pass = 2 THEN
            IF v_procesa_regulador THEN
                IF v_reg IS NULL OR COALESCE(NULLIF(TRIM(COALESCE(
                    v_reg->>'resultado', v_reg->>'nombre_resultado', ''
                )), ''), '') = '' THEN
                    RETURN json_build_object(
                        'error', 'Debe indicar el resultado del regulador/accesorio',
                        'registro', NULL
                    );
                END IF;

                v_reg_resultado := UPPER(TRIM(COALESCE(
                    v_reg->>'resultado',
                    v_reg->>'nombre_resultado',
                    ''
                )));
                v_reg_condicion := UPPER(TRIM(COALESCE(
                    v_reg->>'condicion',
                    v_reg->>'nombreCondicion',
                    v_reg->>'nombre_condicion',
                    ''
                )));
                v_reg_nueva_fecha := COALESCE(
                    NULLIF(v_reg->>'nuevaFechaRetorno', '')::DATE,
                    NULLIF(v_reg->>'nueva_fecha_retorno', '')::DATE
                );
                v_reg_obs := NULLIF(TRIM(COALESCE(v_reg->>'observacion', '')), '');

                IF v_reg_resultado NOT IN ('RECOGIDO', 'NO_RECOGIDO', 'EXTENDIDO') THEN
                    RETURN json_build_object(
                        'error', 'Resultado de regulador inválido: ' || COALESCE(v_reg_resultado, '(vacío)'),
                        'registro', NULL
                    );
                END IF;

                SELECT lo.id INTO v_id_resultado_reg
                FROM gen_lista_opciones lo
                INNER JOIN gen_lista l ON l.id = lo.id_lista
                WHERE l.nombre = 'ResultadoRecojoDetalle'
                  AND lo.nombre = v_reg_resultado
                  AND lo.estado = 1
                LIMIT 1;

                IF v_id_resultado_reg IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se encontró el resultado ' || v_reg_resultado || ' en ResultadoRecojoDetalle',
                        'registro', NULL
                    );
                END IF;

                IF v_reg_resultado = 'RECOGIDO' THEN
                    IF v_reg_condicion NOT IN ('BUENO', 'PARA_REPARAR') THEN
                        RETURN json_build_object(
                            'error', 'Debe indicar si el regulador está BUENO o PARA_REPARAR',
                            'registro', NULL
                        );
                    END IF;

                    SELECT lo.id INTO v_id_condicion_reg
                    FROM gen_lista_opciones lo
                    INNER JOIN gen_lista l ON l.id = lo.id_lista
                    WHERE l.nombre = 'CondicionRegulador'
                      AND lo.nombre = v_reg_condicion
                      AND lo.estado = 1
                    LIMIT 1;

                    IF v_id_condicion_reg IS NULL THEN
                        RETURN json_build_object(
                            'error', 'No se encontró la condición ' || v_reg_condicion || ' en CondicionRegulador',
                            'registro', NULL
                        );
                    END IF;

                    v_cnt_recogido := v_cnt_recogido + 1;
                ELSIF v_reg_resultado = 'EXTENDIDO' THEN
                    v_cnt_extendido := v_cnt_extendido + 1;
                ELSE
                    v_cnt_no_recogido := v_cnt_no_recogido + 1;
                    v_pendientes_json := v_pendientes_json || jsonb_build_array(
                        jsonb_build_object(
                            'solo_regulador', TRUE,
                            'nueva_fecha_retorno', v_fecha_visita + 1,
                            'observacion', v_reg_obs,
                            'no_recogido', TRUE
                        )
                    );
                END IF;
            END IF;

            v_cnt_efectivo := v_cnt_total + CASE WHEN v_procesa_regulador THEN 1 ELSE 0 END;

            IF v_cnt_efectivo = 0 THEN
                RETURN json_build_object(
                    'error', 'No hay ítems para registrar en este recojo',
                    'registro', NULL
                );
            END IF;

            IF v_cnt_no_recogido = v_cnt_efectivo THEN
                v_estado_header := 'FALLIDO';
            ELSIF v_cnt_no_recogido > 0 THEN
                v_estado_header := 'REPROGRAMADO';
            ELSE
                v_estado_header := 'EXITOSO';
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

            IF v_estado_header = 'FALLIDO' AND v_id_motivo IS NULL THEN
                RETURN json_build_object(
                    'error', 'Debe indicar el motivo de fallo cuando el recojo es FALLIDO',
                    'registro', NULL
                );
            END IF;

            IF v_cnt_no_recogido > 0 THEN
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
                            WHEN NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_alquiler_detalle', (elem->>'id_alquiler_detalle')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            WHEN NULLIF(elem->>'id_balon', '') IS NOT NULL THEN
                                jsonb_build_object(
                                    'id_balon', (elem->>'id_balon')::INTEGER,
                                    'observacion', elem->>'observacion'
                                )
                            ELSE NULL
                        END
                    ) FILTER (WHERE COALESCE(elem->>'solo_regulador', 'false') <> 'true'
                              AND (
                                  NULLIF(elem->>'id_prestamo_detalle', '') IS NOT NULL
                                  OR NULLIF(elem->>'id_alquiler_detalle', '') IS NOT NULL
                                  OR NULLIF(elem->>'id_balon', '') IS NOT NULL
                              )),
                    '[]'::JSONB
                )
                INTO v_repro_detalles
                FROM jsonb_array_elements(v_pendientes_json) elem;

                IF v_id_cliente IS NULL OR v_fecha_repro IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se puede reprogramar el recojo: faltan cliente o fecha',
                        'registro', NULL
                    );
                END IF;

                IF v_id_recarga_planta IS NULL
                   AND COALESCE(jsonb_array_length(v_repro_detalles), 0) = 0
                   AND v_id_alquiler IS NULL THEN
                    RETURN json_build_object(
                        'error', 'No se puede reprogramar el recojo: no hay pendientes válidos',
                        'registro', NULL
                    );
                END IF;
            END IF;
        END IF;

        FOR v_item IN
            SELECT * FROM jsonb_array_elements(
                CASE WHEN v_cnt_total = 0 THEN '[]'::JSONB ELSE p_detalles::JSONB END
            )
        LOOP
            v_id_pd := COALESCE(
                NULLIF(v_item->>'idPrestamoDetalle', '')::INTEGER,
                NULLIF(v_item->>'id_prestamo_detalle', '')::INTEGER
            );
            v_id_ad := COALESCE(
                NULLIF(v_item->>'idAlquilerDetalle', '')::INTEGER,
                NULLIF(v_item->>'id_alquiler_detalle', '')::INTEGER
            );
            v_id_b := COALESCE(
                NULLIF(v_item->>'idBalon', '')::INTEGER,
                NULLIF(v_item->>'id_balon', '')::INTEGER
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
            v_cantidad_restante := COALESCE(
                NULLIF(v_item->>'cantidadRestante', '')::NUMERIC,
                NULLIF(v_item->>'cantidad_restante', '')::NUMERIC
            );
            v_lb_restante := COALESCE(
                NULLIF(v_item->>'lbRetorno', '')::NUMERIC,
                NULLIF(v_item->>'lb_retorno', '')::NUMERIC
            );
            v_peso_bruto_lb := COALESCE(
                NULLIF(v_item->>'pesoBrutoLb', '')::NUMERIC,
                NULLIF(v_item->>'peso_bruto_lb', '')::NUMERIC
            );
            v_presion_psi := COALESCE(
                NULLIF(v_item->>'presionActual', '')::NUMERIC,
                NULLIF(v_item->>'presion_actual', '')::NUMERIC,
                NULLIF(v_item->>'presionPsi', '')::NUMERIC,
                NULLIF(v_item->>'presion_psi', '')::NUMERIC
            );

            IF (v_id_pd IS NOT NULL)::INTEGER + (v_id_ad IS NOT NULL)::INTEGER + (v_id_b IS NOT NULL)::INTEGER <> 1 THEN
                RETURN json_build_object(
                    'error', 'Cada detalle debe indicar id_prestamo_detalle, id_alquiler_detalle o id_balon',
                    'registro', NULL
                );
            END IF;

            IF v_id_pd IS NOT NULL THEN
                IF v_id_pd = ANY(v_seen_pd) THEN
                    RETURN json_build_object(
                        'error', 'Detalle de préstamo duplicado: ' || v_id_pd,
                        'registro', NULL
                    );
                END IF;
                v_seen_pd := array_append(v_seen_pd, v_id_pd);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_prestamo_detalle = v_id_pd AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El detalle de préstamo ' || v_id_pd || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_id_ad IS NOT NULL THEN
                IF v_id_ad = ANY(v_seen_ad) THEN
                    RETURN json_build_object(
                        'error', 'Detalle de alquiler duplicado: ' || v_id_ad,
                        'registro', NULL
                    );
                END IF;
                v_seen_ad := array_append(v_seen_ad, v_id_ad);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_alquiler_detalle = v_id_ad AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El detalle de alquiler ' || v_id_ad || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
            END IF;

            IF v_id_b IS NOT NULL THEN
                IF v_id_b = ANY(v_seen_b) THEN
                    RETURN json_build_object(
                        'error', 'Balón duplicado en el recojo: ' || v_id_b,
                        'registro', NULL
                    );
                END IF;
                v_seen_b := array_append(v_seen_b, v_id_b);

                IF NOT EXISTS (
                    SELECT 1 FROM bal_recojo_detalle
                    WHERE id_recojo = p_id AND id_balon = v_id_b AND estado = 1
                ) THEN
                    RETURN json_build_object(
                        'error', 'El balón ' || v_id_b || ' no pertenece a este recojo',
                        'registro', NULL
                    );
                END IF;
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



            IF v_resultado = 'EXTENDIDO' THEN
                v_nueva_fecha := COALESCE(v_nueva_fecha, v_fecha_visita + 1);
            END IF;

            IF v_resultado = 'RECOGIDO' THEN
                IF v_id_pd IS NOT NULL THEN
                    SELECT pd.id_balon, tb.capacidad
                    INTO v_id_balon, v_capacidad_tipo
                    FROM bal_prestamo_detalle pd
                    JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE pd.id = v_id_pd AND pd.estado = 1;
                ELSIF v_id_ad IS NOT NULL THEN
                    SELECT ad.id_balon, tb.capacidad
                    INTO v_id_balon, v_capacidad_tipo
                    FROM bal_alquiler_detalle ad
                    JOIN bal_balon b ON b.id = ad.id_balon AND b.estado = 1
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE ad.id = v_id_ad AND ad.estado = 1;
                ELSE
                    v_id_balon := v_id_b;
                    SELECT tb.capacidad
                    INTO v_capacidad_tipo
                    FROM bal_balon b
                    JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    WHERE b.id = v_id_b AND b.estado = 1;
                END IF;

                IF v_cantidad_restante IS NULL THEN
                    IF UPPER(COALESCE(v_nombre_contenido, 'VACIO')) = 'VACIO' THEN
                        v_cantidad_restante := 0;
                    ELSIF UPPER(COALESCE(v_nombre_contenido, '')) = 'LLENO' THEN
                        v_cantidad_restante := v_capacidad_tipo;
                    END IF;
                ELSIF v_cantidad_restante < 0 THEN
                    RETURN json_build_object(
                        'error', 'La cantidad restante no puede ser negativa',
                        'registro', NULL
                    );
                ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante > v_capacidad_tipo THEN
                    RETURN json_build_object(
                        'error',
                        'La cantidad restante (' || v_cantidad_restante
                            || ') supera la capacidad del cilindro (' || v_capacidad_tipo || ')',
                        'registro', NULL
                    );
                END IF;

                IF v_nombre_contenido IS NULL AND v_cantidad_restante IS NOT NULL THEN
                    IF v_cantidad_restante <= 0 THEN
                        v_nombre_contenido := 'VACIO';
                    ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante >= v_capacidad_tipo THEN
                        v_nombre_contenido := 'LLENO';
                    ELSIF v_capacidad_tipo IS NOT NULL AND v_cantidad_restante < v_capacidad_tipo THEN
                        v_nombre_contenido := 'SEMILLLENO';
                    ELSE
                        v_nombre_contenido := 'DESCONOCIDO';
                    END IF;
                END IF;
            ELSE
                v_cantidad_restante := NULL;
                v_id_balon := NULL;
            END IF;

            IF v_pass = 1 THEN
                IF v_resultado = 'RECOGIDO' THEN
                    v_cnt_recogido := v_cnt_recogido + 1;
                ELSIF v_resultado = 'EXTENDIDO' THEN
                    v_cnt_extendido := v_cnt_extendido + 1;
                ELSE
                    v_cnt_no_recogido := v_cnt_no_recogido + 1;
                    v_pendientes_json := v_pendientes_json || jsonb_build_array(
                        jsonb_build_object(
                            'id_prestamo_detalle', v_id_pd,
                            'id_alquiler_detalle', v_id_ad,
                            'id_balon', v_id_b,
                            'nueva_fecha_retorno', v_fecha_visita + 1,
                            'observacion', v_obs,
                            'no_recogido', TRUE
                        )
                    );
                END IF;
            ELSE
                UPDATE bal_recojo_detalle
                SET
                    id_resultado = v_id_resultado,
                    cantidad_restante = CASE
                        WHEN v_resultado = 'RECOGIDO' THEN v_cantidad_restante
                        ELSE cantidad_restante
                    END,
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
                    v_dev := NULL;
                    IF v_id_pd IS NOT NULL THEN
                        SELECT pd.fecha_devolucion INTO v_ya_devuelto
                        FROM bal_prestamo_detalle pd
                        WHERE pd.id = v_id_pd AND pd.estado = 1;
                    ELSIF v_id_ad IS NOT NULL THEN
                        SELECT ad.fecha_devolucion INTO v_ya_devuelto
                        FROM bal_alquiler_detalle ad
                        WHERE ad.id = v_id_ad AND ad.estado = 1;
                    ELSE
                        v_ya_devuelto := NULL;
                    END IF;

                    IF v_ya_devuelto IS NULL THEN
                        IF v_id_pd IS NOT NULL THEN
                            v_dev := bal_devolver_prestamo_detalle(
                                v_id_pd,
                                v_fecha_visita,
                                v_id_almacen,
                                p_id_usuario_auditoria,
                                COALESCE(v_nombre_contenido, 'VACIO'),
                                v_obs
                            );
                        ELSIF v_id_ad IS NOT NULL THEN
                            v_dev := bal_devolver_alquiler_detalle(
                                v_id_ad,
                                v_fecha_visita,
                                v_id_almacen,
                                p_id_usuario_auditoria
                            );
                        ELSE
                            -- Recarga en planta externa: ingreso físico del balón al almacén
                            PERFORM bal_actualizar_balon(
                                p_id                   => v_id_balon,
                                p_id_almacen           => v_id_almacen,
                                p_id_estado_balon      => v_id_estado_en_almacen,
                                p_id_usuario_auditoria => p_id_usuario_auditoria
                            );

                            IF v_id_recarga_planta IS NOT NULL THEN
                                SELECT id_producto_gas INTO v_id_producto_gas_recojo
                                FROM bal_balon WHERE id = v_id_balon;

                                v_dev := inv_registrar_movimiento(
                                    p_naturaleza                => 'BALON',
                                    p_codigo_tipo_movimiento    => 'ENTRADA_LLENADO',
                                    p_fecha                     => LOCALTIMESTAMP,
                                    p_id_producto               => v_id_producto_gas_recojo,
                                    p_id_balon                  => v_id_balon,
                                    p_cantidad                  => COALESCE(v_cantidad_restante, NULLIF(v_capacidad_tipo, 0), 1),
                                    p_id_almacen_destino        => v_id_almacen,
                                    p_id_cliente                => v_id_cliente,
                                    p_codigo_tipo_documento_origen => 'RECARGA',
                                    p_id_documento_origen       => v_id_recarga_planta,
                                    p_glosa                     => 'Entrada por recojo de recarga en planta (orden #'
                                        || v_id_recarga_planta || ')',
                                    p_id_usuario_auditoria      => p_id_usuario_auditoria
                                );
                                IF v_dev->>'error' IS NOT NULL THEN
                                    RAISE EXCEPTION 'No se pudo registrar el movimiento de entrada del balón %: %',
                                        v_id_balon, v_dev->>'error';
                                END IF;
                            END IF;
                        END IF;
                        IF v_dev->>'error' IS NOT NULL THEN
                            RAISE EXCEPTION '%', v_dev->>'error';
                        END IF;
                    END IF;

                    IF v_id_balon IS NOT NULL AND (
                        v_peso_bruto_lb IS NOT NULL
                        OR v_lb_restante IS NOT NULL
                        OR v_cantidad_restante IS NOT NULL
                    ) THEN
                        NULL;
                    END IF;
                ELSIF v_resultado = 'EXTENDIDO' THEN
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
                    WHERE l.nombre = 'EstadoBalon'
                      AND lo.nombre = CASE WHEN v_id_ad IS NOT NULL THEN 'ALQUILADO' ELSE 'PRESTADO_CLIENTE' END
                      AND lo.estado = 1
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
                END IF;
            END IF;
        END LOOP;

        IF v_pass = 1 AND v_cnt_total > 0 THEN
            SELECT COUNT(*)::INTEGER INTO v_cnt_cubiertos
            FROM bal_recojo_detalle rd
            WHERE rd.id_recojo = p_id
              AND rd.estado = 1
              AND (
                  (rd.id_prestamo_detalle IS NOT NULL AND rd.id_prestamo_detalle = ANY(v_seen_pd))
                  OR (rd.id_alquiler_detalle IS NOT NULL AND rd.id_alquiler_detalle = ANY(v_seen_ad))
                  OR (rd.id_balon IS NOT NULL AND rd.id_balon = ANY(v_seen_b))
              );

            IF v_cnt_cubiertos <> v_cnt_total THEN
                RETURN json_build_object(
                    'error',
                    'Debe informar resultado para todos los detalles del recojo (' || v_cnt_total || ')',
                    'registro', NULL
                );
            END IF;
        END IF;
    END LOOP;

    -- Mutación de regulador (después de validar todo el payload)
    IF v_procesa_regulador THEN
        IF v_reg_resultado = 'RECOGIDO' THEN
            v_dev := bal_devolver_regulador_alquiler(
                v_id_alquiler,
                v_fecha_visita,
                v_reg_condicion,
                v_reg_obs,
                p_id,
                p_id_usuario_auditoria
            );

            IF v_dev->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_dev->>'error';
            END IF;
        ELSIF v_reg_resultado = 'EXTENDIDO' THEN
            v_reg_nueva_fecha := COALESCE(v_reg_nueva_fecha, v_fecha_visita + 1);

            UPDATE bal_alquiler
            SET
                fecha_fin_pactada = v_reg_nueva_fecha,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_alquiler AND estado = 1;
        END IF;
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
        id_resultado_regulador = COALESCE(v_id_resultado_reg, id_resultado_regulador),
        id_condicion_regulador = COALESCE(v_id_condicion_reg, id_condicion_regulador),
        nueva_fecha_retorno_regulador = CASE
            WHEN v_reg_resultado = 'EXTENDIDO' THEN v_reg_nueva_fecha
            ELSE nueva_fecha_retorno_regulador
        END,
        observacion_regulador = COALESCE(v_reg_obs, observacion_regulador),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF v_id_alquiler IS NOT NULL AND v_reg_resultado = 'RECOGIDO' THEN
        SELECT COUNT(*)::INTEGER INTO v_cil_pendientes
        FROM bal_alquiler_detalle ad
        WHERE ad.id_alquiler = v_id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL;

        IF v_cil_pendientes = 0 THEN
            SELECT lo.id INTO v_id_estado_prestado
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoAlquiler' AND lo.nombre = 'FINALIZADO' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_prestado IS NOT NULL THEN
                v_dev := bal_actualizar_alquiler(
                    v_id_alquiler,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::DATE,
                    NULL::DATE,
                    v_fecha_visita,
                    NULL::NUMERIC,
                    NULL::NUMERIC,
                    v_id_estado_prestado,
                    NULL::VARCHAR,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    NULL::INTEGER,
                    p_id_usuario_auditoria
                );

                IF v_dev->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION '%', v_dev->>'error';
                END IF;
            END IF;
        END IF;
    END IF;

    IF v_cnt_no_recogido > 0 THEN
        v_nuevo := bal_crear_recojo(
            v_id_cliente,
            CASE
                WHEN COALESCE(jsonb_array_length(v_repro_detalles), 0) = 0 THEN NULL
                ELSE v_id_prestamo
            END,
            v_id_alquiler,
            v_id_recarga_planta,
            v_fecha_repro,
            NULL::TIME,
            NULL::INTEGER,
            'Reprogramado desde recojo #' || p_id,
            COALESCE(v_repro_detalles, '[]'::JSONB)::JSON,
            p_id_usuario_auditoria
        );

        IF v_nuevo->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo reprogramar el recojo: %', v_nuevo->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_recojo(p_id);
END;
$function$
