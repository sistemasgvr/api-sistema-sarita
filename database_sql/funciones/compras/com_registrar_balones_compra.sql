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
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   las validaciones de códigos (vacío, repetido en el lote, ya en el libro)
--   corren sobre todo el lote antes del bucle, y dentro del bucle todo fallo
--   es RAISE. Antes un {error} blando en el 3.er cilindro dejaba los dos
--   primeros dados de alta con su movimiento (sin rollback).
--
-- Actualizada por database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql:
--   "los cilindros ya llegaron" se mide por la ENTRADA_PLANTA_EXTERNA vigente
--   de los envases, no por doc_salida.fecha_llegada_almacen: una orden con solo
--   la fecha tiene los cilindros todavía en planta, y el gas de esta compra
--   entraba igual (inflando el stock).
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
                   SELECT 1
                   FROM inv_movimiento m
                   JOIN doc_salida_detalle dd ON dd.id = m.id_documento_detalle
                   JOIN gen_lista_opciones tmv ON tmv.id = m.id_tipo_movimiento
                   JOIN gen_lista ltmv ON ltmv.id = tmv.id_lista
                   WHERE m.estado = 1
                     AND m.naturaleza = 'BALON'
                     AND ltmv.nombre = 'TipoMovInvUnificado'
                     AND tmv.nombre = 'ENTRADA_PLANTA_EXTERNA'
                     AND dd.id_doc_salida = c.id_doc_salida
                     AND dd.id_balon IS NOT NULL
                     AND m.id_balon = dd.id_balon
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

    -- El gas entra al stock cuando los cilindros ya llegaron. Si la compra cuelga
    -- de una orden a planta cuyo retorno no se marcó, el gas todavía está en la
    -- planta y sumarlo inflaría el inventario. Se valida ANTES del bucle: si se
    -- comprobara por línea, los cilindros anteriores ya estarían dados de alta.
    IF NOT v_compra.retorno_marcado
       AND EXISTS (
           SELECT 1 FROM jsonb_array_elements(p_balones) AS a(x)
           WHERE COALESCE((x->>'cantidad_gas')::NUMERIC, 0) > 0
       )
    THEN
        RETURN json_build_object(
            'error', 'Los cilindros aún no figuran como retornados: marca el retorno en la orden de salida (o desde la compra) antes de ingresar el gas.',
            'registro', NULL
        );
    END IF;

    -- Validaciones de todo el lote ANTES de dar de alta el primero: dentro del
    -- bucle un {error} blando dejaría confirmados los cilindros anteriores
    -- (la función no falla, así que no hay rollback).
    IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(p_balones) AS a(x)
        WHERE NULLIF(TRIM(x->>'codigo_balon'), '') IS NULL
    ) THEN
        RETURN json_build_object('error', 'Cada cilindro comprado necesita su código', 'registro', NULL);
    END IF;

    SELECT UPPER(TRIM(x->>'codigo_balon')) INTO v_codigo
    FROM jsonb_array_elements(p_balones) AS a(x)
    GROUP BY UPPER(TRIM(x->>'codigo_balon'))
    HAVING COUNT(*) > 1
    LIMIT 1;

    IF v_codigo IS NOT NULL THEN
        RETURN json_build_object(
            'error', format('El código %s está repetido en el lote de cilindros', v_codigo),
            'registro', NULL
        );
    END IF;

    SELECT b.codigo_balon INTO v_codigo
    FROM bal_balon b
    WHERE b.estado = 1
      AND UPPER(TRIM(b.codigo_balon)) IN (
          SELECT UPPER(TRIM(x->>'codigo_balon')) FROM jsonb_array_elements(p_balones) AS a(x)
      )
    LIMIT 1;

    IF v_codigo IS NOT NULL THEN
        RETURN json_build_object(
            'error', format('El cilindro %s ya existe en el libro', v_codigo),
            'registro', NULL
        );
    END IF;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(p_balones)
    LOOP
        v_codigo := NULLIF(TRIM(v_linea->>'codigo_balon'), '');

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

        -- Desde el segundo cilindro ya hay altas confirmadas: cualquier fallo se
        -- levanta con RAISE para que la transacción entera se deshaga y no
        -- queden cilindros dados de alta a medias.
        IF (v_res->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo dar de alta el cilindro %: %', v_codigo, v_res->>'error';
        END IF;

        v_id_balon := (v_res->'registro'->>'id')::INTEGER;

        IF v_id_balon IS NULL THEN
            RAISE EXCEPTION 'No se pudo crear el cilindro %', v_codigo;
        END IF;

        -- El cilindro ya existe en el libro: si el movimiento falla se levanta
        -- excepción para que no quede un balón dado de alta sin su entrada de
        -- inventario.
        -- id_documento_detalle = id_balon: cada cilindro es un hecho distinto para
        -- la idempotencia de inv_registrar_movimiento (sin esto, el 2.º gas del
        -- mismo producto reusa el 1.er movimiento y se pierde stock).
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
            p_id_documento_detalle         => v_id_balon,
            p_glosa                        => format('Ingreso del cilindro %s por compra', v_codigo),
            p_id_usuario_auditoria         => p_id_usuario_auditoria
        );

        IF (v_res->>'error') IS NOT NULL THEN
            RAISE EXCEPTION 'No se pudo registrar la entrada del cilindro %: %',
                v_codigo, v_res->>'error';
        END IF;

        -- Gas del cilindro comprado: entra al stock del producto por la misma vía
        -- unificada que cualquier otro ingreso.
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
                p_id_documento_detalle         => v_id_balon,
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
