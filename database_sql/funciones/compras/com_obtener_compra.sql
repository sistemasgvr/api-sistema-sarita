-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_obtener_compra
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.954Z
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
