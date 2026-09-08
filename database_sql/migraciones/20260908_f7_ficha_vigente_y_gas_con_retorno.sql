-- ============================================================
-- Migración: ficha vigente única + gas solo con retorno marcado
-- Fecha: 2026-09-08
--
-- 1) bal_crear_lote_protocolo rechaza una ficha nueva si ya hay otra vigente
--    (misma planta y mismo gas, sin vencer). Registrar dos fichas del mismo
--    lote en curso es casi siempre una duplicación.
--
-- 2) com_registrar_balones_compra no ingresa el gas si la compra cuelga de una
--    orden a planta cuyo retorno no se marcó: ese gas todavía está en la planta.
--    Devuelve un error accionable en vez de inflar el inventario en silencio.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260908_f7_ficha_vigente_y_gas_con_retorno.sql
-- ============================================================



-- ============================================================
-- database_sql/funciones/lotes-protocolo/bal_crear_lote_protocolo.sql
-- ============================================================

-- Function: bal_crear_lote_protocolo
-- Fase 5 — alta de una ficha ICP. Los datos de análisis y la relación de envases
-- llegan como JSON en el mismo llamado: la ficha no tiene sentido a medias.
DROP FUNCTION IF EXISTS bal_crear_lote_protocolo(p_numero_lote character varying, p_numero_protocolo character varying, p_id_proveedor integer, p_id_producto_gas integer, p_descripcion_producto character varying, p_forma_farmaceutica character varying, p_presentacion character varying, p_norma_tecnica character varying, p_metodo_fabricacion character varying, p_fecha_analisis date, p_fecha_emision date, p_fecha_fabricacion date, p_fecha_vencimiento date, p_tamano_lote_m3 numeric, p_cantidad_envases integer, p_valoracion_o2_pct numeric, p_limite_co2_ppm numeric, p_limite_co_ppm numeric, p_cilindro_muestreado_serie character varying, p_temperatura_muestreo_c numeric, p_presion_muestreo_psi numeric, p_analista character varying, p_conclusion character varying, p_codigo_documento character varying, p_version_documento character varying, p_id_archivo_pdf integer, p_observacion character varying, p_pruebas json, p_envases json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_lote_protocolo(p_numero_lote character varying, p_numero_protocolo character varying DEFAULT NULL::character varying, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_descripcion_producto character varying DEFAULT NULL::character varying, p_forma_farmaceutica character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_norma_tecnica character varying DEFAULT NULL::character varying, p_metodo_fabricacion character varying DEFAULT NULL::character varying, p_fecha_analisis date DEFAULT NULL::date, p_fecha_emision date DEFAULT NULL::date, p_fecha_fabricacion date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_tamano_lote_m3 numeric DEFAULT NULL::numeric, p_cantidad_envases integer DEFAULT NULL::integer, p_valoracion_o2_pct numeric DEFAULT NULL::numeric, p_limite_co2_ppm numeric DEFAULT NULL::numeric, p_limite_co_ppm numeric DEFAULT NULL::numeric, p_cilindro_muestreado_serie character varying DEFAULT NULL::character varying, p_temperatura_muestreo_c numeric DEFAULT NULL::numeric, p_presion_muestreo_psi numeric DEFAULT NULL::numeric, p_analista character varying DEFAULT NULL::character varying, p_conclusion character varying DEFAULT NULL::character varying, p_codigo_documento character varying DEFAULT NULL::character varying, p_version_documento character varying DEFAULT NULL::character varying, p_id_archivo_pdf integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_pruebas json DEFAULT NULL::json, p_envases json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_numero_lote VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero_lote := NULLIF(TRIM(p_numero_lote), '');

    IF v_numero_lote IS NULL THEN
        RETURN json_build_object('error', 'El número de lote es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_lote_protocolo lp
        WHERE lp.estado = 1
          AND UPPER(TRIM(lp.numero_lote)) = UPPER(v_numero_lote)
          AND COALESCE(lp.id_proveedor, 0) = COALESCE(p_id_proveedor, 0)
    ) THEN
        RETURN json_build_object(
            'error', format('Ya existe una ficha activa con el lote %s para ese proveedor', v_numero_lote),
            'registro', NULL
        );
    END IF;

    -- Una ficha vigente cubre el lote en curso: mientras no venza, registrar otra
    -- del mismo proveedor y gas significa casi siempre que se está duplicando.
    IF EXISTS (
        SELECT 1
        FROM bal_lote_protocolo lp
        WHERE lp.estado = 1
          AND COALESCE(lp.id_proveedor, 0) = COALESCE(p_id_proveedor, 0)
          AND COALESCE(lp.id_producto_gas, 0) = COALESCE(p_id_producto_gas, 0)
          AND lp.fecha_vencimiento IS NOT NULL
          AND lp.fecha_vencimiento >= CURRENT_DATE
    ) THEN
        RETURN json_build_object(
            'error', (
                SELECT format(
                    'Ya hay una ficha vigente para este proveedor y gas: lote %s, vence %s. No se puede registrar otra hasta que venza.',
                    lp.numero_lote, TO_CHAR(lp.fecha_vencimiento, 'MM/YYYY')
                )
                FROM bal_lote_protocolo lp
                WHERE lp.estado = 1
                  AND COALESCE(lp.id_proveedor, 0) = COALESCE(p_id_proveedor, 0)
                  AND COALESCE(lp.id_producto_gas, 0) = COALESCE(p_id_producto_gas, 0)
                  AND lp.fecha_vencimiento IS NOT NULL
                  AND lp.fecha_vencimiento >= CURRENT_DATE
                ORDER BY lp.fecha_vencimiento DESC
                LIMIT 1
            ),
            'registro', NULL
        );
    END IF;

    INSERT INTO bal_lote_protocolo (
        numero_lote, numero_protocolo, id_proveedor, id_producto_gas,
        descripcion_producto, forma_farmaceutica, presentacion, norma_tecnica,
        metodo_fabricacion, fecha_analisis, fecha_emision, fecha_fabricacion,
        fecha_vencimiento, tamano_lote_m3, cantidad_envases, valoracion_o2_pct,
        limite_co2_ppm, limite_co_ppm, cilindro_muestreado_serie,
        temperatura_muestreo_c, presion_muestreo_psi, analista, conclusion,
        codigo_documento, version_documento, id_archivo_pdf, observacion,
        estado, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_numero_lote, NULLIF(TRIM(p_numero_protocolo), ''), p_id_proveedor, p_id_producto_gas,
        p_descripcion_producto, p_forma_farmaceutica, p_presentacion, p_norma_tecnica,
        p_metodo_fabricacion, p_fecha_analisis, p_fecha_emision, p_fecha_fabricacion,
        p_fecha_vencimiento, p_tamano_lote_m3, p_cantidad_envases, p_valoracion_o2_pct,
        p_limite_co2_ppm, p_limite_co_ppm, NULLIF(TRIM(p_cilindro_muestreado_serie), ''),
        p_temperatura_muestreo_c, p_presion_muestreo_psi, p_analista, p_conclusion,
        p_codigo_documento, p_version_documento, p_id_archivo_pdf, p_observacion,
        1, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    PERFORM bal_reemplazar_lote_protocolo_detalle(v_id, p_pruebas, p_envases, p_id_usuario_auditoria);

    RETURN bal_obtener_lote_protocolo(v_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/compras/com_registrar_balones_compra.sql
-- ============================================================

-- Function: com_registrar_balones_compra
-- Fase 7 — compra de cilindros: los da de alta en el libro y mueve inventario.
--
-- Comprar un balón no es como comprar un producto: el cilindro tiene identidad
-- propia, así que además de la línea de compra hay que crearlo en bal_balon y
-- registrar su ENTRADA_COMPRA en inv_movimiento. Un movimiento por cilindro,
-- no uno por línea (apunte 4.b.iv).
--
-- Si el cilindro viene cargado, `cantidad_gas` registra además la entrada del
-- gas como movimiento de PRODUCTO: comprar un balón lleno son dos hechos —
-- entra el envase y entra su contenido— y cada uno lleva su movimiento.
--
-- p_balones: [{ codigo_balon, numero_serie, id_tipo_balon, id_producto_gas,
--               id_marca_cilindro, fecha_fabricacion,
--               fecha_ultima_prueba_hidrostatica, cantidad_gas }]
DROP FUNCTION IF EXISTS com_registrar_balones_compra(p_id_comprobante integer, p_balones jsonb, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_registrar_balones_compra(p_id_comprobante integer, p_balones jsonb DEFAULT NULL::jsonb, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_compra            RECORD;
    v_linea             JSONB;
    v_codigo            VARCHAR;
    v_id_balon          INTEGER;
    v_id_propietario    INTEGER;
    v_id_estado         INTEGER;
    v_id_referencia     INTEGER;
    v_res               JSON;
    v_id_gas            INTEGER;
    v_cantidad_gas      NUMERIC(12,4);
    v_gas_total         NUMERIC(12,4) := 0;
    v_creados           INTEGER := 0;
    v_ids               INTEGER[] := ARRAY[]::INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_balones IS NULL OR jsonb_array_length(p_balones) = 0 THEN
        RETURN json_build_object('error', NULL, 'registro', json_build_object('creados', 0, 'id_balones', '[]'::JSON));
    END IF;

    SELECT c.id, c.fecha, c.serie, c.numero, c.id_almacen, c.id_proveedor,
           c.id_doc_salida,
           (
               c.id_doc_salida IS NULL
               OR EXISTS (
                   SELECT 1 FROM doc_salida d
                   WHERE d.id = c.id_doc_salida AND d.fecha_llegada_almacen IS NOT NULL
               )
           ) AS retorno_marcado
    INTO v_compra
    FROM com_comprobante_compra c
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF v_compra.id IS NULL THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    -- Un cilindro comprado entra como propio y disponible en el almacén de la compra.
    SELECT lo.id INTO v_id_propietario
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'EMPRESA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1 LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Falta el estado DISPONIBLE en el catálogo EstadoBalon', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_referencia
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'ReferenciaCilindro' AND lo.nombre = 'ALMACEN' AND lo.estado = 1 LIMIT 1;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(p_balones)
    LOOP
        v_codigo := NULLIF(TRIM(v_linea->>'codigo_balon'), '');

        IF v_codigo IS NULL THEN
            RETURN json_build_object('error', 'Cada cilindro comprado necesita su código', 'registro', NULL);
        END IF;

        IF EXISTS (SELECT 1 FROM bal_balon WHERE UPPER(TRIM(codigo_balon)) = UPPER(v_codigo) AND estado = 1) THEN
            RETURN json_build_object(
                'error', format('El cilindro %s ya existe en el libro', v_codigo),
                'registro', NULL
            );
        END IF;

        -- El gas no se elige a mano: lo define el tipo de balón. Un cilindro de
        -- oxígeno medicinal no puede entrar con otro gas por un descuido al tipear.
        v_id_gas := COALESCE(
            (v_linea->>'id_producto_gas')::INTEGER,
            (SELECT tb.id_gas FROM bal_tipo_balon tb WHERE tb.id = (v_linea->>'id_tipo_balon')::INTEGER)
        );
        v_cantidad_gas := COALESCE((v_linea->>'cantidad_gas')::NUMERIC, 0);

        v_res := bal_crear_balon(
            p_codigo_balon                     => v_codigo,
            p_fecha_registro                   => v_compra.fecha,
            p_id_almacen                       => v_compra.id_almacen,
            p_id_propietario                   => v_id_propietario,
            p_id_referencia                    => v_id_referencia,
            p_id_tipo_balon                    => (v_linea->>'id_tipo_balon')::INTEGER,
            p_id_producto_gas                  => v_id_gas,
            p_id_estado_balon                  => v_id_estado,
            p_fecha_ultima_prueba_hidrostatica => (v_linea->>'fecha_ultima_prueba_hidrostatica')::DATE,
            p_fecha_fabricacion                => (v_linea->>'fecha_fabricacion')::DATE,
            p_observacion                      => format(
                'Alta por compra %s',
                NULLIF(TRIM(CONCAT_WS('-', v_compra.serie, v_compra.numero)), '')
            ),
            p_numero_serie                     => NULLIF(TRIM(v_linea->>'numero_serie'), ''),
            p_id_marca_cilindro                => (v_linea->>'id_marca_cilindro')::INTEGER,
            p_id_usuario_auditoria             => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            RETURN json_build_object('error', v_res->>'error', 'registro', NULL);
        END IF;

        v_id_balon := (v_res->'registro'->>'id')::INTEGER;

        IF v_id_balon IS NULL THEN
            RETURN json_build_object(
                'error', format('No se pudo crear el cilindro %s', v_codigo),
                'registro', NULL
            );
        END IF;

        -- A partir de acá el cilindro ya existe en el libro: si el movimiento
        -- falla se levanta excepción para que la transacción entera se deshaga
        -- y no quede un balón dado de alta sin su entrada de inventario.
        v_res := inv_registrar_movimiento(
            p_naturaleza                   => 'BALON',
            p_codigo_tipo_movimiento       => 'ENTRADA_COMPRA',
            p_fecha                        => v_compra.fecha,
            p_id_balon                     => v_id_balon,
            p_cantidad                     => 1,
            p_id_almacen_destino           => v_compra.id_almacen,
            p_id_cliente                   => v_compra.id_proveedor,
            p_codigo_tipo_documento_origen => 'COMPRA',
            p_id_documento_origen          => p_id_comprobante,
            p_glosa                        => format('Ingreso del cilindro %s por compra', v_codigo),
            p_id_usuario_auditoria         => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo registrar la entrada del cilindro %: %',
                v_codigo, v_res->>'error';
        END IF;

        -- Gas del cilindro comprado: entra al stock del producto por la misma vía
        -- unificada que cualquier otro ingreso.
        -- El gas entra al stock cuando los cilindros ya llegaron. Si la compra
        -- cuelga de una orden a planta cuyo retorno no se marcó, el gas todavía
        -- está en la planta: sumarlo acá inflaría el inventario.
        IF v_cantidad_gas > 0 AND NOT v_compra.retorno_marcado THEN
            RETURN json_build_object(
                'error', 'Los cilindros aún no figuran como retornados: marca el retorno en la orden de salida (o desde la compra) antes de ingresar el gas.',
                'registro', NULL
            );
        END IF;

        IF v_cantidad_gas > 0 AND v_id_gas IS NOT NULL THEN
            v_res := inv_registrar_movimiento(
                p_naturaleza                   => 'PRODUCTO',
                p_codigo_tipo_movimiento       => 'INGRESO',
                p_fecha                        => v_compra.fecha,
                p_id_producto                  => v_id_gas,
                p_cantidad                     => v_cantidad_gas,
                p_id_almacen_origen            => v_compra.id_almacen,
                p_id_cliente                   => v_compra.id_proveedor,
                p_codigo_tipo_documento_origen => 'COMPRA',
                p_id_documento_origen          => p_id_comprobante,
                p_glosa                        => format('Gas del cilindro %s por compra', v_codigo),
                p_id_usuario_auditoria         => p_id_usuario_auditoria
            );

            IF (v_res->>'error') IS NOT NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el gas del cilindro %: %',
                    v_codigo, v_res->>'error';
            END IF;

            v_gas_total := v_gas_total + v_cantidad_gas;
        END IF;

        v_ids := v_ids || v_id_balon;
        v_creados := v_creados + 1;
    END LOOP;

    UPDATE com_comprobante_compra
    SET afecta_inventario = TRUE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'creados', v_creados,
            'id_balones', array_to_json(v_ids),
            'gas_ingresado', v_gas_total
        )
    );
END;
$function$;
