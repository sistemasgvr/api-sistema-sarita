DROP FUNCTION IF EXISTS public.com_crear_compra(integer, character varying, character varying, date, integer, integer, jsonb, integer, integer, integer, integer, integer, integer, integer, boolean, character varying, integer, boolean);
DROP FUNCTION IF EXISTS public.com_crear_compra(integer, character varying, character varying, date, integer, integer, jsonb, integer, integer, integer, integer, integer, integer, integer, boolean, character varying, integer, boolean, date, character varying, date, date, integer, character varying, character varying);

CREATE OR REPLACE FUNCTION public.com_crear_compra(
    p_id_tipo_comprobante integer,
    p_serie character varying,
    p_numero character varying,
    p_fecha date,
    p_id_proveedor integer,
    p_id_almacen integer,
    p_detalles jsonb,
    p_id_comprobante_referencia integer DEFAULT NULL::integer,
    p_id_recarga_planta integer DEFAULT NULL::integer,
    p_id_tipo_registro integer DEFAULT NULL::integer,
    p_id_categoria_gasto integer DEFAULT NULL::integer,
    p_id_sucursal integer DEFAULT NULL::integer,
    p_id_moneda integer DEFAULT NULL::integer,
    p_id_condicion_pago integer DEFAULT NULL::integer,
    p_declarar_sunat boolean DEFAULT false,
    p_glosa character varying DEFAULT NULL::character varying,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_registrar_retorno_balones boolean DEFAULT false,
    p_fecha_llegada_almacen date DEFAULT NULL::date,
    p_lote character varying DEFAULT NULL::character varying,
    p_fecha_vencimiento_lote date DEFAULT NULL::date,
    p_fecha_prueba_hidrostatica date DEFAULT NULL::date,
    p_id_guia_retorno integer DEFAULT NULL::integer,
    p_serie_guia_ingreso character varying DEFAULT NULL::character varying,
    p_numero_guia_ingreso character varying DEFAULT NULL::character varying,
    p_fecha_vencimiento_cxp date DEFAULT NULL::date,
    p_cuotas_cxp jsonb DEFAULT NULL::jsonb
)
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
    v_id_almacen_linea    INTEGER;
    v_cantidad            NUMERIC(12,4);
    v_precio_unitario     NUMERIC(12,6);
    v_afecta_stock        BOOLEAN;
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
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;
 
    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén (por defecto) indicado no existe o está inactivo', 'registro', NULL);
    END IF;
 
    -- El detalle de productos es opcional: se puede registrar la cabecera
    -- (por ejemplo, ligada a una orden de recarga en planta externa) y
    -- agregar las líneas después con com_crear_compra_detalle.
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

    -- La orden debe existir, estar activa, y NO estar ya cerrada/facturada
    -- (id_comprobante_compra ya seteado por bal_finalizar_recarga_planta en
    -- una compra anterior) — si no, se estaría facturando la misma orden
    -- dos veces.
    IF p_id_recarga_planta IS NOT NULL THEN
        SELECT rp.id_comprobante_compra, est.nombre
        INTO v_recarga_id_comprobante, v_recarga_estado_nombre
        FROM bal_recarga_planta rp
        LEFT JOIN gen_lista_opciones est ON est.id = rp.id_estado
        WHERE rp.id = p_id_recarga_planta AND rp.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La orden de recarga en planta externa indicada no existe o está inactiva', 'registro', NULL);
        END IF;

        IF v_recarga_id_comprobante IS NOT NULL OR v_recarga_estado_nombre = 'CERRADO' THEN
            RETURN json_build_object(
                'error', 'La orden de recarga en planta externa indicada ya está cerrada/facturada y no se puede volver a vincular',
                'registro', NULL
            );
        END IF;
    END IF;

    -- IDs de listas resueltos una sola vez (no dentro del loop). Solo hace
    -- falta que estén configuradas si de verdad hay líneas que procesar.
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
        declarar_sunat, glosa, id_comprobante_referencia, id_recarga_planta,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, p_serie, p_numero, p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia, p_id_recarga_planta,
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
            RAISE EXCEPTION 'La línea % no tiene id_producto', v_item;
        END IF;
 
        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'La cantidad de la línea % debe ser mayor a cero', v_item;
        END IF;
 
        IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = v_id_almacen_linea AND estado = 1) THEN
            RAISE EXCEPTION 'El almacén id=% de la línea % no existe o está inactivo', v_id_almacen_linea, v_item;
        END IF;
 
        SELECT afecta_stock INTO v_afecta_stock
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;
 
        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la línea % no existe o está inactivo', v_id_producto, v_item;
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
            v_result_movimiento := pro_crear_movimiento(
                p_fecha                 => p_fecha,
                p_id_producto           => v_id_producto,
                p_id_almacen            => v_id_almacen_linea,
                p_id_tipo_movimiento    => v_id_tipo_ingreso,
                p_cantidad              => v_cantidad,
                p_id_documento_ref      => v_id_detalle,
                p_id_tipo_documento_ref => v_id_tipo_doc_ref,
                p_glosa                 => 'Ingreso por compra ' || p_serie || '-' || p_numero,
                p_id_usuario_auditoria  => p_id_usuario_auditoria
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

    -- Vínculo opcional con orden de recarga planta externa (factura de costo).
    -- El gas NO ingresa a pro_stock: el retorno físico va por bal_actualizar_recarga_planta.
    IF p_id_recarga_planta IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_recarga_planta WHERE id = p_id_recarga_planta AND estado = 1
        ) THEN
            RAISE EXCEPTION 'Orden de recarga planta no encontrada o inactiva';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_recarga_planta
            WHERE id = p_id_recarga_planta
              AND estado = 1
              AND id_proveedor IS NOT NULL
              AND p_id_proveedor IS NOT NULL
              AND id_proveedor <> p_id_proveedor
        ) THEN
            RAISE EXCEPTION 'El proveedor de la compra no coincide con el de la orden de recarga';
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_recarga_planta
            WHERE id = p_id_recarga_planta
              AND estado = 1
              AND id_comprobante_compra IS NOT NULL
              AND id_comprobante_compra <> v_id_compra
        ) THEN
            RAISE EXCEPTION 'La orden de recarga ya tiene otra compra vinculada';
        END IF;

        -- Retorno físico: checkbox o fecha de llegada enviada desde Compras.
        -- Protocolo (lote/venc/P.H.) puede venir en params o ya estar en la orden.
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE)
            OR p_fecha_llegada_almacen IS NOT NULL;

        SELECT
            COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(rp.lote), '')),
            COALESCE(p_fecha_vencimiento_lote, rp.fecha_vencimiento_lote),
            COALESCE(p_fecha_prueba_hidrostatica, rp.fecha_prueba_hidrostatica)
        INTO v_lote, v_fecha_venc_lote, v_fecha_ph
        FROM bal_recarga_planta rp
        WHERE rp.id = p_id_recarga_planta AND rp.estado = 1;

        IF v_registrar_retorno THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);

            IF v_lote IS NULL OR v_fecha_venc_lote IS NULL OR v_fecha_ph IS NULL THEN
                RAISE EXCEPTION
                    'Para registrar el retorno de cilindros indique lote, vencimiento y P.H. (o complételos en la orden de recarga).';
            END IF;
        ELSE
            v_fecha_llegada := NULL;
        END IF;

        v_link_planta := bal_actualizar_recarga_planta(
            p_id                    => p_id_recarga_planta,
            p_id_almacen            => p_id_almacen,
            p_id_guia_retorno       => p_id_guia_retorno,
            p_serie_guia_ingreso    => p_serie_guia_ingreso,
            p_numero_guia_ingreso   => p_numero_guia_ingreso,
            p_id_comprobante_compra => v_id_compra,
            p_serie_factura         => p_serie,
            p_numero_factura        => p_numero,
            p_fecha_llegada_almacen => v_fecha_llegada,
            p_lote                  => v_lote,
            p_fecha_vencimiento_lote => v_fecha_venc_lote,
            p_fecha_prueba_hidrostatica => v_fecha_ph,
            p_id_usuario_auditoria  => p_id_usuario_auditoria
        );

        IF v_link_planta->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_link_planta->>'error';
        END IF;
    END IF;

    -- Crédito / cuotas: genera CxP vinculada a la compra según condición de pago.
    PERFORM com_generar_cxp_compra(
        v_id_compra,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    RETURN com_obtener_compra(v_id_compra);
END;
$function$
