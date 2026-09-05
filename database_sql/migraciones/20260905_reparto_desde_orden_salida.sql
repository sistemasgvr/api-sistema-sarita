-- El reparto (actividad) pasa a colgar de la orden de salida.
--
-- age_actividad ya tenia la columna id_doc_salida y age_crear_actividad ya sabia
-- llenarla (su parametro p_id_guia_remision apunta a doc_salida y copia los
-- items desde doc_salida_detalle). Lo unico que faltaba era que el comprobante
-- siguiera viendo su reparto: su LATERAL solo miraba a.id_comprobante, asi que
-- un reparto programado desde la orden de salida no aparecia en la venta.
--
-- Ahora la venta lo alcanza por JOIN a traves de su orden de salida, y se
-- mantiene la rama por id_comprobante para los repartos ya creados. Ninguna fila
-- existente cambia de significado.

-- ---------------------------------------------------------------------------
-- ven_obtener_comprobante
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ven_obtener_comprobante(p_id integer);

CREATE OR REPLACE FUNCTION ven_obtener_comprobante(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_detalles JSON;
    v_cuotas JSON;
    v_pagos JSON;
    v_prestamos JSON;
    v_garantias JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_tipo_operacion_sunat,
            tos.nombre AS nombre_tipo_operacion_sunat,
            tos.descripcion AS codigo_tipo_operacion_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.ticket_sunat,
            c.hash_documento,
            c.xml_firmado,
            c.cdr_respuesta,
            c.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            c.id_tipo_venta,
            tv.nombre AS nombre_tipo_venta,
            c.fecha,
            c.fecha_vencimiento,
            c.tipo_cambio,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_sucursal,
            su.nombre AS nombre_sucursal,
            c.id_almacen,
            al.nombre AS nombre_almacen,
            c.id_condicion_pago,
            cp.nombre AS nombre_condicion_pago,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            mo.descripcion AS codigo_moneda,
            c.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            c.sub_total,
            c.descuento,
            c.valor_venta,
            c.igv,
            c.total_importe,
            c.anticipos,
            c.exonerado,
            c.glosa,
            c.observaciones,
            c.periodo_contable,
            c.operacion,
            c.origen_pos,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.estado,
            c.fecha_creacion,
            c.fecha_modificacion,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            act.nombre_chofer_responsable,
            (act.id IS NOT NULL) AS tiene_actividad
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones tos ON c.id_tipo_operacion_sunat = tos.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN gen_lista_opciones tm ON c.id_tipo_movimiento = tm.id
        LEFT JOIN gen_lista_opciones tv ON c.id_tipo_venta = tv.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_sucursal su ON c.id_sucursal = su.id
        LEFT JOIN gen_almacen al ON c.id_almacen = al.id
        LEFT JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN gen_lista_opciones mp ON c.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad,
                TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            LEFT JOIN gen_chofer ch ON ch.id = a.id_chofer_responsable
            -- El reparto se programa desde la orden de salida, que es lo que
            -- realmente sale a la calle, asi que cuelga de doc_salida y no del
            -- comprobante. La venta lo sigue mostrando alcanzandolo por JOIN a
            -- traves de su orden. Se conserva la rama por id_comprobante para
            -- los repartos creados antes de ese cambio.
            WHERE (
                    a.id_comprobante = c.id
                    OR a.id_doc_salida IN (
                        SELECT ds.id
                        FROM doc_salida ds
                        WHERE ds.id_venta = c.id AND ds.estado = 1
                    )
                  )
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        WHERE c.id = p_id AND c.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    -- `es_linea_garantia` marca las líneas que el POS antiguo insertaba para
    -- cobrar la garantía dentro de la venta. Desde este cambio ya no se crean,
    -- pero los comprobantes emitidos antes las conservan: la bandera deja que el
    -- detalle, el ticket y el mapper de SUNAT las traten como garantía sin que
    -- cada uno repita la comparación de texto por su cuenta. Es el mismo
    -- criterio que ya usaba ven_producto_mueve_kardex_venta para no descontar
    -- stock por ellas.
    SELECT COALESCE(json_agg(row_to_json(d) ORDER BY d.item), '[]'::JSON) INTO v_detalles
    FROM (
        SELECT
            d.id,
            d.id_comprobante,
            d.item,
            d.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.es_gas,
            p.es_servicio,
            p.es_alquilable,
            d.descripcion,
            d.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            d.cantidad,
            d.precio_unitario,
            d.descuento,
            d.valor_venta,
            d.porcentaje_igv,
            d.id_afectacion_igv,
            ai.nombre AS nombre_afectacion_igv,
            ai.descripcion AS codigo_afectacion_igv,
            d.impuesto,
            d.importe,
            d.id_balon,
            b.codigo_balon,
            d.capacidad_cilindro,
            d.id_estado_cilindro,
            ec.nombre AS nombre_estado_cilindro,
            (COALESCE(d.descripcion, '') ~* 'garant[ií]a') AS es_linea_garantia,
            d.estado,
            d.fecha_creacion,
            d.fecha_modificacion
        FROM ven_comprobante_detalle d
        LEFT JOIN pro_producto p ON d.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON d.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones ai ON d.id_afectacion_igv = ai.id
        LEFT JOIN bal_balon b ON d.id_balon = b.id
        LEFT JOIN gen_lista_opciones ec ON d.id_estado_cilindro = ec.id
        WHERE d.id_comprobante = p_id AND d.estado = 1
    ) d;

    SELECT COALESCE(json_agg(row_to_json(q) ORDER BY q.numero_cuota), '[]'::JSON) INTO v_cuotas
    FROM (
        SELECT
            q.id,
            q.id_comprobante,
            q.numero_cuota,
            q.fecha_vencimiento,
            q.monto,
            q.monto_pagado,
            q.id_estado,
            eq.nombre AS nombre_estado,
            q.estado,
            q.fecha_creacion,
            q.fecha_modificacion
        FROM ven_cuotas q
        LEFT JOIN gen_lista_opciones eq ON q.id_estado = eq.id
        WHERE q.id_comprobante = p_id AND q.estado = 1
    ) q;

    -- Fase 3: desglose del cobro. Solo las líneas reales de ven_comprobante_pago;
    -- si la venta no tiene ninguna, el array va vacío y el frontend cae al
    -- medio de pago de la cabecera, que es donde estaba el dato antes.
    SELECT COALESCE(json_agg(row_to_json(pg) ORDER BY pg.item), '[]'::JSON) INTO v_pagos
    FROM (
        SELECT
            pp.id,
            pp.item,
            pp.id_medio_pago,
            mp.nombre AS nombre_medio_pago,
            pp.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            pp.monto,
            pp.numero_operacion,
            pp.referencia,
            pp.observacion
        FROM ven_comprobante_pago pp
        LEFT JOIN gen_lista_opciones mp ON mp.id = pp.id_medio_pago
        LEFT JOIN gen_cuenta_bancaria cb ON cb.id = pp.id_cuenta_bancaria
        WHERE pp.id_comprobante = p_id AND pp.estado = 1
    ) pg;

    -- Préstamos de cilindro nacidos de esta venta, con TODOS sus balones: no se
    -- filtra por id_estado del detalle ni por fecha_devolucion a propósito. El
    -- comprobante documenta qué cilindros salieron con esa venta; que uno ya
    -- haya vuelto no lo borra de lo que se entregó ese día, solo cambia la
    -- etiqueta de estado que se muestra al costado. Se incluyen ambos roles:
    -- ENTREGADO (lo que se lleva el cliente) y GARANTIA (el cilindro propio que
    -- deja como colateral).
    SELECT COALESCE(json_agg(row_to_json(pr) ORDER BY pr.id), '[]'::JSON) INTO v_prestamos
    FROM (
        SELECT
            p.id,
            p.numero_prestamo,
            p.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            p.id_almacen,
            a.nombre AS nombre_almacen,
            p.fecha_salida,
            p.fecha_retorno_pactada,
            p.fecha_retorno_real,
            p.titulo,
            p.observacion,
            p.id_estado,
            ep.nombre AS nombre_estado,
            p.id_prestamo_origen,
            po.numero_prestamo AS numero_prestamo_origen,
            (
                SELECT COALESCE(json_agg(row_to_json(bl) ORDER BY bl.rol, bl.id), '[]'::JSON)
                FROM (
                    SELECT
                        pd.id,
                        pd.rol,
                        pd.id_balon,
                        b.codigo_balon,
                        b.numero_serie,
                        b.id_tipo_balon,
                        tb.nombre AS nombre_tipo_balon,
                        tb.capacidad,
                        b.id_estado_balon,
                        eb.nombre AS nombre_estado_balon,
                        pd.id_producto,
                        COALESCE(pgas.nombre, prod.nombre) AS nombre_producto,
                        pd.fecha_entregado,
                        pd.fecha_prestamo,
                        pd.fecha_vencimiento,
                        pd.fecha_devolucion,
                        pd.id_estado,
                        epd.nombre AS nombre_estado,
                        pd.motivo_especifico,
                        pd.observacion
                    FROM bal_prestamo_detalle pd
                    LEFT JOIN bal_balon b ON b.id = pd.id_balon
                    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
                    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                    LEFT JOIN pro_producto prod ON prod.id = pd.id_producto
                    LEFT JOIN pro_producto pgas ON pgas.id = b.id_producto_gas
                    LEFT JOIN gen_lista_opciones epd ON epd.id = pd.id_estado
                    WHERE pd.id_prestamo = p.id AND pd.estado = 1
                ) bl
            ) AS balones
        FROM bal_prestamo p
        LEFT JOIN gen_lista_opciones tp ON tp.id = p.id_tipo_prestamo
        LEFT JOIN gen_almacen a ON a.id = p.id_almacen
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        LEFT JOIN bal_prestamo po ON po.id = p.id_prestamo_origen
        WHERE p.id_comprobante_venta = p_id AND p.estado = 1
    ) pr;

    -- Garantías ligadas a esta venta. Se llega a ellas por tres caminos porque
    -- ven_garantia no guarda id_comprobante: por el préstamo, por el alquiler o
    -- por el movimiento de cobro, que sí apunta al comprobante.
    -- `monto_cobrado_comprobante` es lo que se cobró en ESTA venta; los demás
    -- montos son el estado vigente de la garantía (para pantalla, no para el
    -- ticket impreso, que debe quedar como foto del día de emisión).
    SELECT COALESCE(json_agg(row_to_json(gr) ORDER BY gr.id), '[]'::JSON) INTO v_garantias
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            g.id_prestamo,
            pr.numero_prestamo,
            g.id_alquiler,
            alq.numero_alquiler,
            g.id_producto,
            prod.nombre AS nombre_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            umg.nombre AS nombre_unidad_medida,
            g.ubicacion,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.id_medio_pago,
            mpg.nombre AS nombre_medio_pago,
            g.observacion,
            COALESCE((
                SELECT SUM(gm.monto)
                FROM ven_garantia_movimiento gm
                INNER JOIN gen_lista_opciones tmg ON tmg.id = gm.id_tipo_movimiento
                WHERE gm.id_garantia = g.id
                  AND gm.id_comprobante = p_id
                  AND gm.estado = 1
                  AND UPPER(tmg.nombre) = 'COBRO'
            ), 0) AS monto_cobrado_comprobante
        FROM ven_garantia g
        LEFT JOIN bal_prestamo pr ON pr.id = g.id_prestamo
        LEFT JOIN bal_alquiler alq ON alq.id = g.id_alquiler
        LEFT JOIN pro_producto prod ON prod.id = g.id_producto
        LEFT JOIN gen_lista_opciones umg ON umg.id = g.id_unidad_medida
        LEFT JOIN gen_lista_opciones eg ON eg.id = g.id_estado
        LEFT JOIN gen_lista_opciones mpg ON mpg.id = g.id_medio_pago
        WHERE g.estado = 1
          AND (
              pr.id_comprobante_venta = p_id
              OR alq.id_comprobante_venta = p_id
              OR EXISTS (
                  SELECT 1
                  FROM ven_garantia_movimiento gm
                  WHERE gm.id_garantia = g.id
                    AND gm.id_comprobante = p_id
                    AND gm.estado = 1
              )
          )
    ) gr;

    RETURN json_build_object(
        'registro', v_registro,
        'detalles', v_detalles,
        'cuotas', v_cuotas,
        'pagos', v_pagos,
        'prestamos', v_prestamos,
        'garantias', v_garantias
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- ven_listar_comprobantes
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS ven_listar_comprobantes(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_comprobante integer, p_id_cliente integer, p_id_estado integer, p_id_estado_sunat integer, p_fecha_desde date, p_fecha_hasta date, p_serie character varying);

CREATE OR REPLACE FUNCTION ven_listar_comprobantes(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_comprobante integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_id_estado_sunat integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_serie character varying DEFAULT NULL::character varying, p_solo_activos integer DEFAULT 1)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_busqueda TEXT;
    v_busqueda_norm TEXT;
    v_busqueda_sin_guion TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_busqueda := TRIM(COALESCE(p_busqueda, ''));
    v_busqueda_norm := LOWER(REPLACE(REPLACE(v_busqueda, ' ', ''), '/', '-'));
    v_busqueda_sin_guion := REPLACE(v_busqueda_norm, '-', '');

    SELECT COUNT(*) INTO v_total
    FROM ven_comprobante c
    LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
    LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
    WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
      AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
      AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
      AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
      AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
      AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
      AND (
          v_busqueda = ''
          OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
          OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
          OR gen_texto_coincide(COALESCE(cl.razon_social, ''), v_busqueda)
          OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
          OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            c.id,
            c.id_tipo_comprobante,
            tc.nombre AS nombre_tipo_comprobante,
            tc.descripcion AS codigo_tipo_comprobante,
            c.serie,
            c.numero,
            c.fecha,
            c.id_cliente,
            COALESCE(
                cl.razon_social,
                TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno))
            ) AS nombre_cliente,
            cl.numero_documento AS documento_cliente,
            c.id_estado,
            ed.nombre AS nombre_estado,
            c.id_estado_sunat,
            es.nombre AS nombre_estado_sunat,
            c.id_comprobante_origen,
            co.serie AS serie_comprobante_origen,
            co.numero AS numero_comprobante_origen,
            tc_origen.descripcion AS codigo_tipo_comprobante_origen,
            tc_origen.nombre AS nombre_tipo_comprobante_origen,
            cd.id AS id_comprobante_destino,
            cd.serie AS serie_comprobante_destino,
            cd.numero AS numero_comprobante_destino,
            tc_destino.descripcion AS codigo_tipo_comprobante_destino,
            tc_destino.nombre AS nombre_tipo_comprobante_destino,
            c.id_motivo_nota,
            mn.nombre AS nombre_motivo_nota,
            mn.descripcion AS codigo_motivo_nota,
            c.total_importe,
            c.id_moneda,
            mo.nombre AS nombre_moneda,
            act.id AS id_actividad,
            act.titulo AS titulo_actividad,
            act.nombre_tipo_actividad,
            act.nombre_estado_actividad,
            (act.id IS NOT NULL) AS tiene_actividad,
            c.estado,
            c.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_comprobante_detalle d
                WHERE d.id_comprobante = c.id AND d.estado = 1
            ) AS total_detalles
        FROM ven_comprobante c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
        LEFT JOIN ven_comprobante co ON c.id_comprobante_origen = co.id
        LEFT JOIN gen_lista_opciones tc_origen ON co.id_tipo_comprobante = tc_origen.id
        LEFT JOIN LATERAL (
            SELECT d.id, d.serie, d.numero, d.id_tipo_comprobante
            FROM ven_comprobante d
            WHERE d.id_comprobante_origen = c.id AND d.estado = 1
            ORDER BY d.id DESC
            LIMIT 1
        ) cd ON TRUE
        LEFT JOIN gen_lista_opciones tc_destino ON cd.id_tipo_comprobante = tc_destino.id
        LEFT JOIN gen_lista_opciones mn ON c.id_motivo_nota = mn.id
        LEFT JOIN cli_clientes cl ON c.id_cliente = cl.id
        LEFT JOIN gen_lista_opciones ed ON c.id_estado = ed.id
        LEFT JOIN gen_lista_opciones es ON c.id_estado_sunat = es.id
        LEFT JOIN gen_lista_opciones mo ON c.id_moneda = mo.id
        LEFT JOIN LATERAL (
            SELECT
                a.id,
                a.titulo,
                ta.nombre AS nombre_tipo_actividad,
                ea.nombre AS nombre_estado_actividad
            FROM age_actividad a
            LEFT JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
            LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
            -- El reparto se programa desde la orden de salida, que es lo que
            -- realmente sale a la calle, asi que cuelga de doc_salida y no del
            -- comprobante. La venta lo sigue mostrando alcanzandolo por JOIN a
            -- traves de su orden. Se conserva la rama por id_comprobante para
            -- los repartos creados antes de ese cambio.
            WHERE (
                    a.id_comprobante = c.id
                    OR a.id_doc_salida IN (
                        SELECT ds.id
                        FROM doc_salida ds
                        WHERE ds.id_venta = c.id AND ds.estado = 1
                    )
                  )
              AND a.estado = 1
              AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO')
            ORDER BY a.id DESC
            LIMIT 1
        ) act ON TRUE
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
          AND (p_id_cliente IS NULL OR c.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR c.id_estado = p_id_estado)
          AND (p_id_estado_sunat IS NULL OR c.id_estado_sunat = p_id_estado_sunat)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_serie IS NULL OR p_serie = '' OR c.serie = TRIM(p_serie))
          AND (
              v_busqueda = ''
              OR LOWER(c.serie) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || '-' || c.numero) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(c.serie || c.numero) LIKE '%' || v_busqueda_sin_guion || '%'
              OR LOWER(COALESCE(co.serie, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR LOWER(COALESCE(co.serie, '') || '-' || COALESCE(co.numero, '')) LIKE '%' || v_busqueda_norm || '%'
              OR gen_texto_coincide(COALESCE(cl.razon_social, ''), v_busqueda)
              OR gen_texto_coincide(COALESCE(cl.numero_documento, ''), v_busqueda)
              OR gen_texto_coincide(COALESCE(c.glosa, ''), v_busqueda)
          )
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
