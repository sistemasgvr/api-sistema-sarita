-- ============================================================
-- Migracion: Wave 4 hardening
-- Fecha: 2026-09-11
--
-- 1) doc_generar_salida: EstadoCicloSalida GENERADA antes del kardex; soft-error si falta catalogo. Conserva U.M. conversion + prevuelo.
-- 2) doc_convertir_a_gre / doc_obtener_siguiente_numero: pg_advisory_xact_lock.
-- 3) Baja cliente (solicitar/aprobar/eliminar-logico): bloquea ven_garantia.monto_saldo > 0 activa.
-- 4) gen_actualizar_vehiculo: p_clear_id_cliente para flota propia.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_w4_hardening.sql
-- ============================================================


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
--
-- Actualizada por database_sql/migraciones/20260911_w4_hardening.sql:
--   · EstadoCicloSalida GENERADA se resuelve ANTES del loop de kardex; si falta
--     el catálogo se devuelve soft-error sin mover stock.
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

    -- EstadoCicloSalida GENERADA: resolver ANTES de cualquier movimiento de stock.
    -- Si falta el catálogo y se moviera el kardex primero, la orden quedaría con
    -- inventario tocado y el ciclo aún en BORRADOR (mismo patrón que doc_anular_salida).
    SELECT lo.id INTO v_id_generada
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoCicloSalida' AND lo.nombre = 'GENERADA' AND lo.estado = 1;

    IF v_id_generada IS NULL THEN
        RETURN json_build_object(
            'error', 'Falta el estado GENERADA en el catálogo EstadoCicloSalida',
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

    UPDATE doc_salida
    SET id_estado_ciclo = v_id_generada,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_convertir_a_gre.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_convertir_a_gre
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_convertir_a_gre(p_id integer, p_id_tipo_guia_remision integer, p_serie character varying, p_id_motivo_traslado integer, p_id_modalidad_traslado integer, p_id_transportista integer, p_id_chofer integer, p_id_vehiculo integer, p_id_unidad_medida integer, p_peso_bruto numeric, p_numero_bultos integer, p_direccion_origen character varying, p_id_distrito_origen integer, p_direccion_llegada character varying, p_id_distrito_llegada integer, p_fecha_traslado date, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_convertir_a_gre(p_id integer, p_id_tipo_guia_remision integer, p_serie character varying, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_fecha_traslado date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_serie VARCHAR;
    v_siguiente INTEGER;
    v_numero VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'BORRADOR' THEN
        RETURN json_build_object(
            'error', 'Genera el documento antes de convertirlo en guía de remisión',
            'registro', NULL
        );
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object('error', 'El documento ya fue emitido a SUNAT', 'registro', NULL);
    END IF;

    v_serie := UPPER(TRIM(COALESCE(p_serie, v_doc.serie, '')));
    IF v_serie = '' THEN
        RETURN json_build_object('error', 'La serie de la guía de remisión es obligatoria', 'registro', NULL);
    END IF;

    IF char_length(v_serie) <> 4 THEN
        RETURN json_build_object('error', 'La serie electrónica debe tener 4 caracteres (ej. T001, V001)', 'registro', NULL);
    END IF;

    IF p_id_tipo_guia_remision IS NULL AND v_doc.id_tipo_guia_remision IS NULL THEN
        RETURN json_build_object('error', 'El tipo de guía de remisión es obligatorio', 'registro', NULL);
    END IF;

    -- El correlativo SUNAT se reserva ahora; si ya tenía uno, se conserva.
    IF v_doc.numero_sunat IS NOT NULL AND v_doc.serie = v_serie THEN
        v_numero := v_doc.numero_sunat;
    ELSE
        -- Candado por serie dentro de la TX: evita dos GRE concurrentes con el mismo correlativo.
        PERFORM pg_advisory_xact_lock(872017, hashtext(v_serie));

        SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(numero_sunat, '\D', '', 'g'), '')::INTEGER), 0) + 1
        INTO v_siguiente
        FROM doc_salida
        WHERE serie = v_serie;

        v_numero := LPAD(v_siguiente::TEXT, 8, '0');
    END IF;

    UPDATE doc_salida
    SET id_tipo_guia_remision = COALESCE(p_id_tipo_guia_remision, id_tipo_guia_remision),
        serie = v_serie,
        numero_sunat = v_numero,
        id_motivo_traslado = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_modalidad_traslado = COALESCE(p_id_modalidad_traslado, id_modalidad_traslado),
        id_transportista = COALESCE(p_id_transportista, id_transportista),
        id_chofer = COALESCE(p_id_chofer, id_chofer),
        id_vehiculo = COALESCE(p_id_vehiculo, id_vehiculo),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso_bruto = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos = COALESCE(p_numero_bultos, numero_bultos),
        direccion_origen = COALESCE(p_direccion_origen, direccion_origen),
        id_distrito_origen = COALESCE(p_id_distrito_origen, id_distrito_origen),
        direccion_llegada = COALESCE(p_direccion_llegada, direccion_llegada),
        id_distrito_llegada = COALESCE(p_id_distrito_llegada, id_distrito_llegada),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado, fecha),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    -- Si la orden nace de una venta, esa venta es su documento de referencia SUNAT.
    IF v_doc.id_venta IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM doc_salida_referencia WHERE id_doc_salida = p_id AND id_comprobante = v_doc.id_venta AND estado = 1
    ) THEN
        INSERT INTO doc_salida_referencia (
            id_doc_salida, id_tipo_comprobante, id_comprobante, serie, numero, fecha,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT p_id, vc.id_tipo_comprobante, vc.id, vc.serie, vc.numero, vc.fecha,
               p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM ven_comprobante vc WHERE vc.id = v_doc.id_venta;
    END IF;

    RETURN doc_obtener_salida(p_id);
END;
$function$;


-- ============================================================
-- database_sql/funciones/documentos-salida/doc_obtener_siguiente_numero.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_obtener_siguiente_numero
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
DROP FUNCTION IF EXISTS doc_obtener_siguiente_numero(p_id_sucursal integer, p_fecha date);

CREATE OR REPLACE FUNCTION doc_obtener_siguiente_numero(p_id_sucursal integer, p_fecha date DEFAULT NULL::date)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio INTEGER;
    v_prefijo VARCHAR;
    v_siguiente INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_sucursal IS NULL THEN
        RAISE EXCEPTION 'La sucursal es obligatoria para numerar el documento de salida';
    END IF;

    v_anio := EXTRACT(YEAR FROM COALESCE(p_fecha, CURRENT_DATE))::INTEGER;
    v_prefijo := 'OS-' || LPAD(p_id_sucursal::TEXT, 2, '0') || '-' || v_anio::TEXT || '-';

    -- Candado por prefijo dentro de la TX: evita dos creates concurrentes con el mismo correlativo.
    PERFORM pg_advisory_xact_lock(872016, hashtext(v_prefijo));

    -- Se toma el mayor correlativo ya usado con ese prefijo (incluye anulados, para no
    -- reutilizar números) y se avanza uno.
    SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(RIGHT(d.numero, 6), '\D', '', 'g'), '')::INTEGER), 0) + 1
    INTO v_siguiente
    FROM doc_salida d
    WHERE d.numero LIKE v_prefijo || '%';

    RETURN v_prefijo || LPAD(v_siguiente::TEXT, 6, '0');
END;
$function$;


-- ============================================================
-- database_sql/funciones/bajas-cliente/cli_solicitar_baja_cliente.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_solicitar_baja_cliente
-- Overloads: 1
-- Updated: 2026-09-09 — bloquea si CxC con saldo > 0 o préstamos/alquileres ACTIVO
-- Updated: 2026-09-11 — bloquea si ven_garantia.monto_saldo > 0 activa
DROP FUNCTION IF EXISTS cli_solicitar_baja_cliente(p_id_cliente integer, p_id_motivo_baja integer, p_motivo_detalle character varying, p_id_usuario_auditoria integer, p_id_tipo_solicitud integer);

CREATE OR REPLACE FUNCTION cli_solicitar_baja_cliente(p_id_cliente integer, p_id_motivo_baja integer DEFAULT NULL::integer, p_motivo_detalle character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_tipo_solicitud integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_baja INTEGER;
    v_estado_cliente INT;
    v_id_pendiente INTEGER;
    v_id_tipo INTEGER;
    v_id_tipo_cobrar INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado_cliente FROM cli_clientes WHERE id = p_id_cliente;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente no existe');
    END IF;

    IF v_estado_cliente = 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente ya está inactivo');
    END IF;

    -- Bloqueo: cuentas por cobrar con saldo pendiente
    SELECT glo.id INTO v_id_tipo_cobrar
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
    LIMIT 1;

    IF v_id_tipo_cobrar IS NOT NULL AND EXISTS (
        SELECT 1
        FROM fin_cuenta fc
        WHERE fc.id_tercero = p_id_cliente
          AND fc.id_tipo_cuenta = v_id_tipo_cobrar
          AND fc.estado = 1
          AND COALESCE(fc.monto_saldo, 0) > 0
    ) THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede solicitar la baja: el cliente tiene cuentas por cobrar con saldo pendiente'
        );
    END IF;

    -- Bloqueo: préstamos activos
    IF EXISTS (
        SELECT 1
        FROM bal_prestamo p
        JOIN gen_lista_opciones ep ON ep.id = p.id_estado AND ep.nombre = 'ACTIVO'
        WHERE p.id_cliente = p_id_cliente
          AND p.estado = 1
    ) THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede solicitar la baja: el cliente tiene préstamos activos'
        );
    END IF;

    -- Bloqueo: alquileres activos
    IF EXISTS (
        SELECT 1
        FROM bal_alquiler a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado AND ea.nombre = 'ACTIVO'
        WHERE a.id_cliente = p_id_cliente
          AND a.estado = 1
    ) THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede solicitar la baja: el cliente tiene alquileres activos'
        );
    END IF;

    -- Bloqueo: garantías con saldo pendiente
    IF EXISTS (
        SELECT 1
        FROM ven_garantia g
        WHERE g.id_cliente = p_id_cliente
          AND g.estado = 1
          AND COALESCE(g.monto_saldo, 0) > 0
    ) THEN
        RETURN json_build_object(
            'registro', NULL,
            'error', 'No se puede solicitar la baja: el cliente tiene garantías con saldo pendiente'
        );
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'PENDIENTE';

    v_id_tipo := COALESCE(p_id_tipo_solicitud, (SELECT lo.id
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'TipoSolicitud' AND lo.nombre = 'BAJA'));

    IF EXISTS (
        SELECT 1 FROM cli_baja_cliente
        WHERE id_cliente = p_id_cliente
          AND estado = 1
          AND id_estado_aprobacion = v_id_pendiente
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'El cliente ya tiene una solicitud de baja pendiente');
    END IF;

    INSERT INTO cli_baja_cliente (
        id_cliente, id_motivo_baja, fecha_baja,
        id_usuario_solicita, id_estado_aprobacion,
        id_tipo_solicitud, motivo_detalle,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_cliente, p_id_motivo_baja, CURRENT_DATE,
        p_id_usuario_auditoria, v_id_pendiente,
        v_id_tipo, NULLIF(TRIM(p_motivo_detalle), ''),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_baja;

    RETURN cli_obtener_baja_cliente(v_id_baja);
END;
$function$;


-- ============================================================
-- database_sql/funciones/bajas-cliente/cli_aprobar_baja_cliente.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_aprobar_baja_cliente
-- Overloads: 1
-- Updated: 2026-09-09 — bloquea deudas en BAJA; cascada soft-delete/restaurar relacionados
-- Updated: 2026-09-11 — bloquea si ven_garantia.monto_saldo > 0 activa
DROP FUNCTION IF EXISTS cli_aprobar_baja_cliente(p_id_baja integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_aprobar_baja_cliente(p_id_baja integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_pendiente INTEGER;
    v_id_aprobada INTEGER;
    v_id_estado_actual INTEGER;
    v_id_cliente INTEGER;
    v_tipo_solicitud VARCHAR;
    v_id_tipo_cobrar INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_usuario_auditoria IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Debe indicar el administrador autorizador');
    END IF;

    -- Rol Administrador + permiso bajas_cliente.aprobar (o auth.todo). Usa el usuario de sesión (JWT).
    IF NOT auth_usuario_es_admin_con_permiso(p_id_usuario_auditoria, 'bajas_cliente.aprobar') THEN
        RETURN json_build_object(
            'registro',
            NULL,
            'error',
            'La solicitud debe ser autorizada por un administrador con permiso de aprobar bajas de cliente'
        );
    END IF;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'PENDIENTE';

    SELECT lo.id INTO v_id_aprobada
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoAprobacion' AND lo.nombre = 'APROBADA';

    SELECT
        bc.id_estado_aprobacion,
        bc.id_cliente,
        ts.nombre
    INTO
        v_id_estado_actual,
        v_id_cliente,
        v_tipo_solicitud
    FROM cli_baja_cliente bc
    LEFT JOIN gen_lista_opciones ts ON ts.id = bc.id_tipo_solicitud
    WHERE bc.id = p_id_baja AND bc.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL, 'error', 'La solicitud no existe');
    END IF;

    IF v_id_estado_actual <> v_id_pendiente THEN
        RETURN json_build_object('registro', NULL, 'error', 'La solicitud ya fue procesada');
    END IF;

    -- En BAJA: bloquear si hay deudas / préstamos / alquileres activos
    IF UPPER(COALESCE(v_tipo_solicitud, 'BAJA')) <> 'REACTIVACION' THEN
        SELECT glo.id INTO v_id_tipo_cobrar
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
        LIMIT 1;

        IF v_id_tipo_cobrar IS NOT NULL AND EXISTS (
            SELECT 1
            FROM fin_cuenta fc
            WHERE fc.id_tercero = v_id_cliente
              AND fc.id_tipo_cuenta = v_id_tipo_cobrar
              AND fc.estado = 1
              AND COALESCE(fc.monto_saldo, 0) > 0
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene cuentas por cobrar con saldo pendiente'
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo p
            JOIN gen_lista_opciones ep ON ep.id = p.id_estado AND ep.nombre = 'ACTIVO'
            WHERE p.id_cliente = v_id_cliente
              AND p.estado = 1
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene préstamos activos'
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler a
            JOIN gen_lista_opciones ea ON ea.id = a.id_estado AND ea.nombre = 'ACTIVO'
            WHERE a.id_cliente = v_id_cliente
              AND a.estado = 1
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene alquileres activos'
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM ven_garantia g
            WHERE g.id_cliente = v_id_cliente
              AND g.estado = 1
              AND COALESCE(g.monto_saldo, 0) > 0
        ) THEN
            RETURN json_build_object(
                'registro', NULL,
                'error', 'No se puede aprobar la baja: el cliente tiene garantías con saldo pendiente'
            );
        END IF;
    END IF;

    UPDATE cli_baja_cliente
    SET
        id_estado_aprobacion = v_id_aprobada,
        id_usuario_autoriza = p_id_usuario_auditoria,
        fecha_autorizacion = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_baja;

    IF UPPER(COALESCE(v_tipo_solicitud, 'BAJA')) = 'REACTIVACION' THEN
        UPDATE cli_clientes
        SET
            estado = 1,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cliente;

        UPDATE cli_direcciones
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE gen_chofer
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE gen_vehiculo
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE gen_cuenta_bancaria
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;

        UPDATE cli_contacto
        SET estado = 1,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 0;
    ELSE
        UPDATE cli_clientes
        SET
            estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cliente;

        UPDATE cli_direcciones
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE gen_chofer
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE gen_vehiculo
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE gen_cuenta_bancaria
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;

        UPDATE cli_contacto
        SET estado = 0,
            id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
            fecha_modificacion = NOW()
        WHERE id_cliente = v_id_cliente AND estado = 1;
    END IF;

    RETURN cli_obtener_baja_cliente(p_id_baja);
END;
$function$;


-- ============================================================
-- database_sql/funciones/clientes/cli_eliminar_logico_cliente.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_eliminar_logico_cliente
-- Overloads: 1
-- Updated: 2026-09-09 — bloquea si CxC con saldo > 0 o préstamos/alquileres ACTIVO
-- Updated: 2026-09-11 — bloquea si ven_garantia.monto_saldo > 0 activa
DROP FUNCTION IF EXISTS cli_eliminar_logico_cliente(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION cli_eliminar_logico_cliente(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado INT;
    v_id_tipo_cobrar INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT estado INTO v_estado FROM cli_clientes WHERE id = p_id;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id
        );
    END IF;

    IF v_estado = 0 THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id
        );
    END IF;

    SELECT glo.id INTO v_id_tipo_cobrar
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera' AND glo.nombre = 'COBRAR'
    LIMIT 1;

    IF v_id_tipo_cobrar IS NOT NULL AND EXISTS (
        SELECT 1
        FROM fin_cuenta fc
        WHERE fc.id_tercero = p_id
          AND fc.id_tipo_cuenta = v_id_tipo_cobrar
          AND fc.estado = 1
          AND COALESCE(fc.monto_saldo, 0) > 0
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene cuentas por cobrar con saldo pendiente'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_prestamo p
        JOIN gen_lista_opciones ep ON ep.id = p.id_estado AND ep.nombre = 'ACTIVO'
        WHERE p.id_cliente = p_id
          AND p.estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene préstamos activos'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM bal_alquiler a
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado AND ea.nombre = 'ACTIVO'
        WHERE a.id_cliente = p_id
          AND a.estado = 1
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene alquileres activos'
        );
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ven_garantia g
        WHERE g.id_cliente = p_id
          AND g.estado = 1
          AND COALESCE(g.monto_saldo, 0) > 0
    ) THEN
        RETURN json_build_object(
            'eliminado', false,
            'id', p_id,
            'error', 'No se puede desactivar el cliente: tiene garantías con saldo pendiente'
        );
    END IF;

    UPDATE cli_clientes
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id = p_id;

    UPDATE cli_direcciones
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_chofer
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_vehiculo
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE gen_cuenta_bancaria
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    UPDATE cli_contacto
    SET estado = 0,
        id_usuario_modificacion = COALESCE(p_id_usuario_auditoria, id_usuario_modificacion),
        fecha_modificacion = NOW()
    WHERE id_cliente = p_id AND estado = 1;

    RETURN json_build_object(
        'eliminado', true,
        'id', p_id
    );
END;
$function$;


-- ============================================================
-- database_sql/funciones/vehiculos/gen_actualizar_vehiculo.sql
-- ============================================================
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_vehiculo
-- Overloads: 1
-- Updated: 2026-09-11 — p_clear_id_cliente permite flota propia (id_cliente NULL)
DROP FUNCTION IF EXISTS gen_actualizar_vehiculo(p_id integer, p_id_cliente integer, p_id_tipo_vehiculo integer, p_placa character varying, p_placa2 character varying, p_marca character varying, p_marca2 character varying, p_modelo character varying, p_anio integer, p_color character varying, p_certificado_inscripcion character varying, p_certificado2 character varying, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS gen_actualizar_vehiculo(p_id integer, p_id_cliente integer, p_id_tipo_vehiculo integer, p_placa character varying, p_placa2 character varying, p_marca character varying, p_marca2 character varying, p_modelo character varying, p_anio integer, p_color character varying, p_certificado_inscripcion character varying, p_certificado2 character varying, p_clear_id_cliente boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_vehiculo(p_id integer, p_id_cliente integer DEFAULT NULL::integer, p_id_tipo_vehiculo integer DEFAULT NULL::integer, p_placa character varying DEFAULT NULL::character varying, p_placa2 character varying DEFAULT NULL::character varying, p_marca character varying DEFAULT NULL::character varying, p_marca2 character varying DEFAULT NULL::character varying, p_modelo character varying DEFAULT NULL::character varying, p_anio integer DEFAULT NULL::integer, p_color character varying DEFAULT NULL::character varying, p_certificado_inscripcion character varying DEFAULT NULL::character varying, p_certificado2 character varying DEFAULT NULL::character varying, p_clear_id_cliente boolean DEFAULT false, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_placa IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_vehiculo
        WHERE placa = p_placa AND estado = 1 AND id <> p_id
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'Ya existe un vehículo activo con esa placa');
    END IF;

    UPDATE gen_vehiculo
    SET
        -- Flota propia: el FE envía idCliente null + p_clear_id_cliente; sin el flag,
        -- COALESCE(null, id_cliente) dejaría el dueño anterior.
        id_cliente = CASE
            WHEN COALESCE(p_clear_id_cliente, FALSE) THEN NULL
            ELSE COALESCE(p_id_cliente, id_cliente)
        END,
        id_tipo_vehiculo = COALESCE(p_id_tipo_vehiculo, id_tipo_vehiculo),
        placa = COALESCE(p_placa, placa),
        placa2 = COALESCE(p_placa2, placa2),
        marca = COALESCE(p_marca, marca),
        marca2 = COALESCE(p_marca2, marca2),
        modelo = COALESCE(p_modelo, modelo),
        anio = COALESCE(p_anio, anio),
        color = COALESCE(p_color, color),
        certificado_inscripcion = COALESCE(p_certificado_inscripcion, certificado_inscripcion),
        certificado2 = COALESCE(p_certificado2, certificado2),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_vehiculo(p_id);
END;
$function$;
