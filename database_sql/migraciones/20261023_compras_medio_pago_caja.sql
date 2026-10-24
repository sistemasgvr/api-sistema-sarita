-- 20261023 — Compras: medio de pago y reflejo en caja.
--
-- Una compra al contado no movía la caja: solo salía dinero al pagar la CxP de
-- una compra al crédito (fin_pago PAGAR). Ahora la compra al contado guarda su
-- medio de pago, la cuenta de la empresa y el Nº de operación (como un gasto de
-- caja, pero con comprobante) y entra a fin_caja_calcular_totales como pago a
-- proveedor del día y la sucursal de la compra. Si el medio afecta caja, crear,
-- editar o anular la compra exige esa caja abierta.
--
-- Las compras al contado existentes quedan sin medio y no cambian ninguna caja.
--
-- Incluye, tal como están en el repo, com_crear_compra y com_anular_compra
-- (con cambios previos que no estaban aplicados en la base: ficha ICP en el
-- retorno de planta y validaciones al anular) y fin_obtener_libro_diario.

ALTER TABLE com_comprobante_compra
    ADD COLUMN IF NOT EXISTS id_medio_pago integer,
    ADD COLUMN IF NOT EXISTS id_cuenta_bancaria integer,
    ADD COLUMN IF NOT EXISTS numero_operacion character varying(80);

ALTER TABLE com_comprobante_compra
    DROP CONSTRAINT IF EXISTS com_comprobante_compra_id_medio_pago_fkey,
    ADD CONSTRAINT com_comprobante_compra_id_medio_pago_fkey FOREIGN KEY (id_medio_pago) REFERENCES public.gen_lista_opciones(id);

ALTER TABLE com_comprobante_compra
    DROP CONSTRAINT IF EXISTS com_comprobante_compra_id_cuenta_bancaria_fkey,
    ADD CONSTRAINT com_comprobante_compra_id_cuenta_bancaria_fkey FOREIGN KEY (id_cuenta_bancaria) REFERENCES public.gen_cuenta_bancaria(id);

-- ===== funciones/compras/com_pago_caja_compra.sql
-- Function: com_pago_caja_compra
-- 20261023: el pago que una compra aporta a la caja, o NULL si no aporta ninguno.
--
-- Solo aporta una compra activa, AL CONTADO (sin CxP activa) y con medio de
-- pago: una al crédito mueve dinero al pagar su CxP (fin_pago), y las compras
-- al contado anteriores a esta fecha no tienen medio y no se reinterpretan como
-- efectivo, porque eso descuadraría el arqueo de cajas ya cerradas.
--
-- Mismo criterio que el bloque de compras al contado de fin_caja_calcular_totales.
-- Los que modifican una compra comparan este valor antes y después del cambio
-- (com_assert_caja_compra) para exigir la caja abierta solo cuando el cambio
-- toca de verdad el arqueo.

DROP FUNCTION IF EXISTS com_pago_caja_compra(p_id_comprobante integer);

CREATE OR REPLACE FUNCTION com_pago_caja_compra(p_id_comprobante integer)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
AS $function$
    SELECT jsonb_build_object(
        'idMedioPago', cc.id_medio_pago,
        'monto',       cc.total_importe,
        'fecha',       cc.fecha,
        'idSucursal',  cc.id_sucursal,
        'afectaCaja',  fin_medio_pago_flag(cc.id_medio_pago, 'AFECTA_CAJA')
    )
    FROM com_comprobante_compra cc
    WHERE cc.id = p_id_comprobante
      AND cc.estado = 1
      AND cc.id_medio_pago IS NOT NULL
      AND COALESCE(cc.total_importe, 0) > 0
      AND NOT EXISTS (
          SELECT 1
          FROM fin_cuenta fc
          WHERE fc.id_comprobante_compra = cc.id
            AND fc.estado = 1
      );
$function$;

-- ===== funciones/compras/com_assert_caja_compra.sql
-- Function: com_assert_caja_compra
-- 20261023: valida que un cambio en el pago de caja de una compra
-- (com_pago_caja_compra antes / después) caiga en una caja abierta.
--
-- Devuelve NULL si es válido o el mensaje de error, igual que
-- fin_caja_assert_abierta. Sin cambio no valida nada: editar la glosa de una
-- compra de un día ya cerrado sigue permitido.
--
-- Solo los medios con AFECTA_CAJA (efectivo, Yape, Plin) exigen la caja: son
-- los que entran al arqueo. Una compra pagada por transferencia puede
-- registrarse aunque la factura llegue días después y esa caja esté cerrada.
-- Se valida la caja del pago anterior y la del nuevo: mover una compra en
-- efectivo de una caja cerrada a otra abierta también altera la cerrada.

DROP FUNCTION IF EXISTS com_assert_caja_compra(p_antes jsonb, p_despues jsonb);

CREATE OR REPLACE FUNCTION com_assert_caja_compra(p_antes jsonb, p_despues jsonb)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_pago JSONB;
    v_err TEXT;
BEGIN
    IF p_antes IS NOT DISTINCT FROM p_despues THEN
        RETURN NULL;
    END IF;

    FOREACH v_pago IN ARRAY ARRAY[p_antes, p_despues]
    LOOP
        CONTINUE WHEN v_pago IS NULL OR NOT COALESCE((v_pago->>'afectaCaja')::BOOLEAN, FALSE);

        IF v_pago->>'idSucursal' IS NULL THEN
            RETURN 'Una compra al contado pagada con un medio que afecta caja necesita sucursal: el pago sale de la caja de esa sucursal.';
        END IF;

        v_err := fin_caja_assert_abierta((v_pago->>'fecha')::DATE, (v_pago->>'idSucursal')::INTEGER);
        IF v_err IS NOT NULL THEN
            RETURN 'El pago de esta compra sale de la caja del ' || to_char((v_pago->>'fecha')::DATE, 'DD/MM/YYYY') || '. ' || v_err;
        END IF;
    END LOOP;

    RETURN NULL;
END;
$function$;

-- ===== funciones/compras/com_obtener_compra.sql
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_obtener_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20260910_compras_detalle_es_gas.sql:
--   el detalle expone es_gas del producto (el editor de la compra lo necesita
--   para validar la cantidad: un gas admite decimales aunque su U.M. sea UNID).
-- Actualizada por database_sql/migraciones/20261023_compras_medio_pago_caja.sql:
--   la cabecera expone el medio de pago, la cuenta y el Nº de operación.
DROP FUNCTION IF EXISTS com_obtener_compra(p_id integer);

CREATE OR REPLACE FUNCTION com_obtener_compra(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
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
        -- Activa: se puede editar cabecera y líneas (ingresos/salidas según afecta_stock)
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
            -- El editor valida la cantidad según la U.M.: los gases admiten
            -- decimales aunque su unidad sea de las que exigen enteros.
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

-- ===== funciones/compras/com_recalcular_totales_compra.sql
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_recalcular_totales_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20261023_compras_medio_pago_caja.sql:
--   cambiar líneas de una compra al contado cambia lo que pagó de la caja, así
--   que exige esa caja abierta (com_assert_caja_compra).
DROP FUNCTION IF EXISTS com_recalcular_totales_compra(p_id_comprobante integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION com_recalcular_totales_compra(p_id_comprobante integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_bruto     NUMERIC(12,4);
    v_tasa_igv        NUMERIC(6,4) := 0.18;
    v_base_imponible  NUMERIC(12,4);
    v_igv_calculado   NUMERIC(12,4);
    v_pago_antes      JSONB;
    v_err             TEXT;
BEGIN
    v_pago_antes := com_pago_caja_compra(p_id_comprobante);

    SELECT COALESCE(SUM(importe), 0) INTO v_total_bruto
    FROM com_comprobante_compra_detalle
    WHERE id_comprobante = p_id_comprobante AND estado = 1;

    v_base_imponible := ROUND(v_total_bruto / (1 + v_tasa_igv), 4);
    v_igv_calculado := v_total_bruto - v_base_imponible;

    UPDATE com_comprobante_compra
    SET sub_total = v_base_imponible,
        igv = v_igv_calculado,
        total_importe = v_total_bruto,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;

    -- Si la cabecera se creó sin líneas (total 0) y ahora hay importe + crédito/cuotas,
    -- genera la CxP (idempotente si ya existe).
    PERFORM com_sincronizar_cxp_compra(p_id_comprobante, p_id_usuario_auditoria);

    v_err := com_assert_caja_compra(v_pago_antes, com_pago_caja_compra(p_id_comprobante));
    IF v_err IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err;
    END IF;
END;
$function$;

-- ===== funciones/compras/com_crear_compra.sql
-- p_id_doc_salida: antes se llamaba p_id_recarga_planta. Desde la Fase 2 la
-- orden de recarga vive en doc_salida, así que el nombre viejo apuntaba a una
-- tabla que ya no existe. Misma posición en la firma: las llamadas posicionales
-- no cambian.
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_crear_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
-- Actualizada por database_sql/migraciones/20260910_recarga_retorno_gas_por_compra.sql:
--   el retorno de cilindros desde Compras solo lo dispara el checkbox
--   (p_registrar_retorno_balones), ya no la fecha de llegada; no exige
--   lote/vencimiento/P.H. (el protocolo va por la ficha ICP del documento de
--   salida); y si la orden ya tiene fecha_llegada_almacen (retorno registrado
--   desde el documento de salida) solo vincula la compra, sin volver a mover
--   inventario.
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   · la orden se bloquea (FOR UPDATE) al validarla: dos compras simultáneas
--     ya no pueden vincular la misma orden (además hay índice único parcial
--     sobre com_comprobante_compra.id_doc_salida);
--   · exige la orden GENERADA / EMITIDA_SUNAT (se quita el check muerto de
--     'CERRADO', que no existe en EstadoCicloSalida);
--   · si el retorno ya estaba registrado, al vincular la factura el gas se
--     re-sincroniza a las cantidades facturadas
--     (bal_sincronizar_gas_retorno_planta) y no se pisa el almacén de llegada;
--   · se elimina p_id_guia_retorno: nunca se persistía (la GRE del proveedor
--     va como serie/número de guía de ingreso, referencial).
-- Actualizada por database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql:
--   · "el retorno ya está registrado" pasa a mirar la ENTRADA_PLANTA_EXTERNA
--     vigente de los envases, no fecha_llegada_almacen. Una orden con la fecha
--     puesta pero sin entrada física (finalizar sin "guardar en almacén")
--     hacía que la compra se saltara el retorno: los cilindros se quedaban
--     EN_RECARGA_EXTERNA y el gas nunca ingresaba;
--   · el almacén de llegada ya no pisa doc_salida.id_almacen (origen de la
--     salida): va a id_almacen_retorno.
-- Actualizada por database_sql/migraciones/20261023_compras_medio_pago_caja.sql:
--   p_id_medio_pago / p_id_cuenta_bancaria / p_numero_operacion: cómo se pagó
--   una compra al contado (obligatorio si tiene importe). Ese pago entra a la
--   caja como pago a proveedor; si el medio afecta caja exige la caja abierta.
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_recarga_planta integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_id_guia_retorno integer, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer, p_id_doc_salida integer, p_id_tipo_registro integer, p_id_categoria_gasto integer, p_id_sucursal integer, p_id_moneda integer, p_id_condicion_pago integer, p_declarar_sunat boolean, p_glosa character varying, p_id_usuario_auditoria integer, p_registrar_retorno_balones boolean, p_fecha_llegada_almacen date, p_lote character varying, p_fecha_vencimiento_lote date, p_fecha_prueba_hidrostatica date, p_serie_guia_ingreso character varying, p_numero_guia_ingreso character varying, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb, p_id_medio_pago integer, p_id_cuenta_bancaria integer, p_numero_operacion character varying);

CREATE OR REPLACE FUNCTION com_crear_compra(p_id_tipo_comprobante integer, p_serie character varying, p_numero character varying, p_fecha date, p_id_proveedor integer, p_id_almacen integer, p_detalles jsonb, p_id_comprobante_referencia integer DEFAULT NULL::integer, p_id_doc_salida integer DEFAULT NULL::integer, p_id_tipo_registro integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer, p_id_moneda integer DEFAULT NULL::integer, p_id_condicion_pago integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT false, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_registrar_retorno_balones boolean DEFAULT false, p_fecha_llegada_almacen date DEFAULT NULL::date, p_lote character varying DEFAULT NULL::character varying, p_fecha_vencimiento_lote date DEFAULT NULL::date, p_fecha_prueba_hidrostatica date DEFAULT NULL::date, p_serie_guia_ingreso character varying DEFAULT NULL::character varying, p_numero_guia_ingreso character varying DEFAULT NULL::character varying, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb, p_id_medio_pago integer DEFAULT NULL::integer, p_id_cuenta_bancaria integer DEFAULT NULL::integer, p_numero_operacion character varying DEFAULT NULL::character varying)
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
        RETURN json_build_object('error', 'La fecha de la compra es obligatoria', 'registro', NULL);
    END IF;

    -- Pago al contado (20261023). Si la condición resulta ser crédito el medio
    -- se descarta más abajo, así que aquí solo se valida que sea coherente.
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

    -- La orden debe existir, estar activa, GENERADA (o con GRE emitida) y sin
    -- otra compra activa vinculada: si no, se estaría facturando la misma orden
    -- dos veces. FOR UPDATE: dos compras que lleguen a la vez por la misma
    -- orden se serializan aquí y la segunda ve el vínculo de la primera.
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
        declarar_sunat, glosa, id_comprobante_referencia, id_doc_salida,
        id_medio_pago, id_cuenta_bancaria, numero_operacion,
        id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_tipo_comprobante, p_serie, p_numero, p_fecha, p_id_proveedor,
        p_id_tipo_registro, p_id_categoria_gasto, p_id_sucursal, p_id_almacen,
        p_id_moneda, p_id_condicion_pago, 0, 0, 0,
        p_declarar_sunat, v_glosa_final, p_id_comprobante_referencia, p_id_doc_salida,
        p_id_medio_pago, p_id_cuenta_bancaria, NULLIF(TRIM(p_numero_operacion), ''),
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

        SELECT afecta_stock, COALESCE(es_gas, FALSE)
        INTO v_afecta_stock, v_es_gas
        FROM pro_producto
        WHERE id = v_id_producto AND estado = 1;

        IF v_afecta_stock IS NULL THEN
            RAISE EXCEPTION 'El producto id=% de la línea % no existe o está inactivo', v_id_producto, v_item;
        END IF;

        -- Payload puede forzar afecta_stock (p.ej. costo de recarga planta = false).
        IF v_linea ? 'afecta_stock' AND jsonb_typeof(v_linea->'afecta_stock') <> 'null' THEN
            v_afecta_stock := COALESCE((v_linea->>'afecta_stock')::BOOLEAN, v_afecta_stock);
        END IF;

        -- Compra vinculada a orden de planta: el gas lo ingresa solo el retorno
        -- (bal_finalizar_recarga_planta / bal_sincronizar_gas_retorno_planta).
        -- La línea es costo.
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

    -- Vínculo opcional con orden de recarga planta externa (factura de costo).
    -- El gas NO ingresa por líneas de compra: lo ingresa el retorno con las
    -- cantidades de esta factura.
    v_id_almacen_compra := p_id_almacen;

    IF p_id_doc_salida IS NOT NULL THEN
        -- Retorno físico: SOLO el checkbox lo dispara. Antes bastaba con que
        -- viniera p_fecha_llegada_almacen, pero el formulario la precarga desde
        -- la orden cuando el retorno ya se registró en el documento de salida,
        -- y eso volvía a disparar el retorno (doble ingreso).
        v_registrar_retorno := COALESCE(p_registrar_retorno_balones, FALSE);

        -- Lote/venc/P.H. ya no son obligatorios para el retorno: el protocolo se
        -- registra por la ficha ICP desde el documento de salida. Si vienen, se
        -- copian a la orden (COALESCE de abajo).
        v_lote := COALESCE(NULLIF(TRIM(p_lote), ''), NULLIF(TRIM(v_orden.lote), ''));
        v_fecha_venc_lote := COALESCE(p_fecha_vencimiento_lote, v_orden.fecha_vencimiento_lote);
        v_fecha_ph := COALESCE(p_fecha_prueba_hidrostatica, v_orden.fecha_prueba_hidrostatica);

        -- El retorno está hecho cuando los envases tienen su ENTRADA_PLANTA_
        -- EXTERNA vigente, no cuando la orden tiene fecha de llegada. Mismo
        -- criterio que bal_finalizar_recarga_planta y bal_sincronizar_gas_
        -- retorno_planta: una fecha sin entrada física dejaba los cilindros en
        -- planta y el gas sin ingresar, y la compra ni lo intentaba.
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

        -- Con el retorno ya registrado (envases + gas) desde el documento de
        -- salida, la compra se vincula y el gas se ajusta a lo facturado, sin
        -- volver a mover los cilindros.
        IF v_registrar_retorno AND NOT v_retorno_ya_registrado THEN
            v_fecha_llegada := COALESCE(p_fecha_llegada_almacen, p_fecha);
        ELSE
            v_registrar_retorno := FALSE;
            v_fecha_llegada := NULL;
        END IF;

        -- Serie/número de factura no se replican: quedan en la compra y las
        -- lecturas de la orden los resuelven por JOIN vía este FK.
        -- id_almacen es el origen de la salida y no se toca; el almacén de
        -- llegada solo se escribe cuando el retorno se registra ahora (con
        -- retorno previo manda el almacén donde entraron los cilindros).
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
            -- El retorno físico de los cilindros (custodia de los envases +
            -- entrada de gas consolidada con las cantidades de esta compra) lo
            -- hace bal_finalizar_recarga_planta. Su parámetro sigue llamándose
            -- p_id_recarga_planta; el rename a p_id_doc_salida fue solo aquí.
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
            -- La factura llegó después del retorno: hasta ahora el stock tenía
            -- el gas declarado en la orden; pasa a tener lo facturado. Si el
            -- retorno se registró "sin guardar en almacén" no hay gas que
            -- ajustar y la función no hace nada.
            PERFORM bal_sincronizar_gas_retorno_planta(p_id_doc_salida, p_id_usuario_auditoria);
        END IF;
    END IF;

    -- Crédito / cuotas: genera CxP vinculada a la compra según condición de pago.
    PERFORM com_generar_cxp_compra(
        v_id_compra,
        p_id_usuario_auditoria,
        p_fecha_vencimiento_cxp,
        p_cuotas_cxp
    );

    -- Al crédito el dinero sale al pagar la CxP: el medio no aplica. Al contado
    -- con importe el medio es obligatorio, y si afecta caja el pago entra al
    -- arqueo de hoy (com_pago_caja_compra), así que la caja debe estar abierta.
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

-- ===== funciones/compras/com_actualizar_compra_cabecera.sql
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_actualizar_compra_cabecera
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
-- Actualizada por database_sql/migraciones/20261023_compras_medio_pago_caja.sql:
--   p_id_medio_pago / p_id_cuenta_bancaria / p_numero_operacion. Con medio se
--   reemplazan los tres (la cuenta y el Nº de operación dependen del medio);
--   sin medio se conservan. Si el cambio altera el pago que la compra aporta a
--   la caja (medio, importe o paso contado ↔ crédito), la caja de la compra
--   debe estar abierta: com_assert_caja_compra.
DROP FUNCTION IF EXISTS com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying, p_id_condicion_pago integer, p_id_categoria_gasto integer, p_declarar_sunat boolean, p_id_usuario_auditoria integer, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb);
DROP FUNCTION IF EXISTS com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying, p_id_condicion_pago integer, p_id_categoria_gasto integer, p_declarar_sunat boolean, p_id_usuario_auditoria integer, p_fecha_vencimiento_cxp date, p_cuotas_cxp jsonb, p_id_medio_pago integer, p_id_cuenta_bancaria integer, p_numero_operacion character varying);

CREATE OR REPLACE FUNCTION com_actualizar_compra_cabecera(p_id_comprobante integer, p_glosa character varying DEFAULT NULL::character varying, p_id_condicion_pago integer DEFAULT NULL::integer, p_id_categoria_gasto integer DEFAULT NULL::integer, p_declarar_sunat boolean DEFAULT NULL::boolean, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_fecha_vencimiento_cxp date DEFAULT NULL::date, p_cuotas_cxp jsonb DEFAULT NULL::jsonb, p_id_medio_pago integer DEFAULT NULL::integer, p_id_cuenta_bancaria integer DEFAULT NULL::integer, p_numero_operacion character varying DEFAULT NULL::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_pago_antes JSONB;
    v_tenia_cxp BOOLEAN;
    v_err TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

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
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion  = NOW()
    WHERE id = p_id_comprobante;

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
        -- Pasó de crédito a contado: ahora se paga en el momento. Una compra al
        -- contado de antes de 20261023 sin medio se puede seguir editando.
        SELECT 1 FROM com_comprobante_compra
        WHERE id = p_id_comprobante AND id_medio_pago IS NULL AND COALESCE(total_importe, 0) > 0
    ) THEN
        RAISE EXCEPTION 'Indica el medio de pago: al pasar la compra a contado se paga en el momento.';
    END IF;

    v_err := com_assert_caja_compra(v_pago_antes, com_pago_caja_compra(p_id_comprobante));
    IF v_err IS NOT NULL THEN
        RAISE EXCEPTION '%', v_err;
    END IF;

    RETURN com_obtener_compra(p_id_comprobante);
END;
$function$;

-- ===== funciones/compras/com_anular_compra.sql
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_anular_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.953Z
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
--   Anular la compra deshace SOLO lo que la compra movió (etiquetado COMPRA):
--   INGRESOs de líneas, cilindros comprados (ENTRADA_COMPRA + su gas) y el gas
--   del retorno de planta facturado (ENTRADA_PLANTA_EXTERNA PRODUCTO).
--   La orden de recarga vinculada se desvincula y conserva su retorno físico
--   (los envases están etiquetados ORDEN_SALIDA): el gas vuelve a lo declarado
--   en las líneas de la orden vía bal_sincronizar_gas_retorno_planta.
--   Antes revertía toda la orden por ('ORDEN_SALIDA', id) —incluida la
--   SALIDA_PLANTA_EXTERNA de ida— y escribía doc_salida.id_estado, columna
--   que no existe (el ciclo real es id_estado_ciclo y no cambia al anular la
--   factura). com_revertir_cilindros_recarga_compra queda eliminada.
-- Actualizada por database_sql/migraciones/20261023_compras_medio_pago_caja.sql:
--   anular una compra al contado devuelve su pago a la caja: si el medio afecta
--   caja, exige la caja de la compra abierta (como fin_anular_pago).
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
    v_orden               RECORD;
    v_hay_pagos_cxp       BOOLEAN;
    v_id_cuenta_padre     INTEGER;
    v_id_tipo_doc_compra  INTEGER;
    v_id_tipo_entrada_compra INTEGER;
    v_ids_balones_compra  INTEGER[];
    v_balon_ocupado       RECORD;
    v_err_caja            TEXT;
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

    v_err_caja := com_assert_caja_compra(com_pago_caja_compra(p_id_comprobante), NULL);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id_comprobante, 'error', v_err_caja);
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

    -- ---------- PASO 1: VALIDACIÓN COMPLETA (sin modificar nada aún) ----------

    -- 1.a Un cilindro comprado que ya salió del almacén (prestado, vendido, en
    --     planta...) no se puede dar de baja como si nunca hubiera entrado.
    IF cardinality(v_ids_balones_compra) > 0 THEN
        SELECT b.codigo_balon, COALESCE(eb.nombre, 'sin estado') AS estado_balon
        INTO v_balon_ocupado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = ANY (v_ids_balones_compra)
          AND b.estado = 1
          AND COALESCE(eb.nombre, '') <> 'DISPONIBLE'
        LIMIT 1;

        IF FOUND THEN
            RETURN json_build_object(
                'eliminado', FALSE, 'id', p_id_comprobante,
                'error', format(
                    'No se puede anular: el cilindro %s comprado con esta factura ya no está disponible en almacén (estado %s).',
                    v_balon_ocupado.codigo_balon, v_balon_ocupado.estado_balon
                )
            );
        END IF;
    END IF;

    -- 1.b Stock suficiente para revertir todos los ingresos de producto que
    --     hizo esta compra, agregados por (producto, almacén): líneas
    --     afecta_stock, gas de cilindros comprados y gas del retorno de planta
    --     facturado. Todos están etiquetados COMPRA + esta compra.
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
              AND v_id_tipo_doc_compra IS NOT NULL
              AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
              AND m.id_documento_origen = p_id_comprobante
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
                  AND EXISTS (
                      SELECT 1 FROM gen_lista_opciones lo
                      WHERE lo.id = m.id_tipo_movimiento
                        AND UPPER(lo.nombre) = 'TRASLADO'
                  )
              )
              -- Evitar doble conteo: líneas de detalle ya cubiertas arriba
              AND NOT (
                  m.naturaleza = 'PRODUCTO'
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
    -- Todo lo etiquetado COMPRA + esta compra: INGRESOs de líneas, cilindros
    -- comprados con su gas y el gas del retorno de planta facturado. Los
    -- envases del retorno están etiquetados ORDEN_SALIDA y no se tocan.
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

    -- Baja lógica de cilindros creados por esta compra (ENTRADA_COMPRA).
    IF cardinality(v_ids_balones_compra) > 0 THEN
        UPDATE bal_balon
        SET estado = 0,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = ANY (v_ids_balones_compra)
          AND estado = 1;
    END IF;

    -- Órdenes de recarga planta que apuntaban a esta compra: se desvinculan y
    -- conservan su ciclo (id_estado_ciclo) y su retorno físico. El gas del
    -- retorno, que era el facturado, vuelve a lo declarado en la orden; si la
    -- orden no tenía retorno registrado no hay nada que ajustar.
    FOR v_orden IN
        SELECT id
        FROM doc_salida
        WHERE id_comprobante_compra = p_id_comprobante
          AND estado = 1
        FOR UPDATE
    LOOP
        UPDATE doc_salida
        SET
            id_comprobante_compra = NULL,
            serie_factura = NULL,
            numero_factura = NULL,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_orden.id;

        PERFORM bal_sincronizar_gas_retorno_planta(v_orden.id, p_id_usuario_auditoria);
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

    -- Baja lógica de CxP vinculada (cabeceras + cuotas hijas). Ya validado sin pagos.
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

-- ===== funciones/caja/fin_caja_calcular_totales.sql
-- Function: fin_caja_calcular_totales
-- Fase 3. Dos cambios de fondo:
--
--   1. La clasificación por medio de pago sale de fin_medio_pago_config, no de
--      `UPPER(mp.nombre) IN ('EFECTIVO','YAPE','PLIN')`. Ese literal estaba
--      repetido en cinco bloques de esta función: añadir un medio nuevo al
--      catálogo lo dejaba fuera del arqueo en silencio. Mismo criterio que
--      inv_signo_tipo_movimiento en F1.
--
--   2. Las ventas se miden por sus líneas de cobro (ven_pagos_de_comprobante),
--      no por el medio único de la cabecera, de modo que una venta cobrada
--      mitad en efectivo y mitad por transferencia aporta a los dos resúmenes.
--
-- Claves nuevas del JSON (las anteriores se conservan):
--   ventasEfectivo, ventasOtrosMedios, cobranzasEfectivo, gastosCajaMediosCaja.
--
-- P0 (20260910): los pagos de cuentas por pagar (CxP de compras) entran al JSON
-- como pagosProveedor / pagosProveedorMediosCaja. Ver el bloque correspondiente.
--
-- 20261007: resumen por medio de pago. Todos los movimientos del día se arman una
-- sola vez en `mov` (tipo, medio, monto) y de ahí salen tanto las claves de siempre
-- como dos nuevas:
--   porMedio     — una fila por medio de pago con movimiento (Efectivo, Yape, Plin,
--                  Transferencia...): ventas, cobranzas, garantías, gastos, pagos a
--                  proveedor, depósitos, ingresos, egresos y neto. Los medios de
--                  crédito no entran: una venta al crédito no mueve dinero.
--   efectivoNeto — el neto de la fila EFECTIVO. Es lo único que se cuenta en el
--                  arqueo: Yape y Plin tienen AFECTA_CAJA pero no son billetes en
--                  el cajón, y sumarlos al "efectivo esperado" hacía que el arqueo
--                  no cuadrara nunca contra el conteo físico.
--
-- 20261023: las compras AL CONTADO con medio de pago también son pagos a
-- proveedor (tipo PAGO_PROVEEDOR): hasta ahora solo salía de la caja el pago de
-- una CxP, así que una compra pagada en efectivo en el momento no restaba del
-- arqueo. Mismo criterio que com_pago_caja_compra.

DROP FUNCTION IF EXISTS fin_caja_calcular_totales(p_fecha date, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_caja_calcular_totales(p_fecha date, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_efectivo_id INT;
    v_ventas_contado NUMERIC(14,4) := 0;
    v_ventas_credito NUMERIC(14,4) := 0;
    v_ventas_caja NUMERIC(14,4) := 0;
    v_ventas_efectivo NUMERIC(14,4) := 0;
    v_ventas_otros NUMERIC(14,4) := 0;
    v_cobranzas NUMERIC(14,4) := 0;
    v_cobranzas_caja NUMERIC(14,4) := 0;
    v_cobranzas_efectivo NUMERIC(14,4) := 0;
    v_pagos_proveedor NUMERIC(14,4) := 0;
    v_pagos_proveedor_caja NUMERIC(14,4) := 0;
    v_gastos_caja NUMERIC(14,4) := 0;
    v_gastos_caja_medios NUMERIC(14,4) := 0;
    v_gastos_compra NUMERIC(14,4) := 0;
    v_depositos NUMERIC(14,4) := 0;
    v_garantias_cobro NUMERIC(14,4) := 0;
    v_garantias_cobro_caja NUMERIC(14,4) := 0;
    v_garantias_dev NUMERIC(14,4) := 0;
    v_garantias_dev_caja NUMERIC(14,4) := 0;
    v_por_medio JSON;
    v_efectivo_neto NUMERIC(14,4) := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Un movimiento sin medio de pago se sigue tratando como efectivo, que es
    -- lo que hacía el COALESCE(mp.nombre, 'EFECTIVO') anterior.
    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    WITH mov AS (
        -- Ventas, medidas por línea de cobro. Una Nota de Crédito referida a una venta
        -- anterior RESTA, en vez de excluirse: su propia c.fecha es el día en que se
        -- emite (hoy), no el día de la venta original, así que una devolución de una
        -- venta de hace días reduce la caja de HOY, no reabre ni altera la caja (ya
        -- cerrada) de aquel día. Nota de débito suma, igual que una venta normal.
        -- Antes ambas quedaban excluidas del todo, así que una NC no reducía la caja
        -- en ningún día — la venta original se quedaba contada para siempre.
        --
        -- Un comprobante dado de baja ante SUNAT (comunicación de baja, ven_estado_sunat
        -- = 'BAJA') también se excluye de su propio día: es la otra forma real de anular
        -- una factura/nota ya aceptada (no genera NC), y no existía ningún campo que lo
        -- reflejara aquí — c.id_estado nunca se setea a ANULADO en ese flujo, solo
        -- c.id_estado_sunat pasa a BAJA.
        SELECT
            'VENTA'::TEXT AS tipo,
            COALESCE(pg.id_medio_pago, v_efectivo_id) AS id_medio_pago,
            pg.monto * CASE WHEN UPPER(COALESCE(tip.nombre, '')) = 'NOTA_CREDITO' THEN -1 ELSE 1 END AS monto
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        WHERE c.estado = 1
          AND c.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          -- VSD/NV convertida a boleta/factura: el cobro ya cuenta en el CPE destino.
          -- Marca: existe otro comprobante activo con id_comprobante_origen = VSD.
          AND NOT (
              UPPER(COALESCE(tip.descripcion, '')) IN ('NV', 'VSD')
              AND EXISTS (
                  SELECT 1
                  FROM ven_comprobante conv
                  WHERE conv.id_comprobante_origen = c.id
                    AND conv.estado = 1
              )
          )

        UNION ALL

        -- Cobranzas de cuentas por cobrar (COBRAR) y pagos de cuentas por pagar
        -- (PAGAR, la CxP que genera una compra a crédito). Excluye abonos contables
        -- AJUSTE_NC: no son cobros ni pagos reales, abonan la cuenta sin mover dinero.
        --
        -- fin_registrar_pago exige caja abierta para registrar un PAGAR, pero hasta el
        -- P0 (20260910) aquí solo se sumaban los COBRAR, así que el dinero entregado al
        -- proveedor salía del cajón sin restarse del arqueo.
        --
        -- Deliberadamente los PAGAR NO se suman a `gastos` ni a `gastosCompra`:
        -- gastosCompra mide el devengo de las compras tipo GASTO por su fecha de
        -- emisión, esté pagada o no, así que sumar aquí el pago de una de esas compras
        -- a crédito contaría el mismo importe dos veces. gastosCompra tampoco entra en
        -- el arqueo, de modo que restar el pago del efectivo no duplica ninguna salida.
        SELECT
            CASE WHEN UPPER(tc.nombre) = 'COBRAR' THEN 'COBRANZA' ELSE 'PAGO_PROVEEDOR' END,
            COALESCE(p.id_medio_pago, v_efectivo_id),
            p.monto
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        WHERE p.estado = 1
          AND p.fecha_pago = p_fecha
          AND UPPER(tc.nombre) IN ('COBRAR', 'PAGAR')
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        -- Compras al contado: se pagan el día de la compra con el medio que
        -- indica su cabecera. Sin CxP activa (una al crédito sale por fin_pago,
        -- arriba) y con medio: las compras al contado anteriores al 20261023 no
        -- lo tienen y no se reinterpretan como efectivo, porque cambiaría el
        -- arqueo de cajas ya cerradas. Igual que los PAGAR, no se suman a
        -- gastosCompra, que mide el devengo de las compras tipo GASTO.
        SELECT 'PAGO_PROVEEDOR', cc.id_medio_pago, cc.total_importe
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND cc.fecha = p_fecha
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )

        UNION ALL

        -- Gastos de caja. Solo los pagados con un medio que afecta caja salen del
        -- arqueo: un gasto pagado por transferencia no vacía el cajón.
        SELECT 'GASTO', COALESCE(g.id_medio_pago, v_efectivo_id), g.monto
        FROM fin_caja_gasto g
        LEFT JOIN fin_caja_sesion s ON s.id = g.id_sesion AND s.estado = 1
        WHERE g.estado = 1 AND g.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        -- Depósitos al banco: billetes que salen del cajón. d.id_medio_pago dice cómo
        -- llegaron al banco (depósito, transferencia), no de dónde salieron, así que
        -- el depósito siempre se descuenta del efectivo.
        SELECT 'DEPOSITO', v_efectivo_id, d.monto
        FROM fin_caja_deposito d
        LEFT JOIN fin_caja_sesion s ON s.id = d.id_sesion AND s.estado = 1
        WHERE d.estado = 1 AND d.fecha = p_fecha
          AND (p_id_sucursal IS NULL OR s.id_sucursal = p_id_sucursal)

        UNION ALL

        -- Cobros de garantía. El monto de una garantía (ven_garantia/ven_garantia_movimiento)
        -- nunca viaja dentro de c.total_importe del comprobante al que queda ligada — el POS
        -- la registra como efecto aparte de ven_aplicar_efectos_pos, nunca como línea de venta
        -- (ver PosVentaPanel.vue/PosAlquilerPanel.vue: "totales" solo suma líneas de producto,
        -- la garantía es un campo separado) — así que excluirla cuando gm.id_comprobante
        -- apuntaba a una boleta/factura/NV dejaba esas garantías (el caso normal: casi toda
        -- garantía se cobra junto a una venta) fuera del arqueo de caja por completo.
        SELECT 'GARANTIA_COBRO', COALESCE(gm.id_medio_pago, g.id_medio_pago, v_efectivo_id), gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'COBRO'
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          )

        UNION ALL

        SELECT
            'GARANTIA_DEVOLUCION',
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago, v_efectivo_id),
            gm.monto
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        WHERE gm.estado = 1
          AND gm.fecha = p_fecha
          AND UPPER(tm.nombre) = 'DEVOLUCION'
          AND (
              p_id_sucursal IS NULL
              OR gm.id_sucursal = p_id_sucursal
          )
    ),
    m AS (
        SELECT
            mov.tipo,
            mov.id_medio_pago,
            mov.monto,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_CREDITO')  AS es_credito,
            fin_medio_pago_flag(mov.id_medio_pago, 'AFECTA_CAJA') AS afecta_caja,
            fin_medio_pago_flag(mov.id_medio_pago, 'ES_EFECTIVO') AS es_efectivo
        FROM mov
    ),
    por_medio AS (
        SELECT
            m.id_medio_pago,
            BOOL_OR(m.es_efectivo) AS es_efectivo,
            BOOL_OR(m.afecta_caja) AS afecta_caja,
            SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA') AS ventas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA') AS cobranzas,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO') AS garantias_cobro,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO') AS gastos,
            SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR') AS pagos_proveedor,
            SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION') AS garantias_devolucion,
            SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO') AS depositos
        FROM m
        WHERE NOT m.es_credito
        GROUP BY m.id_medio_pago
    )
    SELECT
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_credito), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'VENTA' AND NOT m.es_credito AND NOT m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'COBRANZA' AND m.es_efectivo), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'PAGO_PROVEEDOR' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GASTO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'DEPOSITO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_COBRO' AND m.afecta_caja), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION'), 0),
        COALESCE(SUM(m.monto) FILTER (WHERE m.tipo = 'GARANTIA_DEVOLUCION' AND m.afecta_caja), 0),
        COALESCE(SUM(CASE
            WHEN m.tipo IN ('VENTA', 'COBRANZA', 'GARANTIA_COBRO') THEN m.monto
            ELSE -m.monto END) FILTER (WHERE m.es_efectivo), 0),
        (
            SELECT COALESCE(json_agg(row_to_json(r) ORDER BY r.orden, r."medioPago"), '[]'::JSON)
            FROM (
                SELECT
                    pm.id_medio_pago AS "idMedioPago",
                    COALESCE(o.nombre, 'SIN MEDIO') AS "medioPago",
                    pm.es_efectivo AS "esEfectivo",
                    pm.afecta_caja AS "afectaCaja",
                    COALESCE(pm.ventas, 0) AS ventas,
                    COALESCE(pm.cobranzas, 0) AS cobranzas,
                    COALESCE(pm.garantias_cobro, 0) AS "garantiasCobro",
                    COALESCE(pm.gastos, 0) AS gastos,
                    COALESCE(pm.pagos_proveedor, 0) AS "pagosProveedor",
                    COALESCE(pm.garantias_devolucion, 0) AS "garantiasDevolucion",
                    COALESCE(pm.depositos, 0) AS depositos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0) AS ingresos,
                    COALESCE(pm.gastos, 0) + COALESCE(pm.pagos_proveedor, 0)
                        + COALESCE(pm.garantias_devolucion, 0) + COALESCE(pm.depositos, 0) AS egresos,
                    COALESCE(pm.ventas, 0) + COALESCE(pm.cobranzas, 0)
                        + COALESCE(pm.garantias_cobro, 0)
                        - COALESCE(pm.gastos, 0) - COALESCE(pm.pagos_proveedor, 0)
                        - COALESCE(pm.garantias_devolucion, 0) - COALESCE(pm.depositos, 0) AS neto,
                    COALESCE(cfg.orden, 999) AS orden
                FROM por_medio pm
                LEFT JOIN gen_lista_opciones o ON o.id = pm.id_medio_pago
                LEFT JOIN fin_medio_pago_config cfg ON cfg.id_medio_pago = pm.id_medio_pago
            ) r
        )
    INTO v_ventas_contado, v_ventas_credito, v_ventas_caja, v_ventas_efectivo, v_ventas_otros,
         v_cobranzas, v_cobranzas_caja, v_cobranzas_efectivo,
         v_pagos_proveedor, v_pagos_proveedor_caja,
         v_gastos_caja, v_gastos_caja_medios,
         v_depositos,
         v_garantias_cobro, v_garantias_cobro_caja,
         v_garantias_dev, v_garantias_dev_caja,
         v_efectivo_neto,
         v_por_medio
    FROM m;

    SELECT COALESCE(SUM(cc.total_importe), 0)
    INTO v_gastos_compra
    FROM com_comprobante_compra cc
    LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
    WHERE cc.estado = 1
      AND cc.fecha = p_fecha
      AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
      AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal);

    RETURN json_build_object(
        'ventasContado', v_ventas_contado,
        'ventasCredito', v_ventas_credito,
        'ventasMediosCaja', v_ventas_caja,
        'ventasEfectivo', v_ventas_efectivo,
        'ventasOtrosMedios', v_ventas_otros,
        'cobranzas', v_cobranzas,
        'cobranzasMediosCaja', v_cobranzas_caja,
        'cobranzasEfectivo', v_cobranzas_efectivo,
        'pagosProveedor', v_pagos_proveedor,
        'pagosProveedorMediosCaja', v_pagos_proveedor_caja,
        'gastosCaja', v_gastos_caja,
        'gastosCajaMediosCaja', v_gastos_caja_medios,
        'gastosCompra', v_gastos_compra,
        'gastos', v_gastos_caja + v_gastos_compra,
        'depositos', v_depositos,
        'garantiasCobro', v_garantias_cobro,
        'garantiasCobroMediosCaja', v_garantias_cobro_caja,
        'garantiasDevolucion', v_garantias_dev,
        'garantiasDevolucionMediosCaja', v_garantias_dev_caja,
        'efectivoNeto', v_efectivo_neto,
        'porMedio', v_por_medio
    );
END;
$function$;

-- ===== funciones/caja/fin_obtener_libro_diario.sql
-- Function: fin_obtener_libro_diario
-- Fase 3 — el historial de caja se organiza en pestañas por resumen (apunte
-- 1.a.ii). El payload gana tres cosas, todas aditivas:
--
--   * `ventasPagos`  — una fila por línea de cobro (ven_pagos_de_comprobante),
--     de modo que una venta cobrada mitad en efectivo y mitad por transferencia
--     aparezca en las dos pestañas. El array `ventas` (una fila por comprobante)
--     se conserva intacto porque de él viven LibroDiarioView y la exportación a
--     Excel.
--   * `garantias`    — cobros y devoluciones de garantía, que hasta ahora se
--     sumaban en los totales pero no se podían listar.
--   * `resumenes`    — la definición de las pestañas: clave, etiqueta, signo
--     respecto de la caja, total y número de filas. El frontend dibuja las
--     pestañas a partir de esto en vez de tener la lista hardcodeada, así que
--     añadir un resumen nuevo no obliga a tocar el Vue.
--
-- No se creó una tabla `fin_caja_resumen`: los resúmenes son datos derivados y
-- una tabla exigiría mantenerla sincronizada con cada venta, gasto y depósito.
--
-- P0 (20260910): `pagosProveedor` — pagos de cuentas por pagar (CxP de compras),
-- con su propio resumen de signo -1. Antes el libro heredaba el sesgo de
-- fin_caja_calcular_totales y solo listaba los pagos de cuentas COBRAR.
--
-- 20261023: `pagosProveedor` también lista las compras al contado con medio de
-- pago (origen CONTADO), que fin_caja_calcular_totales ya suma a pagosProveedor.
-- Cada fila trae `clave` (P<id pago> / C<id compra>): los ids de fin_pago y de
-- com_comprobante_compra pueden coincidir.

DROP FUNCTION IF EXISTS fin_obtener_libro_diario(p_fecha_desde date, p_fecha_hasta date, p_id_cliente integer, p_id_sucursal integer);

CREATE OR REPLACE FUNCTION fin_obtener_libro_diario(p_fecha_desde date, p_fecha_hasta date DEFAULT NULL::date, p_id_cliente integer DEFAULT NULL::integer, p_id_sucursal integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_hasta DATE;
    v_efectivo_id INT;
    v_ventas JSON;
    v_ventas_pagos JSON;
    v_cobranzas JSON;
    v_pagos_proveedor JSON;
    v_gastos JSON;
    v_depositos JSON;
    v_garantias JSON;
    v_observaciones JSON;
    v_totales JSON;
    v_dias JSON;
    v_resumenes JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_fecha_desde IS NULL THEN
        RETURN json_build_object('error', 'fechaDesde es obligatoria', 'registro', NULL);
    END IF;

    v_hasta := COALESCE(p_fecha_hasta, p_fecha_desde);

    IF v_hasta < p_fecha_desde THEN
        RETURN json_build_object('error', 'fechaHasta no puede ser menor que fechaDesde', 'registro', NULL);
    END IF;

    SELECT o.id INTO v_efectivo_id
    FROM gen_lista_opciones o
    JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
    WHERE UPPER(o.nombre) = 'EFECTIVO'
    LIMIT 1;

    -- Ventas (una fila por comprobante) — forma histórica, sin cambios.
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_ventas
    FROM (
        SELECT
            c.id,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            c.serie,
            c.numero,
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            mp.nombre AS "medioPago",
            CASE WHEN UPPER(COALESCE(mp.nombre, '')) = 'CREDITO' THEN true ELSE false END AS "esCredito",
            c.total_importe AS "totalImporte",
            (
                SELECT string_agg(
                    COALESCE(d.descripcion, pr.nombre)
                    || CASE WHEN d.cantidad IS NOT NULL THEN ' × ' || gen_formato_cantidad(d.cantidad) ELSE '' END
                    || CASE WHEN um.nombre IS NOT NULL THEN ' ' || um.nombre ELSE '' END,
                    '; '
                )
                FROM ven_comprobante_detalle d
                LEFT JOIN pro_producto pr ON pr.id = d.id_producto
                LEFT JOIN gen_lista_opciones um ON um.id = COALESCE(d.id_unidad_medida, pr.id_unidad_medida)
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS "detalleProductos"
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones mp ON mp.id = c.id_medio_pago
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          AND NOT (
              UPPER(COALESCE(tip.descripcion, '')) IN ('NV', 'VSD')
              AND EXISTS (
                  SELECT 1
                  FROM ven_comprobante conv
                  WHERE conv.id_comprobante_origen = c.id
                    AND conv.estado = 1
              )
          )
    ) t;

    -- Ventas por línea de cobro. `grupo` es la pestaña a la que pertenece.
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t."idComprobante", t.item), '[]'::json)
    INTO v_ventas_pagos
    FROM (
        SELECT
            c.id AS "idComprobante",
            pg.id_pago AS "idPago",
            pg.item,
            c.fecha,
            tip.nombre AS "tipoComprobante",
            (c.serie || '-' || c.numero) AS "serieNumero",
            c.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            pg.id_medio_pago AS "idMedioPago",
            COALESCE(mp.nombre, mpe.nombre) AS "medioPago",
            pg.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            pg.numero_operacion AS "numeroOperacion",
            pg.monto,
            pg.origen,
            CASE
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_CREDITO')
                    THEN 'CREDITO'
                WHEN fin_medio_pago_flag(COALESCE(pg.id_medio_pago, v_efectivo_id), 'ES_EFECTIVO')
                    THEN 'EFECTIVO'
                ELSE 'OTROS'
            END AS grupo
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tip ON tip.id = c.id_tipo_comprobante
        LEFT JOIN gen_lista_opciones est ON est.id = c.id_estado
        LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
        LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
        CROSS JOIN LATERAL ven_pagos_de_comprobante(c.id) pg
        LEFT JOIN gen_lista_opciones mp ON mp.id = pg.id_medio_pago
        LEFT JOIN gen_lista_opciones mpe ON mpe.id = v_efectivo_id
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pg.id_cuenta_bancaria
        WHERE c.estado = 1
          AND c.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_sucursal IS NULL OR c.id_sucursal = p_id_sucursal)
          AND COALESCE(UPPER(est.nombre), '') <> 'ANULADO'
          AND COALESCE(UPPER(es.nombre), '') <> 'BAJA'
          AND COALESCE(UPPER(tip.nombre), '') NOT IN ('NOTA_CREDITO', 'NOTA_DEBITO')
          AND NOT (
              UPPER(COALESCE(tip.descripcion, '')) IN ('NV', 'VSD')
              AND EXISTS (
                  SELECT 1
                  FROM ven_comprobante conv
                  WHERE conv.id_comprobante_origen = c.id
                    AND conv.estado = 1
              )
          )
    ) t;

    -- Cobranzas
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.id), '[]'::json)
    INTO v_cobranzas
    FROM (
        SELECT
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            cu.id_tercero AS "idCliente"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes cli ON cli.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'COBRAR'
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          -- Mismo filtro de sucursal que fin_caja_calcular_totales. Sin él, la
          -- pestaña mostraba filas de otra sucursal bajo un total que las excluía.
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )
    ) t;

    -- Pagos de cuentas por pagar (CxP de compras). P0 (20260910): el libro solo
    -- listaba los pagos de cuentas COBRAR, así que el dinero entregado a un
    -- proveedor no aparecía en ninguna pestaña aunque hubiera salido del cajón.
    -- Va aparte de `gastos` a propósito: ahí conviven los gastos de caja con el
    -- devengo de las compras tipo GASTO, y el pago de una de esas compras a
    -- crédito aparecería dos veces si se mezclaran.
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t."fechaPago", t.clave), '[]'::json)
    INTO v_pagos_proveedor
    FROM (
        SELECT
            'P' || p.id AS clave,
            'CXP' AS origen,
            p.id,
            p.fecha_pago AS "fechaPago",
            p.monto,
            p.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            p.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            p.numero_operacion AS "numeroOperacion",
            p.observacion,
            cu.id AS "idCuenta",
            cu.id_tercero AS "idProveedor",
            COALESCE(
                NULLIF(TRIM(cu.tercero_nombre), ''),
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ) AS proveedor,
            -- En un plan de cuotas la compra la referencia la cabecera, no la cuota.
            COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra) AS "idCompra",
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '') AS "compraSerieNumero"
        FROM fin_pago p
        INNER JOIN fin_cuenta cu ON cu.id = p.id_cuenta AND cu.estado = 1
        INNER JOIN gen_lista_opciones tc ON tc.id = cu.id_tipo_cuenta
        LEFT JOIN fin_cuenta pad ON pad.id = cu.id_cuenta_padre
        LEFT JOIN com_comprobante_compra cc
               ON cc.id = COALESCE(cu.id_comprobante_compra, pad.id_comprobante_compra)
        LEFT JOIN gen_lista_opciones mp ON mp.id = p.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = p.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cu.id_tercero
        WHERE p.estado = 1
          AND p.fecha_pago BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tc.nombre) = 'PAGAR'
          AND COALESCE(UPPER(mp.nombre), '') <> 'AJUSTE_NC'
          -- Clientes y proveedores viven en cli_clientes, así que el filtro de
          -- tercero se aplica igual que en cobranzas.
          AND (p_id_cliente IS NULL OR cu.id_tercero = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(p.id_sucursal, fin_sucursal_de_cuenta(cu.id)) = p_id_sucursal
          )

        UNION ALL

        -- Compras al contado: mismo filtro que su bloque en fin_caja_calcular_totales.
        SELECT
            'C' || cc.id,
            'CONTADO',
            cc.id,
            cc.fecha,
            cc.total_importe,
            cc.id_medio_pago,
            mp.nombre,
            cc.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta),
            cc.numero_operacion,
            cc.glosa,
            NULL::INTEGER,
            cc.id_proveedor,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), '')
            ),
            cc.id,
            NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), '')
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones mp ON mp.id = cc.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = cc.id_cuenta_bancaria
        LEFT JOIN cli_clientes ter ON ter.id = cc.id_proveedor
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND cc.id_medio_pago IS NOT NULL
          AND COALESCE(cc.total_importe, 0) > 0
          AND (p_id_cliente IS NULL OR cc.id_proveedor = p_id_cliente)
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
          AND NOT EXISTS (
              SELECT 1 FROM fin_cuenta fc
              WHERE fc.id_comprobante_compra = cc.id AND fc.estado = 1
          )
    ) t;

    -- Gastos (caja menudos + compras tipo GASTO)
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.origen, t.id), '[]'::json)
    INTO v_gastos
    FROM (
        SELECT
            g.id,
            g.fecha,
            'CAJA'::text AS origen,
            g.concepto,
            g.monto,
            g.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            g.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            g.observacion
        FROM fin_caja_gasto g
        LEFT JOIN gen_lista_opciones mp ON mp.id = g.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN fin_caja_sesion sg ON sg.id = g.id_sesion AND sg.estado = 1
        WHERE g.estado = 1
          AND g.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sg.id_sucursal = p_id_sucursal)
        UNION ALL
        SELECT
            cc.id,
            cc.fecha,
            'COMPRA'::text AS origen,
            COALESCE(
                NULLIF(TRIM(cc.glosa), ''),
                NULLIF(TRIM(CONCAT_WS('-', cc.serie, cc.numero)), ''),
                'Gasto compra'
            ) AS concepto,
            cc.total_importe AS monto,
            NULL::integer AS "idMedioPago",
            NULL::varchar AS "medioPago",
            NULL::integer AS "idCuentaBancaria",
            NULL::varchar AS "cuentaBancaria",
            cc.glosa AS observacion
        FROM com_comprobante_compra cc
        LEFT JOIN gen_lista_opciones tr ON tr.id = cc.id_tipo_registro
        WHERE cc.estado = 1
          AND cc.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(COALESCE(tr.nombre, '')) = 'GASTO'
          AND (p_id_sucursal IS NULL OR cc.id_sucursal = p_id_sucursal)
    ) t;

    -- Depósitos
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_depositos
    FROM (
        SELECT
            d.id,
            d.fecha,
            d.monto,
            d.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            d.id_medio_pago AS "idMedioPago",
            mp.nombre AS "medioPago",
            d.numero_operacion AS "numeroOperacion",
            d.observacion
        FROM fin_caja_deposito d
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = d.id_cuenta_bancaria
        LEFT JOIN gen_lista_opciones mp ON mp.id = d.id_medio_pago
        LEFT JOIN fin_caja_sesion sd ON sd.id = d.id_sesion AND sd.estado = 1
        WHERE d.estado = 1
          AND d.fecha BETWEEN p_fecha_desde AND v_hasta
          AND (p_id_sucursal IS NULL OR sd.id_sucursal = p_id_sucursal)
    ) t;

    -- Garantías: cobros y devoluciones, con el mismo criterio de exclusión que
    -- fin_caja_calcular_totales (los cobros ya incluidos en un CPE no se repiten).
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_garantias
    FROM (
        SELECT
            gm.id,
            gm.fecha,
            UPPER(tm.nombre) AS tipo,
            gm.id_garantia AS "idGarantia",
            gm.monto,
            COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago) AS "idMedioPago",
            mp.nombre AS "medioPago",
            gm.id_cuenta_bancaria AS "idCuentaBancaria",
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS "cuentaBancaria",
            gm.numero_operacion AS "numeroOperacion",
            g.id_cliente AS "idCliente",
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno))
            ) AS cliente,
            gm.observacion
        FROM ven_garantia_movimiento gm
        INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
        LEFT JOIN ven_garantia g ON g.id = gm.id_garantia
        LEFT JOIN cli_clientes cli ON cli.id = g.id_cliente
        LEFT JOIN ven_comprobante c ON c.id = gm.id_comprobante
        LEFT JOIN gen_lista_opciones mp
               ON mp.id = COALESCE(gm.id_medio_pago, g.id_medio_reembolso, g.id_medio_pago)
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = gm.id_cuenta_bancaria
        WHERE gm.estado = 1
          AND gm.fecha BETWEEN p_fecha_desde AND v_hasta
          AND UPPER(tm.nombre) IN ('COBRO', 'DEVOLUCION')
          AND (p_id_cliente IS NULL OR g.id_cliente = p_id_cliente)
          AND (
              p_id_sucursal IS NULL
              OR COALESCE(gm.id_sucursal, c.id_sucursal) = p_id_sucursal
          )
          -- Mismo criterio que fin_caja_calcular_totales: el cobro junto a un CPE
          -- también entra (no viaja en total_importe de la venta).
    ) t;

    -- Observaciones
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.fecha, t.id), '[]'::json)
    INTO v_observaciones
    FROM (
        SELECT
            o.id,
            o.fecha,
            o.texto,
            u.nombre AS usuario,
            o.fecha_creacion AS "fechaCreacion"
        FROM fin_caja_observacion o
        LEFT JOIN auth_usuarios u ON u.id = o.id_usuario_creacion
        WHERE o.estado = 1
          AND o.fecha BETWEEN p_fecha_desde AND v_hasta
    ) t;

    -- Totales del rango (suma día a día cuando hay filtro sucursal; si no, una pasada)
    SELECT json_build_object(
        'ventasContado', COALESCE(SUM((t.tot->>'ventasContado')::NUMERIC), 0),
        'ventasCredito', COALESCE(SUM((t.tot->>'ventasCredito')::NUMERIC), 0),
        'ventasMediosCaja', COALESCE(SUM((t.tot->>'ventasMediosCaja')::NUMERIC), 0),
        'ventasEfectivo', COALESCE(SUM((t.tot->>'ventasEfectivo')::NUMERIC), 0),
        'ventasOtrosMedios', COALESCE(SUM((t.tot->>'ventasOtrosMedios')::NUMERIC), 0),
        'cobranzas', COALESCE(SUM((t.tot->>'cobranzas')::NUMERIC), 0),
        'cobranzasMediosCaja', COALESCE(SUM((t.tot->>'cobranzasMediosCaja')::NUMERIC), 0),
        'cobranzasEfectivo', COALESCE(SUM((t.tot->>'cobranzasEfectivo')::NUMERIC), 0),
        'pagosProveedor', COALESCE(SUM((t.tot->>'pagosProveedor')::NUMERIC), 0),
        'pagosProveedorMediosCaja', COALESCE(SUM((t.tot->>'pagosProveedorMediosCaja')::NUMERIC), 0),
        'gastosCaja', COALESCE(SUM((t.tot->>'gastosCaja')::NUMERIC), 0),
        'gastosCajaMediosCaja', COALESCE(SUM((t.tot->>'gastosCajaMediosCaja')::NUMERIC), 0),
        'gastosCompra', COALESCE(SUM((t.tot->>'gastosCompra')::NUMERIC), 0),
        'gastos', COALESCE(SUM((t.tot->>'gastos')::NUMERIC), 0),
        'depositos', COALESCE(SUM((t.tot->>'depositos')::NUMERIC), 0),
        'garantiasCobro', COALESCE(SUM((t.tot->>'garantiasCobro')::NUMERIC), 0),
        'garantiasCobroMediosCaja', COALESCE(SUM((t.tot->>'garantiasCobroMediosCaja')::NUMERIC), 0),
        'garantiasDevolucion', COALESCE(SUM((t.tot->>'garantiasDevolucion')::NUMERIC), 0),
        'garantiasDevolucionMediosCaja', COALESCE(SUM((t.tot->>'garantiasDevolucionMediosCaja')::NUMERIC), 0)
    )
    INTO v_totales
    FROM (
        SELECT fin_caja_calcular_totales(d::date, p_id_sucursal) AS tot
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) t;

    -- Desglose por día (útil en filtro mes)
    SELECT COALESCE(json_agg(row_to_json(x) ORDER BY x.fecha), '[]'::json)
    INTO v_dias
    FROM (
        SELECT
            d::date AS fecha,
            fin_caja_calcular_totales(d::date, p_id_sucursal) AS totales
        FROM generate_series(p_fecha_desde, v_hasta, '1 day'::interval) d
    ) x;

    -- Definición de las pestañas del historial.
    --   coleccion -> array del payload del que salen las filas
    --   filtroCampo/filtroValor -> cómo quedarse con las filas de esa pestaña
    --   signo -> +1 entra a caja, -1 sale, 0 no mueve caja
    SELECT json_agg(row_to_json(r) ORDER BY r.orden)
    INTO v_resumenes
    FROM (
        VALUES
            ('ventas_efectivo',    'Ventas en efectivo',   'ventasPagos', 'grupo',  'EFECTIVO',
             1,  (v_totales->>'ventasEfectivo')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'EFECTIVO'), 10),
            ('ventas_otros_medios','Ventas otros medios',  'ventasPagos', 'grupo',  'OTROS',
             1,  (v_totales->>'ventasOtrosMedios')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'OTROS'), 20),
            ('ventas_credito',     'Ventas a crédito',     'ventasPagos', 'grupo',  'CREDITO',
             0,  (v_totales->>'ventasCredito')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_ventas_pagos) e WHERE e->>'grupo' = 'CREDITO'), 30),
            ('cobranzas',          'Cobranzas',            'cobranzas',   NULL,     NULL,
             1,  (v_totales->>'cobranzas')::NUMERIC,
             json_array_length(v_cobranzas), 40),
            ('garantias_cobradas', 'Garantías cobradas',   'garantias',   'tipo',   'COBRO',
             1,  (v_totales->>'garantiasCobro')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'COBRO'), 50),
            ('garantias_devueltas','Garantías devueltas',  'garantias',   'tipo',   'DEVOLUCION',
             -1, (v_totales->>'garantiasDevolucion')::NUMERIC,
             (SELECT COUNT(*) FROM json_array_elements(v_garantias) e WHERE e->>'tipo' = 'DEVOLUCION'), 60),
            ('pagos_proveedor',    'Pagos a proveedores',  'pagosProveedor', NULL,  NULL,
             -1, (v_totales->>'pagosProveedor')::NUMERIC,
             json_array_length(v_pagos_proveedor), 65),
            ('gastos',             'Gastos',               'gastos',      NULL,     NULL,
             -1, (v_totales->>'gastos')::NUMERIC,
             json_array_length(v_gastos), 70),
            ('depositos',          'Depósitos a banco',    'depositos',   NULL,     NULL,
             -1, (v_totales->>'depositos')::NUMERIC,
             json_array_length(v_depositos), 80),
            ('observaciones',      'Observaciones',        'observaciones', NULL,   NULL,
             0,  NULL::NUMERIC,
             json_array_length(v_observaciones), 90)
    ) AS r(clave, etiqueta, coleccion, "filtroCampo", "filtroValor", signo, total, cantidad, orden);

    RETURN json_build_object(
        'registro', json_build_object(
            'fechaDesde', p_fecha_desde,
            'fechaHasta', v_hasta,
            'idCliente', p_id_cliente,
            'idSucursal', p_id_sucursal,
            'ventas', v_ventas,
            'ventasPagos', v_ventas_pagos,
            'cobranzas', v_cobranzas,
            'pagosProveedor', v_pagos_proveedor,
            'gastos', v_gastos,
            'depositos', v_depositos,
            'garantias', v_garantias,
            'observaciones', v_observaciones,
            'resumenes', v_resumenes,
            'totales', v_totales,
            'dias', v_dias
        )
    );
END;
$function$;

