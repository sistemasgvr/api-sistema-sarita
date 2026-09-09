-- ============================================================
-- Migracion: flujo completo de entrega para actividades REPARTO
-- Fecha: 2026-09-09
--
-- El reparto pasa a tener cuatro momentos encadenados:
--
--   tomar -> verificar SALIDA (100%) -> EN_RUTA -> verificar LLEGADA (100%) -> REALIZADA
--
-- Decisiones de negocio que fija esta migracion:
--
--   * El gate es estricto: no se avanza con items PENDIENTE ni CON_OBSERVACION.
--     Un item observado se resuelve volviendolo a verificar como conforme; la
--     observacion queda en la bitacora age_actividad_verificacion, que es el
--     rastro historico, y no bloquea para siempre.
--
--   * La actividad NO mueve inventario ni custodia de cilindros. Eso ya lo hizo
--     doc_generar_salida (inv_registrar_movimiento con SALIDA_ENTREGA_CLIENTE),
--     que ademas se autoprotege contra doble efecto. Aqui solo se registra la
--     operativa de la entrega.
--
--   * Los items se clasifican en tres clases, derivadas (sin columna nueva):
--       CILINDRO  -> id_balon NOT NULL. Se verifica escaneando el envase.
--       GAS       -> producto que es el id_producto_gas de algun cilindro de la
--                    misma actividad. No se escanea: se deriva de sus cilindros.
--                    doc_generar_salida arma el detalle en dos planos (una linea
--                    por balon y otra por el gas total), asi que el gas siempre
--                    llega como linea aparte aunque el operador lo vea junto al
--                    cilindro.
--       ACCESORIO -> el resto (llaves, valvulas...). Se confirma por cantidad.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_age_reparto_flujo_entrega.sql
-- ============================================================

-- ------------------------------------------------------------
-- Estado EN_RUTA
-- ------------------------------------------------------------

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion, estado)
SELECT l.id, 'EN_RUTA', 'La entrega salio del almacen y va camino al cliente', 1
FROM gen_lista l
WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND UPPER(TRIM(lo.nombre)) = 'EN_RUTA'
  );

-- ------------------------------------------------------------
-- Cantidad verificada (solo la usan los items ACCESORIO)
-- ------------------------------------------------------------

ALTER TABLE age_actividad_item
    ADD COLUMN IF NOT EXISTS cantidad_verificada_salida NUMERIC(12,4) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS cantidad_verificada_llegada NUMERIC(12,4) NOT NULL DEFAULT 0;

-- ------------------------------------------------------------
-- age_clasificar_items_actividad
--
-- Una sola definicion de "que es cada item", para que registrar_verificacion,
-- iniciar_entrega y culminar_entrega no puedan discrepar entre si.
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS age_clasificar_items_actividad(integer);

CREATE OR REPLACE FUNCTION age_clasificar_items_actividad(p_id_actividad integer)
RETURNS TABLE (id_item integer, clase character varying)
LANGUAGE sql
STABLE
AS $function$
    SELECT
        ai.id,
        CASE
            WHEN ai.id_balon IS NOT NULL THEN 'CILINDRO'
            WHEN ai.id_producto IS NOT NULL AND EXISTS (
                SELECT 1
                FROM age_actividad_item c
                JOIN bal_balon b ON b.id = c.id_balon
                WHERE c.id_actividad = ai.id_actividad
                  AND c.estado = 1
                  AND c.id_balon IS NOT NULL
                  AND b.id_producto_gas = ai.id_producto
            ) THEN 'GAS'
            ELSE 'ACCESORIO'
        END::VARCHAR
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id_actividad
      AND ai.estado = 1;
$function$;

-- ------------------------------------------------------------
-- age_registrar_verificacion
--
-- Reemplaza la version de Fase 6, que aplicaba una unica observacion a toda la
-- tanda escaneada y por tanto no podia expresar "el balon A conforme, el B con
-- averia". Ahora cada lectura trae su propia conformidad.
--
-- p_lecturas: array donde cada entrada es, o bien un escaneo:
--     { "codigo": "BAL-OXM10-001", "conforme": true, "observacion": null }
--   o bien una confirmacion de cantidad para un accesorio:
--     { "id_item": 45, "cantidad": 5, "conforme": true, "observacion": null }
--
-- conforme se asume true si no viene. Los codigos que no pertenecen a la
-- actividad se registran igual en la bitacora con coincide = FALSE: saber que
-- se escaneo algo ajeno es informacion, no ruido que convenga descartar.
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_codigos json, p_observacion character varying, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS age_registrar_verificacion(p_id_actividad integer, p_momento character varying, p_lecturas json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION age_registrar_verificacion(
    p_id_actividad integer,
    p_momento character varying,
    p_lecturas json DEFAULT NULL::json,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_momento        VARCHAR;
    v_es_salida      BOOLEAN;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_id_pendiente   INTEGER;
    v_lectura        JSON;
    v_codigo         VARCHAR;
    v_id_item        INTEGER;
    v_clase          VARCHAR;
    v_conforme       BOOLEAN;
    v_observacion    VARCHAR;
    v_cantidad       NUMERIC;
    v_estado_destino INTEGER;
    v_coincidencias  INTEGER := 0;
    v_ajenos         INTEGER := 0;
    v_pendientes     INTEGER := 0;
    v_observados     INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_momento := UPPER(TRIM(COALESCE(p_momento, '')));

    IF v_momento NOT IN ('SALIDA', 'LLEGADA') THEN
        RETURN json_build_object('error', 'El momento debe ser SALIDA o LLEGADA', 'registro', NULL);
    END IF;

    v_es_salida := v_momento = 'SALIDA';

    IF NOT EXISTS (SELECT 1 FROM age_actividad WHERE id = p_id_actividad AND estado = 1) THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1 LIMIT 1;

    IF v_id_ok IS NULL THEN
        RETURN json_build_object('error', 'Falta el catalogo EstadoVerificacionItem', 'registro', NULL);
    END IF;

    FOR v_lectura IN
        SELECT x FROM json_array_elements(COALESCE(p_lecturas, '[]'::JSON)) AS a(x)
    LOOP
        v_id_item     := NULL;
        v_clase       := NULL;
        v_codigo      := NULLIF(UPPER(TRIM(COALESCE(v_lectura->>'codigo', ''))), '');
        v_observacion := NULLIF(TRIM(COALESCE(v_lectura->>'observacion', '')), '');
        v_conforme    := COALESCE((v_lectura->>'conforme')::BOOLEAN, TRUE);
        v_cantidad    := NULLIF(v_lectura->>'cantidad', '')::NUMERIC;

        IF v_codigo IS NOT NULL THEN
            -- Cada clase se busca por sus propios codigos. Cruzarlas haria que
            -- escanear el codigo del gas marcara un cilindro, porque el item de
            -- cilindro lleva el gas en id_producto.
            SELECT c.id_item, c.clase INTO v_id_item, v_clase
            FROM age_clasificar_items_actividad(p_id_actividad) c
            JOIN age_actividad_item ai ON ai.id = c.id_item
            LEFT JOIN bal_balon b ON b.id = ai.id_balon
            LEFT JOIN pro_producto p ON p.id = ai.id_producto
            WHERE (
                    c.clase = 'CILINDRO' AND (
                        UPPER(TRIM(COALESCE(b.codigo_balon, ''))) = v_codigo
                        OR UPPER(TRIM(COALESCE(b.numero_serie, ''))) = v_codigo
                    )
                )
               OR (
                    c.clase = 'ACCESORIO' AND (
                        UPPER(TRIM(COALESCE(p.codigo, ''))) = v_codigo
                        OR UPPER(TRIM(COALESCE(p.codigo_barra, ''))) = v_codigo
                    )
                )
            ORDER BY ai.item
            LIMIT 1;

            INSERT INTO age_actividad_verificacion (
                id_actividad, id_actividad_item, momento, codigo_escaneado, coincide,
                observacion, id_usuario_creacion, id_usuario_modificacion
            ) VALUES (
                p_id_actividad, v_id_item, v_momento, v_codigo, v_id_item IS NOT NULL,
                v_observacion, p_id_usuario_auditoria, p_id_usuario_auditoria
            );

            IF v_id_item IS NULL THEN
                v_ajenos := v_ajenos + 1;
                CONTINUE;
            END IF;

            -- Un accesorio escaneado suma una unidad; el cilindro se cierra de
            -- una vez porque la linea es el envase mismo.
            IF v_clase = 'ACCESORIO' THEN
                v_cantidad := COALESCE(v_cantidad, 1);
            END IF;

        ELSE
            v_id_item := NULLIF(v_lectura->>'id_item', '')::INTEGER;

            IF v_id_item IS NULL THEN
                CONTINUE;
            END IF;

            SELECT c.clase INTO v_clase
            FROM age_clasificar_items_actividad(p_id_actividad) c
            WHERE c.id_item = v_id_item;

            IF v_clase IS NULL THEN
                v_ajenos := v_ajenos + 1;
                CONTINUE;
            END IF;

            -- El gas no se confirma a mano: sale de sus cilindros mas abajo.
            IF v_clase = 'GAS' THEN
                CONTINUE;
            END IF;
        END IF;

        v_estado_destino := CASE WHEN v_conforme THEN v_id_ok
                                 ELSE COALESCE(v_id_observado, v_id_ok) END;

        IF v_es_salida THEN
            UPDATE age_actividad_item
            SET cantidad_verificada_salida = CASE
                    WHEN v_clase = 'ACCESORIO' AND v_cantidad IS NOT NULL
                        THEN LEAST(cantidad, cantidad_verificada_salida + v_cantidad)
                    WHEN v_clase = 'ACCESORIO' THEN cantidad_verificada_salida
                    ELSE cantidad
                END,
                id_estado_verificacion_salida = CASE
                    -- Un accesorio no queda OK hasta completar su cantidad.
                    WHEN v_clase = 'ACCESORIO'
                         AND LEAST(cantidad, cantidad_verificada_salida + COALESCE(v_cantidad, 0)) < cantidad
                        THEN COALESCE(v_id_pendiente, id_estado_verificacion_salida)
                    ELSE v_estado_destino
                END,
                observacion_salida = COALESCE(v_observacion, observacion_salida),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_item;
        ELSE
            UPDATE age_actividad_item
            SET cantidad_verificada_llegada = CASE
                    WHEN v_clase = 'ACCESORIO' AND v_cantidad IS NOT NULL
                        THEN LEAST(cantidad, cantidad_verificada_llegada + v_cantidad)
                    WHEN v_clase = 'ACCESORIO' THEN cantidad_verificada_llegada
                    ELSE cantidad
                END,
                id_estado_verificacion_llegada = CASE
                    WHEN v_clase = 'ACCESORIO'
                         AND LEAST(cantidad, cantidad_verificada_llegada + COALESCE(v_cantidad, 0)) < cantidad
                        THEN COALESCE(v_id_pendiente, id_estado_verificacion_llegada)
                    ELSE v_estado_destino
                END,
                observacion_llegada = COALESCE(v_observacion, observacion_llegada),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_item;
        END IF;

        v_coincidencias := v_coincidencias + 1;
    END LOOP;

    -- El gas se deriva: queda como el peor estado de los cilindros que lo
    -- transportan, y solo pasa a OK cuando todos ellos estan OK.
    IF v_es_salida THEN
        UPDATE age_actividad_item gas
        SET id_estado_verificacion_salida = d.estado_derivado,
            cantidad_verificada_salida = CASE WHEN d.estado_derivado = v_id_ok THEN gas.cantidad ELSE 0 END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM (
            SELECT
                g.id_item,
                CASE
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_ok
                                            AND ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_observado) > 0
                        THEN COALESCE(v_id_pendiente, v_id_ok)
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida = v_id_observado) > 0
                        THEN COALESCE(v_id_observado, v_id_ok)
                    ELSE v_id_ok
                END AS estado_derivado
            FROM age_clasificar_items_actividad(p_id_actividad) g
            JOIN age_actividad_item gi ON gi.id = g.id_item
            JOIN age_actividad_item ai ON ai.id_actividad = p_id_actividad AND ai.estado = 1 AND ai.id_balon IS NOT NULL
            JOIN bal_balon b ON b.id = ai.id_balon AND b.id_producto_gas = gi.id_producto
            WHERE g.clase = 'GAS'
            GROUP BY g.id_item
        ) d
        WHERE gas.id = d.id_item;
    ELSE
        UPDATE age_actividad_item gas
        SET id_estado_verificacion_llegada = d.estado_derivado,
            cantidad_verificada_llegada = CASE WHEN d.estado_derivado = v_id_ok THEN gas.cantidad ELSE 0 END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        FROM (
            SELECT
                g.id_item,
                CASE
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_ok
                                            AND ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_observado) > 0
                        THEN COALESCE(v_id_pendiente, v_id_ok)
                    WHEN COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada = v_id_observado) > 0
                        THEN COALESCE(v_id_observado, v_id_ok)
                    ELSE v_id_ok
                END AS estado_derivado
            FROM age_clasificar_items_actividad(p_id_actividad) g
            JOIN age_actividad_item gi ON gi.id = g.id_item
            JOIN age_actividad_item ai ON ai.id_actividad = p_id_actividad AND ai.estado = 1 AND ai.id_balon IS NOT NULL
            JOIN bal_balon b ON b.id = ai.id_balon AND b.id_producto_gas = gi.id_producto
            WHERE g.clase = 'GAS'
            GROUP BY g.id_item
        ) d
        WHERE gas.id = d.id_item;
    END IF;

    SELECT
        COUNT(*) FILTER (WHERE est IS DISTINCT FROM v_id_ok AND est IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE est = v_id_observado)
    INTO v_pendientes, v_observados
    FROM (
        SELECT CASE WHEN v_es_salida THEN ai.id_estado_verificacion_salida
                    ELSE ai.id_estado_verificacion_llegada END AS est
        FROM age_actividad_item ai
        WHERE ai.id_actividad = p_id_actividad AND ai.estado = 1
    ) s;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'momento', v_momento,
            'coincidencias', v_coincidencias,
            'no_pertenecen', v_ajenos,
            'pendientes', v_pendientes,
            'observados', v_observados,
            -- completo = se puede avanzar. El gate es estricto, asi que un item
            -- observado tampoco cuenta como completo.
            'completo', v_pendientes = 0 AND v_observados = 0
        )
    );
END;
$function$;

-- ------------------------------------------------------------
-- age_iniciar_entrega: PENDIENTE/PROGRAMADA -> EN_RUTA
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS age_iniciar_entrega(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_entrega(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act            RECORD;
    v_nombre_estado  VARCHAR;
    v_nombre_tipo    VARCHAR;
    v_id_en_ruta     INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_trabajador_responsable, a.id_estado_actividad
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
    FROM gen_lista_opciones lo WHERE lo.id = v_act.id_estado_actividad;

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_tipo
    FROM age_actividad a JOIN gen_lista_opciones lo ON lo.id = a.id_tipo_actividad
    WHERE a.id = p_id;

    IF COALESCE(v_nombre_tipo, '') <> 'REPARTO' THEN
        RETURN json_build_object('error', 'Solo las actividades de REPARTO tienen flujo de entrega', 'registro', NULL);
    END IF;

    IF v_nombre_estado IN ('REALIZADA', 'CANCELADA', 'CANCELADO') THEN
        RETURN json_build_object('error', format('La actividad ya esta %s', v_nombre_estado), 'registro', NULL);
    END IF;

    IF v_nombre_estado = 'EN_RUTA' THEN
        RETURN json_build_object('error', 'La entrega ya esta en ruta', 'registro', NULL);
    END IF;

    -- Sin responsable no hay quien responda por la carga que sale.
    IF v_act.id_trabajador_responsable IS NULL THEN
        RETURN json_build_object('error', 'Asigna un responsable antes de iniciar la entrega', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_en_ruta
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'EN_RUTA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_en_ruta IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado EN_RUTA en EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_ok
                           AND ai.id_estado_verificacion_salida IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_salida = v_id_observado)
    INTO v_items, v_pendientes, v_observados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_items = 0 THEN
        RETURN json_build_object('error', 'La actividad no tiene items que verificar', 'registro', NULL);
    END IF;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format('Faltan %s item(s) por verificar en la salida', v_pendientes),
            'registro', NULL
        );
    END IF;

    IF v_observados > 0 THEN
        RETURN json_build_object(
            'error', format(
                '%s item(s) quedaron con observacion: resuelvelos volviendo a verificarlos como conformes',
                v_observados
            ),
            'registro', NULL
        );
    END IF;

    UPDATE age_actividad
    SET id_estado_actividad = v_id_en_ruta,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;

-- ------------------------------------------------------------
-- age_culminar_entrega: EN_RUTA -> REALIZADA
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS age_culminar_entrega(integer, integer);

CREATE OR REPLACE FUNCTION age_culminar_entrega(
    p_id integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre_estado  VARCHAR;
    v_id_realizada   INTEGER;
    v_id_ok          INTEGER;
    v_id_observado   INTEGER;
    v_items          INTEGER;
    v_pendientes     INTEGER;
    v_observados     INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT UPPER(TRIM(lo.nombre)) INTO v_nombre_estado
    FROM age_actividad a
    LEFT JOIN gen_lista_opciones lo ON lo.id = a.id_estado_actividad
    WHERE a.id = p_id AND a.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La actividad no existe o esta anulada', 'registro', NULL);
    END IF;

    -- Culminar exige haber pasado por EN_RUTA: si no, la verificacion de salida
    -- nunca se exigio y la de llegada no prueba nada.
    IF COALESCE(v_nombre_estado, '') <> 'EN_RUTA' THEN
        RETURN json_build_object(
            'error', 'Solo se puede culminar una entrega que este EN_RUTA',
            'registro', NULL
        );
    END IF;

    -- Se acota a la lista EstadoActividad: buscar 'realizada' suelto puede
    -- traer la opcion homonima de otra lista.
    SELECT lo.id INTO v_id_realizada
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE (l.nombre = 'EstadoActividad' OR l.id = 49)
      AND UPPER(TRIM(lo.nombre)) = 'REALIZADA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_realizada IS NULL THEN
        RETURN json_build_object('error', 'No se encontro el estado REALIZADA en EstadoActividad', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_ok
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'OK' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_observado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'CON_OBSERVACION' AND lo.estado = 1 LIMIT 1;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_ok
                           AND ai.id_estado_verificacion_llegada IS DISTINCT FROM v_id_observado),
        COUNT(*) FILTER (WHERE ai.id_estado_verificacion_llegada = v_id_observado)
    INTO v_items, v_pendientes, v_observados
    FROM age_actividad_item ai
    WHERE ai.id_actividad = p_id AND ai.estado = 1;

    IF v_pendientes > 0 THEN
        RETURN json_build_object(
            'error', format('Faltan %s item(s) por verificar en la llegada', v_pendientes),
            'registro', NULL
        );
    END IF;

    IF v_observados > 0 THEN
        RETURN json_build_object(
            'error', format(
                '%s item(s) llegaron con observacion: resuelvelos volviendo a verificarlos como conformes',
                v_observados
            ),
            'registro', NULL
        );
    END IF;

    -- No se toca inventario ni custodia: doc_generar_salida ya movio el stock y
    -- el estado del cilindro cuando se genero la orden.
    UPDATE age_actividad
    SET id_estado_actividad = v_id_realizada,
        fecha_hora_cierre = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN age_obtener_actividad(p_id);
END;
$function$;

-- ------------------------------------------------------------
-- age_iniciar_verificacion: aceptar tambien REPARTO
--
-- La version de recojos aborta con "no tiene origen de recojo" cuando la
-- actividad no cuelga de prestamo/alquiler. En REPARTO los items ya vienen
-- creados desde doc_salida, asi que basta devolver la actividad.
-- ------------------------------------------------------------

DROP FUNCTION IF EXISTS age_iniciar_verificacion(integer, integer);

CREATE OR REPLACE FUNCTION age_iniciar_verificacion(
    p_id_actividad integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_act RECORD;
    v_id_pendiente INTEGER;
    v_items INTEGER := 0;
    v_n INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT a.id, a.id_prestamo, a.id_alquiler, a.id_doc_salida, a.id_comprobante
    INTO v_act
    FROM age_actividad a
    WHERE a.id = p_id_actividad AND a.estado = 1;

    IF v_act.id IS NULL THEN
        RETURN json_build_object('error', 'La actividad no existe', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM age_actividad_item i
        WHERE i.id_actividad = p_id_actividad AND i.estado = 1
    ) THEN
        RETURN age_obtener_actividad(p_id_actividad);
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoVerificacionItem' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_act.id_prestamo IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_prestamo_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY pd.id),
            COALESCE(pd.id_producto, b.id_producto_gas),
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            pd.id_balon,
            pd.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_prestamo_detalle pd
        LEFT JOIN bal_balon b ON b.id = pd.id_balon
        WHERE pd.id_prestamo = v_act.id_prestamo
          AND pd.estado = 1
          AND pd.fecha_devolucion IS NULL
          AND pd.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;
    ELSIF v_act.id_alquiler IS NOT NULL THEN
        INSERT INTO age_actividad_item (
            id_actividad, item, id_producto, descripcion, cantidad, id_balon,
            id_alquiler_detalle, id_estado_verificacion_salida, id_estado_verificacion_llegada,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT
            p_id_actividad,
            ROW_NUMBER() OVER (ORDER BY ad.id),
            b.id_producto_gas,
            COALESCE(b.codigo_balon, 'Cilindro'),
            1,
            ad.id_balon,
            ad.id,
            v_id_pendiente,
            v_id_pendiente,
            p_id_usuario_auditoria,
            p_id_usuario_auditoria
        FROM bal_alquiler_detalle ad
        LEFT JOIN bal_balon b ON b.id = ad.id_balon
        WHERE ad.id_alquiler = v_act.id_alquiler
          AND ad.estado = 1
          AND ad.fecha_devolucion IS NULL
          AND ad.id_balon IS NOT NULL;
        GET DIAGNOSTICS v_items = ROW_COUNT;

        -- Regulador pendiente: fila sin balon, solo producto.
        IF EXISTS (
            SELECT 1 FROM bal_alquiler a
            WHERE a.id = v_act.id_alquiler
              AND a.id_producto_regulador IS NOT NULL
              AND a.fecha_devolucion_regulador IS NULL
        ) THEN
            SELECT COALESCE(MAX(item), 0) INTO v_n
            FROM age_actividad_item
            WHERE id_actividad = p_id_actividad AND estado = 1;

            INSERT INTO age_actividad_item (
                id_actividad, item, id_producto, descripcion, cantidad, id_balon,
                id_estado_verificacion_salida, id_estado_verificacion_llegada,
                id_usuario_creacion, id_usuario_modificacion
            )
            SELECT
                p_id_actividad,
                v_n + 1,
                a.id_producto_regulador,
                COALESCE(pr.nombre, 'Regulador / accesorio'),
                1,
                NULL,
                v_id_pendiente,
                v_id_pendiente,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            FROM bal_alquiler a
            LEFT JOIN pro_producto pr ON pr.id = a.id_producto_regulador
            WHERE a.id = v_act.id_alquiler;

            v_items := v_items + 1;
        END IF;
    ELSIF v_act.id_doc_salida IS NOT NULL OR v_act.id_comprobante IS NOT NULL THEN
        -- REPARTO sin items materializados: no hay nada que derivar aqui, los
        -- items los crea age_crear_actividad desde el detalle del documento.
        RETURN json_build_object(
            'error', 'La actividad de reparto no tiene items: revisa el documento de origen',
            'registro', NULL
        );
    ELSE
        RETURN json_build_object(
            'error', 'La actividad no tiene origen del que derivar items',
            'registro', NULL
        );
    END IF;

    RETURN age_obtener_actividad(p_id_actividad);
END;
$function$;
