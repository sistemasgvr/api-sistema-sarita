-- Historial de prestamos: exponer la cadena de renovaciones.
--
-- Renovar cierra el prestamo y abre uno nuevo encadenado por
-- bal_prestamo.id_prestamo_origen (esa es la forma de tener historial en vez de
-- ir pisando el mismo registro). La columna existe y bal_renovar_prestamo la
-- llena, pero ninguna funcion de lectura la devolvia, asi que desde la
-- aplicacion no habia manera de recorrer la cadena.
--
-- Se agrega el prestamo de origen en el listado y en el detalle, y ademas la
-- renovacion siguiente en el detalle, para poder navegar la cadena en los dos
-- sentidos.

-- ---------------------------------------------------------------------------
-- bal_obtener_prestamo
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS bal_obtener_prestamo(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_prestamo(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            pr.id,
            pr.numero_prestamo,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            pr.id_proveedor,
            COALESCE(
                NULLIF(TRIM(prov.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), ''),
                prov.numero_documento
            ) AS nombre_proveedor,
            pr.id_almacen,
            a.nombre AS nombre_almacen,
            pr.fecha_salida,
            pr.fecha_retorno_pactada,
            pr.fecha_retorno_real,
            pr.titulo,
            pr.observacion,
            pr.id_estado,
            ep.nombre AS nombre_estado,
            pr.id_prestamo_origen,
            po.numero_prestamo AS numero_prestamo_origen,
            (
                SELECT pd_sig.id
                FROM bal_prestamo pd_sig
                WHERE pd_sig.id_prestamo_origen = pr.id AND pd_sig.estado = 1
                ORDER BY pd_sig.id ASC
                LIMIT 1
            ) AS id_prestamo_renovacion,
            (
                SELECT pd_sig.numero_prestamo
                FROM bal_prestamo pd_sig
                WHERE pd_sig.id_prestamo_origen = pr.id AND pd_sig.estado = 1
                ORDER BY pd_sig.id ASC
                LIMIT 1
            ) AS numero_prestamo_renovacion,
            pr.id_comprobante_venta,
            cv.serie AS serie_comprobante_venta,
            cv.numero AS numero_comprobante_venta,
            cv.fecha AS fecha_comprobante_venta,
            COALESCE(
                NULLIF(TRIM(cv_cli.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cv_cli.nombres, cv_cli.apellido_paterno, cv_cli.apellido_materno)), ''),
                cv_cli.numero_documento
            ) AS nombre_cliente_comprobante_venta,
            cv.total_importe AS total_comprobante_venta,
            pr.id_comprobante_compra,
            cc.serie AS serie_comprobante_compra,
            cc.numero AS numero_comprobante_compra,
            cc.fecha AS fecha_comprobante_compra,
            cc_prov.razon_social AS nombre_proveedor_comprobante_compra,
            cc.total_importe AS total_comprobante_compra,
            pr.estado,
            pr.fecha_creacion,
            pr.fecha_modificacion,
            pr.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            pr.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = pr.id AND pd.estado = 1
            ) AS total_detalles
        FROM bal_prestamo pr
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN cli_clientes prov ON pr.id_proveedor = prov.id
        LEFT JOIN gen_almacen a ON pr.id_almacen = a.id
        LEFT JOIN gen_lista_opciones ep ON pr.id_estado = ep.id
        LEFT JOIN bal_prestamo po ON po.id = pr.id_prestamo_origen
        LEFT JOIN ven_comprobante cv ON pr.id_comprobante_venta = cv.id
        LEFT JOIN cli_clientes cv_cli ON cv.id_cliente = cv_cli.id
        LEFT JOIN com_comprobante_compra cc ON pr.id_comprobante_compra = cc.id
        LEFT JOIN cli_clientes cc_prov ON cc.id_proveedor = cc_prov.id
        LEFT JOIN auth_usuarios uc ON pr.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON pr.id_usuario_modificacion = um.id
        WHERE pr.id = p_id AND pr.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ---------------------------------------------------------------------------
-- bal_listar_prestamos
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS bal_listar_prestamos(p_busqueda character varying, p_limite integer, p_offset integer, p_id_tipo_prestamo integer, p_id_cliente integer, p_id_estado integer);

CREATE OR REPLACE FUNCTION bal_listar_prestamos(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_tipo_prestamo integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_prestamo pr
    LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
    WHERE pr.estado = 1
      AND (p_id_tipo_prestamo IS NULL OR pr.id_tipo_prestamo = p_id_tipo_prestamo)
      AND (p_id_cliente IS NULL OR pr.id_cliente = p_id_cliente)
      AND (p_id_estado IS NULL OR pr.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.titulo, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            pr.id,
            pr.numero_prestamo,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            pr.fecha_salida,
            pr.fecha_retorno_pactada,
            pr.fecha_retorno_real,
            pr.titulo,
            pr.id_estado,
            ep.nombre AS nombre_estado,
            pr.id_prestamo_origen,
            po.numero_prestamo AS numero_prestamo_origen,
            pr.id_comprobante_venta,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante_venta,
            pr.id_comprobante_compra,
            CASE
                WHEN cc.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cc.serie, cc.numero)
            END AS comprobante_compra,
            pr.estado,
            pr.fecha_creacion,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                WHERE pd.id_prestamo = pr.id AND pd.estado = 1
            ) AS total_detalles,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia vg
                WHERE vg.id_prestamo = pr.id AND vg.estado = 1
            ) AS total_garantias,
            (
                pr.id_comprobante_venta IS NULL
                AND pr.id_comprobante_compra IS NULL
                AND NOT EXISTS (
                    SELECT 1 FROM bal_prestamo_detalle pd
                    WHERE pd.id_prestamo = pr.id AND pd.estado = 1
                )
                AND NOT EXISTS (
                    SELECT 1 FROM ven_garantia vg
                    WHERE vg.id_prestamo = pr.id AND vg.estado = 1
                )
            ) AS puede_eliminar
        FROM bal_prestamo pr
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN gen_lista_opciones ep ON pr.id_estado = ep.id
        LEFT JOIN ven_comprobante cv ON pr.id_comprobante_venta = cv.id
        LEFT JOIN bal_prestamo po ON po.id = pr.id_prestamo_origen
        LEFT JOIN com_comprobante_compra cc ON pr.id_comprobante_compra = cc.id
        WHERE pr.estado = 1
          AND (p_id_tipo_prestamo IS NULL OR pr.id_tipo_prestamo = p_id_tipo_prestamo)
          AND (p_id_cliente IS NULL OR pr.id_cliente = p_id_cliente)
          AND (p_id_estado IS NULL OR pr.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.titulo, ''), p_busqueda)
          )
        ORDER BY pr.fecha_salida DESC NULLS LAST, pr.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
