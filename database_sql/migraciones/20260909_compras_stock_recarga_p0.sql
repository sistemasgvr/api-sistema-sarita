-- ============================================================
-- Migración: P0/P1 compras / stock / recarga
-- Fecha: 2026-09-09
--
-- 1) com_crear_compra(+detalle): honor afecta_stock del payload; gas de
--    compra vinculada a planta NO ingresa (solo bal_finalizar_recarga_planta).
-- 2) inv_revertir_por_documento: estricto como inv_eliminar_movimiento.
-- 3) com_registrar_balones_compra: id_documento_detalle = id_balon.
-- 4) com_anular_compra / com_revertir_cilindros: ORDEN_SALIDA, baja balones,
--    validar todos los ingresos (incl. gas planta).
-- 5) inv_registrar_movimiento: reactivar pro_stock estado=0.
-- 6) gen_eliminar_almacen: rechazar si hay stock activo > 0.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_compras_stock_recarga_p0.sql
-- ============================================================


-- ===== funciones\compras\com_crear_compra.sql =====

-- p_id_doc_salida: antes se llamaba p_id_recarga_planta. Desde la Fase 2 la
-- orden de recarga vive en doc_salida, asÃ­ que el nombre viejo apuntaba a una
-- tabla que ya no existe. Misma posiciÃ³n en la firma: las llamadas posicionales
-- no cambian.
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_crear_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_recarga_planta integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);

CREATE OR REPLACE FUNCTION com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer DEFAULT NULL::integer, p_id_doc_salida integer DEFAULT NULL::integer, p_id_tipo_registro integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT false, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_registrar_retorno_balones boolean DEFAULT false, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_id_guia_retorno integer DEFAULT NULL::integer, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_compra           INTEGER;
    v_link_planta         JSON;
    v_id_detalle          INTEGER;
    v_item                INTEGER := 0;
    v_linea               JSONB;
    v_id_producto         INTEGER;
    v_id_almacen_compra   INTEGER;
    v_id_almacen_linea    INTEGER;
    v_cantidad            NUMERIC(12,4);
    v_precio_unitario     NUMERIC(12,6);
    v_afecta_stock        BOOLEAN;
    v_es_gas              BOOLEAN;
    v_importe             NUMERIC(12,4);
    v_total_bruto         NUMERIC(12,4) := 0;
    v_tasa_igv            NUMERIC(6,4) := 0.18;
    v_base_imponible      NUMERIC(12,4);
    v_igv_calculado       NUMERIC(12,4);
    v_id_tipo_ingreso     INTEGER;
    v_id_tipo_doc_ref     INTEGER;
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
    v_ref_estado          INTEGER;
    v_ref_serie           VARCHAR;
    v_ref_numero          VARCHAR;
    v_glosa_final         VARCHAR;
    v_recarga_id_comprobante INTEGER;
    v_recarga_estado_nombre  VARCHAR;
    v_registrar_retorno   BOOLEAN;
    v_fecha_llegada       DATE;
    v_lote                VARCHAR;
    v_fecha_venc_lote     DATE;
    v_fecha_ph            DATE;
BEGIN
    SET TIME ZONE 'America/Lima';
 
    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha de la compra es obligatoria', 'registro', NULL);
    END IF;
 
    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;
 
    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacÃ©n (por defecto) indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;
 
    -- El detalle de productos es opcional: se puede registrar la cabecera
    -- (por ejemplo, ligada a una orden de recarga en planta externa) y
    -- agregar las lÃ­neas despuÃ©s con com_crear_compra_detalle.
    IF p_detalles IS NOT NULL AND jsonb_typeof(p_detalles) IS DISTINCT FROM 'array' THEN
        RETURN json_build_object('error', 'El detalle de productos debe ser un arreglo JSON', 'registro', NULL);
    END IF;

    v_glosa_final := p_glosa;
    IF p_id_comprobante_referencia IS NOT NULL THEN
        SELECT estado, serie, numero INTO v_ref_estado, v_ref_serie, v_ref_numero
        FROM com_comprobante_compra
        WHERE id = p_id_comprobante_referencia;
 
        IF v_ref_estado IS NULL THEN
            RETURN json_build_object('error', 'La compra de referencia indicada no existe', 'registro', NULL);
        END IF;
 
        IF v_ref_estado <> 0 THEN
            RETURN json_build_object(
                'error', 'La compra de referencia debe estar anulada antes de registrar la correcciÃ³n (serie ' || v_ref_serie || '-' || v_ref_numero || ' sigue activa)',
                'registro', NULL
            );
        END IF;
 
        IF v_glosa_final IS NULL THEN
            v_glosa_final := 'Corrige compra anulada ' || v_ref_serie || '-' || v_ref_numero;
        END IF;
    END IF;

    -- La orden debe existir, estar activa, y NO estar ya cerrada/facturada
    -- (id_comprobante_compra ya seteado por bal_finalizar_recarga_planta en
    -- una compra anterior) â€” si no, se estarÃ­a facturando la misma orden
    -- dos veces.
    IF p_id_doc_salida IS NOT NULL THEN
        SELECT rp.id_comprobante_compra, est.nombre
        INTO v_recarga_id_comprobante, v_recarga_estado_nombre
        FROM doc_salida rp
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La orden de recarga en planta externa indicada no existe o estÃ¡ inactiva', 'registro', NULL);
        END IF;

        IF v_recarga_id_comprobante IS NOT NULL OR v_recarga_estado_nombre = 'CERRADO' THEN
            RETURN json_build_object(
                'error', 'La orden de recarga en planta externa indicada ya estÃ¡ cerrada/facturada y no se puede volver a vincular',
                'registro', NULL
            );
        END IF;
    END IF;

    -- IDs de listas resueltos una sola vez (no dentro del loop). Solo hace
    -- falta que estÃ©n configuradas si de verdad hay lÃ­neas que procesar.
    IF p_detalles IS NOT NULL AND jsonb_array_length(p_detalles) > 0 THEN
        SELECT glo.id INTO v_id_tipo_ingreso
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoMovInv' AND glo.nombre = 'INGRESO' AND glo.estado = 1;

        SELECT glo.id INTO v_id_tipo_doc_ref
        FROM gen_lista_opciones glo
        JOIN gen_lista gl ON gl.id = glo.id_lista
        WHERE gl.nombre = 'TipoDocumentoRef' AND glo.nombre = 'COMPRA' AND glo.estado = 1;

        IF v_id_tipo_ingreso IS NULL OR v_id_tipo_doc_ref IS NULL THEN
            RAISE EXCEPTION 'Faltan configurar las opciones INGRESO (TipoMovInv) o COMPRA (TipoDocumentoRef) en gen_lista_opciones';
        END IF;
    END IF;

    -- Cabecera (totales en 0; se recalculan al final con lo realmente insertado)
    INSERT INTO com_comprobante_compra (
        id_tipo_comprobante, serie, numero, fecha, id_proveedor,
        id_tipo_registro, id_categoria_gasto, id_sucursal, id_almacen,
        id_moneda, id_condicion_pago, sub_total, igv, total_importe,
        declarar_sunat, glosa, id_comprobante_referencia, id_doc_salida,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, p_serie, p_numero, p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia, p_id_doc_salida,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_compra;
 
    FOR v_linea IN SELECT * FROM jsonb_array_elements(COALESCE(p_detalles, '[]'::JSONB))
    LOOP
        v_item := v_item + 1;
 
        v_id_producto := (v_linea->>'id_producto')::INTEGER;
        v_cantidad := (v_linea->>'cantidad')::NUMERIC;
        v_precio_unitario := COALESCE((v_linea->>'precio_unitario')::NUMERIC, 0);
        v_id_almacen_linea := COALESCE((v_linea->>'id_almacen')::INTEGER, p_id_almacen);
 
        IF v_id_producto IS NULL THEN
            RAISE EXCEPTION 'La lÃ­nea % no tiene id_producto', v_item;
        END IF;
 
        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad de la lÃ­nea % debe ser mayor a cero', v_item;
        END IF;
 
        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
            RAISE EXCEPTION 'El almacÃ©n id=% de la lÃ­nea % no existe o estÃ¡ inactivo', v_id_almacen_linea, v_item;
        END IF;
 
        SELECT afecta_stock, COALESCE(es_gas, FALSE)
        INTO v_afecta_stock, v_es_gas
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;
 
        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la lÃ­nea % no existe o estÃ¡ inactivo', v_id_producto, v_item;
        END IF;

        -- Payload puede forzar afecta_stock (p.ej. costo de recarga planta = false).
        IF v_linea ? 'afecta_stock' AND jsonb_typeof(v_linea->'afecta_stock') <> 'null' THEN
            v_afecta_stock := COALESCE((v_linea->>'afecta_stock')::BOOLEAN, v_afecta_stock);
        END IF;

        -- Compra vinculada a orden de planta: el gas lo ingresa solo
        -- bal_finalizar_recarga_planta al marcar retorno. La lÃ­nea es costo.
        IF p_id_doc_salida IS NOT NULL AND v_es_gas THEN
            v_afecta_stock := FALSE;
        END IF;
 
        v_importe := v_cantidad * v_precio_unitario;
        v_total_bruto := v_total_bruto + v_importe;
 
        v_descripcion_linea := v_linea->>'descripcion';
        IF v_descripcion_linea IS NULL THEN
            SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = v_id_producto;
        END IF;
 
        INSERT INTO com_comprobante_compra_detalle (
            id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
            id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
            afecta_stock, id_usuario_creacion, id_usuario_modificacion
        ) VALUES (
            v_id_compra, v_item,
            (v_linea->>'id_clasificacion_gasto')::INTEGER,
            v_id_producto,
            v_descripcion_linea,
            (v_linea->>'id_unidad_medida')::INTEGER,
            v_id_almacen_linea,
            v_cantidad, v_precio_unitario, v_importe,
            v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id_detalle;
 
        IF v_afecta_stock THEN
            v_result_movimiento := inv_registrar_movimiento(
                p_naturaleza                => 'PRODUCTO',
                p_codigo_tipo_movimiento    => 'INGRESO',
                p_fecha                     => p_fecha,
                p_id_producto               => v_id_producto,
                p_id_balon                  => NULL,
                p_cantidad                  => v_cantidad,
                p_id_almacen_origen         => v_id_almacen_linea,
                p_id_almacen_destino        => NULL,
                p_id_cliente                => NULL,
                p_codigo_tipo_documento_origen => 'COMPRA',
                p_id_documento_origen       => v_id_compra,
                p_id_documento_detalle      => v_id_detalle,
                p_glosa                     => 'Ingreso por compra ' || p_serie || '-' || p_numero,
                p_id_usuario_auditoria      => p_id_usuario_auditoria
            );
 
            IF (v_result_movimiento->>'error') IS NOT NULL THEN
                RAISE EXCEPTION '%', v_result_movimiento->>'error';
            END IF;
        END IF;
 
    END LOOP;
 
    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = v_id_compra
              AND afecta_stock = TRUE
              AND estado = 1
        )
    WHERE id = v_id_compra;

    -- VÃ­nculo opcional con orden de recarga planta externa (factura de costo).
    -- El gas NO ingresa por lÃ­neas de compra: el retorno fÃ­sico + INGRESO de gas
    -- lo hace solo bal_finalizar_recarga_planta.
    v_id_almacen_compra := p_id_almacen;

    IF p_id_doc_salida IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM doc_salida WHERE id = p_id_doc_salida AND estado = 1
        ) THEN
            RAISE EXCEPTION 'Orden de recarga planta no encontrada o inactiva';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM doc_salida
            WHERE id = p_id_doc_salida
              AND estado = 1
              AND id_proveedor IS NOT NULL
              AND p_id_proveedor IS NOT NULL
              AND id_proveedor <> p_id_proveedor
        ) THEN
            RAISE EXCEPTION 'El proveedor de la compra no coincide con el de la orden de recarga';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM doc_salida
            WHERE id = p_id_doc_salida
              AND estado = 1
              AND id_comprobante_compra IS NOT NULL
              AND id_comprobante_compra <> v_id_compra
        ) THEN
            RAISE EXCEPTION 'La orden de recarga ya tiene otra compra vinculada';
        END IF;

        -- Retorno fÃ­sico: checkbox o fecha de llegada enviada desde Compras.
        -- Protocolo (lote/venc/P.H.) puede venir en params o ya estar en la orden.
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE)
            OR p_fecha_llegada_almacen IS NOT NULL;

        SELECT
            COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(rp.lote), '')),
            COALESCE(p_fecha_vencimiento_lote, rp.fecha_vencimiento_lote),
            COALESCE(p_fecha_prueba_hidrostatica, rp.fecha_prueba_hidrostatica)
        INTO v_lote, v_fecha_venc_lote, v_fecha_ph
        FROM doc_salida rp
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1;

        IF v_registrar_retorno THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);

            IF v_lote IS NULL OR v_fecha_venc_lote IS NULL OR v_fecha_ph IS NULL THEN
                RAISE EXCEPTION
                    'Para registrar el retorno de cilindros indique lote, vencimiento y P.H. (o complÃ©telos en la orden de recarga).';
            END IF;
        ELSE
            v_fecha_llegada := NULL;
        END IF;

        -- bal_actualizar_recarga_planta desapareciÃ³ en la unificaciÃ³n a doc_salida
        -- (Fase 2) y esta llamada quedÃ³ apuntando al vacÃ­o: vincular una compra a
        -- una orden de planta reventaba con "function does not exist". Ahora se
        -- escribe directo sobre doc_salida, que es donde vive la orden.
        --
        -- Serie/nÃºmero de factura no se replican: quedan en la compra y las
        -- lecturas de la orden los resuelven por JOIN vÃ­a este FK.
        UPDATE doc_salida
        SET id_comprobante_compra   = v_id_compra,
            id_almacen              = COALESCE(p_id_almacen, id_almacen),
            serie_guia_ingreso      = COALESCE(p_serie_guia_ingreso, serie_guia_ingreso),
            numero_guia_ingreso     = COALESCE(p_numero_guia_ingreso, numero_guia_ingreso),
            fecha_llegada_almacen   = COALESCE(v_fecha_llegada, fecha_llegada_almacen),
            fecha_retorno           = COALESCE(v_fecha_llegada, fecha_retorno),
            lote                    = COALESCE(v_lote, lote),
            fecha_vencimiento_lote  = COALESCE(v_fecha_venc_lote, fecha_vencimiento_lote),
            fecha_prueba_hidrostatica = COALESCE(v_fecha_ph, fecha_prueba_hidrostatica),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion      = NOW()
        WHERE id = p_id_doc_salida AND estado = 1;

        -- El retorno fÃ­sico de los cilindros (custodia + entrada de gas) lo hace
        -- bal_finalizar_recarga_planta desde el documento de salida.
        IF v_registrar_retorno THEN
            v_link_planta := bal_finalizar_recarga_planta(
                p_id_doc_salida        => p_id_doc_salida,
                p_id_comprobante_compra    => v_id_compra,
                p_fecha_llegada_almacen    => v_fecha_llegada,
                p_id_almacen               => COALESCE(p_id_almacen, v_id_almacen_compra),
                p_id_proveedor             => p_id_proveedor,
                p_guardar_balones_almacen  => TRUE,
                p_lote                     => v_lote,
                p_fecha_vencimiento_lote   => v_fecha_venc_lote,
                p_fecha_prueba_hidrostatica => v_fecha_ph,
                p_id_usuario_auditoria     => p_id_usuario_auditoria
            );

            IF v_link_planta->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_link_planta->>'error';
            END IF;
        END IF;
    END IF;

    -- CrÃ©dito / cuotas: genera CxP vinculada a la compra segÃºn condiciÃ³n de pago.
    PERFORM com_generar_cxp_compra(
        v_id_compra,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    RETURN com_obtener_compra(v_id_compra);
END;
$function$;


-- ===== funciones\compras\com_crear_compra_detalle.sql =====

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_crear_compra_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS com_crear_compra_detalle(p_id_comprobante integer, p_id_producto integer, p_cantidad numeric, p_precio_unitario numeric, p_id_clasificacion_gasto integer, p_descripcion character varying, p_id_unidad_medida integer, p_id_almacen integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_crear_compra_detalle(p_id_comprobante integer, p_id_producto integer, p_cantidad numeric, p_precio_unitario numeric DEFAULT 0, p_id_clasificacion_gasto integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_id_unidad_medida integer DEFAULT NULL::integer, p_id_almacen integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_detalle          INTEGER;
    v_item                INTEGER;
    v_afecta_stock        BOOLEAN;
    v_es_gas              BOOLEAN;
    v_id_doc_salida       INTEGER;
    v_id_almacen_cabecera INTEGER;
    v_id_almacen_linea    INTEGER;
    v_fecha               DATE;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_importe             NUMERIC(12,4);
    v_result_movimiento   JSON;
    v_descripcion_linea   VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_cantidad IS NULL OR p_cantidad <= 0 THEN
        RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
    END IF;

    SELECT id_almacen, fecha, serie, numero, id_doc_salida
    INTO v_id_almacen_cabecera, v_fecha, v_serie, v_numero, v_id_doc_salida
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante AND estado = 1
    FOR UPDATE;

    IF v_id_almacen_cabecera IS NULL THEN
        RETURN json_build_object('error', 'La compra indicada no existe o estÃ¡ anulada', 'registro', NULL);
    END IF;

    SELECT afecta_stock, COALESCE(es_gas, FALSE)
    INTO v_afecta_stock, v_es_gas
    FROM pro_producto
    WHERE id = p_id_producto AND estado = 1;

    IF v_afecta_stock IS NULL THEN
        RETURN json_build_object('error', 'El producto indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    -- Compra de costo de planta: el gas lo ingresa bal_finalizar_recarga_planta.
    IF v_id_doc_salida IS NOT NULL AND v_es_gas THEN
        v_afecta_stock := FALSE;
    END IF;

    v_id_almacen_linea := COALESCE(p_id_almacen, v_id_almacen_cabecera);

    IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
        RETURN json_build_object('error', 'El almacÃ©n indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    SELECT COALESCE(MAX(item), 0) + 1 INTO v_item
    FROM com_comprobante_compra_detalle
    WHERE id_comprobante = p_id_comprobante;

    v_importe := p_cantidad * p_precio_unitario;

    v_descripcion_linea := p_descripcion;
    IF v_descripcion_linea IS NULL THEN
        SELECT nombre INTO v_descripcion_linea FROM pro_producto WHERE id = p_id_producto;
    END IF;

    INSERT INTO com_comprobante_compra_detalle (
        id_comprobante, item, id_clasificacion_gasto, id_producto, descripcion,
        id_unidad_medida, id_almacen, cantidad, precio_unitario, importe,
        afecta_stock, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_comprobante, v_item, p_id_clasificacion_gasto, p_id_producto, v_descripcion_linea,
        p_id_unidad_medida, v_id_almacen_linea, p_cantidad, p_precio_unitario, v_importe,
        v_afecta_stock, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_detalle;

    IF v_afecta_stock THEN
        v_result_movimiento := inv_registrar_movimiento(
            p_naturaleza                => 'PRODUCTO',
            p_codigo_tipo_movimiento    => 'INGRESO',
            p_fecha                     => v_fecha,
            p_id_producto               => p_id_producto,
            p_cantidad                  => p_cantidad,
            p_id_almacen_origen         => v_id_almacen_linea,
            p_codigo_tipo_documento_origen => 'COMPRA',
            p_id_documento_origen       => p_id_comprobante,
            p_id_documento_detalle      => v_id_detalle,
            p_glosa                     => 'Ingreso por compra ' || v_serie || '-' || v_numero,
            p_id_usuario_auditoria      => p_id_usuario_auditoria
        );

        IF (v_result_movimiento->>'error') IS NOT NULL THEN
            RAISE EXCEPTION '%', v_result_movimiento->>'error';
        END IF;
    END IF;

    UPDATE com_comprobante_compra
    SET afecta_inventario = EXISTS (
            SELECT 1
            FROM com_comprobante_compra_detalle
            WHERE id_comprobante = p_id_comprobante
              AND afecta_stock = TRUE
              AND estado = 1
        ),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    PERFORM com_recalcular_totales_compra(p_id_comprobante, p_id_usuario_auditoria);

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;


-- ===== funciones\compras\com_registrar_balones_compra.sql =====

-- Function: com_registrar_balones_compra
-- Fase 7 â€” compra de cilindros: los da de alta en el libro y mueve inventario.
--
-- Comprar un balÃ³n no es como comprar un producto: el cilindro tiene identidad
-- propia, asÃ­ que ademÃ¡s de la lÃ­nea de compra hay que crearlo en bal_balon y
-- registrar su ENTRADA_COMPRA en inv_movimiento. Un movimiento por cilindro,
-- no uno por lÃ­nea (apunte 4.b.iv).
--
-- Si el cilindro viene cargado, `cantidad_gas` registra ademÃ¡s la entrada del
-- gas como movimiento de PRODUCTO: comprar un balÃ³n lleno son dos hechos â€”
-- entra el envase y entra su contenidoâ€” y cada uno lleva su movimiento.
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
        RETURN json_build_object('error', 'La compra no existe o estÃ¡ anulada', 'registro', NULL);
    END IF;

    -- Un cilindro comprado entra como propio y disponible en el almacÃ©n de la compra.
    SELECT lo.id INTO v_id_propietario
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'EMPRESA' AND lo.estado = 1 LIMIT 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1 LIMIT 1;

    IF v_id_estado IS NULL THEN
        RETURN json_build_object('error', 'Falta el estado DISPONIBLE en el catÃ¡logo EstadoBalon', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_referencia
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'ReferenciaCilindro' AND lo.nombre = 'ALMACEN' AND lo.estado = 1 LIMIT 1;

    -- El gas entra al stock cuando los cilindros ya llegaron. Si la compra cuelga
    -- de una orden a planta cuyo retorno no se marcÃ³, el gas todavÃ­a estÃ¡ en la
    -- planta y sumarlo inflarÃ­a el inventario. Se valida ANTES del bucle: si se
    -- comprobara por lÃ­nea, los cilindros anteriores ya estarÃ­an dados de alta.
    IF NOT v_compra.retorno_marcado
       AND EXISTS (
           SELECT 1 FROM jsonb_array_elements(p_balones) AS a(x)
           WHERE COALESCE((x->>'cantidad_gas')::NUMERIC, 0) > 0
       )
    THEN
        RETURN json_build_object(
            'error', 'Los cilindros aÃºn no figuran como retornados: marca el retorno en la orden de salida (o desde la compra) antes de ingresar el gas.',
            'registro', NULL
        );
    END IF;

    FOR v_linea IN SELECT * FROM jsonb_array_elements(p_balones)
    LOOP
        v_codigo := NULLIF(TRIM(v_linea->>'codigo_balon'), '');

        IF v_codigo IS NULL THEN
            RETURN json_build_object('error', 'Cada cilindro comprado necesita su cÃ³digo', 'registro', NULL);
        END IF;

        IF EXISTS (SELECT 1 FROM bal_balon WHERE UPPER(TRIM(codigo_balon)) = UPPER(v_codigo) AND estado = 1) THEN
            RETURN json_build_object(
                'error', format('El cilindro %s ya existe en el libro', v_codigo),
                'registro', NULL
            );
        END IF;

        -- El gas no se elige a mano: lo define el tipo de balÃ³n. Un cilindro de
        -- oxÃ­geno medicinal no puede entrar con otro gas por un descuido al tipear.
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

        -- A partir de acÃ¡ el cilindro ya existe en el libro: si el movimiento
        -- falla se levanta excepciÃ³n para que la transacciÃ³n entera se deshaga
        -- y no quede un balÃ³n dado de alta sin su entrada de inventario.
        -- id_documento_detalle = id_balon: cada cilindro es un hecho distinto para
        -- la idempotencia de inv_registrar_movimiento (sin esto, el 2.Âº gas del
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

        -- Gas del cilindro comprado: entra al stock del producto por la misma vÃ­a
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


-- ===== funciones\compras\com_anular_compra.sql =====

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_anular_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
DROP FUNCTION IF EXISTS com_anular_compra(p_id_comprobante integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_anular_compra(p_id_comprobante integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_detalle             RECORD;
    v_id_almacen_default  INTEGER;
    v_serie               VARCHAR;
    v_numero              VARCHAR;
    v_result_movimiento   JSON;
    v_stock_actual        NUMERIC(12,4);
    v_faltantes           TEXT := '';
    v_nombre_producto     VARCHAR;
    v_nombre_almacen      VARCHAR;
    v_id_estado_retornado INTEGER;
    v_id_estado_enviado   INTEGER;
    v_orden               RECORD;
    v_hay_pagos_cxp       BOOLEAN;
    v_id_cuenta_padre     INTEGER;
    v_id_tipo_doc_compra  INTEGER;
    v_id_tipo_doc_os      INTEGER;
    v_id_tipo_entrada_compra INTEGER;
    v_ids_balones_compra  INTEGER[];
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT id_almacen, serie, numero
    INTO v_id_almacen_default, v_serie, v_numero
    FROM com_comprobante_compra
    WHERE id = p_id_comprobante AND estado = 1
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_comprobante);
    END IF;

    -- No anular si la CxP vinculada ya tiene pagos.
    SELECT EXISTS (
        SELECT 1
        FROM fin_pago p
        JOIN fin_cuenta c ON c.id = p.id_cuenta
        WHERE p.estado = 1
          AND c.estado = 1
          AND (
              c.id_comprobante_compra = p_id_comprobante
              OR c.id_cuenta_padre IN (
                  SELECT fc.id
                  FROM fin_cuenta fc
                  WHERE fc.id_comprobante_compra = p_id_comprobante
                    AND fc.estado = 1
                    AND fc.id_cuenta_padre IS NULL
              )
          )
    ) INTO v_hay_pagos_cxp;

    IF v_hay_pagos_cxp THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id_comprobante,
            'error', 'No se puede anular: la cuenta por pagar vinculada tiene pagos registrados. Anule primero los pagos en Finanzas.'
        );
    END IF;

    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_os
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoDocumentoRef' AND lo.nombre = 'ORDEN_SALIDA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_entrada_compra
    FROM gen_lista_opciones lo
    JOIN gen_lista gl ON gl.id = lo.id_lista
    WHERE gl.nombre = 'TipoMovInvUnificado' AND lo.nombre = 'ENTRADA_COMPRA' AND lo.estado = 1
    LIMIT 1;

    -- Cilindros dados de alta por esta compra (antes de revertir movimientos).
    SELECT COALESCE(array_agg(DISTINCT m.id_balon) FILTER (WHERE m.id_balon IS NOT NULL), ARRAY[]::INTEGER[])
    INTO v_ids_balones_compra
    FROM inv_movimiento m
    WHERE m.estado = 1
      AND m.naturaleza = 'BALON'
      AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
      AND m.id_documento_origen = p_id_comprobante
      AND (v_id_tipo_entrada_compra IS NULL OR m.id_tipo_movimiento = v_id_tipo_entrada_compra);

    -- ---------- PASO 1: VALIDACIÃ“N COMPLETA (sin modificar nada aÃºn) ----------
    -- Agrega por (producto, almacÃ©n) todos los ingresos a revertir: lÃ­neas
    -- afecta_stock, gas de cilindros comprados y ENTRADA_PLANTA (COMPRA u OS).
    FOR v_detalle IN
        WITH ingresos AS (
            SELECT
                d.id_producto,
                COALESCE(d.id_almacen, v_id_almacen_default) AS id_almacen,
                d.cantidad
            FROM com_comprobante_compra_detalle d
            WHERE d.id_comprobante = p_id_comprobante
              AND d.afecta_stock = TRUE
              AND d.estado = 1

            UNION ALL

            SELECT
                m.id_producto,
                CASE
                    WHEN m.naturaleza = 'PRODUCTO' THEN m.id_almacen_origen
                    ELSE COALESCE(m.id_almacen_destino, m.id_almacen_origen)
                END AS id_almacen,
                m.cantidad
            FROM inv_movimiento m
            WHERE m.estado = 1
              AND m.id_producto IS NOT NULL
              AND m.stock_anterior IS NOT NULL
              AND m.stock_nuevo IS NOT NULL
              AND m.stock_nuevo >= m.stock_anterior
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND EXISTS (
                      SELECT 1 FROM gen_lista_opciones lo
                      WHERE lo.id = m.id_tipo_movimiento
                        AND UPPER(lo.nombre) = 'TRASLADO'
                  )
              )
              AND (
                  (v_id_tipo_doc_compra IS NOT NULL
                   AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
                   AND m.id_documento_origen = p_id_comprobante)
                  OR
                  (v_id_tipo_doc_os IS NOT NULL
                   AND m.id_tipo_documento_origen = v_id_tipo_doc_os
                   AND m.id_documento_origen IN (
                       SELECT ds.id FROM doc_salida ds
                       WHERE ds.id_comprobante_compra = p_id_comprobante AND ds.estado = 1
                   ))
              )
              -- Evitar doble conteo: lÃ­neas de detalle ya cubiertas arriba
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND v_id_tipo_doc_compra IS NOT NULL
                  AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
                  AND m.id_documento_origen = p_id_comprobante
                  AND m.id_documento_detalle IN (
                      SELECT d2.id FROM com_comprobante_compra_detalle d2
                      WHERE d2.id_comprobante = p_id_comprobante
                        AND d2.afecta_stock = TRUE
                        AND d2.estado = 1
                  )
              )
        )
        SELECT id_producto, id_almacen, SUM(cantidad) AS cantidad
        FROM ingresos
        WHERE id_producto IS NOT NULL AND id_almacen IS NOT NULL
        GROUP BY id_producto, id_almacen
    LOOP
        SELECT stock INTO v_stock_actual
        FROM pro_stock
        WHERE id_producto = v_detalle.id_producto
          AND id_almacen = v_detalle.id_almacen
          AND estado = 1
        FOR UPDATE;

        v_stock_actual := COALESCE(v_stock_actual, 0);

        IF v_stock_actual < v_detalle.cantidad THEN
            SELECT nombre INTO v_nombre_producto FROM pro_producto WHERE id = v_detalle.id_producto;
            SELECT nombre INTO v_nombre_almacen FROM gen_almacen WHERE id = v_detalle.id_almacen;

            v_faltantes := v_faltantes || format(
                E'\n- %s en %s: a revertir %s, disponible %s, falta %s',
                v_nombre_producto, v_nombre_almacen,
                v_detalle.cantidad, v_stock_actual, (v_detalle.cantidad - v_stock_actual)
            );
        END IF;
    END LOOP;

    IF v_faltantes <> '' THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id_comprobante,
            'error', 'No se puede anular: el stock ya fue consumido por ventas u otros movimientos posteriores. Regularice el inventario antes de anular.' || v_faltantes
        );
    END IF;

    -- ---------- PASO 2: REVERSA REAL (ya validado que hay stock suficiente) ----------
    v_result_movimiento := inv_revertir_por_documento(
        'COMPRA',
        p_id_comprobante,
        p_id_usuario_auditoria
    );
    IF (v_result_movimiento->>'error') IS NOT NULL THEN
        RAISE EXCEPTION 'No se pudo anular: %', v_result_movimiento->>'error';
    END IF;

    UPDATE com_comprobante_compra
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    UPDATE com_comprobante_compra_detalle
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id_comprobante;

    -- Baja lÃ³gica de cilindros creados por esta compra (ENTRADA_COMPRA).
    IF cardinality(v_ids_balones_compra) > 0 THEN
        UPDATE bal_balon
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = ANY (v_ids_balones_compra)
          AND estado = 1;
    END IF;

    -- Desvincular Ã³rdenes de recarga planta que apuntaban a esta compra.
    SELECT lo.id INTO v_id_estado_retornado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'RETORNADO' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_estado_enviado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoRecargaPlanta' AND lo.nombre = 'ENVIADO' AND lo.estado = 1
    LIMIT 1;

    FOR v_orden IN
        SELECT id, fecha_llegada_almacen, id_almacen
        FROM doc_salida
        WHERE id_comprobante_compra = p_id_comprobante
          AND estado = 1
    LOOP
        -- Revierte ORDEN_SALIDA (+ legado RECARGA) y deja cilindros en planta.
        PERFORM com_revertir_cilindros_recarga_compra(
            v_orden.id,
            p_id_comprobante,
            p_id_usuario_auditoria
        );

        UPDATE doc_salida
        SET
            id_comprobante_compra = NULL,
            serie_factura = NULL,
            numero_factura = NULL,
            id_estado = CASE
                WHEN v_orden.fecha_llegada_almacen IS NOT NULL THEN COALESCE(v_id_estado_retornado, id_estado)
                ELSE COALESCE(v_id_estado_enviado, id_estado)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_orden.id;
    END LOOP;

    UPDATE bal_movimiento_recarga
    SET
        id_comprobante_compra = NULL,
        serie_factura = NULL,
        numero_factura = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_compra = p_id_comprobante
      AND estado = 1;

    -- Baja lÃ³gica de CxP vinculada (cabeceras + cuotas hijas). Ya validado sin pagos.
    FOR v_id_cuenta_padre IN
        SELECT fc.id
        FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante
          AND fc.estado = 1
          AND fc.id_cuenta_padre IS NULL
    LOOP
        UPDATE fin_cuenta
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_cuenta_padre
           OR id_cuenta_padre = v_id_cuenta_padre;
    END LOOP;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id_comprobante);
END;
$function$;


-- ===== funciones\compras\com_revertir_cilindros_recarga_compra.sql =====

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_revertir_cilindros_recarga_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
DROP FUNCTION IF EXISTS com_revertir_cilindros_recarga_compra(p_id_recarga_planta integer, p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION com_revertir_cilindros_recarga_compra(p_id_recarga_planta integer, p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_det RECORD;
    v_estado VARCHAR;
    v_id_recarga_ext INTEGER;
    v_result JSON;
BEGIN
    SELECT lo.id INTO v_id_recarga_ext
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    FOR v_det IN
        SELECT d.id_balon
        FROM doc_salida_detalle d
        WHERE d.id_doc_salida = p_id_recarga_planta
          AND d.estado = 1
          AND d.id_balon IS NOT NULL
    LOOP
        SELECT eb.nombre INTO v_estado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = v_det.id_balon AND b.estado = 1;

        IF COALESCE(v_estado, '') NOT IN ('DISPONIBLE', 'EN_RECARGA_EXTERNA') THEN
            RAISE EXCEPTION
                'No se puede anular la compra: el cilindro % ya no estÃ¡ en almacÃ©n ni en recarga externa (estado %).',
                v_det.id_balon,
                COALESCE(v_estado, 'sin estado');
        END IF;

        IF COALESCE(v_estado, '') = 'DISPONIBLE' AND v_id_recarga_ext IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_recarga_ext,
                id_almacen = NULL,
                id_usuario_modificacion = p_id_usuario,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon AND estado = 1;
        END IF;
    END LOOP;

    -- Entradas de retorno etiquetadas ORDEN_SALIDA (retorno sin factura, o
    -- legado). Las etiquetadas COMPRA ya las revirtiÃ³ com_anular_compra.
    v_result := inv_revertir_por_documento('ORDEN_SALIDA', p_id_recarga_planta, p_id_usuario);
    IF (v_result->>'error') IS NOT NULL THEN
        RAISE EXCEPTION '%', v_result->>'error';
    END IF;

    -- Compatibilidad con movimientos aÃºn etiquetados RECARGA (pre-F2).
    v_result := inv_revertir_por_documento('RECARGA', p_id_recarga_planta, p_id_usuario);
    IF (v_result->>'error') IS NOT NULL
       AND POSITION('no configurado' IN LOWER(COALESCE(v_result->>'error', ''))) = 0
    THEN
        RAISE EXCEPTION '%', v_result->>'error';
    END IF;

    -- Al anular la compra los cilindros deben volver a EN_RECARGA_EXTERNA.
    IF v_id_recarga_ext IS NOT NULL THEN
        UPDATE bal_balon b
        SET
            id_estado_balon = v_id_recarga_ext,
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.estado = 1
          AND b.id IN (
              SELECT d.id_balon
              FROM doc_salida_detalle d
              WHERE d.id_doc_salida = p_id_recarga_planta
                AND d.estado = 1
                AND d.id_balon IS NOT NULL
          );
    END IF;
END;
$function$;


-- ===== funciones\inventario-movimientos\inv_revertir_por_documento.sql =====

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_revertir_por_documento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.964Z
DROP FUNCTION IF EXISTS inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer, p_id_documento_detalle integer);

CREATE OR REPLACE FUNCTION inv_revertir_por_documento(p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_documento_detalle integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_mov RECORD;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_almacen_stock INTEGER;
    v_count INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_documento_origen IS NULL THEN
        RETURN json_build_object('revertidos', 0, 'error', 'id_documento_origen es obligatorio');
    END IF;

    SELECT lo.id INTO v_id_tipo_doc
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef'
      AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, '')))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc IS NULL THEN
        RETURN json_build_object(
            'revertidos', 0,
            'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, ''))))
        );
    END IF;

    FOR v_mov IN
        SELECT * FROM inv_movimiento
        WHERE estado = 1
          AND id_tipo_documento_origen = v_id_tipo_doc
          AND id_documento_origen = p_id_documento_origen
          AND (p_id_documento_detalle IS NULL OR id_documento_detalle = p_id_documento_detalle)
        ORDER BY id DESC
        FOR UPDATE
    LOOP
        SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
        v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
        IF v_es_traslado THEN
            v_es_salida := TRUE;
        ELSIF v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL THEN
            v_es_salida := v_mov.stock_nuevo < v_mov.stock_anterior;
        ELSE
            v_es_salida := COALESCE(inv_signo_tipo_movimiento(v_mov.id_tipo_movimiento), 1) < 0;
        END IF;

        -- Revertir stock (producto, o gas cargado por un movimiento de balÃ³n).
        -- Misma estrictitud que inv_eliminar_movimiento: si no se puede revertir
        -- el stock, NO soft-deletear el movimiento (RAISE â†’ rollback).
        IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
            IF v_mov.naturaleza = 'PRODUCTO' THEN
                v_id_almacen_stock := v_mov.id_almacen_origen;
            ELSE
                v_id_almacen_stock := COALESCE(
                    CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                    v_mov.id_almacen_origen,
                    v_mov.id_almacen_destino
                );
            END IF;

            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                RAISE EXCEPTION
                    'No se encontrÃ³ el registro de stock para revertir el movimiento %',
                    v_mov.id;
            END IF;

            v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
            IF v_stock_revertido < 0 THEN
                RAISE EXCEPTION
                    'No se puede revertir el movimiento % porque dejarÃ­a stock negativo',
                    v_mov.id;
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;

            IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_actual
                FROM pro_stock
                WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NULL THEN
                    RAISE EXCEPTION
                        'No se encontrÃ³ el stock de destino para revertir el traslado %',
                        v_mov.id;
                END IF;

                v_stock_revertido := v_stock_actual - v_mov.cantidad;
                IF v_stock_revertido < 0 THEN
                    RAISE EXCEPTION
                        'No se puede revertir el traslado % porque el destino ya no tiene esa cantidad',
                        v_mov.id;
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
            END IF;
        END IF;

        -- Restaurar custodia previa del balÃ³n (no forzar DISPONIBLE a ciegas).
        IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            UPDATE bal_balon
            SET
                id_estado_balon = COALESCE(v_mov.id_estado_balon_anterior, v_id_estado_en_almacen, id_estado_balon),
                id_cliente_ubicacion = CASE
                    WHEN v_mov.id_estado_balon_anterior IS NOT NULL THEN v_mov.id_cliente_ubicacion_anterior
                    ELSE NULL
                END,
                id_almacen = COALESCE(
                    v_mov.id_almacen_anterior,
                    v_mov.id_almacen_origen,
                    v_mov.id_almacen_destino,
                    id_almacen
                ),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_mov.id_balon AND estado = 1;
        END IF;

        UPDATE inv_movimiento
        SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_mov.id;

        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object('revertidos', v_count);
END;
$function$;


-- ===== funciones\inventario-movimientos\inv_registrar_movimiento.sql =====

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_registrar_movimiento
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
DROP FUNCTION IF EXISTS inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone, p_id_producto integer, p_id_balon integer, p_cantidad numeric, p_id_almacen_origen integer, p_id_almacen_destino integer, p_id_cliente integer, p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_glosa character varying, p_id_usuario_auditoria integer, p_id_movimiento_padre integer, p_sentido_ajuste character varying, p_forzar boolean, p_id_documento_detalle integer);

CREATE OR REPLACE FUNCTION inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone DEFAULT now(), p_id_producto integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_cantidad numeric DEFAULT 0, p_id_almacen_origen integer DEFAULT NULL::integer, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_codigo_tipo_documento_origen character varying DEFAULT NULL::character varying, p_id_documento_origen integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_movimiento_padre integer DEFAULT NULL::integer, p_sentido_ajuste character varying DEFAULT NULL::character varying, p_forzar boolean DEFAULT false, p_id_documento_detalle integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_naturaleza VARCHAR;
    v_id_tipo_mov INTEGER;
    v_nombre_tipo_mov VARCHAR;
    v_id_tipo_doc INTEGER;
    v_id_existente INTEGER;
    v_cantidad NUMERIC(12,4);
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_signo INTEGER;
    v_id INTEGER;
    -- rama PRODUCTO
    v_afecta_stock BOOLEAN;
    v_id_unidad_medida INTEGER;
    v_id_stock INTEGER;
    v_id_stock_dest INTEGER;
    v_stock_anterior NUMERIC(12,4);
    v_stock_nuevo NUMERIC(12,4);
    v_stock_dest_ant NUMERIC(12,4);
    -- rama BALON
    v_nombre_estado_actual VARCHAR;
    v_codigo_estado_destino VARCHAR;
    v_cliente_destino INTEGER;
    v_limpiar_almacen BOOLEAN;
    v_codigo_contenido VARCHAR;
    v_id_estado_balon INTEGER;
    v_id_almacen_balon INTEGER;
    v_id_estado_anterior INTEGER;
    v_id_cliente_anterior INTEGER;
    v_id_almacen_anterior INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_naturaleza := UPPER(TRIM(COALESCE(p_naturaleza, '')));
    IF v_naturaleza NOT IN ('PRODUCTO', 'BALON') THEN
        RETURN json_build_object('error', 'naturaleza debe ser PRODUCTO o BALON', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'PRODUCTO' AND p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'id_producto es obligatorio para naturaleza PRODUCTO', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'BALON' AND p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'id_balon es obligatorio para naturaleza BALON', 'registro', NULL);
    END IF;

    IF p_codigo_tipo_movimiento IS NULL OR TRIM(p_codigo_tipo_movimiento) = '' THEN
        RETURN json_build_object('error', 'El tipo de movimiento es obligatorio', 'registro', NULL);
    END IF;

    SELECT lo.id, lo.nombre INTO v_id_tipo_mov, v_nombre_tipo_mov
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = UPPER(TRIM(p_codigo_tipo_movimiento))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_mov IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_movimiento))),
            'registro', NULL
        );
    END IF;

    IF p_codigo_tipo_documento_origen IS NOT NULL AND TRIM(p_codigo_tipo_documento_origen) <> '' THEN
        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_documento_origen))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_doc IS NULL THEN
            RETURN json_build_object(
                'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(p_codigo_tipo_documento_origen))),
                'registro', NULL
            );
        END IF;
    END IF;
    IF p_id_documento_origen IS NOT NULL AND v_id_tipo_doc IS NOT NULL AND NOT COALESCE(p_forzar, FALSE) THEN
        SELECT m.id INTO v_id_existente
        FROM inv_movimiento m
        WHERE m.estado = 1
          AND m.naturaleza = v_naturaleza
          AND m.id_tipo_documento_origen = v_id_tipo_doc
          AND m.id_documento_origen = p_id_documento_origen
          AND COALESCE(m.id_documento_detalle, -1) = COALESCE(p_id_documento_detalle, -1)
          AND m.id_tipo_movimiento = v_id_tipo_mov
          AND (v_naturaleza <> 'PRODUCTO' OR m.id_producto = p_id_producto)
          AND (v_naturaleza <> 'BALON' OR m.id_balon = p_id_balon)
        ORDER BY m.id
        LIMIT 1;

        IF v_id_existente IS NOT NULL THEN
            RETURN (inv_obtener_movimiento(v_id_existente)::JSONB || jsonb_build_object('creado', FALSE))::JSON;
        END IF;
    END IF;

    v_cantidad := ABS(COALESCE(p_cantidad, 0));
    v_es_traslado := (v_naturaleza = 'PRODUCTO' AND UPPER(v_nombre_tipo_mov) = 'TRASLADO');
    v_signo := inv_signo_tipo_movimiento(v_id_tipo_mov);

    IF UPPER(v_nombre_tipo_mov) = 'AJUSTE' THEN
        IF UPPER(TRIM(COALESCE(p_sentido_ajuste, ''))) NOT IN ('MAS', 'MENOS') THEN
            RETURN json_build_object('error', 'El ajuste requiere sentido MAS o MENOS', 'registro', NULL);
        END IF;
        v_es_salida := UPPER(TRIM(p_sentido_ajuste)) = 'MENOS';
    ELSIF v_signo IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no tiene signo configurado', v_nombre_tipo_mov),
            'registro', NULL
        );
    ELSE
        v_es_salida := v_signo < 0 OR v_es_traslado;
    END IF;

    IF v_naturaleza = 'PRODUCTO' THEN
        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
            RETURN json_build_object('error', 'El producto indicado no existe o estÃ¡ inactivo', 'registro', NULL);
        END IF;

        IF p_id_almacen_origen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_origen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacÃ©n indicado no existe o estÃ¡ inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(afecta_stock, FALSE), id_unidad_medida
        INTO v_afecta_stock, v_id_unidad_medida
        FROM pro_producto WHERE id = p_id_producto;

        IF v_es_traslado THEN
            IF p_id_almacen_destino IS NULL THEN
                RETURN json_build_object('error', 'El traslado requiere almacÃ©n de destino', 'registro', NULL);
            END IF;
            IF p_id_almacen_destino = p_id_almacen_origen THEN
                RETURN json_build_object('error', 'El almacÃ©n de destino debe ser distinto al de origen', 'registro', NULL);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1) THEN
                RETURN json_build_object('error', 'El almacÃ©n de destino no existe o estÃ¡ inactivo', 'registro', NULL);
            END IF;
        END IF;

        v_stock_anterior := 0;
        v_stock_nuevo := 0;

        IF v_afecta_stock THEN
            SELECT id, stock INTO v_id_stock, v_stock_anterior
            FROM pro_stock
            WHERE id_almacen = p_id_almacen_origen AND id_producto = p_id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                -- Soft-delete previo: UNIQUE(id_almacen, id_producto) bloquea INSERT.
                -- Reactivar como pro_crear_stock en vez de fallar.
                SELECT id INTO v_id_stock
                FROM pro_stock
                WHERE id_almacen = p_id_almacen_origen AND id_producto = p_id_producto AND estado = 0
                FOR UPDATE;

                IF v_id_stock IS NOT NULL THEN
                    UPDATE pro_stock
                    SET stock = 0,
                        estado = 1,
                        id_usuario_modificacion = p_id_usuario_auditoria,
                        fecha_modificacion = NOW()
                    WHERE id = v_id_stock;
                    v_stock_anterior := 0;
                ELSE
                    INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                    VALUES (p_id_almacen_origen, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                    RETURNING id, stock INTO v_id_stock, v_stock_anterior;
                END IF;
            END IF;

            IF v_es_salida THEN
                v_stock_nuevo := v_stock_anterior - v_cantidad;
            ELSE
                v_stock_nuevo := v_stock_anterior + v_cantidad;
            END IF;

            IF v_stock_nuevo < 0 THEN
                RETURN json_build_object('error', 'Stock insuficiente para registrar la salida', 'registro', NULL);
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;

            IF v_es_traslado THEN
                SELECT id, stock INTO v_id_stock_dest, v_stock_dest_ant
                FROM pro_stock
                WHERE id_almacen = p_id_almacen_destino AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock_dest IS NULL THEN
                    SELECT id INTO v_id_stock_dest
                    FROM pro_stock
                    WHERE id_almacen = p_id_almacen_destino AND id_producto = p_id_producto AND estado = 0
                    FOR UPDATE;

                    IF v_id_stock_dest IS NOT NULL THEN
                        UPDATE pro_stock
                        SET stock = 0,
                            estado = 1,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_stock_dest;
                        v_stock_dest_ant := 0;
                    ELSE
                        INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                        VALUES (p_id_almacen_destino, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                        RETURNING id, stock INTO v_id_stock_dest, v_stock_dest_ant;
                    END IF;
                END IF;

                UPDATE pro_stock
                SET stock = COALESCE(v_stock_dest_ant, 0) + v_cantidad,
                    id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock_dest;
            END IF;
        END IF;

        INSERT INTO inv_movimiento (
            fecha, id_tipo_movimiento, naturaleza, id_producto, cantidad, id_unidad_medida,
            id_almacen_origen, id_almacen_destino, id_cliente,
            id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
            stock_anterior, stock_nuevo, glosa,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'PRODUCTO', p_id_producto, v_cantidad, v_id_unidad_medida,
            p_id_almacen_origen, p_id_almacen_destino, p_id_cliente,
            p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
            CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
            CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
            p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

        RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
    END IF;
    SELECT eb.nombre, b.id_almacen, b.id_estado_balon, b.id_cliente_ubicacion
    INTO v_nombre_estado_actual, v_id_almacen_balon, v_id_estado_anterior, v_id_cliente_anterior
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1
    FOR UPDATE OF b;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o estÃ¡ inactivo', 'registro', NULL);
    END IF;

    IF COALESCE(v_nombre_estado_actual, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error', 'No se puede registrar movimiento de un cilindro dado de baja o reportado como robo',
            'registro', NULL
        );
    END IF;

    v_id_almacen_anterior := v_id_almacen_balon;
    v_limpiar_almacen := FALSE;
    v_codigo_contenido := NULL;
    v_cliente_destino := NULL;
    CASE v_nombre_tipo_mov
        WHEN 'SALIDA_PRESTAMO' THEN
            v_codigo_estado_destino := 'PRESTADO_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ALQUILER' THEN
            v_codigo_estado_destino := 'ALQUILADO'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_VENTA' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ENTREGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_MANTENIMIENTO' THEN
            v_codigo_estado_destino := 'EN_MANTENIMIENTO'; v_cliente_destino := p_id_cliente;
        WHEN 'SALIDA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'EN_RECARGA_EXTERNA'; v_limpiar_almacen := TRUE; v_codigo_contenido := 'VACIO';
        WHEN 'ENTRADA_DEVOLUCION', 'ENTRADA_MANTENIMIENTO', 'RETORNO_LIMA' THEN
            v_codigo_estado_destino := 'DISPONIBLE';
        WHEN 'ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'DISPONIBLE'; v_codigo_contenido := 'LLENO';
        WHEN 'RECARGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'TRASLADO_LIMA' THEN
            v_codigo_estado_destino := 'EN_RUTA_LIMA'; v_limpiar_almacen := TRUE;
        ELSE
            v_codigo_estado_destino := NULL;
    END CASE;

    IF v_codigo_estado_destino IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_balon
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = v_codigo_estado_destino AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_balon IS NULL THEN
            RETURN json_build_object('error', format('Estado %s no configurado', v_codigo_estado_destino), 'registro', NULL);
        END IF;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_balon,
            id_cliente_ubicacion = CASE WHEN v_cliente_destino IS NOT NULL THEN v_cliente_destino ELSE NULL END,
            id_almacen = CASE
                WHEN v_limpiar_almacen THEN NULL
                ELSE COALESCE(p_id_almacen_destino, p_id_almacen_origen, id_almacen)
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;

    ELSIF UPPER(v_nombre_tipo_mov) = 'TRASLADO' AND p_id_almacen_destino IS NOT NULL THEN
        -- Trasladar un cilindro cambia dÃ³nde estÃ¡, no en quÃ© situaciÃ³n estÃ¡:
        -- sigue DISPONIBLE (o como estuviera), solo que en el otro almacÃ©n. Sin
        -- esto el traslado registraba el movimiento y dejaba el balÃ³n en el
        -- almacÃ©n de origen, que es justo lo que venÃ­a a cambiar.
        UPDATE bal_balon
        SET id_almacen = p_id_almacen_destino,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    -- Si el movimiento del balÃ³n tambiÃ©n mueve gas, se refleja en pro_stock del gas.
    v_stock_anterior := NULL;
    v_stock_nuevo := NULL;
    IF p_id_producto IS NOT NULL AND v_cantidad > 0 THEN
        DECLARE
            v_id_almacen_gas INTEGER;
        BEGIN
            v_id_almacen_gas := COALESCE(
                CASE WHEN v_es_salida THEN p_id_almacen_origen ELSE p_id_almacen_destino END,
                p_id_almacen_origen, p_id_almacen_destino, v_id_almacen_balon
            );

            IF v_id_almacen_gas IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_anterior
                FROM pro_stock
                WHERE id_almacen = v_id_almacen_gas AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NULL THEN
                    SELECT id INTO v_id_stock
                    FROM pro_stock
                    WHERE id_almacen = v_id_almacen_gas AND id_producto = p_id_producto AND estado = 0
                    FOR UPDATE;

                    IF v_id_stock IS NOT NULL THEN
                        UPDATE pro_stock
                        SET stock = 0,
                            estado = 1,
                            id_usuario_modificacion = p_id_usuario_auditoria,
                            fecha_modificacion = NOW()
                        WHERE id = v_id_stock;
                        v_stock_anterior := 0;
                    ELSE
                        INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                        VALUES (v_id_almacen_gas, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                        RETURNING id, stock INTO v_id_stock, v_stock_anterior;
                    END IF;
                END IF;

                IF v_es_salida THEN
                    v_stock_nuevo := v_stock_anterior - v_cantidad;
                ELSE
                    v_stock_nuevo := v_stock_anterior + v_cantidad;
                END IF;

                IF v_stock_nuevo < 0 THEN
                    RETURN json_build_object('error', 'Stock de gas insuficiente para registrar la salida', 'registro', NULL);
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
            END IF;
        END;
    END IF;

    SELECT id_unidad_medida INTO v_id_unidad_medida FROM pro_producto WHERE id = p_id_producto;

    INSERT INTO inv_movimiento (
        fecha, id_tipo_movimiento, naturaleza, id_producto, id_balon, cantidad, id_unidad_medida,
        id_almacen_origen, id_almacen_destino, id_cliente,
        id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
        stock_anterior, stock_nuevo, id_estado_balon_snapshot,
        id_estado_balon_anterior, id_cliente_ubicacion_anterior, id_almacen_anterior,
        glosa, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'BALON', p_id_producto, p_id_balon, v_cantidad, v_id_unidad_medida,
        p_id_almacen_origen, p_id_almacen_destino, COALESCE(v_cliente_destino, p_id_cliente),
        p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
        v_stock_anterior, v_stock_nuevo, v_id_estado_balon,
        v_id_estado_anterior, v_id_cliente_anterior, v_id_almacen_anterior,
        p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
END;
$function$;


-- ===== funciones\almacenes\gen_eliminar_almacen.sql =====

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_eliminar_almacen
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_eliminar_almacen(p_id integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_eliminar_almacen(p_id integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF EXISTS (
        SELECT 1
        FROM pro_stock
        WHERE id_almacen = p_id
          AND estado = 1
          AND COALESCE(stock, 0) > 0
    ) THEN
        RETURN json_build_object(
            'eliminado', FALSE,
            'id', p_id,
            'error', 'No se puede eliminar el almacÃ©n: tiene stock activo con cantidad mayor a cero. Traslade o ajuste el inventario primero.'
        );
    END IF;

    UPDATE gen_almacen
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;

