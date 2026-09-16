-- GRE P0 (plan docs/PLAN_GRE_DIAGNOSTICO_Y_CAMBIOS_20260916.md, etapas 1-4):
--  * domicilio fiscal real de la empresa emisora (id_distrito → ubigeo);
--  * nombres y apellidos del chofer por separado en doc_obtener_salida;
--  * entorno/empresa/RUC registrados en cada intento de envío;
--  * correlativo GRE reservado por empresa + serie (antes global por serie).
-- Requiere aplicada 20260916_gre_fecha_e_intentos.sql (doc_gre_intento).
BEGIN;

-- 1. Domicilio fiscal de la empresa emisora.
ALTER TABLE gen_empresa ADD COLUMN IF NOT EXISTS id_distrito integer REFERENCES gen_distrito(id);

-- 2. Contexto de cada intento: con qué empresa, RUC y entorno del PSE se envió.
--    La consulta posterior compara contra esto y no contra la configuración vigente.
ALTER TABLE doc_gre_intento ADD COLUMN IF NOT EXISTS id_empresa integer REFERENCES gen_empresa(id);
ALTER TABLE doc_gre_intento ADD COLUMN IF NOT EXISTS ruc_emisor varchar(11);
ALTER TABLE doc_gre_intento ADD COLUMN IF NOT EXISTS entorno text;
ALTER TABLE doc_gre_intento ADD COLUMN IF NOT EXISTS id_empresa_pse integer;
ALTER TABLE doc_gre_intento ADD COLUMN IF NOT EXISTS consultas integer NOT NULL DEFAULT 0;
ALTER TABLE doc_gre_intento ADD COLUMN IF NOT EXISTS proxima_consulta timestamptz;
CREATE INDEX IF NOT EXISTS ix_doc_gre_intento_pendientes ON doc_gre_intento(proxima_consulta)
WHERE estado IN ('PENDIENTE', 'POR_CONFIRMAR');

-- 3. Numeración por empresa + serie. Los históricos sin empresa quedan en el
--    grupo 0 y conservan su unicidad; no se renumera ni se reutilizan números.
DROP INDEX IF EXISTS uq_doc_salida_serie_numero;
CREATE UNIQUE INDEX IF NOT EXISTS uq_doc_salida_empresa_serie_numero
ON doc_salida (COALESCE(id_empresa, 0), serie, numero_sunat)
WHERE serie IS NOT NULL AND numero_sunat IS NOT NULL AND estado = 1;


-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_obtener_empresa
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.963Z
--
-- Actualizada por database_sql/migraciones/20260916_gre_p0_fiscal_numeracion_entorno.sql:
-- expone el distrito fiscal (id, nombres y ubigeo) para la dirección de la
-- empresa emisora en la GRE.
DROP FUNCTION IF EXISTS gen_obtener_empresa(p_id integer);

CREATE OR REPLACE FUNCTION gen_obtener_empresa(p_id integer)
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
            e.id,
            e.ruc,
            e.razon_social,
            e.nombre_comercial,
            e.direccion,
            -- Domicilio fiscal (GRE): el ubigeo sale de la empresa, no de un
            -- valor fijo en el mapper.
            e.id_distrito,
            dist.nombre AS nombre_distrito,
            dist.codigo_ubigeo,
            dist.id_provincia,
            prov.nombre AS nombre_provincia,
            prov.id_departamento,
            dep.nombre AS nombre_departamento,
            dep.id_pais,
            e.telefono,
            e.email,
            e.tolerancia_m3_ruta_pueblo,
            e.psi_minimo_util,
            e.estado,
            e.fecha_creacion,
            e.fecha_modificacion,
            e.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            e.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_empresa e
        LEFT JOIN gen_distrito dist ON dist.id = e.id_distrito
        LEFT JOIN gen_provincia prov ON prov.id = dist.id_provincia
        LEFT JOIN gen_departamento dep ON dep.id = prov.id_departamento
        LEFT JOIN auth_usuarios uc ON e.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON e.id_usuario_modificacion = um.id
        WHERE e.id = p_id AND e.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;


-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_listar_empresas
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.962Z
DROP FUNCTION IF EXISTS gen_listar_empresas(p_busqueda character varying, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION gen_listar_empresas(p_busqueda character varying DEFAULT ''::character varying, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_empresa e
    WHERE e.estado = 1
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(e.ruc, p_busqueda)
          OR gen_texto_coincide(COALESCE(e.razon_social, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(e.nombre_comercial, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(e.email, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            e.id,
            e.ruc,
            e.razon_social,
            e.nombre_comercial,
            e.direccion,
            e.id_distrito,
            dist.nombre AS nombre_distrito,
            dist.codigo_ubigeo,
            e.telefono,
            e.email,
            e.tolerancia_m3_ruta_pueblo,
            e.psi_minimo_util,
            e.estado,
            e.fecha_creacion,
            e.fecha_modificacion,
            e.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            e.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_empresa e
        LEFT JOIN gen_distrito dist ON dist.id = e.id_distrito
        LEFT JOIN auth_usuarios uc ON e.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON e.id_usuario_modificacion = um.id
        WHERE e.estado = 1
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(e.ruc, p_busqueda)
              OR gen_texto_coincide(COALESCE(e.razon_social, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(e.nombre_comercial, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(e.email, ''), p_busqueda)
          )
        ORDER BY e.nombre_comercial ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;


-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_crear_empresa
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_crear_empresa(p_ruc character varying, p_razon_social character varying, p_nombre_comercial character varying, p_direccion character varying, p_telefono character varying, p_email character varying, p_id_usuario_auditoria integer, p_tolerancia_m3_ruta_pueblo numeric, p_psi_minimo_util numeric);
DROP FUNCTION IF EXISTS gen_crear_empresa(p_ruc character varying, p_razon_social character varying, p_nombre_comercial character varying, p_direccion character varying, p_telefono character varying, p_email character varying, p_id_usuario_auditoria integer, p_tolerancia_m3_ruta_pueblo numeric, p_psi_minimo_util numeric, p_id_distrito integer);

CREATE OR REPLACE FUNCTION gen_crear_empresa(p_ruc character varying, p_razon_social character varying DEFAULT NULL::character varying, p_nombre_comercial character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_tolerancia_m3_ruta_pueblo numeric DEFAULT NULL::numeric, p_psi_minimo_util numeric DEFAULT NULL::numeric, p_id_distrito integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    INSERT INTO gen_empresa (
        ruc,
        razon_social,
        nombre_comercial,
        direccion,
        telefono,
        email,
        tolerancia_m3_ruta_pueblo,
        psi_minimo_util,
        id_distrito,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_ruc,
        p_razon_social,
        p_nombre_comercial,
        p_direccion,
        p_telefono,
        p_email,
        p_tolerancia_m3_ruta_pueblo,
        p_psi_minimo_util,
        p_id_distrito,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN gen_obtener_empresa(v_id);
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('error', SQLERRM, 'registro', NULL);
END;
$function$;


-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_empresa
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.961Z
DROP FUNCTION IF EXISTS gen_actualizar_empresa(p_id integer, p_ruc character varying, p_razon_social character varying, p_nombre_comercial character varying, p_direccion character varying, p_telefono character varying, p_email character varying, p_tolerancia_m3_ruta_pueblo numeric, p_psi_minimo_util numeric, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS gen_actualizar_empresa(p_id integer, p_ruc character varying, p_razon_social character varying, p_nombre_comercial character varying, p_direccion character varying, p_telefono character varying, p_email character varying, p_tolerancia_m3_ruta_pueblo numeric, p_psi_minimo_util numeric, p_id_usuario_auditoria integer, p_id_distrito integer);

CREATE OR REPLACE FUNCTION gen_actualizar_empresa(p_id integer, p_ruc character varying DEFAULT NULL::character varying, p_razon_social character varying DEFAULT NULL::character varying, p_nombre_comercial character varying DEFAULT NULL::character varying, p_direccion character varying DEFAULT NULL::character varying, p_telefono character varying DEFAULT NULL::character varying, p_email character varying DEFAULT NULL::character varying, p_tolerancia_m3_ruta_pueblo numeric DEFAULT NULL::numeric, p_psi_minimo_util numeric DEFAULT NULL::numeric, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_distrito integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_tolerancia_m3_ruta_pueblo IS NOT NULL AND p_tolerancia_m3_ruta_pueblo < 0 THEN
        RETURN json_build_object('error', 'La tolerancia de ruta pueblos no puede ser negativa', 'registro', NULL);
    END IF;

    IF p_psi_minimo_util IS NOT NULL AND p_psi_minimo_util < 0 THEN
        RETURN json_build_object('error', 'El umbral PSI mínimo no puede ser negativo', 'registro', NULL);
    END IF;

    IF p_id_distrito IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_distrito WHERE id = p_id_distrito AND estado = 1 AND codigo_ubigeo IS NOT NULL
    ) THEN
        RETURN json_build_object('error', 'El distrito fiscal no existe o no tiene código ubigeo', 'registro', NULL);
    END IF;

    UPDATE gen_empresa
    SET
        ruc = COALESCE(p_ruc, ruc),
        razon_social = COALESCE(p_razon_social, razon_social),
        nombre_comercial = COALESCE(p_nombre_comercial, nombre_comercial),
        direccion = COALESCE(p_direccion, direccion),
        telefono = COALESCE(p_telefono, telefono),
        email = COALESCE(p_email, email),
        tolerancia_m3_ruta_pueblo = COALESCE(p_tolerancia_m3_ruta_pueblo, tolerancia_m3_ruta_pueblo),
        psi_minimo_util = COALESCE(p_psi_minimo_util, psi_minimo_util),
        id_distrito = COALESCE(p_id_distrito, id_distrito),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_empresa(p_id);
END;
$function$;


-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: doc_obtener_salida
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.958Z
--
-- Actualizada por database_sql/migraciones/20260910_compras_anular_retorno_p0p1.sql:
-- el detalle expone id_unidad_capacidad_balon (U.M. de la capacidad del tipo
-- de balón). Compras arma sus líneas de gas sumando capacidades, y sin el id
-- de esa unidad la línea quedaba con U.M. nula y el gas entraba sin convertir.
--
-- Actualizada por database_sql/migraciones/20260905_venta_gas_prestamo_garantia_join.sql:
-- con id_venta el detalle une los items de la venta con los cilindros
-- entregados en prestamo (rol ENTREGADO) y descarta las lineas de garantia.
--
-- Actualizada por database_sql/migraciones/20260910_retorno_fisico_fecha_ph.sql:
-- retorno_fisico (¿los cilindros ya entraron al almacén?) y el almacén de
-- llegada. La UI daba el retorno por hecho con solo fecha_llegada_almacen, que
-- no implica movimiento de inventario.
DROP FUNCTION IF EXISTS doc_obtener_salida(p_id integer);

CREATE OR REPLACE FUNCTION doc_obtener_salida(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_id_venta INTEGER;
    v_venta_anulada BOOLEAN;
    v_detalle JSON;
    v_ultimo_item_venta INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.id_venta INTO v_id_venta FROM doc_salida d WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF v_id_venta IS NOT NULL THEN
        SELECT (vc.estado = 0) INTO v_venta_anulada FROM ven_comprobante vc WHERE vc.id = v_id_venta;

        -- El detalle de una orden ligada a venta se arma por JOIN (principio
        -- "detalle no duplicado") y tiene dos orígenes:
        --   VENTA    — los ítems/productos del comprobante. Si la venta fue
        --              anulada sus líneas quedaron en estado=0
        --              (ven_eliminar_comprobante), así que el OR con
        --              v_venta_anulada evita que el documento se vea vacío en
        --              vez de mostrar qué se vendió originalmente. Cuando el
        --              ítem ya trae id_balon, esa fila representa el cilindro
        --              y el gas despachado.
        --   PRESTAMO — cilindros entregados en préstamo por esa misma venta
        --              que NO aparezcan ya en el detalle de la venta. Si el
        --              gas se vendió ligado al mismo cilindro, repetirlo aquí
        --              duplicaba el balón en la orden de salida.
        -- Se excluyen dos cosas: las líneas de garantía antiguas (garantía es
        -- dinero, no se despacha) y los cilindros de rol GARANTIA, que entran al
        -- almacén en vez de salir.
        -- El item de los cilindros continúa la numeración de la venta, así que
        -- se calcula antes: dentro del UNION no hay forma de mirar el otro lado.
        SELECT COALESCE(MAX(vd.item), 0) INTO v_ultimo_item_venta
        FROM ven_comprobante_detalle vd
        WHERE vd.id_comprobante = v_id_venta
          AND (vd.estado = 1 OR v_venta_anulada)
          AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a';

        SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON) INTO v_detalle
        FROM (
            SELECT
                vd.id,
                vd.item,
                vd.id_producto,
                p.codigo AS codigo_producto,
                COALESCE(vd.descripcion, p.nombre) AS descripcion,
                vd.id_balon,
                b.codigo_balon,
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                vd.cantidad,
                vd.id_unidad_medida,
                um.nombre AS nombre_unidad_medida,
                um.descripcion AS codigo_unidad_medida,
                COALESCE(pgb.nombre, p.nombre) AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'VENTA'::VARCHAR AS origen_detalle
            FROM ven_comprobante_detalle vd
            LEFT JOIN pro_producto p ON p.id = vd.id_producto
            LEFT JOIN bal_balon b ON b.id = vd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            LEFT JOIN gen_lista_opciones um ON um.id = vd.id_unidad_medida
            WHERE vd.id_comprobante = v_id_venta
              AND (vd.estado = 1 OR v_venta_anulada)
              AND COALESCE(vd.descripcion, '') !~* 'garant[ií]a'
            UNION ALL
            SELECT
                pd.id,
                v_ultimo_item_venta + (ROW_NUMBER() OVER (ORDER BY pd.id))::INTEGER AS item,
                NULL::INTEGER AS id_producto,
                b.codigo_balon AS codigo_producto,
                (
                    'Cilindro en préstamo — '
                    || COALESCE(b.codigo_balon, 'sin código')
                    || COALESCE(' (' || tb.nombre || ')', '')
                )::VARCHAR AS descripcion,
                pd.id_balon,
                b.codigo_balon,
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                1::NUMERIC AS cantidad,
                NULL::INTEGER AS id_unidad_medida,
                NULL::VARCHAR AS nombre_unidad_medida,
                NULL::VARCHAR AS codigo_unidad_medida,
                COALESCE(pgb.nombre, tb.nombre)::VARCHAR AS nombre_producto,
                NULL::VARCHAR AS glosa,
                NULL::INTEGER AS id_movimiento,
                'PRESTAMO'::VARCHAR AS origen_detalle
            FROM bal_prestamo pr
            INNER JOIN bal_prestamo_detalle pd
                ON pd.id_prestamo = pr.id AND pd.estado = 1
            LEFT JOIN bal_balon b ON b.id = pd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            WHERE pr.id_comprobante_venta = v_id_venta
              AND pr.estado = 1
              AND pd.rol = 'ENTREGADO'
              AND pd.id_balon IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM ven_comprobante_detalle vd_bal
                  WHERE vd_bal.id_comprobante = v_id_venta
                    AND vd_bal.id_balon = pd.id_balon
                    AND (vd_bal.estado = 1 OR v_venta_anulada)
                    AND COALESCE(vd_bal.descripcion, '') !~* 'garant[ií]a'
              )
        ) t;
    ELSE
        SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.item), '[]'::JSON) INTO v_detalle
        FROM (
            SELECT
                dd.id,
                dd.item,
                dd.id_producto,
                p.codigo AS codigo_producto,
                COALESCE(dd.descripcion, p.nombre, b.codigo_balon) AS descripcion,
                dd.id_balon,
                b.codigo_balon,
                -- Tipo y almacén del cilindro: la card del detalle los muestra
                -- igual que el selector, y el detalle no los tenía.
                b.id_tipo_balon,
                tb.nombre AS nombre_tipo_balon,
                alm.nombre AS nombre_almacen_balon,
                -- Capacidad del tipo: en planta externa el editor la suma por
                -- gas para topar cuánto se puede declarar que sale. Sin esto,
                -- al recargar un documento ya guardado no habría con qué
                -- calcular ese tope.
                tb.capacidad AS capacidad_balon,
                umtb.nombre AS unidad_capacidad_balon,
                tb.id_unidad_medida AS id_unidad_capacidad_balon,
                -- Gas del cilindro: decide si la orden puede asociarse a una
                -- ficha de lote y protocolo (una ficha cubre un solo gas).
                b.id_producto_gas AS id_producto_gas_balon,
                pgb.nombre AS nombre_producto_gas_balon,
                b.numero_serie AS numero_serie_balon,
                b.id_lote_protocolo_vigente,
                dd.cantidad,
                dd.id_unidad_medida,
                um.nombre AS nombre_unidad_medida,
                um.descripcion AS codigo_unidad_medida,
                p.nombre AS nombre_producto,
                dd.glosa,
                dd.id_movimiento,
                'PROPIO'::VARCHAR AS origen_detalle
            FROM doc_salida_detalle dd
            LEFT JOIN pro_producto p ON p.id = dd.id_producto
            LEFT JOIN bal_balon b ON b.id = dd.id_balon
            LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
            LEFT JOIN gen_lista_opciones umtb ON umtb.id = tb.id_unidad_medida
            LEFT JOIN pro_producto pgb ON pgb.id = b.id_producto_gas
            LEFT JOIN gen_almacen alm ON alm.id = b.id_almacen
            LEFT JOIN gen_lista_opciones um ON um.id = dd.id_unidad_medida
            WHERE dd.id_doc_salida = p_id AND dd.estado = 1
        ) t;
    END IF;

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            d.id, d.numero, d.id_empresa,
            d.id_tipo_orden, tor.nombre AS nombre_tipo_orden,
            d.id_estado_ciclo, ec.nombre AS nombre_estado_ciclo,
            d.emitido_sunat,
            d.id_venta, vc.serie AS serie_venta, vc.numero AS numero_venta,
            d.id_doc_salida_origen,
            d.id_sucursal, suc.nombre AS nombre_sucursal,
            d.id_almacen, alm.nombre AS nombre_almacen,
            -- Destino del traslado: además de mover el stock, es la dirección
            -- de llegada por defecto de la guía de remisión.
            d.id_almacen_destino,
            almdest.nombre AS nombre_almacen_destino,
            almdest.ubicacion AS direccion_almacen_destino,
            almdest.id_distrito AS id_distrito_almacen_destino,
            almdest.id_provincia AS id_provincia_almacen_destino,
            almdest.id_departamento AS id_departamento_almacen_destino,
            depalmdest.id_pais AS id_pais_almacen_destino,
            -- Ubicación del almacén: es el punto de partida por defecto de la
            -- guía de remisión, para no volver a tipear el origen.
            alm.ubicacion AS direccion_almacen,
            alm.id_distrito AS id_distrito_almacen,
            alm.id_provincia AS id_provincia_almacen,
            alm.id_departamento AS id_departamento_almacen,
            distalm.codigo_ubigeo AS ubigeo_almacen,
            depalm.id_pais AS id_pais_almacen,
            d.id_cliente,
            COALESCE(NULLIF(TRIM(cli.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), '')) AS nombre_cliente,
            d.id_destinatario, d.destinatario_nombre, d.destinatario_documento,
            COALESCE(NULLIF(TRIM(d.destinatario_nombre), ''),
                     NULLIF(TRIM(dest.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', dest.nombres, dest.apellido_paterno, dest.apellido_materno)), '')) AS nombre_destinatario,
            COALESCE(NULLIF(TRIM(d.destinatario_documento), ''), dest.numero_documento) AS documento_destinatario,
            tddest.nombre AS nombre_tipo_doc_destinatario,
            COALESCE(NULLIF(TRIM(d.remitente_documento), ''), cli.numero_documento) AS documento_cliente,
            tdcli.nombre AS nombre_tipo_doc_cliente,
            d.id_proveedor,
            COALESCE(NULLIF(TRIM(prov.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', prov.nombres, prov.apellido_paterno, prov.apellido_materno)), '')) AS nombre_proveedor,
            prov.numero_documento AS documento_proveedor,
            d.fecha, d.fecha_emision_gre,
            (SELECT i.estado FROM doc_gre_intento i WHERE i.id_doc_salida = d.id ORDER BY i.id DESC LIMIT 1) AS gre_estado_envio,
            -- Entorno (beta/produccion) con el que se envió el último intento: la
            -- consulta posterior debe usar ese y no la configuración vigente.
            (SELECT i.entorno FROM doc_gre_intento i WHERE i.id_doc_salida = d.id ORDER BY i.id DESC LIMIT 1) AS gre_entorno,
            d.fecha_traslado, d.fecha_retorno,
            d.id_tipo_guia_remision, tgr.nombre AS nombre_tipo_guia_remision,
            tgr.descripcion AS codigo_tipo_guia,
            d.serie, d.numero_sunat,
            d.id_estado_sunat, es.nombre AS nombre_estado_sunat,
            d.ticket_sunat, d.hash_documento, d.cdr_respuesta,
            d.tipo_cambio,
            d.id_motivo_traslado, mt.nombre AS nombre_motivo_traslado,
            mt.descripcion AS codigo_motivo_traslado,
            d.id_modalidad_traslado, mod.nombre AS nombre_modalidad_traslado,
            mod.descripcion AS codigo_modalidad_traslado,
            d.id_unidad_medida, umd.nombre AS nombre_unidad_medida,
            umd.descripcion AS codigo_unidad_medida,
            d.peso_bruto, d.numero_bultos,
            d.direccion_origen, d.id_distrito_origen,
            disto.codigo_ubigeo AS ubigeo_origen,
            disto.id_provincia AS id_provincia_origen,
            provo.id_departamento AS id_departamento_origen,
            depo.id_pais AS id_pais_origen,
            d.direccion_llegada, d.id_distrito_llegada,
            distl.codigo_ubigeo AS ubigeo_llegada,
            distl.id_provincia AS id_provincia_llegada,
            provl.id_departamento AS id_departamento_llegada,
            depl.id_pais AS id_pais_llegada,
            d.direccion_entrega, d.referencia_entrega, d.latitud, d.longitud,
            d.id_distrito_entrega, distent.nombre AS nombre_distrito_entrega,
            distent.codigo_ubigeo AS ubigeo_entrega,
            distent.id_provincia AS id_provincia_entrega,
            propent.id_departamento AS id_departamento_entrega,
            depent.id_pais AS id_pais_entrega,
            d.id_direccion_cliente,
            d.id_transportista,
            COALESCE(NULLIF(TRIM(trans.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', trans.nombres, trans.apellido_paterno, trans.apellido_materno)), '')) AS nombre_transportista,
            trans.numero_documento AS documento_transportista,
            d.id_chofer,
            -- Preferir identidad del trabajador vinculado (más actual) para GRE.
            TRIM(CONCAT_WS(
                ' ',
                COALESCE(NULLIF(TRIM(tra.nombres), ''), cho.nombres),
                COALESCE(NULLIF(TRIM(tra.apellido_paterno), ''), cho.apellido_paterno),
                COALESCE(NULLIF(TRIM(tra.apellido_materno), ''), cho.apellido_materno)
            )) AS nombre_chofer,
            -- Nombres y apellidos por separado: la GRE los exige estructurados y
            -- partir la cadena falla con nombres compuestos.
            COALESCE(NULLIF(TRIM(tra.nombres), ''), NULLIF(TRIM(cho.nombres), '')) AS nombres_chofer,
            COALESCE(NULLIF(TRIM(tra.apellido_paterno), ''), NULLIF(TRIM(cho.apellido_paterno), '')) AS apellido_paterno_chofer,
            COALESCE(NULLIF(TRIM(tra.apellido_materno), ''), NULLIF(TRIM(cho.apellido_materno), '')) AS apellido_materno_chofer,
            COALESCE(NULLIF(TRIM(tra.numero_documento), ''), cho.numero_documento) AS documento_chofer,
            COALESCE(tdtra.descripcion, tdch.descripcion) AS codigo_tipo_doc_chofer,
            (SELECT lic.codigo FROM gen_licencia lic
              WHERE lic.id_chofer = cho.id AND lic.estado = 1
              ORDER BY lic.fecha_vencimiento DESC, lic.fecha_emision DESC, lic.id DESC LIMIT 1) AS licencia_chofer,
            (SELECT lic.fecha_vencimiento FROM gen_licencia lic
              WHERE lic.id_chofer = cho.id AND lic.estado = 1
              ORDER BY lic.fecha_vencimiento DESC, lic.fecha_emision DESC, lic.id DESC LIMIT 1) AS licencia_chofer_vencimiento,
            d.id_vehiculo, veh.placa AS placa_vehiculo, veh.placa,
            d.id_responsable, d.remitente_nombre, d.remitente_documento,
            d.id_comprobante_compra,
            d.serie_guia_salida, d.numero_guia_salida,
            d.serie_guia_ingreso, d.numero_guia_ingreso,
            d.serie_factura, d.numero_factura,
            d.fecha_llegada_almacen, d.lote, d.fecha_vencimiento_lote, d.fecha_prueba_hidrostatica,
            d.id_lote_protocolo,
            -- Almacén al que llegaron los cilindros de planta externa. Es otra
            -- cosa que id_almacen (de dónde salieron), que el retorno pisaba.
            d.id_almacen_retorno, almret.nombre AS nombre_almacen_retorno,
            -- Retorno físico: los envases tienen su entrada vigente. Solo con
            -- esto los cilindros están de vuelta y el gas ingresó; la fecha de
            -- llegada por sí sola no mueve inventario.
            EXISTS (
                SELECT 1
                FROM inv_movimiento m
                JOIN doc_salida_detalle ddr ON ddr.id = m.id_documento_detalle
                JOIN gen_lista_opciones tmv ON tmv.id = m.id_tipo_movimiento
                JOIN gen_lista ltmv ON ltmv.id = tmv.id_lista
                WHERE m.estado = 1
                  AND m.naturaleza = 'BALON'
                  AND ltmv.nombre = 'TipoMovInvUnificado'
                  AND tmv.nombre = 'ENTRADA_PLANTA_EXTERNA'
                  AND ddr.id_doc_salida = d.id
                  AND ddr.id_balon IS NOT NULL
                  AND m.id_balon = ddr.id_balon
            ) AS retorno_fisico,
            d.periodo_contable, d.operacion, d.observaciones, d.id_archivo_pdf,
            d.estado, d.fecha_creacion, d.fecha_modificacion,
            d.id_usuario_creacion, uc.nombre AS nombre_usuario_creacion,
            (d.id_venta IS NOT NULL) AS detalle_desde_venta,
            COALESCE(v_venta_anulada, FALSE) AS venta_anulada,
            v_detalle AS detalle,
            (
                SELECT COALESCE(json_agg(row_to_json(r)), '[]'::JSON)
                FROM (
                    SELECT dr.id, dr.id_tipo_comprobante, tc.nombre AS nombre_tipo_comprobante,
                           tc.descripcion AS codigo_tipo_comprobante,
                           dr.id_comprobante, dr.serie, dr.numero, dr.fecha
                    FROM doc_salida_referencia dr
                    LEFT JOIN gen_lista_opciones tc ON tc.id = dr.id_tipo_comprobante
                    WHERE dr.id_doc_salida = d.id AND dr.estado = 1
                ) r
            ) AS referencias
        FROM doc_salida d
        LEFT JOIN gen_lista_opciones tor ON tor.id = d.id_tipo_orden
        LEFT JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
        LEFT JOIN gen_lista_opciones es ON es.id = d.id_estado_sunat
        LEFT JOIN gen_lista_opciones tgr ON tgr.id = d.id_tipo_guia_remision
        LEFT JOIN gen_lista_opciones mt ON mt.id = d.id_motivo_traslado
        LEFT JOIN gen_lista_opciones mod ON mod.id = d.id_modalidad_traslado
        LEFT JOIN ven_comprobante vc ON vc.id = d.id_venta
        LEFT JOIN gen_sucursal suc ON suc.id = d.id_sucursal
        LEFT JOIN gen_almacen alm ON alm.id = d.id_almacen
        LEFT JOIN gen_almacen almdest ON almdest.id = d.id_almacen_destino
        LEFT JOIN gen_almacen almret ON almret.id = d.id_almacen_retorno
        LEFT JOIN cli_clientes cli ON cli.id = d.id_cliente
        LEFT JOIN cli_clientes prov ON prov.id = d.id_proveedor
        LEFT JOIN gen_vehiculo veh ON veh.id = d.id_vehiculo
        LEFT JOIN gen_lista_opciones umd ON umd.id = d.id_unidad_medida
        LEFT JOIN gen_distrito distalm ON distalm.id = alm.id_distrito
        LEFT JOIN gen_departamento depalm ON depalm.id = alm.id_departamento
        LEFT JOIN gen_departamento depalmdest ON depalmdest.id = almdest.id_departamento
        LEFT JOIN gen_distrito disto ON disto.id = d.id_distrito_origen
        LEFT JOIN gen_provincia provo ON provo.id = disto.id_provincia
        LEFT JOIN gen_departamento depo ON depo.id = provo.id_departamento
        LEFT JOIN gen_distrito distl ON distl.id = d.id_distrito_llegada
        LEFT JOIN gen_provincia provl ON provl.id = distl.id_provincia
        LEFT JOIN gen_departamento depl ON depl.id = provl.id_departamento
        LEFT JOIN gen_distrito distent ON distent.id = d.id_distrito_entrega
        LEFT JOIN gen_provincia propent ON propent.id = distent.id_provincia
        LEFT JOIN gen_departamento depent ON depent.id = propent.id_departamento
        LEFT JOIN cli_clientes trans ON trans.id = d.id_transportista
        LEFT JOIN cli_clientes dest ON dest.id = d.id_destinatario
        LEFT JOIN gen_chofer cho ON cho.id = d.id_chofer
        LEFT JOIN tra_trabajadores tra ON tra.id = cho.id_trabajador AND tra.estado = 1
        LEFT JOIN gen_lista_opciones tdch ON tdch.id = cho.id_tipo_documento
        LEFT JOIN gen_lista_opciones tdtra ON tdtra.id = tra.id_tipo_documento
        LEFT JOIN gen_lista_opciones tddest ON tddest.id = dest.id_tipo_documento
        LEFT JOIN gen_lista_opciones tdcli ON tdcli.id = cli.id_tipo_documento
        LEFT JOIN auth_usuarios uc ON uc.id = d.id_usuario_creacion
        WHERE d.id = p_id AND d.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;


-- Firma única: empresa emisora y datos adicionales GRE.
-- Sustituye las variantes incompatibles de 17 y 18 parámetros, sin CASCADE.
--
-- Actualizada por database_sql/migraciones/20260916_gre_p0_fiscal_numeracion_entorno.sql:
-- el correlativo se reserva por empresa + serie (índice único
-- uq_doc_salida_empresa_serie_numero); antes era global por serie.
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer);
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, integer);
DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, json);

DROP FUNCTION IF EXISTS public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, integer, json);

CREATE OR REPLACE FUNCTION public.doc_convertir_a_gre(p_id integer, p_id_tipo_guia_remision integer, p_serie character varying, p_id_motivo_traslado integer DEFAULT NULL::integer, p_id_modalidad_traslado integer DEFAULT NULL::integer, p_id_transportista integer DEFAULT NULL::integer, p_id_chofer integer DEFAULT NULL::integer, p_id_vehiculo integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso_bruto numeric DEFAULT NULL::numeric, p_numero_bultos integer DEFAULT NULL::integer, p_direccion_origen character varying DEFAULT NULL::character varying, p_id_distrito_origen integer DEFAULT NULL::integer, p_direccion_llegada character varying DEFAULT NULL::character varying, p_id_distrito_llegada integer DEFAULT NULL::integer, p_fecha_traslado date DEFAULT NULL::date, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_empresa integer DEFAULT NULL::integer, p_gre_extra json DEFAULT NULL::json, p_fecha_emision_gre date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_serie VARCHAR;
    v_siguiente INTEGER;
    v_numero VARCHAR;
    v_id_tipo_guia INTEGER;
    v_codigo_tipo_guia VARCHAR;
    v_id_modalidad INTEGER;
    v_codigo_modalidad VARCHAR;
    v_id_transportista INTEGER;
    v_id_chofer INTEGER;
    v_id_vehiculo INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1 FOR UPDATE OF d;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF p_id_empresa IS NULL OR NOT EXISTS (SELECT 1 FROM gen_empresa WHERE id = p_id_empresa AND estado = 1) THEN
        RETURN json_build_object('error', 'Selecciona una empresa emisora activa', 'registro', NULL);
    END IF;
    IF v_doc.id_empresa IS NOT NULL AND v_doc.id_empresa <> p_id_empresa AND v_doc.numero_sunat IS NOT NULL THEN
        RETURN json_build_object('error', 'La guía ya pertenece a otra empresa emisora', 'registro', NULL);
    END IF;
    IF v_doc.id_empresa IS NULL AND (v_doc.ticket_sunat IS NOT NULL OR COALESCE(v_doc.emitido_sunat, FALSE)) THEN
        RETURN json_build_object('error', 'Esta guía histórica requiere verificar su emisor antes de vincular una empresa', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'BORRADOR' THEN
        RETURN json_build_object(
            'error', 'Genera el documento antes de convertirlo en guía de remisión',
            'registro', NULL
        );
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF COALESCE(v_doc.emitido_sunat, FALSE) THEN
        RETURN json_build_object('error', 'El documento ya fue emitido a SUNAT', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM doc_gre_intento WHERE id_doc_salida = p_id AND estado <> 'RECHAZADO') THEN
        RETURN json_build_object('error', 'La GRE tiene un envío en curso, aceptado o pendiente de verificar', 'registro', NULL);
    END IF;
    IF COALESCE(p_fecha_emision_gre, v_doc.fecha_emision_gre) IS NULL THEN
        RETURN json_build_object('error', 'Indica la fecha de emisión de la GRE', 'registro', NULL);
    END IF;

    v_serie := UPPER(TRIM(COALESCE(p_serie, v_doc.serie, '')));
    IF v_serie = '' THEN
        RETURN json_build_object('error', 'La serie de la guía de remisión es obligatoria', 'registro', NULL);
    END IF;

    IF char_length(v_serie) <> 4 THEN
        RETURN json_build_object('error', 'La serie electrónica debe tener 4 caracteres (ej. T001, V001)', 'registro', NULL);
    END IF;

    IF p_id_tipo_guia_remision IS NULL AND v_doc.id_tipo_guia_remision IS NULL THEN
        RETURN json_build_object('error', 'El tipo de guía de remisión es obligatorio', 'registro', NULL);
    END IF;

    -- Tipo de guía y modalidad efectivos (lo enviado o lo ya guardado).
    v_id_tipo_guia := COALESCE(p_id_tipo_guia_remision, v_doc.id_tipo_guia_remision);
    SELECT TRIM(lo.descripcion) INTO v_codigo_tipo_guia
    FROM gen_lista_opciones lo WHERE lo.id = v_id_tipo_guia;

    v_id_modalidad := COALESCE(p_id_modalidad_traslado, v_doc.id_modalidad_traslado);

    -- GRE transportista (31): la empresa emisora ES el transportista, así que
    -- la modalidad SUNAT es siempre transporte público (01).
    IF v_codigo_tipo_guia = '31' THEN
        SELECT lo.id INTO v_id_modalidad
        FROM gen_lista_opciones lo
        JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'ModalidadTraslado' AND lo.nombre = 'PUBLICO' AND lo.estado = 1
        LIMIT 1;
    END IF;

    SELECT TRIM(lo.descripcion) INTO v_codigo_modalidad
    FROM gen_lista_opciones lo WHERE lo.id = v_id_modalidad;

    -- Transporte según lo que SUNAT espera en cada caso; lo que no aplica se
    -- limpia para que ni el PDF ni el payload arrastren datos de una
    -- modalidad anterior.
    v_id_transportista := COALESCE(p_id_transportista, v_doc.id_transportista);
    v_id_chofer := COALESCE(p_id_chofer, v_doc.id_chofer);
    v_id_vehiculo := COALESCE(p_id_vehiculo, v_doc.id_vehiculo);

    IF v_codigo_tipo_guia = '31' THEN
        -- Vehículo y chofer propios; el transportista es la propia empresa.
        v_id_transportista := NULL;
    ELSIF v_codigo_modalidad = '01' THEN
        -- Público: un tercero con RUC lleva la carga con su propia flota.
        v_id_chofer := NULL;
        v_id_vehiculo := NULL;
    ELSIF v_codigo_modalidad = '02' THEN
        -- Privado: flota propia, sin transportista tercero.
        v_id_transportista := NULL;
    END IF;

    -- El correlativo SUNAT se reserva ahora; si ya tenía uno, se conserva.
    IF v_doc.numero_sunat IS NOT NULL AND v_doc.serie = v_serie AND v_doc.id_empresa = p_id_empresa THEN
        v_numero := v_doc.numero_sunat;
    ELSE
        -- Candado por empresa + serie dentro de la TX: dos empresas pueden usar
        -- la misma serie (cada RUC numera aparte en SUNAT) sin bloquearse ni
        -- colisionar; dos GRE concurrentes de la misma empresa se serializan.
        PERFORM pg_advisory_xact_lock(872017, hashtext(p_id_empresa::TEXT || '|' || v_serie));

        -- Se cuentan también los documentos anulados (no se reutilizan números)
        -- y los históricos sin empresa: mientras no se determine su emisor, es
        -- más seguro asumir que ese correlativo ya se usó ante SUNAT.
        SELECT COALESCE(MAX(NULLIF(REGEXP_REPLACE(numero_sunat, '\D', '', 'g'), '')::INTEGER), 0) + 1
        INTO v_siguiente
        FROM doc_salida
        WHERE serie = v_serie AND (id_empresa = p_id_empresa OR id_empresa IS NULL);

        v_numero := LPAD(v_siguiente::TEXT, 8, '0');
    END IF;

    UPDATE doc_salida
    SET id_empresa = p_id_empresa,
        id_tipo_guia_remision = v_id_tipo_guia,
        serie = v_serie,
        numero_sunat = v_numero,
        id_motivo_traslado = COALESCE(p_id_motivo_traslado, id_motivo_traslado),
        id_modalidad_traslado = v_id_modalidad,
        id_transportista = v_id_transportista,
        id_chofer = v_id_chofer,
        id_vehiculo = v_id_vehiculo,
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso_bruto = COALESCE(p_peso_bruto, peso_bruto),
        numero_bultos = COALESCE(p_numero_bultos, numero_bultos),
        direccion_origen = COALESCE(p_direccion_origen, direccion_origen),
        id_distrito_origen = COALESCE(p_id_distrito_origen, id_distrito_origen),
        direccion_llegada = COALESCE(p_direccion_llegada, direccion_llegada),
        id_distrito_llegada = COALESCE(p_id_distrito_llegada, id_distrito_llegada),
        fecha_emision_gre = COALESCE(p_fecha_emision_gre, fecha_emision_gre),
        fecha_traslado = COALESCE(p_fecha_traslado, fecha_traslado, fecha),
        -- Datos opcionales SUNAT (indicadores, MTC, docBaja, tercero...). NULL = no tocar;
        -- {} = limpiar.
        gre_extra = COALESCE(p_gre_extra::jsonb, gre_extra),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    -- Si la orden nace de una venta, esa venta es su documento de referencia SUNAT.
    IF v_doc.id_venta IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM doc_salida_referencia WHERE id_doc_salida = p_id AND id_comprobante = v_doc.id_venta AND estado = 1
    ) THEN
        INSERT INTO doc_salida_referencia (
            id_doc_salida, id_tipo_comprobante, id_comprobante, serie, numero, fecha,
            id_usuario_creacion, id_usuario_modificacion
        )
        SELECT p_id, vc.id_tipo_comprobante, vc.id, vc.serie, vc.numero, vc.fecha,
               p_id_usuario_auditoria, p_id_usuario_auditoria
        FROM ven_comprobante vc WHERE vc.id = v_doc.id_venta;
    END IF;

    RETURN doc_obtener_salida(p_id);
END;
$function$;


-- Verificación de firmas y dependencias requeridas por el backend.
DO $$
BEGIN
  PERFORM 'public.doc_convertir_a_gre(integer, integer, character varying, integer, integer, integer, integer, integer, integer, numeric, integer, character varying, integer, character varying, integer, date, integer, integer, json, date)'::regprocedure;
  PERFORM 'public.gen_actualizar_empresa(integer, character varying, character varying, character varying, character varying, character varying, character varying, numeric, numeric, integer, integer)'::regprocedure;
  PERFORM 'public.gen_crear_empresa(character varying, character varying, character varying, character varying, character varying, character varying, integer, numeric, numeric, integer)'::regprocedure;
  PERFORM 'public.doc_obtener_salida(integer)'::regprocedure;
  PERFORM 'public.doc_listar_series_gre(integer)'::regprocedure;
  PERFORM 'public.doc_registrar_respuesta_sunat(integer, character varying, character varying, character varying, text, text, integer)'::regprocedure;
  IF (SELECT COUNT(*) FROM pg_proc WHERE proname = 'doc_convertir_a_gre') <> 1 THEN
    RAISE EXCEPTION 'doc_convertir_a_gre debe tener una única firma';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'doc_gre_intento' AND column_name = 'entorno') THEN
    RAISE EXCEPTION 'doc_gre_intento.entorno ausente';
  END IF;
END $$;

COMMIT;
