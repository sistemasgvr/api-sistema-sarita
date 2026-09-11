-- Dirección de entrega marcada desde la orden de salida → ficha del
-- cliente/proveedor → mapa.
--
-- Hoy la dirección manual del modal "Dirección de entrega" solo queda en
-- doc_salida, así que el cliente/proveedor sigue sin ubicación y no aparece en
-- el mapa. Con este cambio:
--   1) doc_registrar_direccion_entrega recibe p_guardar_en_cliente (default TRUE)
--      y, en modo manual, inserta/reutiliza la dirección en cli_direcciones del
--      destinatario (id_destinatario → id_cliente → id_proveedor) y enlaza el
--      documento a esa fila. Es principal solo si el cliente no tenía una.
--   2) cli_listar_clientes_mapa deja de exigir es_principal: dibuja la principal
--      si está georreferenciada y, si no, la dirección con coordenadas más
--      reciente.
--
-- ⚠️ NO EJECUTAR sin revisión — aplicar con apply-migration.js cuando el
-- usuario lo confirme:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260911_doc_salida_direccion_a_cliente.sql

-- 1) ===== database_sql/funciones/documentos-salida/doc_registrar_direccion_entrega.sql =====
-- Registra o actualiza la dirección de entrega + coordenadas de un documento
-- de salida. Se puede llamar en cualquier momento del ciclo (BORRADOR o
-- GENERADA) — no mueve inventario ni cambia estado, solo guarda dónde
-- entregar. Si viene de una dirección guardada del cliente (p_id_direccion_cliente),
-- se copia el snapshot de esa fila; si es manual, se usan los parámetros tal cual.
--
-- Dirección manual + p_guardar_en_cliente (default TRUE): la dirección se
-- registra también en cli_direcciones del destinatario del documento
-- (id_destinatario → id_cliente → id_proveedor; los proveedores también son
-- filas de cli_clientes) y el doc queda enlazado a esa fila. Así una dirección
-- marcada desde la orden de salida aparece en la ficha del cliente/proveedor
-- y en el mapa (cli_listar_clientes_mapa). Si el cliente ya tiene una
-- dirección activa con el mismo texto se reutiliza (y se completan sus
-- coordenadas/referencia/distrito con lo nuevo) en vez de duplicarla. Solo se
-- marca como principal cuando el cliente aún no tiene una.
--
-- ⚠️ Requiere las columnas agregadas por
-- database_sql/migraciones/20260904_doc_salida_direccion_entrega.sql.
DROP FUNCTION IF EXISTS doc_registrar_direccion_entrega(p_id integer, p_direccion_entrega character varying, p_referencia_entrega character varying, p_latitud numeric, p_longitud numeric, p_id_distrito_entrega integer, p_id_direccion_cliente integer, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS doc_registrar_direccion_entrega(p_id integer, p_direccion_entrega character varying, p_referencia_entrega character varying, p_latitud numeric, p_longitud numeric, p_id_distrito_entrega integer, p_id_direccion_cliente integer, p_id_usuario_auditoria integer, p_guardar_en_cliente boolean);

CREATE OR REPLACE FUNCTION doc_registrar_direccion_entrega(
    p_id integer,
    p_direccion_entrega character varying DEFAULT NULL::character varying,
    p_referencia_entrega character varying DEFAULT NULL::character varying,
    p_latitud numeric DEFAULT NULL::numeric,
    p_longitud numeric DEFAULT NULL::numeric,
    p_id_distrito_entrega integer DEFAULT NULL::integer,
    p_id_direccion_cliente integer DEFAULT NULL::integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_guardar_en_cliente boolean DEFAULT TRUE
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_direccion VARCHAR;
    v_referencia VARCHAR;
    v_latitud NUMERIC;
    v_longitud NUMERIC;
    v_id_distrito INTEGER;
    v_id_direccion_cliente INTEGER;
    v_id_cliente INTEGER;
    v_id_provincia INTEGER;
    v_id_departamento INTEGER;
    v_id_pais INTEGER;
    v_tiene_principal BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    v_id_direccion_cliente := p_id_direccion_cliente;

    IF p_id_direccion_cliente IS NOT NULL THEN
        SELECT cd.direccion, cd.referencia, cd.latitud, cd.longitud, cd.id_distrito
        INTO v_direccion, v_referencia, v_latitud, v_longitud, v_id_distrito
        FROM cli_direcciones cd
        WHERE cd.id = p_id_direccion_cliente AND cd.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La dirección del cliente indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    ELSE
        v_direccion := NULLIF(TRIM(p_direccion_entrega), '');
        v_referencia := NULLIF(TRIM(p_referencia_entrega), '');
        v_latitud := p_latitud;
        v_longitud := p_longitud;
        v_id_distrito := p_id_distrito_entrega;
    END IF;

    IF v_direccion IS NULL THEN
        RETURN json_build_object('error', 'La dirección de entrega es obligatoria', 'registro', NULL);
    END IF;

    -- Dirección manual: asociarla al cliente/proveedor destinatario del documento.
    v_id_cliente := COALESCE(v_doc.id_destinatario, v_doc.id_cliente, v_doc.id_proveedor);

    IF p_id_direccion_cliente IS NULL AND COALESCE(p_guardar_en_cliente, TRUE) AND v_id_cliente IS NOT NULL THEN
        -- Reutilizar una dirección activa con el mismo texto en vez de duplicarla.
        SELECT cd.id
        INTO v_id_direccion_cliente
        FROM cli_direcciones cd
        WHERE cd.id_cliente = v_id_cliente
          AND cd.estado = 1
          AND LOWER(TRIM(cd.direccion)) = LOWER(v_direccion)
        ORDER BY cd.es_principal DESC, cd.id DESC
        LIMIT 1;

        IF v_id_direccion_cliente IS NOT NULL THEN
            UPDATE cli_direcciones
            SET latitud = COALESCE(v_latitud, latitud),
                longitud = COALESCE(v_longitud, longitud),
                referencia = COALESCE(v_referencia, referencia),
                id_distrito = COALESCE(v_id_distrito, id_distrito),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_direccion_cliente;
        ELSE
            IF v_id_distrito IS NOT NULL THEN
                SELECT d.id_provincia, pr.id_departamento, dp.id_pais
                INTO v_id_provincia, v_id_departamento, v_id_pais
                FROM gen_distrito d
                JOIN gen_provincia pr ON pr.id = d.id_provincia
                JOIN gen_departamento dp ON dp.id = pr.id_departamento
                WHERE d.id = v_id_distrito;
            END IF;

            SELECT EXISTS (
                SELECT 1 FROM cli_direcciones cd
                WHERE cd.id_cliente = v_id_cliente AND cd.estado = 1 AND cd.es_principal = TRUE
            ) INTO v_tiene_principal;

            INSERT INTO cli_direcciones (
                id_cliente,
                descripcion,
                direccion,
                id_pais,
                id_departamento,
                id_provincia,
                id_distrito,
                referencia,
                latitud,
                longitud,
                es_principal,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id_cliente,
                'Entrega ' || COALESCE(v_doc.serie || '-', '') || v_doc.numero,
                v_direccion,
                v_id_pais,
                v_id_departamento,
                v_id_provincia,
                v_id_distrito,
                v_referencia,
                v_latitud,
                v_longitud,
                NOT v_tiene_principal,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            )
            RETURNING id INTO v_id_direccion_cliente;
        END IF;
    END IF;

    UPDATE doc_salida
    SET direccion_entrega = v_direccion,
        referencia_entrega = v_referencia,
        latitud = v_latitud,
        longitud = v_longitud,
        id_distrito_entrega = v_id_distrito,
        id_direccion_cliente = v_id_direccion_cliente,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;

-- 2) ===== database_sql/funciones/clientes/cli_listar_clientes_mapa.sql =====
-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: cli_listar_clientes_mapa
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.952Z
DROP FUNCTION IF EXISTS cli_listar_clientes_mapa(p_solo_activos integer, p_buscar character varying, p_filtro_balones character varying, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION cli_listar_clientes_mapa(p_solo_activos integer DEFAULT 1, p_buscar character varying DEFAULT NULL::character varying, p_filtro_balones character varying DEFAULT NULL::character varying, p_limite integer DEFAULT 500, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_filtro    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');
    v_filtro := NULLIF(UPPER(TRIM(p_filtro_balones)), '');

    WITH balones_campo AS (
        SELECT
            x.id_cliente,
            x.id_balon,
            x.codigo_balon,
            x.numero_serie,
            x.nombre_estado_balon,
            x.nombre_tipo_balon,
            x.tipo_relacion,
            x.fecha_inicio,
            x.fecha_limite,
            x.dias_en_cliente,
            x.vencido,
            x.alerta_antiguedad
        FROM (
            SELECT
                COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) AS id_cliente,
                b.id AS id_balon,
                b.codigo_balon,
                b.numero_serie,
                eb.nombre AS nombre_estado_balon,
                tb.nombre AS nombre_tipo_balon,
                CASE eb.nombre
                    WHEN 'PRESTADO_CLIENTE' THEN 'PRESTAMO'
                    WHEN 'POR_RECOGER' THEN 'PRESTAMO'
                    WHEN 'ALQUILADO' THEN 'ALQUILER'
                    WHEN 'EN_PODER_CLIENTE' THEN 'PROPIO'
                    ELSE eb.nombre
                END AS tipo_relacion,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER')
                        THEN COALESCE(prest.fecha_inicio, b.fecha_modificacion::date)
                    WHEN eb.nombre = 'ALQUILADO'
                        THEN COALESCE(alq.fecha_inicio, b.fecha_modificacion::date)
                    ELSE NULL
                END AS fecha_inicio,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_limite
                    WHEN eb.nombre = 'ALQUILADO' THEN alq.fecha_limite
                    ELSE NULL
                END AS fecha_limite,
                CASE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER', 'ALQUILADO')
                         AND COALESCE(
                             CASE
                                 WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                 WHEN eb.nombre = 'ALQUILADO' THEN alq.fecha_inicio
                             END,
                             b.fecha_modificacion::date
                         ) IS NOT NULL
                    THEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    )::INTEGER
                    ELSE NULL
                END AS dias_en_cliente,
                CASE
                    WHEN eb.nombre = 'ALQUILADO'
                         AND alq.fecha_limite IS NOT NULL
                         AND CURRENT_DATE > alq.fecha_limite
                    THEN TRUE
                    WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER')
                         AND prest.fecha_limite IS NOT NULL
                         AND CURRENT_DATE > prest.fecha_limite
                    THEN TRUE
                    ELSE FALSE
                END AS vencido,
                CASE
                    WHEN eb.nombre NOT IN ('PRESTADO_CLIENTE', 'POR_RECOGER', 'ALQUILADO') THEN NULL
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 180 THEN 'CRITICO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 90 THEN 'SEGUIMIENTO'
                    WHEN (
                        CURRENT_DATE - COALESCE(
                            CASE
                                WHEN eb.nombre IN ('PRESTADO_CLIENTE', 'POR_RECOGER') THEN prest.fecha_inicio
                                WHEN eb.nombre = 'ALQUILADO' THEN alq.fecha_inicio
                            END,
                            b.fecha_modificacion::date
                        )
                    ) >= 30 THEN 'ATENCION'
                    ELSE 'RECIENTE'
                END AS alerta_antiguedad
            FROM bal_balon b
            INNER JOIN gen_lista_opciones eb ON b.id_estado_balon = eb.id
            LEFT JOIN bal_tipo_balon tb ON b.id_tipo_balon = tb.id
            LEFT JOIN LATERAL (
                SELECT
                    COALESCE(pd.fecha_prestamo, pd.fecha_entregado, pr.fecha_salida) AS fecha_inicio,
                    pd.fecha_vencimiento AS fecha_limite
                FROM bal_prestamo_detalle pd
                INNER JOIN bal_prestamo pr ON pr.id = pd.id_prestamo AND pr.estado = 1
                WHERE pd.id_balon = b.id
                  AND pd.estado = 1
                  AND pd.fecha_devolucion IS NULL
                  AND pr.id_cliente = COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario)
                ORDER BY pd.id DESC
                LIMIT 1
            ) prest ON TRUE
            LEFT JOIN LATERAL (
                SELECT
                    al.fecha_inicio,
                    al.fecha_fin_pactada AS fecha_limite
                FROM bal_alquiler_detalle ad
                INNER JOIN bal_alquiler al ON al.id = ad.id_alquiler AND al.estado = 1
                WHERE ad.id_balon = b.id
                  AND ad.estado = 1
                  AND ad.fecha_devolucion IS NULL
                  AND al.id_cliente = COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario)
                ORDER BY ad.id DESC
                LIMIT 1
            ) alq ON TRUE
            WHERE b.estado = 1
              AND eb.nombre IN (
                  'PRESTADO_CLIENTE',
                  'POR_RECOGER',
                  'ALQUILADO',
                  'EN_PODER_CLIENTE'
              )
              AND COALESCE(b.id_cliente_ubicacion, b.id_cliente_propietario) IS NOT NULL
        ) x
    ),
    balones_agg AS (
        SELECT
            bc.id_cliente,
            json_agg(
                json_build_object(
                    'id_balon', bc.id_balon,
                    'codigo_balon', bc.codigo_balon,
                    'numero_serie', bc.numero_serie,
                    'nombre_estado_balon', bc.nombre_estado_balon,
                    'nombre_tipo_balon', bc.nombre_tipo_balon,
                    'tipo_relacion', bc.tipo_relacion,
                    'fecha_inicio', bc.fecha_inicio,
                    'fecha_limite', bc.fecha_limite,
                    'dias_en_cliente', bc.dias_en_cliente,
                    'vencido', bc.vencido,
                    'alerta_antiguedad', bc.alerta_antiguedad
                )
                ORDER BY
                    CASE WHEN bc.vencido THEN 0 ELSE 1 END,
                    bc.dias_en_cliente DESC NULLS LAST,
                    bc.codigo_balon
            ) AS balones,
            COUNT(*)::INT AS total_balones,
            BOOL_OR(bc.tipo_relacion = 'PRESTAMO') AS tiene_prestamo,
            BOOL_OR(bc.tipo_relacion = 'ALQUILER') AS tiene_alquiler,
            BOOL_OR(bc.tipo_relacion = 'PROPIO') AS tiene_propio,
            BOOL_OR(COALESCE(bc.vencido, FALSE)) AS tiene_vencidos,
            MAX(bc.dias_en_cliente) AS max_dias_en_cliente
        FROM (
            SELECT DISTINCT ON (id_cliente, id_balon)
                id_cliente,
                id_balon,
                codigo_balon,
                numero_serie,
                nombre_estado_balon,
                nombre_tipo_balon,
                tipo_relacion,
                fecha_inicio,
                fecha_limite,
                dias_en_cliente,
                vencido,
                alerta_antiguedad
            FROM balones_campo
            ORDER BY id_cliente, id_balon, tipo_relacion
        ) bc
        GROUP BY bc.id_cliente
    ),
    filtrados AS (
        SELECT
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.numero_documento,
            tp.nombre AS nombre_tipo_persona,
            c.telefono,
            dir.direccion,
            dir.referencia,
            dir.latitud,
            dir.longitud,
            c.estado,
            COALESCE(ba.balones, '[]'::json) AS balones,
            COALESCE(ba.total_balones, 0) AS total_balones,
            COALESCE(ba.tiene_prestamo, FALSE) AS tiene_prestamo,
            COALESCE(ba.tiene_alquiler, FALSE) AS tiene_alquiler,
            COALESCE(ba.tiene_propio, FALSE) AS tiene_propio,
            COALESCE(ba.tiene_vencidos, FALSE) AS tiene_vencidos,
            ba.max_dias_en_cliente
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        -- Dirección a dibujar: la principal si tiene coordenadas; si no, la
        -- georreferenciada más reciente (ej. la marcada desde una orden de salida).
        INNER JOIN LATERAL (
            SELECT cd.*
            FROM cli_direcciones cd
            WHERE cd.id_cliente = c.id
              AND cd.estado = 1
              AND cd.latitud IS NOT NULL
              AND cd.longitud IS NOT NULL
            ORDER BY cd.es_principal DESC, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN balones_agg ba ON ba.id_cliente = c.id
        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (
                v_buscar IS NULL
                OR gen_texto_coincide(c.razon_social, v_buscar)
                OR gen_texto_coincide(c.nombres, v_buscar)
                OR gen_texto_coincide(c.apellido_paterno, v_buscar)
                OR gen_texto_coincide(c.apellido_materno, v_buscar)
                OR gen_texto_coincide(c.numero_documento, v_buscar)
                OR gen_texto_coincide(c.codigo_interno, v_buscar)
                OR gen_texto_coincide(dir.direccion, v_buscar)
              )
          AND (
                v_filtro IS NULL
                OR (v_filtro = 'CON_BALONES' AND COALESCE(ba.total_balones, 0) > 0)
                OR (v_filtro = 'PRESTADO_CLIENTE' AND COALESCE(ba.tiene_prestamo, FALSE))
                OR (v_filtro = 'ALQUILADO' AND COALESCE(ba.tiene_alquiler, FALSE))
                OR (v_filtro = 'EN_PODER_CLIENTE' AND COALESCE(ba.tiene_propio, FALSE))
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY
            CASE WHEN tiene_vencidos THEN 0 ELSE 1 END,
            total_balones DESC,
            razon_social NULLS LAST,
            nombres NULLS LAST,
            id DESC
        LIMIT GREATEST(COALESCE(p_limite, 500), 1)
        OFFSET GREATEST(COALESCE(p_offset, 0), 0)
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$;
