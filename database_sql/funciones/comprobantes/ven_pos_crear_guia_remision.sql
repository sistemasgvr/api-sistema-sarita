-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_pos_crear_guia_remision
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.816Z
DROP FUNCTION IF EXISTS ven_pos_crear_guia_remision(p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_pos_crear_guia_remision(p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_comp RECORD;
    v_id_tipo INTEGER;
    v_id_motivo INTEGER;
    v_id_modalidad INTEGER;
    v_id_unidad INTEGER;
    v_id_chofer INTEGER;
    v_id_vehiculo INTEGER;
    v_serie VARCHAR;
    v_dir_origen VARCHAR;
    v_id_dist_origen INTEGER;
    v_dir_llegada VARCHAR;
    v_id_dist_llegada INTEGER;
    v_peso NUMERIC;
    v_detalles JSON;
    v_referencias JSON;
    v_result JSON;
    v_n INTEGER;
    v_id_guia INTEGER;
    v_serie_guia VARCHAR;
    v_numero_guia VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL THEN
        RETURN;
    END IF;

    SELECT COUNT(*)::INTEGER INTO v_n
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1
      AND pd.id_balon IS NOT NULL;

    IF COALESCE(v_n, 0) = 0 THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM gre_documentos_referencia r
        INNER JOIN gre_guia_remision g ON g.id = r.id_guia_remision AND g.estado = 1
        INNER JOIN ven_comprobante c ON c.id = p_id_comprobante
        WHERE r.estado = 1
          AND (
              r.id_comprobante = c.id
              OR (
                  UPPER(COALESCE(r.serie, '')) = UPPER(COALESCE(c.serie, ''))
                  AND COALESCE(r.numero, '') = COALESCE(c.numero, '')
              )
          )
    ) THEN
        RETURN;
    END IF;

    SELECT
        c.id,
        c.serie,
        c.numero,
        c.fecha,
        c.id_tipo_comprobante,
        c.id_cliente,
        c.id_sucursal,
        c.id_almacen
    INTO v_comp
    FROM ven_comprobante c
    WHERE c.id = p_id_comprobante AND c.estado = 1;

    IF v_comp.id_sucursal IS NULL OR v_comp.id_almacen IS NULL OR v_comp.id_cliente IS NULL THEN
        RETURN;
    END IF;

    SELECT lo.id INTO v_id_tipo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoGuiaRemision' AND lo.descripcion = '09' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_motivo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'MotivoTraslado' AND lo.nombre = 'VENTA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_modalidad
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'ModalidadTraslado' AND lo.descripcion = '02' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_unidad
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'UnidadMedida'
      AND UPPER(lo.nombre) IN ('KGM', 'KG')
      AND lo.estado = 1
    ORDER BY CASE UPPER(lo.nombre) WHEN 'KGM' THEN 0 ELSE 1 END
    LIMIT 1;

    SELECT id INTO v_id_chofer FROM gen_chofer WHERE estado = 1 ORDER BY id LIMIT 1;
    SELECT id INTO v_id_vehiculo
    FROM gen_vehiculo
    WHERE estado = 1 AND id_cliente IS NULL
    ORDER BY id
    LIMIT 1;

    SELECT s.direccion, s.id_distrito
    INTO v_dir_origen, v_id_dist_origen
    FROM gen_sucursal s
    WHERE s.id = v_comp.id_sucursal AND s.estado = 1;

    SELECT d.direccion, d.id_distrito
    INTO v_dir_llegada, v_id_dist_llegada
    FROM cli_direcciones d
    WHERE d.id_cliente = v_comp.id_cliente AND d.estado = 1
    ORDER BY d.es_principal DESC, d.id
    LIMIT 1;

    IF v_id_dist_llegada IS NULL THEN
        v_dir_llegada := v_dir_origen;
        v_id_dist_llegada := v_id_dist_origen;
    END IF;

    IF v_id_tipo IS NULL OR v_id_motivo IS NULL OR v_id_modalidad IS NULL
       OR v_id_unidad IS NULL
       OR v_id_dist_origen IS NULL OR v_id_dist_llegada IS NULL
       OR v_id_chofer IS NULL OR v_id_vehiculo IS NULL
    THEN
        RETURN;
    END IF;

    SELECT COALESCE(
        (
            SELECT g.serie
            FROM gre_guia_remision g
            WHERE g.estado = 1 AND LEFT(UPPER(g.serie), 1) = 'T'
            ORDER BY g.id DESC
            LIMIT 1
        ),
        'T001'
    ) INTO v_serie;

    SELECT COALESCE(json_agg(json_build_object(
        'idBalon', pd.id_balon,
        'idProducto', pd.id_producto,
        'cantidad', 1,
        'descripcion', 'Cilindro préstamo POS'
    )), '[]'::JSON)
    INTO v_detalles
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    WHERE p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1
      AND pd.id_balon IS NOT NULL;

    SELECT COALESCE(SUM(COALESCE(b.peso_aproximado_kg, tb.peso, 10)), 10)
    INTO v_peso
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
    INNER JOIN bal_balon b ON b.id = pd.id_balon
    LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
    WHERE p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1;

    v_referencias := json_build_array(json_build_object(
        'idTipoComprobante', v_comp.id_tipo_comprobante,
        'idComprobante', v_comp.id,
        'serie', v_comp.serie,
        'numero', v_comp.numero,
        'fecha', v_comp.fecha
    ));

    v_result := gre_crear_guia_remision(
        v_id_tipo,
        v_serie,
        NULL,
        v_comp.fecha,
        v_comp.fecha,
        v_comp.id_sucursal,
        v_comp.id_almacen,
        v_comp.id_cliente,
        v_id_motivo,
        v_id_unidad,
        GREATEST(v_peso, 0.1),
        v_n,
        v_dir_origen,
        v_id_dist_origen,
        v_comp.id_cliente,
        NULL,
        NULL,
        v_dir_llegada,
        v_id_dist_llegada,
        v_id_modalidad,
        NULL,
        v_id_chofer,
        v_id_vehiculo,
        NULL,
        'GRE automática POS — préstamo de cilindro',
        v_detalles,
        v_referencias,
        p_id_usuario,
        NULL,
        NULL
    );
    -- Si la GRE no se puede emitir (catálogo, correlativo, etc.), no aborta el POS.
    IF v_result->>'error' IS NOT NULL THEN
        RETURN;
    END IF;

    v_id_guia := (v_result->'registro'->>'id')::INTEGER;
    v_serie_guia := v_result->'registro'->>'serie';
    v_numero_guia := v_result->'registro'->>'numero';

    IF v_id_guia IS NULL THEN
        RETURN;
    END IF;

    -- Vínculo real detalle de préstamo ↔ GRE recién emitida. serie/numero se
    -- mantienen como snapshot para la UI que aún los lee.
    UPDATE bal_prestamo_detalle pd
    SET
        id_guia_entrega = v_id_guia,
        serie_guia_entrega = v_serie_guia,
        numero_guia_entrega = v_numero_guia,
        id_usuario_modificacion = COALESCE(p_id_usuario, pd.id_usuario_modificacion),
        fecha_modificacion = NOW()
    FROM bal_prestamo p
    WHERE p.id = pd.id_prestamo
      AND p.estado = 1
      AND p.id_comprobante_venta = p_id_comprobante
      AND pd.estado = 1
      AND pd.id_balon IS NOT NULL
      AND pd.id_guia_entrega IS NULL;
END;
$function$
