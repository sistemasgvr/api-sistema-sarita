-- ============================================================
-- Migración: U.M. simétrica entre la salida y el retorno de gas
-- Fecha: 2026-09-10
--
-- Problema: doc_generar_salida registraba la SALIDA de gas con la cantidad
-- cruda de la línea, mientras el retorno (bal_sincronizar_gas_retorno_planta,
-- y el INGRESO de compra) la convierte a la U.M. del producto con
-- inv_convertir_a_unidad_producto. Cuando la U.M. de la línea no era la del
-- producto —el caso típico es una orden de planta cuyas líneas de gas salen
-- de sumar capacidades en la U.M. del tipo de balón (KG) contra un gas cuya
-- unidad de stock es MT3— el neto quedaba sesgado: salía una magnitud y
-- entraba otra distinta por la misma cantidad física.
--
--  1) doc_cantidad_linea_en_unidad_producto (nueva): única regla para pasar
--     la cantidad de una línea de doc_salida_detalle a la U.M. del producto.
--     Resuelve la unidad de origen en este orden: U.M. de la línea → U.M. de
--     la capacidad del tipo de balón (solo en líneas de cilindro, que es donde
--     la cantidad puede venir de capacidades) → U.M. del producto (neutra).
--     Las líneas de envase puro (sin producto) devuelven la cantidad tal cual:
--     ahí la cantidad cuenta cilindros, no gas.
--
--  2) doc_generar_salida: la cantidad que va al kardex sale de esa función,
--     tanto en las líneas PRODUCTO como en las de cilindro que además arrastran
--     gas (id_balon + id_producto: inv_registrar_movimiento mueve pro_stock del
--     gas con esa cantidad).
--
--  3) doc_generar_salida: pre-vuelo antes de tocar inventario.
--     · Las conversiones se resuelven en seco. inv_convertir_a_unidad_producto
--       lanza excepción si falta factor_kg_m3 / factor_lb_m3 o la unidad no es
--       convertible; dentro del bucle eso tumbaba la petición con el kardex a
--       medias. Ahora devuelve error de negocio y no se movió nada.
--     · En RECARGA_PLANTA_EXTERNA el gas declarado no puede superar la suma de
--       capacidades de los cilindros de la orden, comparando ambos ya en la
--       U.M. del gas. Antes el tope solo lo ponía el formulario. Si los
--       cilindros no tienen gas o capacidad configurados no hay tope contra el
--       cual comparar y la orden pasa igual que antes.
--
-- No toca nada de 20260910_compras_anular_retorno_p0p1: el retorno sigue
-- registrándose con bal_sincronizar_gas_retorno_planta y con las mismas
-- etiquetas de documento. Esta migración solo alinea la ida con esa regla.
--
-- Movimientos ya registrados: no se recalculan. Reexpresarlos exigiría
-- recomputar pro_stock hacia atrás; las órdenes afectadas se listan al final
-- como aviso para revisarlas con operaciones (anular y regenerar la orden es
-- el camino seguro, porque inv_revertir_por_documento devuelve exactamente lo
-- que se movió).
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260910_doc_generar_um_conversion.sql
-- ============================================================


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_cantidad_linea_en_unidad_producto.sql
-- ============================================================
-- Function: doc_cantidad_linea_en_unidad_producto
-- Creada: 2026-09-10 (migración 20260910_doc_generar_um_conversion).
--
-- Cantidad de una línea de doc_salida_detalle expresada en la U.M. del
-- producto, que es la unidad en la que vive pro_stock.
--
-- Existe para que la SALIDA y el RETORNO de la misma orden usen exactamente la
-- misma regla. Antes doc_generar_salida registraba la cantidad cruda mientras
-- bal_sincronizar_gas_retorno_planta convertía, así que cuando la U.M. de la
-- línea no era la del producto (caso típico: capacidades en KG contra un gas
-- en MT3) el neto de stock quedaba sesgado.
--
-- Unidad de origen, por orden de preferencia:
--   1) la U.M. persistida en la línea (doc_crear_salida_detalle ya la
--      completa con la del producto cuando no viene);
--   2) en líneas de cilindro, la U.M. de la capacidad del tipo de balón: esa
--      es la unidad en la que se declaran las capacidades;
--   3) la U.M. del propio producto, que hace la conversión neutra.
--
-- Las líneas de envase puro (sin producto) devuelven la cantidad tal cual: ahí
-- la cantidad cuenta cilindros, no gas.
--
-- Puede lanzar excepción (falta factor_kg_m3 / unidad no convertible) porque
-- inv_convertir_a_unidad_producto lo hace. Los callers que mueven inventario
-- deben probarla en seco antes de empezar.
DROP FUNCTION IF EXISTS doc_cantidad_linea_en_unidad_producto(p_id_detalle integer);

CREATE OR REPLACE FUNCTION doc_cantidad_linea_en_unidad_producto(p_id_detalle integer)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_id_producto INTEGER;
    v_cantidad NUMERIC;
    v_id_unidad_origen INTEGER;
BEGIN
    IF p_id_detalle IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT
        dd.id_producto,
        dd.cantidad,
        CASE
            WHEN dd.id_balon IS NOT NULL
                THEN COALESCE(dd.id_unidad_medida, tb.id_unidad_medida, p.id_unidad_medida)
            ELSE COALESCE(dd.id_unidad_medida, p.id_unidad_medida)
        END
    INTO v_id_producto, v_cantidad, v_id_unidad_origen
    FROM doc_salida_detalle dd
    LEFT JOIN pro_producto p ON p.id = dd.id_producto
    LEFT JOIN bal_balon b ON b.id = dd.id_balon
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE dd.id = p_id_detalle;

    IF NOT FOUND OR v_id_producto IS NULL THEN
        RETURN v_cantidad;
    END IF;

    RETURN inv_convertir_a_unidad_producto(v_id_producto, v_cantidad, v_id_unidad_origen);
END;
$function$;


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_generar_salida.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_generar_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
--
-- Para OS sin venta (id_venta IS NULL) de tipos compatibles con REPARTO, tras el
-- kardex se corrige custodia a PENDIENTE_ENVIO (ver bloque al final del loop).
--
-- Actualizada por database_sql/migraciones/20260910_doc_generar_um_conversion.sql:
--   · la cantidad que va al kardex se expresa en la U.M. del producto
--     (doc_cantidad_linea_en_unidad_producto), la misma regla que usa
--     bal_sincronizar_gas_retorno_planta para la entrada. Antes la salida
--     registraba la cantidad cruda y el retorno la convertía, así que el neto
--     de stock se sesgaba cuando las unidades no coincidían;
--   · pre-vuelo antes de tocar inventario: se resuelven todas las conversiones
--     en seco (un factor faltante devuelve error de negocio en vez de reventar
--     la petición a medio kardex) y, en RECARGA_PLANTA_EXTERNA, se rechaza el
--     gas declarado por encima de la capacidad de los cilindros de la orden.
DROP FUNCTION IF EXISTS doc_generar_salida(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_generar_salida(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_estado VARCHAR;
    v_tipo VARCHAR;
    v_id_generada INTEGER;
    v_det RECORD;
    v_mov JSON;
    v_id_mov INTEGER;
    v_codigo_mov VARCHAR;
    v_n INTEGER := 0;
    v_id_pend_envio INTEGER;
    v_hay_balones BOOLEAN;
    -- Solo fuerza la evaluación del pre-vuelo de unidades; su valor no se usa.
    v_prevuelo NUMERIC;
    v_exceso_gas TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo, tor.nombre AS tipo_orden
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    v_estado := v_doc.estado_ciclo;
    v_tipo := v_doc.tipo_orden;

    IF v_estado = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF v_estado IN ('GENERADA', 'EMITIDA_SUNAT') THEN
        -- Ya produjo efectos; no se repiten.
        RETURN doc_obtener_salida(p_id);
    END IF;

    -- El tipo de movimiento depende del propósito del documento.
    v_codigo_mov := CASE v_tipo
        WHEN 'RECARGA_PLANTA_EXTERNA' THEN 'SALIDA_PLANTA_EXTERNA'
        WHEN 'TRASLADO'               THEN 'TRASLADO'
        ELSE 'SALIDA_ENTREGA_CLIENTE'
    END;

    -- Se comprueba acá y no solo al crear: hay órdenes anteriores a que el
    -- destino existiera, y sin él inv_registrar_movimiento aborta con una
    -- excepción que tumba toda la petición en vez de devolver el error.
    IF v_tipo = 'TRASLADO' AND v_doc.id_almacen_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'El traslado requiere almacén de destino: regístralo antes de generar',
            'registro', NULL
        );
    END IF;

    IF v_doc.id_venta IS NULL THEN
        IF NOT EXISTS (SELECT 1 FROM doc_salida_detalle WHERE id_doc_salida = p_id AND estado = 1) THEN
            RETURN json_build_object('error', 'El documento no tiene líneas que trasladar', 'registro', NULL);
        END IF;

        -- ------------------------------------------------------------
        -- Pre-vuelo de unidades (antes de cualquier movimiento)
        --
        -- Las conversiones se resuelven en seco: si a un gas le falta el
        -- factor o la U.M. de la línea no es convertible,
        -- inv_convertir_a_unidad_producto lanza excepción, y dentro del bucle
        -- eso tumbaría la petición con el kardex a medias. Acá se traduce a un
        -- error de negocio, que es lo que la orden puede corregir.
        --
        -- En RECARGA_PLANTA_EXTERNA se compara además el gas declarado contra
        -- la capacidad de los cilindros de la orden, ambos ya en la U.M. del
        -- gas: la planta no puede haber cargado más de lo que cabe. Si los
        -- cilindros no tienen gas o capacidad configurados no hay tope contra
        -- el cual comparar y la línea pasa.
        -- ------------------------------------------------------------
        BEGIN
            SELECT COALESCE(SUM(doc_cantidad_linea_en_unidad_producto(dd.id)), 0)
            INTO v_prevuelo
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1;

            IF v_tipo = 'RECARGA_PLANTA_EXTERNA' THEN
                SELECT string_agg(
                           format(
                               '%s (declarado %s %s, capacidad %s %s)',
                               t.nombre_producto,
                               TRIM(TO_CHAR(t.declarado, 'FM999999990.0999')),
                               COALESCE(t.unidad, ''),
                               TRIM(TO_CHAR(t.capacidad, 'FM999999990.0999')),
                               COALESCE(t.unidad, '')
                           ),
                           '; ' ORDER BY t.nombre_producto
                       )
                INTO v_exceso_gas
                FROM (
                    SELECT
                        dd.id_producto,
                        p.nombre AS nombre_producto,
                        um.nombre AS unidad,
                        SUM(doc_cantidad_linea_en_unidad_producto(dd.id)) AS declarado,
                        (
                            SELECT COALESCE(SUM(
                                inv_convertir_a_unidad_producto(
                                    dd.id_producto, tb.capacidad, tb.id_unidad_medida
                                )
                            ), 0)
                            FROM doc_salida_detalle db
                            JOIN bal_balon b ON b.id = db.id_balon
                            JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                            WHERE db.id_doc_salida = p_id
                              AND db.estado = 1
                              AND db.id_balon IS NOT NULL
                              AND COALESCE(b.id_producto_gas, tb.id_gas) = dd.id_producto
                              AND COALESCE(tb.capacidad, 0) > 0
                        ) AS capacidad
                    FROM doc_salida_detalle dd
                    JOIN pro_producto p ON p.id = dd.id_producto
                    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
                    WHERE dd.id_doc_salida = p_id
                      AND dd.estado = 1
                      AND dd.id_balon IS NULL
                      AND dd.cantidad > 0
                    GROUP BY dd.id_producto, p.nombre, um.nombre
                ) t
                -- Redondeo a 2 decimales: las conversiones redondean a 4 y se
                -- suman por cilindro, así que un tope exacto rechazaría por
                -- milésimas lo que en la práctica sí cabe.
                WHERE t.capacidad > 0
                  AND ROUND(t.declarado, 2) > ROUND(t.capacidad, 2);

                IF v_exceso_gas IS NOT NULL THEN
                    RETURN json_build_object(
                        'error', format(
                            'El gas declarado supera la capacidad de los cilindros de la orden: %s. Corrige el detalle antes de generar.',
                            v_exceso_gas
                        ),
                        'registro', NULL
                    );
                END IF;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            RETURN json_build_object(
                'error', format('No se puede generar la salida: %s', SQLERRM),
                'registro', NULL
            );
        END;

        -- Custodia REPARTO (OS sin venta): validar catálogo ANTES del kardex.
        IF v_tipo NOT IN ('RECARGA_PLANTA_EXTERNA', 'TRASLADO') THEN
            SELECT EXISTS (
                SELECT 1
                FROM doc_salida_detalle dd
                WHERE dd.id_doc_salida = p_id
                  AND dd.estado = 1
                  AND dd.id_balon IS NOT NULL
            ) INTO v_hay_balones;

            IF v_hay_balones THEN
                SELECT lo.id INTO v_id_pend_envio
                FROM gen_lista_opciones lo
                JOIN gen_lista l ON l.id = lo.id_lista
                WHERE l.nombre = 'EstadoBalon'
                  AND UPPER(TRIM(lo.nombre)) = 'PENDIENTE_ENVIO'
                  AND lo.estado = 1
                LIMIT 1;

                IF v_id_pend_envio IS NULL THEN
                    RETURN json_build_object(
                        'error', 'Falta el estado PENDIENTE_ENVIO en el catálogo EstadoBalon',
                        'registro', NULL
                    );
                END IF;
            END IF;
        END IF;

        FOR v_det IN
            SELECT
                dd.*,
                -- La cantidad del kardex va en la U.M. del producto (la de
                -- pro_stock), no en la de la línea: es la misma regla con la
                -- que entra el gas del retorno.
                doc_cantidad_linea_en_unidad_producto(dd.id) AS cantidad_movimiento
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
            ORDER BY dd.item
        LOOP
            -- El gas viaja SIEMPRE en sus propias líneas de producto, nunca en
            -- la del cilindro. El detalle se arma en dos planos: una línea por
            -- balón, que mueve el envase (estado y almacén), y una línea por
            -- producto con la cantidad total de gas que sale. Tomar además el
            -- gas del balón descontaría el mismo gas dos veces.
            v_mov := inv_registrar_movimiento(
                p_naturaleza                   => CASE WHEN v_det.id_balon IS NOT NULL THEN 'BALON' ELSE 'PRODUCTO' END,
                p_codigo_tipo_movimiento       => v_codigo_mov,
                p_fecha                        => LOCALTIMESTAMP,
                p_id_producto                  => v_det.id_producto,
                p_id_balon                     => v_det.id_balon,
                p_cantidad                     => COALESCE(v_det.cantidad_movimiento, v_det.cantidad),
                p_id_almacen_origen            => v_doc.id_almacen,
                p_id_almacen_destino           => v_doc.id_almacen_destino,
                p_id_cliente                   => COALESCE(v_doc.id_destinatario, v_doc.id_cliente, v_doc.id_proveedor),
                p_codigo_tipo_documento_origen => 'ORDEN_SALIDA',
                p_id_documento_origen          => p_id,
                p_glosa                        => format('Salida por orden %s', v_doc.numero),
                p_id_usuario_auditoria         => p_id_usuario_auditoria,
                p_id_documento_detalle         => v_det.id
            );

            IF v_mov->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_mov->>'error';
            END IF;

            IF COALESCE((v_mov->>'creado')::BOOLEAN, TRUE) IS NOT TRUE THEN
                RAISE EXCEPTION 'No se registró el movimiento de la línea % (duplicado)', v_det.item;
            END IF;

            v_id_mov := (v_mov->'registro'->>'id')::INTEGER;

            UPDATE doc_salida_detalle
            SET id_movimiento = v_id_mov,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_det.id;

            v_n := v_n + 1;
        END LOOP;

        -- ------------------------------------------------------------
        -- Custodia REPARTO (OS sin venta, tipos de entrega a cliente)
        --
        -- TRADEOFF: se mantiene SALIDA_ENTREGA_CLIENTE en inv_registrar_movimiento
        -- (kardex + auditoría del movimiento). Ese tipo pone EN_PODER_CLIENTE y
        -- limpia id_almacen —demasiado temprano para el flujo age_* (iniciar →
        -- EN_TRANSITO, culminar → EN_PODER_CLIENTE), que exige PENDIENTE_ENVIO.
        -- Cambiar el TipoMovInvUnificado / el CASE de estados en
        -- inv_registrar_movimiento es más riesgoso (afecta otros callers).
        -- Corrección local: tras generar, los cilindros de la OS vuelven a
        -- PENDIENTE_ENVIO y al almacén de la orden. TRASLADO y
        -- RECARGA_PLANTA_EXTERNA no pasan por REPARTO y no se tocan.
        -- ------------------------------------------------------------
        IF v_id_pend_envio IS NOT NULL THEN
            UPDATE bal_balon b
            SET id_estado_balon = v_id_pend_envio,
                id_almacen = COALESCE(v_doc.id_almacen, b.id_almacen),
                id_cliente_ubicacion = NULL,
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            FROM doc_salida_detalle dd
            WHERE dd.id_doc_salida = p_id
              AND dd.estado = 1
              AND dd.id_balon = b.id
              AND b.estado = 1
              AND UPPER(COALESCE(
                    (SELECT lo2.nombre FROM gen_lista_opciones lo2 WHERE lo2.id = b.id_estado_balon),
                    ''
                  )) NOT IN ('DADO_DE_BAJA', 'ROBO');
        END IF;
    END IF;
    -- Con id_venta no se toca inventario: el movimiento lo creó la venta y este
    -- documento solo lo respalda documentalmente (apunte 1.c.iv.6).

    SELECT lo.id INTO v_id_generada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'GENERADA' AND lo.estado = 1;

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_generada,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;


-- ------------------------------------------------------------
-- Aviso: órdenes ya generadas cuyo movimiento de gas quedó en una U.M.
-- distinta a la del producto. No se corrigen automáticamente (habría que
-- recomputar pro_stock hacia atrás); se listan para revisarlas.
-- ------------------------------------------------------------
DO $$
DECLARE
    v_fila RECORD;
    v_n INTEGER := 0;
BEGIN
    FOR v_fila IN
        SELECT
            d.id,
            d.numero,
            p.nombre AS producto,
            uml.nombre AS unidad_linea,
            ump.nombre AS unidad_producto,
            dd.cantidad
        FROM doc_salida_detalle dd
        JOIN doc_salida d ON d.id = dd.id_doc_salida
        JOIN pro_producto p ON p.id = dd.id_producto
        JOIN gen_lista_opciones uml ON uml.id = dd.id_unidad_medida
        JOIN gen_lista_opciones ump ON ump.id = p.id_unidad_medida
        WHERE dd.estado = 1
          AND d.estado = 1
          AND dd.id_movimiento IS NOT NULL
          AND dd.id_unidad_medida <> p.id_unidad_medida
          AND UPPER(TRIM(uml.nombre)) <> UPPER(TRIM(ump.nombre))
        ORDER BY d.id
    LOOP
        v_n := v_n + 1;
        RAISE NOTICE 'Orden #% (%): % salió con % % y su stock vive en %',
            v_fila.id, COALESCE(v_fila.numero, 's/n'), v_fila.producto,
            v_fila.cantidad, v_fila.unidad_linea, v_fila.unidad_producto;
    END LOOP;

    IF v_n = 0 THEN
        RAISE NOTICE 'Sin órdenes generadas con U.M. de línea distinta a la del producto.';
    ELSE
        RAISE NOTICE 'Órdenes a revisar con operaciones: %. Anular y regenerar es el camino seguro.', v_n;
    END IF;
END
$$;
