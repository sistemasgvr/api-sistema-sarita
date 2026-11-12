-- Compras: fecha de gasto vs fecha de emisión. com_comprobante_compra.fecha pasa a ser la FECHA DE GASTO (mueve la caja) y se agrega fecha_emision (fecha del comprobante del proveedor; NULL = pendiente de comprobante). Agrega el tipo AJUSTE_COMPRA a la bitácora de caja, crea fin_caja_recalcular_arqueo y publica com_crear_compra (nuevo p_fecha_emision), com_actualizar_compra_cabecera (editar comprobante y mover la fecha de gasto entre cajas), com_listar_compras y com_obtener_compra (devuelven fecha_emision; "sin comprobante" también considera fecha_emision).
-- Respaldar la base antes de aplicarlo; publicar junto con la API y el admin que envían fechaEmision (la API anterior sigue funcionando: los parámetros nuevos tienen default).
-- PENDIENTE DE PUBLICAR: no ejecutar sin revisión. Idempotente (ADD COLUMN IF NOT EXISTS, DROP CONSTRAINT IF EXISTS, DROP/CREATE OR REPLACE).
BEGIN;

-- Solo la primera vez (cuando se crea la columna) las compras existentes con comprobante toman su fecha
-- actual como fecha de emisión. Re-ejecutar la migración no toca compras nuevas que quedaron pendientes a propósito.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'com_comprobante_compra' AND column_name = 'fecha_emision'
    ) THEN
        ALTER TABLE public.com_comprobante_compra ADD COLUMN fecha_emision date;

        UPDATE public.com_comprobante_compra
        SET fecha_emision = fecha
        WHERE NULLIF(TRIM(serie), '') IS NOT NULL
          AND NULLIF(TRIM(numero), '') IS NOT NULL;
    END IF;
END $$;

ALTER TABLE public.fin_caja_sesion_evento
DROP CONSTRAINT IF EXISTS fin_caja_sesion_evento_tipo_check;

ALTER TABLE public.fin_caja_sesion_evento
ADD CONSTRAINT fin_caja_sesion_evento_tipo_check CHECK (
  (
    (tipo)::text = ANY (
      (
        ARRAY[
          'ABRIR'::character varying,
          'CERRAR'::character varying,
          'REABRIR'::character varying,
          'AJUSTE_FONDO'::character varying,
          'AJUSTE_COMPRA'::character varying
        ]
      )::TEXT[]
    )
  )
);

-- Recalcula el arqueo de una caja CERRADA con los totales en vivo de su día (el efectivo contado no cambia)
DROP FUNCTION IF EXISTS public.fin_caja_recalcular_arqueo (p_id_sesion integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION public.fin_caja_recalcular_arqueo (
  p_id_sesion integer,
  p_id_usuario integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_sesion RECORD;
    v_totales JSON;
    v_esperado NUMERIC(14,4);
    v_diferencia NUMERIC(14,4);
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.*, UPPER(COALESCE(est.nombre, '')) AS estado_nombre
    INTO v_sesion
    FROM fin_caja_sesion s
    LEFT JOIN gen_lista_opciones est ON est.id = s.id_estado
    WHERE s.id = p_id_sesion AND s.estado = 1;

    IF NOT FOUND OR v_sesion.estado_nombre <> 'CERRADA' THEN
        RETURN NULL;
    END IF;

    -- Misma fórmula que fin_cerrar_caja_sesion
    v_totales := fin_caja_calcular_totales(v_sesion.fecha, v_sesion.id_sucursal);
    v_esperado := COALESCE(v_sesion.monto_inicial, 0)
        + COALESCE((v_totales->>'efectivoNeto')::NUMERIC, 0);
    v_diferencia := COALESCE(v_sesion.monto_efectivo_contado, 0) - v_esperado;

    UPDATE fin_caja_sesion
    SET monto_esperado = v_esperado,
        diferencia = v_diferencia,
        totales_cierre = v_totales,
        id_usuario_modificacion = p_id_usuario,
        fecha_modificacion = NOW()
    WHERE id = p_id_sesion;

    RETURN json_build_object(
        'montoEsperadoAnterior', v_sesion.monto_esperado,
        'montoEsperado', v_esperado,
        'diferencia', v_diferencia
    );
END;
$function$;

-- Crea compra
DROP FUNCTION IF EXISTS public.com_crear_compra (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_proveedor integer,
  p_id_almacen integer,
  p_detalles jsonb,
  p_id_comprobante_referencia integer,
  p_id_doc_salida integer,
  p_id_tipo_registro integer,
  p_id_categoria_gasto integer,
  p_id_sucursal integer,
  p_id_moneda integer,
  p_id_condicion_pago integer,
  p_declarar_sunat boolean,
  p_glosa character varying,
  p_id_usuario_auditoria integer,
  p_registrar_retorno_balones boolean,
  p_fecha_llegada_almacen date,
  p_lote character varying,
  p_fecha_vencimiento_lote date,
  p_fecha_prueba_hidrostatica date,
  p_serie_guia_ingreso character varying,
  p_numero_guia_ingreso character varying,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying
);

DROP FUNCTION IF EXISTS public.com_crear_compra (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_proveedor integer,
  p_id_almacen integer,
  p_detalles jsonb,
  p_id_comprobante_referencia integer,
  p_id_doc_salida integer,
  p_id_tipo_registro integer,
  p_id_categoria_gasto integer,
  p_id_sucursal integer,
  p_id_moneda integer,
  p_id_condicion_pago integer,
  p_declarar_sunat boolean,
  p_glosa character varying,
  p_id_usuario_auditoria integer,
  p_registrar_retorno_balones boolean,
  p_fecha_llegada_almacen date,
  p_lote character varying,
  p_fecha_vencimiento_lote date,
  p_fecha_prueba_hidrostatica date,
  p_serie_guia_ingreso character varying,
  p_numero_guia_ingreso character varying,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric
);

CREATE OR REPLACE FUNCTION public.com_crear_compra (
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying,
  p_fecha date,
  p_id_proveedor integer,
  p_id_almacen integer,
  p_detalles jsonb,
  p_id_comprobante_referencia integer DEFAULT NULL::integer,
  p_id_doc_salida integer DEFAULT NULL::integer,
  p_id_tipo_registro integer DEFAULT NULL::integer,
  p_id_categoria_gasto integer DEFAULT NULL::integer,
  p_id_sucursal integer DEFAULT NULL::integer,
  p_id_moneda integer DEFAULT NULL::integer,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_declarar_sunat boolean DEFAULT FALSE,
  p_glosa character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_registrar_retorno_balones boolean DEFAULT FALSE,
  p_fecha_llegada_almacen date DEFAULT NULL::date,
  p_lote character varying DEFAULT NULL::character varying,
  p_fecha_vencimiento_lote date DEFAULT NULL::date,
  p_fecha_prueba_hidrostatica date DEFAULT NULL::date,
  p_serie_guia_ingreso character varying DEFAULT NULL::character varying,
  p_numero_guia_ingreso character varying DEFAULT NULL::character varying,
  p_fecha_vencimiento_cxp date DEFAULT NULL::date,
  p_cuotas_cxp jsonb DEFAULT NULL::jsonb,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer,
  p_numero_operacion character varying DEFAULT NULL::character varying,
  p_porcentaje_igv numeric DEFAULT 18,
  p_fecha_emision date DEFAULT NULL::date
) RETURNS json LANGUAGE plpgsql AS $function$
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
    v_porcentaje_igv      NUMERIC(5,2);
    v_tasa_igv            NUMERIC(7,4);
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
    v_orden               RECORD;
    v_registrar_retorno   BOOLEAN;
    v_retorno_ya_registrado BOOLEAN := FALSE;
    v_id_tipo_entrada_planta INTEGER;
    v_fecha_llegada       DATE;
    v_lote                VARCHAR;
    v_fecha_venc_lote     DATE;
    v_fecha_ph            DATE;
    v_err_pago            TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha IS NULL THEN
        RETURN json_build_object('error', 'La fecha de gasto es obligatoria', 'registro', NULL);
    END IF;

    IF p_id_proveedor IS NULL THEN
        RETURN json_build_object('error', 'El proveedor es obligatorio', 'registro', NULL);
    END IF;

    IF p_fecha_emision IS NOT NULL AND p_fecha_emision > CURRENT_DATE THEN
        RETURN json_build_object('error', 'La fecha de emisión no puede ser posterior a hoy', 'registro', NULL);
    END IF;

    v_porcentaje_igv := ROUND(COALESCE(p_porcentaje_igv, 18), 2);
    IF v_porcentaje_igv < 0 OR v_porcentaje_igv > 100 THEN
        RETURN json_build_object('error', 'El porcentaje de IGV debe estar entre 0 y 100', 'registro', NULL);
    END IF;
    v_tasa_igv := v_porcentaje_igv / 100;

    IF fin_medio_pago_flag(p_id_medio_pago, 'ES_CREDITO') THEN
        RETURN json_build_object('error', 'El medio de pago de la compra no puede ser crédito: para una compra al crédito elige la condición de pago.', 'registro', NULL);
    END IF;

    v_err_pago := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
    IF v_err_pago IS NOT NULL THEN
        RETURN json_build_object('error', v_err_pago, 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén (por defecto) indicado no existe o está inactivo', 'registro', NULL);
    END IF;

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
                'error', 'La compra de referencia debe estar anulada antes de registrar la corrección (serie ' || v_ref_serie || '-' || v_ref_numero || ' sigue activa)',
                'registro', NULL
            );
        END IF;

        IF v_glosa_final IS NULL THEN
            v_glosa_final := 'Corrige compra anulada ' || v_ref_serie || '-' || v_ref_numero;
        END IF;
    END IF;

    IF p_id_doc_salida IS NOT NULL THEN
        SELECT
            rp.id,
            rp.id_proveedor,
            rp.id_almacen,
            rp.lote,
            rp.fecha_vencimiento_lote,
            rp.fecha_prueba_hidrostatica,
            rp.fecha_llegada_almacen,
            rp.id_lote_protocolo,
            c.id AS id_compra_vinculada,
            c.serie AS serie_compra_vinculada,
            c.numero AS numero_compra_vinculada,
            est.nombre AS estado_ciclo,
            tor.nombre AS tipo_orden
        INTO v_orden
        FROM doc_salida rp
        JOIN gen_lista_opciones est ON est.id = rp.id_estado_ciclo
        JOIN gen_lista_opciones tor ON tor.id = rp.id_tipo_orden
        LEFT JOIN com_comprobante_compra c
            ON c.id = rp.id_comprobante_compra AND c.estado = 1
        WHERE rp.id = p_id_doc_salida AND rp.estado = 1
        FOR UPDATE OF rp;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La orden de recarga en planta externa indicada no existe o está inactiva', 'registro', NULL);
        END IF;

        IF v_orden.tipo_orden <> 'RECARGA_PLANTA_EXTERNA' THEN
            RETURN json_build_object('error', 'El documento indicado no es una orden de recarga en planta externa', 'registro', NULL);
        END IF;

        IF v_orden.estado_ciclo NOT IN ('GENERADA', 'EMITIDA_SUNAT') THEN
            RETURN json_build_object(
                'error', CASE
                    WHEN v_orden.estado_ciclo = 'ANULADA' THEN 'La orden de recarga indicada está anulada'
                    ELSE 'La orden de recarga aún está en borrador: genérala antes de registrar su factura'
                END,
                'registro', NULL
            );
        END IF;

        IF v_orden.id_compra_vinculada IS NOT NULL THEN
            RETURN json_build_object(
                'error', format(
                    'La orden de recarga ya tiene la compra %s vinculada; anúlala antes de registrar otra',
                    COALESCE(NULLIF(TRIM(CONCAT_WS('-', v_orden.serie_compra_vinculada, v_orden.numero_compra_vinculada)), ''), '#' || v_orden.id_compra_vinculada)
                ),
                'registro', NULL
            );
        END IF;

        IF v_orden.id_proveedor IS NOT NULL
           AND p_id_proveedor IS NOT NULL
           AND v_orden.id_proveedor <> p_id_proveedor
        THEN
            RETURN json_build_object('error', 'El proveedor de la compra no coincide con el de la orden de recarga', 'registro', NULL);
        END IF;
    END IF;

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

    INSERT INTO com_comprobante_compra (
        id_tipo_comprobante, serie, numero, fecha, id_proveedor,
        id_tipo_registro, id_categoria_gasto, id_sucursal, id_almacen,
        id_moneda, id_condicion_pago, sub_total, igv, total_importe,
        declarar_sunat, glosa, id_comprobante_referencia, id_doc_salida,
        id_medio_pago, id_cuenta_bancaria, numero_operacion, porcentaje_igv,
        fecha_emision, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, NULLIF(TRIM(p_serie), ''), NULLIF(TRIM(p_numero), ''), p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia, p_id_doc_salida,
        p_id_medio_pago, p_id_cuenta_bancaria, NULLIF(TRIM(p_numero_operacion), ''), v_porcentaje_igv,
        p_fecha_emision, p_id_usuario_auditoria, p_id_usuario_auditoria
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
            RAISE EXCEPTION 'La línea % no tiene id_producto', v_item;
        END IF;

        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad de la línea % debe ser mayor a cero', v_item;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
            RAISE EXCEPTION 'El almacén id=% de la línea % no existe o está inactivo', v_id_almacen_linea, v_item;
        END IF;

        SELECT afecta_stock, COALESCE(es_gas, FALSE)
        INTO v_afecta_stock, v_es_gas
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;

        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la línea % no existe o está inactivo', v_id_producto, v_item;
        END IF;

        IF v_linea ? 'afecta_stock' AND jsonb_typeof(v_linea->'afecta_stock') <> 'null' THEN
            v_afecta_stock := COALESCE((v_linea->>'afecta_stock')::BOOLEAN, v_afecta_stock);
        END IF;

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
                p_glosa                     => 'Ingreso por compra ' || COALESCE(NULLIF(TRIM(p_serie), '') || '-' || NULLIF(TRIM(p_numero), ''), '#' || v_id_compra),
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

    v_id_almacen_compra := p_id_almacen;

    IF p_id_doc_salida IS NOT NULL THEN
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE);

        v_lote := COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(v_orden.lote), ''));
        v_fecha_venc_lote := COALESCE(p_fecha_vencimiento_lote, v_orden.fecha_vencimiento_lote);
        v_fecha_ph := COALESCE(p_fecha_prueba_hidrostatica, v_orden.fecha_prueba_hidrostatica);

        SELECT lo.id INTO v_id_tipo_entrada_planta
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoMovInvUnificado'
          AND lo.nombre = 'ENTRADA_PLANTA_EXTERNA'
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_entrada_planta IS NULL THEN
            RAISE EXCEPTION 'Falta configurar ENTRADA_PLANTA_EXTERNA en TipoMovInvUnificado';
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM inv_movimiento m
            JOIN doc_salida_detalle dd ON dd.id = m.id_documento_detalle
            WHERE m.estado = 1
              AND m.id_tipo_movimiento = v_id_tipo_entrada_planta
              AND m.naturaleza = 'BALON'
              AND dd.id_doc_salida = p_id_doc_salida
              AND dd.id_balon IS NOT NULL
              AND m.id_balon = dd.id_balon
        ) INTO v_retorno_ya_registrado;

        IF v_registrar_retorno AND NOT v_retorno_ya_registrado THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);
        ELSE
            v_registrar_retorno := FALSE;
            v_fecha_llegada := NULL;
        END IF;

        UPDATE doc_salida
        SET id_comprobante_compra   = v_id_compra,
            id_almacen_retorno      = CASE
                WHEN v_registrar_retorno THEN COALESCE(p_id_almacen, id_almacen_retorno)
                ELSE id_almacen_retorno
            END,
            serie_guia_ingreso      = COALESCE(NULLIF(TRIM(p_serie_guia_ingreso), ''), serie_guia_ingreso),
            numero_guia_ingreso     = COALESCE(NULLIF(TRIM(p_numero_guia_ingreso), ''), numero_guia_ingreso),
            fecha_llegada_almacen   = COALESCE(v_fecha_llegada, fecha_llegada_almacen),
            fecha_retorno           = COALESCE(v_fecha_llegada, fecha_retorno),
            lote                    = COALESCE(v_lote, lote),
            fecha_vencimiento_lote  = COALESCE(v_fecha_venc_lote, fecha_vencimiento_lote),
            fecha_prueba_hidrostatica = COALESCE(v_fecha_ph, fecha_prueba_hidrostatica),
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion      = NOW()
        WHERE id = p_id_doc_salida AND estado = 1;

        IF v_registrar_retorno THEN
            v_link_planta := bal_finalizar_recarga_planta(
                p_id_recarga_planta        => p_id_doc_salida,
                p_id_comprobante_compra    => v_id_compra,
                p_fecha_llegada_almacen    => v_fecha_llegada,
                p_id_almacen               => COALESCE(p_id_almacen, v_id_almacen_compra),
                p_id_proveedor             => p_id_proveedor,
                p_guardar_balones_almacen  => TRUE,
                p_lote                     => v_lote,
                p_fecha_vencimiento_lote   => v_fecha_venc_lote,
                p_fecha_prueba_hidrostatica => v_fecha_ph,
                p_id_usuario_auditoria     => p_id_usuario_auditoria,
                p_id_lote_protocolo        => v_orden.id_lote_protocolo
            );

            IF v_link_planta->>'error' IS NOT NULL THEN
                RAISE EXCEPTION '%', v_link_planta->>'error';
            END IF;
        ELSIF v_retorno_ya_registrado THEN
            PERFORM bal_sincronizar_gas_retorno_planta(p_id_doc_salida, p_id_usuario_auditoria);
        END IF;
    END IF;

    PERFORM com_generar_cxp_compra(
        v_id_compra,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    IF EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = v_id_compra AND fc.estado = 1
    ) THEN
        UPDATE com_comprobante_compra
        SET id_medio_pago = NULL, id_cuenta_bancaria = NULL, numero_operacion = NULL
        WHERE id = v_id_compra;
    ELSIF p_id_medio_pago IS NULL AND v_total_bruto > 0 THEN
        RAISE EXCEPTION 'Indica el medio de pago: una compra al contado se paga en el momento (efectivo, Yape, transferencia...).';
    END IF;

    v_err_pago := com_assert_caja_compra(NULL, com_pago_caja_compra(v_id_compra));
    IF v_err_pago IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err_pago;
    END IF;

    RETURN com_obtener_compra(v_id_compra);
END;
$function$;

-- Actualiza compra cabecera
DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying
);

DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric
);

DROP FUNCTION IF EXISTS public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying,
  p_id_condicion_pago integer,
  p_id_categoria_gasto integer,
  p_declarar_sunat boolean,
  p_id_usuario_auditoria integer,
  p_fecha_vencimiento_cxp date,
  p_cuotas_cxp jsonb,
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer,
  p_numero_operacion character varying,
  p_porcentaje_igv numeric,
  p_fecha date,
  p_fecha_emision date,
  p_id_tipo_comprobante integer,
  p_serie character varying,
  p_numero character varying
);

-- p_fecha es la FECHA DE GASTO: cambiarla mueve el pago a la caja de la nueva fecha (debe estar abierta);
-- si la caja de origen ya estaba cerrada se recalcula su arqueo. Comprobante (tipo, serie, número, emisión)
-- se completa sin tocar la caja. NULL = conservar; para vaciar: p_serie/p_numero '', p_id_tipo_comprobante 0,
-- p_quitar_fecha_emision TRUE (la compra vuelve a "pendiente de comprobante").
CREATE OR REPLACE FUNCTION public.com_actualizar_compra_cabecera (
  p_id_comprobante integer,
  p_glosa character varying DEFAULT NULL::character varying,
  p_id_condicion_pago integer DEFAULT NULL::integer,
  p_id_categoria_gasto integer DEFAULT NULL::integer,
  p_declarar_sunat boolean DEFAULT NULL::boolean,
  p_id_usuario_auditoria integer DEFAULT NULL::integer,
  p_fecha_vencimiento_cxp date DEFAULT NULL::date,
  p_cuotas_cxp jsonb DEFAULT NULL::jsonb,
  p_id_medio_pago integer DEFAULT NULL::integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer,
  p_numero_operacion character varying DEFAULT NULL::character varying,
  p_porcentaje_igv numeric DEFAULT NULL::numeric,
  p_fecha date DEFAULT NULL::date,
  p_fecha_emision date DEFAULT NULL::date,
  p_id_tipo_comprobante integer DEFAULT NULL::integer,
  p_serie character varying DEFAULT NULL::character varying,
  p_numero character varying DEFAULT NULL::character varying,
  p_quitar_fecha_emision boolean DEFAULT FALSE
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_pago_antes JSONB;
    v_pago_despues JSONB;
    v_tenia_cxp BOOLEAN;
    v_err TEXT;
    v_porcentaje_igv NUMERIC(5,2);
    v_compra RECORD;
    v_mueve_fecha BOOLEAN := FALSE;
    v_id_sesion_origen INTEGER;
    v_arqueo JSON;
    v_observacion TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_emision IS NOT NULL AND p_fecha_emision > CURRENT_DATE THEN
        RETURN json_build_object('error', 'La fecha de emisión no puede ser posterior a hoy', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE id = p_id_comprobante AND estado = 1) THEN
        RETURN json_build_object('error', 'La compra no existe o está anulada', 'registro', NULL);
    END IF;

    IF fin_medio_pago_flag(p_id_medio_pago, 'ES_CREDITO') THEN
        RETURN json_build_object('error', 'El medio de pago de la compra no puede ser crédito: para una compra al crédito elige la condición de pago.', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL THEN
        v_err := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
        IF v_err IS NOT NULL THEN
            RETURN json_build_object('error', v_err, 'registro', NULL);
        END IF;
    END IF;

    IF p_porcentaje_igv IS NOT NULL THEN
        v_porcentaje_igv := ROUND(p_porcentaje_igv, 2);
        IF v_porcentaje_igv < 0 OR v_porcentaje_igv > 100 THEN
            RETURN json_build_object('error', 'El porcentaje de IGV debe estar entre 0 y 100', 'registro', NULL);
        END IF;
    END IF;

    SELECT id, fecha, id_sucursal, total_importe INTO v_compra
    FROM com_comprobante_compra WHERE id = p_id_comprobante;
    v_mueve_fecha := p_fecha IS NOT NULL AND p_fecha <> v_compra.fecha;

    v_pago_antes := com_pago_caja_compra(p_id_comprobante);
    v_tenia_cxp := EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    );

    UPDATE com_comprobante_compra
    SET glosa               = COALESCE(p_glosa, glosa),
        id_condicion_pago   = COALESCE(p_id_condicion_pago, id_condicion_pago),
        id_categoria_gasto  = COALESCE(p_id_categoria_gasto, id_categoria_gasto),
        declarar_sunat      = COALESCE(p_declarar_sunat, declarar_sunat),
        id_medio_pago       = COALESCE(p_id_medio_pago, id_medio_pago),
        id_cuenta_bancaria  = CASE WHEN p_id_medio_pago IS NOT NULL THEN p_id_cuenta_bancaria ELSE id_cuenta_bancaria END,
        numero_operacion    = CASE WHEN p_id_medio_pago IS NOT NULL THEN NULLIF(TRIM(p_numero_operacion), '') ELSE numero_operacion END,
        porcentaje_igv      = COALESCE(v_porcentaje_igv, porcentaje_igv),
        fecha               = COALESCE(p_fecha, fecha),
        fecha_emision       = CASE WHEN COALESCE(p_quitar_fecha_emision, FALSE) THEN NULL
                                   ELSE COALESCE(p_fecha_emision, fecha_emision) END,
        id_tipo_comprobante = CASE WHEN p_id_tipo_comprobante = 0 THEN NULL
                                   ELSE COALESCE(p_id_tipo_comprobante, id_tipo_comprobante) END,
        serie               = CASE WHEN p_serie IS NULL THEN serie ELSE NULLIF(TRIM(p_serie), '') END,
        numero              = CASE WHEN p_numero IS NULL THEN numero ELSE NULLIF(TRIM(p_numero), '') END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id_comprobante;

    IF v_porcentaje_igv IS NOT NULL THEN
        UPDATE com_comprobante_compra
        SET sub_total = ROUND(COALESCE(total_importe, 0) / (1 + v_porcentaje_igv / 100), 4),
            igv       = COALESCE(total_importe, 0) - ROUND(COALESCE(total_importe, 0) / (1 + v_porcentaje_igv / 100), 4)
        WHERE id = p_id_comprobante;
    END IF;

    PERFORM com_sincronizar_cxp_compra(
        p_id_comprobante,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    IF EXISTS (
        SELECT 1 FROM fin_cuenta fc
        WHERE fc.id_comprobante_compra = p_id_comprobante AND fc.estado = 1
    ) THEN
        UPDATE com_comprobante_compra
        SET id_medio_pago = NULL, id_cuenta_bancaria = NULL, numero_operacion = NULL
        WHERE id = p_id_comprobante;
    ELSIF v_tenia_cxp AND EXISTS (
        SELECT 1 FROM com_comprobante_compra
        WHERE id = p_id_comprobante AND id_medio_pago IS NULL AND COALESCE(total_importe, 0) > 0
    ) THEN
        RAISE EXCEPTION 'Indica el medio de pago: al pasar la compra a contado se paga en el momento.';
    END IF;

    v_pago_despues := com_pago_caja_compra(p_id_comprobante);
    IF v_mueve_fecha
       AND v_pago_antes->'idMedioPago' IS NOT DISTINCT FROM v_pago_despues->'idMedioPago'
       AND v_pago_antes->'monto' IS NOT DISTINCT FROM v_pago_despues->'monto' THEN
        -- Solo se mueve la fecha de gasto: basta la caja de destino abierta (decisión de negocio);
        -- la de origen puede estar cerrada y su arqueo se recalcula abajo.
        v_err := com_assert_caja_compra(NULL, v_pago_despues);
    ELSE
        -- Cambios de medio/monto (con o sin cambio de fecha) validan origen y destino como siempre.
        v_err := com_assert_caja_compra(v_pago_antes, v_pago_despues);
    END IF;
    IF v_err IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err;
    END IF;

    IF v_mueve_fecha AND COALESCE((v_pago_antes->>'afectaCaja')::BOOLEAN, FALSE) THEN
        SELECT s.id INTO v_id_sesion_origen
        FROM fin_caja_sesion s
        WHERE s.estado = 1
          AND s.fecha = v_compra.fecha
          AND COALESCE(s.id_sucursal, 0) = COALESCE(v_compra.id_sucursal, 0)
        ORDER BY s.id DESC
        LIMIT 1;

        IF v_id_sesion_origen IS NOT NULL THEN
            -- NULL si la caja de origen sigue abierta: sus totales se recalculan solos en vivo.
            v_arqueo := fin_caja_recalcular_arqueo(v_id_sesion_origen, p_id_usuario_auditoria);

            SELECT 'Compra ' || COALESCE(c.serie || '-' || c.numero, '#' || c.id)
                   || ' movida al ' || to_char(p_fecha, 'DD/MM/YYYY')
            INTO v_observacion
            FROM com_comprobante_compra c WHERE c.id = p_id_comprobante;

            IF v_arqueo IS NOT NULL THEN
                v_observacion := v_observacion || ' · arqueo recalculado, esperado '
                    || ROUND(COALESCE((v_arqueo->>'montoEsperadoAnterior')::NUMERIC, 0), 2)
                    || ' → ' || ROUND((v_arqueo->>'montoEsperado')::NUMERIC, 2);
            END IF;

            INSERT INTO fin_caja_sesion_evento (id_sesion, tipo, monto, diferencia, observacion, id_usuario)
            VALUES (
                v_id_sesion_origen, 'AJUSTE_COMPRA', (v_pago_antes->>'monto')::NUMERIC,
                (v_arqueo->>'diferencia')::NUMERIC, LEFT(v_observacion, 500), p_id_usuario_auditoria
            );
        END IF;
    END IF;

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;

-- Lista compras con filtros y paginación
DROP FUNCTION IF EXISTS public.com_listar_compras (
  p_busqueda character varying,
  p_limite integer,
  p_offset integer,
  p_id_proveedor integer,
  p_id_almacen integer,
  p_fecha_desde date,
  p_fecha_hasta date,
  p_estado integer,
  p_id_tipo_registro integer,
  p_id_categoria_gasto integer,
  p_sin_comprobante boolean
);

CREATE OR REPLACE FUNCTION public.com_listar_compras (
  p_busqueda character varying DEFAULT ''::character varying,
  p_limite integer DEFAULT 10,
  p_offset integer DEFAULT 0,
  p_id_proveedor integer DEFAULT NULL::integer,
  p_id_almacen integer DEFAULT NULL::integer,
  p_fecha_desde date DEFAULT NULL::date,
  p_fecha_hasta date DEFAULT NULL::date,
  p_estado integer DEFAULT NULL::integer,
  p_id_tipo_registro integer DEFAULT NULL::integer,
  p_id_categoria_gasto integer DEFAULT NULL::integer,
  p_sin_comprobante boolean DEFAULT NULL::boolean
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM com_comprobante_compra c
    LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor
    WHERE (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
      AND (p_id_almacen IS NULL OR c.id_almacen = p_id_almacen)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_estado IS NULL OR c.estado = p_estado)
      AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
      AND (p_id_categoria_gasto IS NULL OR c.id_categoria_gasto = p_id_categoria_gasto)
      AND (
          p_sin_comprobante IS NULL
          OR (
              p_sin_comprobante = TRUE
              AND (COALESCE(TRIM(c.serie), '') = '' OR COALESCE(TRIM(c.numero), '') = '' OR c.fecha_emision IS NULL)
          )
          OR (
              p_sin_comprobante = FALSE
              AND COALESCE(TRIM(c.serie), '') <> ''
              AND COALESCE(TRIM(c.numero), '') <> ''
              AND c.fecha_emision IS NOT NULL
          )
      )
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR gen_texto_coincide(COALESCE(c.glosa, ''), p_busqueda)
          OR gen_texto_coincide(cli_texto_busqueda(pr), p_busqueda)
          OR LOWER(COALESCE(pr.nombres, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(pr.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_registros
    FROM (
        SELECT
            c.id, c.serie, c.numero, c.fecha, c.fecha_emision,
            c.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pr.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pr.nombres, pr.apellido_paterno, pr.apellido_materno)), ''),
                pr.numero_documento
            ) AS nombre_proveedor,
            c.id_almacen, alm.nombre AS almacen,
            c.id_tipo_registro, tr.nombre AS tipo_registro,
            c.id_categoria_gasto, cat.nombre AS categoria_gasto,
            c.sub_total, c.total_importe, c.porcentaje_igv,
            c.glosa,
            c.estado,
            (
                COALESCE(TRIM(c.serie), '') <> '' AND COALESCE(TRIM(c.numero), '') <> '' AND c.fecha_emision IS NOT NULL
            ) AS tiene_comprobante,
            com_tiene_movimientos_inventario(c.id) AS tiene_movimientos_inventario,
            c.id_comprobante_referencia
        FROM com_comprobante_compra c
        LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor
        LEFT JOIN gen_almacen alm ON alm.id = c.id_almacen
        LEFT JOIN gen_lista_opciones tr ON tr.id = c.id_tipo_registro
        LEFT JOIN gen_lista_opciones cat ON cat.id = c.id_categoria_gasto
        WHERE (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
          AND (p_id_almacen IS NULL OR c.id_almacen = p_id_almacen)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_estado IS NULL OR c.estado = p_estado)
          AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
          AND (p_id_categoria_gasto IS NULL OR c.id_categoria_gasto = p_id_categoria_gasto)
      AND (
          p_sin_comprobante IS NULL
          OR (
              p_sin_comprobante = TRUE
              AND (COALESCE(TRIM(c.serie), '') = '' OR COALESCE(TRIM(c.numero), '') = '' OR c.fecha_emision IS NULL)
          )
          OR (
              p_sin_comprobante = FALSE
              AND COALESCE(TRIM(c.serie), '') <> ''
              AND COALESCE(TRIM(c.numero), '') <> ''
              AND c.fecha_emision IS NOT NULL
          )
      )
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR gen_texto_coincide(COALESCE(c.glosa, ''), p_busqueda)
              OR gen_texto_coincide(cli_texto_busqueda(pr), p_busqueda)
              OR LOWER(COALESCE(pr.nombres, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.apellido_paterno, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(pr.numero_documento, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;

-- Obtiene compra por id
DROP FUNCTION IF EXISTS public.com_obtener_compra (p_id integer);

CREATE OR REPLACE FUNCTION public.com_obtener_compra (p_id integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_cabecera JSON;
    v_detalle  JSON;
    v_cuenta   JSON;
BEGIN
    SELECT json_build_object(
        'id',                        c.id,
        'id_tipo_comprobante',       c.id_tipo_comprobante,
        'tipo_comprobante',          tc.nombre,
        'serie',                     c.serie,
        'numero',                    c.numero,
        'fecha',                     c.fecha,
        'fecha_emision',             c.fecha_emision,
        'id_proveedor',              c.id_proveedor,
        'proveedor',                 COALESCE(
                                          NULLIF(TRIM(pr.razon_social), ''),
                                          NULLIF(TRIM(CONCAT_WS(' ', pr.nombres, pr.apellido_paterno, pr.apellido_materno)), ''),
                                          pr.numero_documento
                                      ),
        'proveedor_documento',       pr.numero_documento,
        'id_tipo_registro',          c.id_tipo_registro,
        'tipo_registro',             tr.nombre,
        'id_categoria_gasto',        c.id_categoria_gasto,
        'categoria_gasto',           cat.nombre,
        'id_sucursal',               c.id_sucursal,
        'sucursal',                  suc.nombre,
        'id_almacen',                c.id_almacen,
        'almacen',                   alm.nombre,
        'id_moneda',                 c.id_moneda,
        'moneda',                    mon.nombre,
        'id_condicion_pago',         c.id_condicion_pago,
        'condicion_pago',            cp.nombre,
        'id_medio_pago',             c.id_medio_pago,
        'medio_pago',                mp.nombre,
        'id_cuenta_bancaria',        c.id_cuenta_bancaria,
        'cuenta_bancaria',           COALESCE(cb.alias, cb.titular, cb.numero_cuenta),
        'numero_operacion',          c.numero_operacion,
        'sub_total',                 c.sub_total,
        'igv',                       c.igv,
        'porcentaje_igv',            c.porcentaje_igv,
        'total_importe',             c.total_importe,
        'afecta_inventario',         c.afecta_inventario,
        'declarar_sunat',            c.declarar_sunat,
        'glosa',                     c.glosa,
        'id_estado',                 c.id_estado,
        'estado_pago',               est.nombre,
        'estado',                    c.estado,
        'id_comprobante_referencia', c.id_comprobante_referencia,
        'id_recarga_planta',         c.id_doc_salida,
        'numero_recarga_planta',     rp.numero,
        'tiene_movimientos_inventario', com_tiene_movimientos_inventario(c.id),
        'puede_modificarse_parcial', (c.estado = 1),
        'fecha_creacion',            c.fecha_creacion,
        'fecha_modificacion',        c.fecha_modificacion
    )
    INTO v_cabecera
    FROM com_comprobante_compra c
    LEFT JOIN cli_clientes pr             ON pr.id = c.id_proveedor
    LEFT JOIN gen_lista_opciones tc       ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones tr       ON tr.id = c.id_tipo_registro
    LEFT JOIN gen_lista_opciones cat      ON cat.id = c.id_categoria_gasto
    LEFT JOIN gen_sucursal suc            ON suc.id = c.id_sucursal
    LEFT JOIN gen_almacen alm             ON alm.id = c.id_almacen
    LEFT JOIN gen_lista_opciones mon      ON mon.id = c.id_moneda
    LEFT JOIN gen_condicion_pago cp       ON cp.id = c.id_condicion_pago
    LEFT JOIN gen_lista_opciones mp       ON mp.id = c.id_medio_pago
    LEFT JOIN gen_cuenta_bancaria cb      ON cb.id = c.id_cuenta_bancaria
    LEFT JOIN gen_lista_opciones est      ON est.id = c.id_estado
    LEFT JOIN doc_salida rp               ON rp.id = c.id_doc_salida
    WHERE c.id = p_id;

    IF v_cabecera IS NULL THEN
        RETURN json_build_object('error', 'La compra no existe', 'registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(d ORDER BY (d->>'item')::INTEGER), '[]'::json)
    INTO v_detalle
    FROM (
        SELECT json_build_object(
            'id',                     cd.id,
            'item',                   cd.item,
            'id_producto',            cd.id_producto,
            'codigo_producto',        p.codigo,
            'nombre_producto',        p.nombre,
            'descripcion',            cd.descripcion,
            'id_unidad_medida',       cd.id_unidad_medida,
            'unidad_medida',          um.nombre,
            'id_almacen',             cd.id_almacen,
            'almacen',                alm2.nombre,
            'cantidad',               cd.cantidad,
            'precio_unitario',        cd.precio_unitario,
            'importe',                cd.importe,
            'afecta_stock',           cd.afecta_stock,
            'es_gas',                 COALESCE(p.es_gas, FALSE),
            'id_clasificacion_gasto', cd.id_clasificacion_gasto,
            'clasificacion_gasto',    CASE WHEN cg.id IS NOT NULL
                                          THEN cg.grupo || ' > ' || cg.subgrupo || ' > ' || cg.sub_subgrupo
                                          ELSE NULL END,
            'id_estado_pago',         cd.id_estado_pago,
            'fecha_pago',             cd.fecha_pago,
            'estado',                 cd.estado
        ) AS d
        FROM com_comprobante_compra_detalle cd
        JOIN pro_producto p                        ON p.id = cd.id_producto
        LEFT JOIN gen_lista_opciones um             ON um.id = cd.id_unidad_medida
        LEFT JOIN gen_almacen alm2                  ON alm2.id = cd.id_almacen
        LEFT JOIN gen_clasificacion_gasto cg        ON cg.id = cd.id_clasificacion_gasto
        WHERE cd.id_comprobante = p_id
          AND cd.estado = 1
    ) sub;

    SELECT json_build_object(
        'id', fc.id,
        'descripcion', fc.descripcion,
        'numero_cuotas_total', fc.numero_cuotas_total,
        'monto_pendiente', fc.monto_pendiente,
        'monto_abonado', COALESCE(fc.monto_abonado, 0),
        'saldo', COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)),
        'fecha_vencimiento', fc.fecha_vencimiento,
        'cuotas', (
            SELECT COALESCE(json_agg(
                json_build_object(
                    'id', h.id,
                    'numero_cuota', h.numero_cuota,
                    'fecha_vencimiento', h.fecha_vencimiento,
                    'monto_pendiente', h.monto_pendiente,
                    'monto_abonado', COALESCE(h.monto_abonado, 0),
                    'saldo', COALESCE(h.monto_saldo, h.monto_pendiente - COALESCE(h.monto_abonado, 0))
                ) ORDER BY h.numero_cuota
            ), '[]'::json)
            FROM fin_cuenta h
            WHERE h.id_cuenta_padre = fc.id AND h.estado = 1
        )
    )
    INTO v_cuenta
    FROM fin_cuenta fc
    WHERE fc.id_comprobante_compra = p_id
      AND fc.estado = 1
      AND fc.id_cuenta_padre IS NULL
    ORDER BY fc.id
    LIMIT 1;

    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'cabecera', v_cabecera,
            'detalle', v_detalle,
            'cuenta_por_pagar', v_cuenta
        )
    );
END;
$function$;

COMMIT;
