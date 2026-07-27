DROP FUNCTION IF EXISTS com_listar_compras;

CREATE OR REPLACE FUNCTION com_listar_compras(
    p_id_proveedor    INTEGER DEFAULT NULL,
    p_id_almacen      INTEGER DEFAULT NULL,
    p_fecha_desde     DATE DEFAULT NULL,
    p_fecha_hasta     DATE DEFAULT NULL,
    p_estado          INTEGER DEFAULT NULL,
    p_limite          INTEGER DEFAULT 50,
    p_offset          INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_registro
    FROM (
        SELECT
            c.id, c.serie, c.numero, c.fecha,
            c.id_proveedor, pr.razon_social AS proveedor,
            c.id_almacen, alm.nombre AS almacen,
            c.sub_total, c.total_importe,
            c.estado,
            com_tiene_movimientos_inventario(c.id) AS tiene_movimientos_inventario,
            c.id_comprobante_referencia
        FROM com_comprobante_compra c
        LEFT JOIN cli_clientes pr ON pr.id = c.id_proveedor
        LEFT JOIN gen_almacen alm ON alm.id = c.id_almacen
        WHERE (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
          AND (p_id_almacen IS NULL OR c.id_almacen = p_id_almacen)
          AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
          AND (p_estado IS NULL OR c.estado = p_estado)
        ORDER BY c.fecha DESC, c.id DESC
        LIMIT p_limite OFFSET p_offset
    ) t;
 
    RETURN json_build_object('error', NULL, 'registro', v_registro);
END;
$function$;
 
CREATE OR REPLACE FUNCTION com_recalcular_totales_compra(
    p_id_comprobante         INTEGER,
    p_id_usuario_auditoria   INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
DECLARE
    v_sub_total NUMERIC(12,4);
BEGIN
    SELECT COALESCE(SUM(importe), 0) INTO v_sub_total
    FROM com_comprobante_compra_detalle
    WHERE id_comprobante = p_id_comprobante AND estado = 1;
 
    UPDATE com_comprobante_compra
    SET sub_total = v_sub_total,
        total_importe = v_sub_total + igv,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_comprobante;
END;
$function$;
 
 
CREATE OR REPLACE FUNCTION com_obtener_compra(
    p_id INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_cabecera JSON;
    v_detalle  JSON;
BEGIN
    SELECT json_build_object(
        'id',                        c.id,
        'id_tipo_comprobante',       c.id_tipo_comprobante,
        'tipo_comprobante',          tc.nombre,
        'serie',                     c.serie,
        'numero',                    c.numero,
        'fecha',                     c.fecha,
        'id_proveedor',              c.id_proveedor,
        'proveedor',                 pr.razon_social,
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
        'tiene_movimientos_inventario', com_tiene_movimientos_inventario(c.id),
        'puede_modificarse_parcial', NOT com_tiene_movimientos_inventario(c.id),
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
    LEFT JOIN gen_lista_opciones est      ON est.id = c.id_estado
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
 
    RETURN json_build_object(
        'error', NULL,
        'registro', json_build_object(
            'cabecera', v_cabecera,
            'detalle', v_detalle
        )
    );
END;
$function$;
-- CREATE OR REPLACE FUNCTION com_listar_compras(
--     p_busqueda VARCHAR DEFAULT '',
--     p_limite INTEGER DEFAULT 10,
--     p_offset INTEGER DEFAULT 0,
--     p_fecha_desde DATE DEFAULT NULL,
--     p_fecha_hasta DATE DEFAULT NULL,
--     p_id_proveedor INTEGER DEFAULT NULL,
--     p_id_tipo_comprobante INTEGER DEFAULT NULL,
--     p_id_tipo_registro INTEGER DEFAULT NULL
-- )
-- RETURNS JSON
-- LANGUAGE plpgsql
-- AS $function$
-- DECLARE
--     v_registros JSON;
--     v_total BIGINT;
-- BEGIN
--     SET TIME ZONE 'America/Lima';

--     SELECT COUNT(*) INTO v_total
--     FROM com_comprobante_compra c
--     LEFT JOIN cli_clientes p ON c.id_proveedor = p.id
--     WHERE c.estado = 1
--       AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
--       AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
--       AND (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
--       AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
--       AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
--       AND (
--           p_busqueda = ''
--           OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
--           OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
--           OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
--           OR LOWER(COALESCE(p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
--       );

--     SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
--     FROM (
--         SELECT
--             c.id,
--             c.id_tipo_comprobante,
--             tc.nombre AS nombre_tipo_comprobante,
--             c.serie,
--             c.numero,
--             c.fecha,
--             c.id_proveedor,
--             p.razon_social AS razon_social_proveedor,
--             p.numero_documento AS doc_proveedor,
--             c.id_tipo_registro,
--             tr.nombre AS nombre_tipo_registro,
--             c.id_categoria_gasto,
--             cg.nombre AS nombre_categoria_gasto,
--             c.id_sucursal,
--             s.nombre AS nombre_sucursal,
--             c.id_almacen,
--             a.nombre AS nombre_almacen,
--             c.id_moneda,
--             m.nombre AS nombre_moneda,
--             c.id_condicion_pago,
--             cp.nombre AS nombre_condicion_pago,
--             c.sub_total,
--             c.igv,
--             c.total_importe,
--             c.afecta_inventario,
--             c.declarar_sunat,
--             c.glosa,
--             c.id_estado,
--             ec.nombre AS nombre_estado,
--             c.fecha_creacion,
--             c.fecha_modificacion
--         FROM com_comprobante_compra c
--         LEFT JOIN gen_lista_opciones tc ON c.id_tipo_comprobante = tc.id
--         LEFT JOIN gen_lista_opciones tr ON c.id_tipo_registro = tr.id
--         LEFT JOIN gen_lista_opciones cg ON c.id_categoria_gasto = cg.id
--         LEFT JOIN gen_lista_opciones m ON c.id_moneda = m.id
--         LEFT JOIN gen_lista_opciones ec ON c.id_estado = ec.id
--         LEFT JOIN cli_clientes p ON c.id_proveedor = p.id
--         LEFT JOIN gen_sucursal s ON c.id_sucursal = s.id
--         LEFT JOIN gen_almacen a ON c.id_almacen = a.id
--         LEFT JOIN gen_condicion_pago cp ON c.id_condicion_pago = cp.id
--         WHERE c.estado = 1
--           AND (p_fecha_desde IS NULL OR c.fecha >= p_fecha_desde)
--           AND (p_fecha_hasta IS NULL OR c.fecha <= p_fecha_hasta)
--           AND (p_id_proveedor IS NULL OR c.id_proveedor = p_id_proveedor)
--           AND (p_id_tipo_comprobante IS NULL OR c.id_tipo_comprobante = p_id_tipo_comprobante)
--           AND (p_id_tipo_registro IS NULL OR c.id_tipo_registro = p_id_tipo_registro)
--           AND (
--               p_busqueda = ''
--               OR LOWER(COALESCE(c.serie, '')) LIKE LOWER('%' || p_busqueda || '%')
--               OR LOWER(COALESCE(c.numero, '')) LIKE LOWER('%' || p_busqueda || '%')
--               OR LOWER(COALESCE(c.glosa, '')) LIKE LOWER('%' || p_busqueda || '%')
--               OR LOWER(COALESCE(p.razon_social, '')) LIKE LOWER('%' || p_busqueda || '%')
--           )
--         ORDER BY c.fecha DESC, c.id DESC
--         LIMIT p_limite
--         OFFSET p_offset
--     ) t;

--     RETURN json_build_object('registros', v_registros, 'total', v_total);
-- END;
-- $function$;