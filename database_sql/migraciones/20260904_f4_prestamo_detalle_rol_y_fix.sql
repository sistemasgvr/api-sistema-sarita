-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
-- Aplicar DESPUÉS de 20260904_f4_prestamo_garantia_balon_esquema.sql (crea la
-- columna bal_prestamo_detalle.rol que estas funciones ya usan).
--
-- Tres funciones de la familia bal_*prestamo_detalle*, todas tocadas por el mismo
-- motivo: Fase 4 (apunte 1.c.viii) agrega el parámetro/columna p_rol/rol
-- ('ENTREGADO' | 'GARANTIA'). De paso corrige un bug preexistente y confirmado
-- en vivo (sin relación con Fase 4): dos de estas funciones seguían
-- referenciando id_guia_entrega/id_guia_devolucion, columnas que Fase 2 renombró
-- a id_doc_salida_entrega/id_doc_salida_devolucion al migrar de gre_guia_remision
-- a doc_salida — solo una de las dos columnas se corrigió en su momento, la otra
-- se quedó rota. Confirmado con pg_get_functiondef contra la BD viva: cualquier
-- llamada a bal_crear_prestamo_detalle o bal_listar_prestamo_detalles fallaba con
-- 'column ... does not exist'.

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
--
-- Fase 4 (apunte 1.c.viii) — agrega p_rol ('ENTREGADO' | 'GARANTIA') para que un
-- mismo préstamo pueda tener tanto el cilindro entregado al cliente como el que
-- dejó en garantía, cada uno como su propia fila de bal_prestamo_detalle.
--
-- De paso, corrige un bug preexistente sin relación con lo anterior: el INSERT
-- escribía en la columna "id_guia_devolucion", que ya no existe (Fase 2 la
-- renombró a "id_doc_salida_devolucion" al migrar de gre_guia_remision a
-- doc_salida; el par "id_doc_salida_entrega" sí se corrigió, este no). Cualquier
-- llamada a esta función fallaba con "column id_guia_devolucion does not exist".
DROP FUNCTION IF EXISTS bal_crear_prestamo_detalle(p_id_prestamo integer, p_id_balon integer, p_id_producto integer, p_motivo_especifico character varying, p_fecha_entregado date, p_fecha_prestamo date, p_dias_prestamo integer, p_fecha_vencimiento date, p_fecha_devolucion date, p_serie_guia_entrega character varying, p_numero_guia_entrega character varying, p_serie_guia_devolucion character varying, p_numero_guia_devolucion character varying, p_id_estado integer, p_observacion character varying, p_id_usuario_auditoria integer, p_id_guia_entrega integer, p_id_guia_devolucion integer);

CREATE OR REPLACE FUNCTION bal_crear_prestamo_detalle(p_id_prestamo integer, p_id_balon integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_motivo_especifico character varying DEFAULT NULL::character varying, p_fecha_entregado date DEFAULT NULL::date, p_fecha_prestamo date DEFAULT NULL::date, p_dias_prestamo integer DEFAULT 30, p_fecha_vencimiento date DEFAULT NULL::date, p_fecha_devolucion date DEFAULT NULL::date, p_serie_guia_entrega character varying DEFAULT NULL::character varying, p_numero_guia_entrega character varying DEFAULT NULL::character varying, p_serie_guia_devolucion character varying DEFAULT NULL::character varying, p_numero_guia_devolucion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_guia_entrega integer DEFAULT NULL::integer, p_id_guia_devolucion integer DEFAULT NULL::integer, p_rol character varying DEFAULT 'ENTREGADO'::character varying)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_producto INTEGER;
    v_id_estado_detalle INTEGER;
    v_salida JSON;
    v_serie_entrega VARCHAR;
    v_numero_entrega VARCHAR;
    v_serie_devolucion VARCHAR;
    v_numero_devolucion VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_id_producto := p_id_producto;
    v_id_estado_detalle := p_id_estado;
    v_serie_entrega := p_serie_guia_entrega;
    v_numero_entrega := p_numero_guia_entrega;
    v_serie_devolucion := p_serie_guia_devolucion;
    v_numero_devolucion := p_numero_guia_devolucion;

    -- Serie/número quedan como snapshot de la GRE vinculada (compatibilidad UI).
    IF p_id_guia_entrega IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_entrega, v_numero_entrega
        FROM doc_salida g
        WHERE g.id = p_id_guia_entrega AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de entrega indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    IF p_id_guia_devolucion IS NOT NULL THEN
        SELECT g.serie, g.numero_sunat INTO v_serie_devolucion, v_numero_devolucion
        FROM doc_salida g
        WHERE g.id = p_id_guia_devolucion AND g.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La guía de remisión de devolución indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    END IF;

    IF v_id_estado_detalle IS NULL AND p_fecha_devolucion IS NULL THEN
        SELECT lo.id INTO v_id_estado_detalle
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'ACTIVO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    IF p_id_balon IS NOT NULL THEN
        IF NOT EXISTS (
            SELECT 1 FROM bal_balon WHERE id = p_id_balon AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(b.id_producto_gas, v_id_producto) INTO v_id_producto
        FROM bal_balon b
        WHERE b.id = p_id_balon AND b.estado = 1;

        IF EXISTS (
            SELECT 1
            FROM bal_alquiler_detalle ad
            INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
            WHERE ad.id_balon = p_id_balon
              AND ad.estado = 1
              AND ad.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro está alquilado actualmente; no se puede prestar',
                'registro', NULL
            );
        END IF;

        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd
            INNER JOIN bal_prestamo p2 ON p2.id = pd.id_prestamo AND p2.estado = 1
            WHERE pd.id_balon = p_id_balon
              AND pd.estado = 1
              AND pd.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro ya tiene un préstamo activo sin devolver',
                'registro', NULL
            );
        END IF;
    END IF;

    INSERT INTO bal_prestamo_detalle (
        id_prestamo, id_balon, id_producto, motivo_especifico,
        fecha_entregado, fecha_prestamo, dias_prestamo, fecha_vencimiento, fecha_devolucion,
        id_doc_salida_entrega, id_doc_salida_devolucion,
        serie_guia_entrega, numero_guia_entrega, serie_guia_devolucion, numero_guia_devolucion,
        id_estado, observacion, rol,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_prestamo, p_id_balon, v_id_producto, p_motivo_especifico,
        p_fecha_entregado, p_fecha_prestamo, COALESCE(p_dias_prestamo, 30), p_fecha_vencimiento, p_fecha_devolucion,
        p_id_guia_entrega, p_id_guia_devolucion,
        v_serie_entrega, v_numero_entrega, v_serie_devolucion, v_numero_devolucion,
        v_id_estado_detalle, p_observacion, COALESCE(p_rol, 'ENTREGADO'),
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    -- Histórico ya devuelto: no mueve custodia. Activo: sale del almacén.
    -- Rol GARANTIA es al revés (el cilindro ENTRA a custodia de Sarita, no sale) —
    -- ese movimiento lo registra quien llama (ven_aplicar_efectos_pos), no aquí.
    IF p_id_balon IS NOT NULL AND p_fecha_devolucion IS NULL AND COALESCE(p_rol, 'ENTREGADO') = 'ENTREGADO' THEN
        v_salida := bal_prestamo_aplicar_salida_cilindro(
            p_id_prestamo,
            p_id_balon,
            p_observacion,
            p_id_usuario_auditoria
        );

        IF v_salida->>'error' IS NOT NULL THEN
            RAISE EXCEPTION '%', v_salida->>'error';
        END IF;
    END IF;

    RETURN bal_obtener_prestamo_detalle(v_id);
END;
$function$;

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_obtener_prestamo_detalle
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.948Z
DROP FUNCTION IF EXISTS bal_obtener_prestamo_detalle(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_prestamo_detalle(p_id integer)
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
            pd.id,
            pd.id_prestamo,
            pr.numero_prestamo,
            pd.id_balon,
            b.codigo_balon,
            pr.id_cliente,
            pr.id_almacen,
            pd.id_producto,
            COALESCE(pg.nombre, p.nombre) AS nombre_producto,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            eb.nombre AS nombre_estado_balon,
            pd.motivo_especifico,
            pd.fecha_entregado,
            pd.fecha_prestamo,
            pd.dias_prestamo,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            pd.id_doc_salida_entrega AS id_guia_entrega,
            ge.serie AS serie_guia_entrega_gre,
            ge.numero_sunat AS numero_guia_entrega_gre,
            pd.id_doc_salida_devolucion AS id_guia_devolucion,
            gd.serie AS serie_guia_devolucion_gre,
            gd.numero_sunat AS numero_guia_devolucion_gre,
            pd.serie_guia_entrega,
            pd.numero_guia_entrega,
            pd.serie_guia_devolucion,
            pd.numero_guia_devolucion,
            pd.id_estado,
            ep.nombre AS nombre_estado,
            pd.rol,
            pd.observacion,
            pd.estado,
            pd.fecha_creacion,
            pd.fecha_modificacion,
            pd.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            pd.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
        LEFT JOIN bal_balon b ON pd.id_balon = b.id
        LEFT JOIN pro_producto p ON pd.id_producto = p.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones ep ON pd.id_estado = ep.id
        LEFT JOIN doc_salida ge ON pd.id_doc_salida_entrega = ge.id
        LEFT JOIN doc_salida gd ON pd.id_doc_salida_devolucion = gd.id
        LEFT JOIN auth_usuarios uc ON pd.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON pd.id_usuario_modificacion = um.id
        WHERE pd.id = p_id AND pd.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_listar_prestamo_detalles
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.947Z
--
-- Fix (encontrado al trabajar en Fase 4, sin relación con lo que pedía esa
-- fase): el SELECT referenciaba pd.id_guia_entrega/pd.id_guia_devolucion, que
-- ya no existen (Fase 2 las renombró a id_doc_salida_entrega/
-- id_doc_salida_devolucion). Toda llamada a esta función fallaba con "column
-- pd.id_guia_entrega does not exist" — confirmado roto también en la BD viva,
-- no solo en este archivo. De paso se agrega pd.rol (Fase 4, apunte 1.c.viii).
DROP FUNCTION IF EXISTS bal_listar_prestamo_detalles(p_busqueda character varying, p_limite integer, p_offset integer, p_id_prestamo integer, p_id_balon integer, p_id_estado integer);

CREATE OR REPLACE FUNCTION bal_listar_prestamo_detalles(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0, p_id_prestamo integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM bal_prestamo_detalle pd
    INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
    LEFT JOIN bal_balon b ON pd.id_balon = b.id
    LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
    WHERE pd.estado = 1
      AND (p_id_prestamo IS NULL OR pd.id_prestamo = p_id_prestamo)
      AND (p_id_balon IS NULL OR pd.id_balon = p_id_balon)
      AND (p_id_estado IS NULL OR pd.id_estado = p_id_estado)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pd.motivo_especifico, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            pd.id,
            pd.id_prestamo,
            pr.numero_prestamo,
            pd.id_balon,
            b.codigo_balon,
            pr.id_tipo_prestamo,
            tp.nombre AS nombre_tipo_prestamo,
            pr.id_cliente,
            c.razon_social AS nombre_cliente,
            pr.id_almacen,
            a.nombre AS nombre_almacen,
            pd.id_producto,
            COALESCE(pg.nombre, p.nombre) AS nombre_producto,
            b.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            eb.nombre AS nombre_estado_balon,
            pd.fecha_entregado,
            pd.fecha_prestamo,
            pd.fecha_vencimiento,
            pd.fecha_devolucion,
            pd.id_doc_salida_entrega AS id_guia_entrega,
            pd.serie_guia_entrega,
            pd.numero_guia_entrega,
            pd.id_doc_salida_devolucion AS id_guia_devolucion,
            pd.serie_guia_devolucion,
            pd.numero_guia_devolucion,
            pd.id_estado,
            ep.nombre AS nombre_estado,
            pd.rol,
            pd.estado,
            pd.fecha_creacion
        FROM bal_prestamo_detalle pd
        INNER JOIN bal_prestamo pr ON pd.id_prestamo = pr.id
        LEFT JOIN bal_balon b ON pd.id_balon = b.id
        LEFT JOIN gen_lista_opciones tp ON pr.id_tipo_prestamo = tp.id
        LEFT JOIN cli_clientes c ON pr.id_cliente = c.id
        LEFT JOIN gen_almacen a ON pr.id_almacen = a.id
        LEFT JOIN pro_producto p ON pd.id_producto = p.id
        LEFT JOIN pro_producto pg ON b.id_producto_gas = pg.id
        LEFT JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
        LEFT JOIN gen_lista_opciones ep ON pd.id_estado = ep.id
        WHERE pd.estado = 1
          AND (p_id_prestamo IS NULL OR pd.id_prestamo = p_id_prestamo)
          AND (p_id_balon IS NULL OR pd.id_balon = p_id_balon)
          AND (p_id_estado IS NULL OR pd.id_estado = p_id_estado)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(b.codigo_balon, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pd.motivo_especifico, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(pr.numero_prestamo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(c.razon_social, ''), p_busqueda)
          )
        ORDER BY pd.fecha_prestamo DESC NULLS LAST, pd.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
