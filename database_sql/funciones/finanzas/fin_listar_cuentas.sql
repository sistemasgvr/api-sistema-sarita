-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_listar_cuentas
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.681Z
DROP FUNCTION IF EXISTS fin_listar_cuentas(p_tipo character varying, p_id_tercero integer, p_estado character varying, p_solo_pendientes integer, p_buscar character varying, p_id_padre integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION fin_listar_cuentas(p_tipo character varying DEFAULT NULL::character varying, p_id_tercero integer DEFAULT NULL::integer, p_estado character varying DEFAULT NULL::character varying, p_solo_pendientes integer DEFAULT NULL::integer, p_buscar character varying DEFAULT NULL::character varying, p_id_padre integer DEFAULT NULL::integer, p_limite integer DEFAULT 10, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
    v_id_tipo   INT;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;

    WITH base AS (
        SELECT
            fc.id,
            fc.id_tipo_cuenta,
            UPPER(p_tipo) AS tipo,
            fc.id_tercero,
            fc.tercero_nombre,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                fc.tercero_nombre,
                'Tercero #' || fc.id
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            fc.id_comprobante_venta,
            fc.id_comprobante_compra,
            fc.id_cuenta_padre,
            fc.numero_cuota,
            fc.numero_cuotas_total,
            fc.descripcion,
            fc.id_banco,
            fc.tasa_interes,
            fc.numero_comprobante,
            COALESCE(
                NULLIF(CONCAT_WS('-', vc.serie, vc.numero), '-'),
                NULLIF(CONCAT_WS('-', cc.serie, cc.numero), '-'),
                fc.numero_comprobante
            ) AS comprobante,
            fc.fecha_emision,
            fc.fecha_vencimiento,
            fin_redondear_monto(fc.monto_pendiente) AS monto_pendiente,
            fin_redondear_monto(COALESCE(fc.monto_abonado, 0)) AS monto_abonado,
            fin_redondear_monto(COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0))) AS saldo,
            fc.observacion,
            -- Indica si es cabecera de un plan de cuotas
            (fc.numero_cuotas_total IS NOT NULL) AS es_plan
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        LEFT JOIN ven_comprobante vc ON vc.id = fc.id_comprobante_venta
        LEFT JOIN com_comprobante_compra cc ON cc.id = fc.id_comprobante_compra
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
          AND (p_id_tercero IS NULL OR fc.id_tercero = p_id_tercero)
          -- Alcance: si p_id_padre viene, listar hijas; si no, solo primer nivel
          AND (
                (p_id_padre IS NULL AND fc.id_cuenta_padre IS NULL)
             OR (p_id_padre IS NOT NULL AND fc.id_cuenta_padre = p_id_padre)
          )
    ),
    calculado AS (
        SELECT b.*,
            fin_estado_cuenta_calculado(b.saldo, b.monto_abonado, b.fecha_vencimiento) AS estado_calculado,
            CASE
                WHEN b.saldo > 0
                     AND b.fecha_vencimiento IS NOT NULL
                     AND b.fecha_vencimiento < CURRENT_DATE
                    THEN (CURRENT_DATE - b.fecha_vencimiento)
                ELSE 0
            END AS dias_vencido
        FROM base b
    ),
    filtrados AS (
        SELECT * FROM calculado c
        WHERE (p_estado IS NULL OR c.estado_calculado = UPPER(p_estado))
          AND (p_solo_pendientes IS NULL OR p_solo_pendientes <> 1 OR c.saldo > 0)
          AND (
                v_buscar IS NULL
                OR c.tercero ILIKE '%' || v_buscar || '%'
                OR c.documento_tercero ILIKE '%' || v_buscar || '%'
                OR c.comprobante ILIKE '%' || v_buscar || '%'
                OR c.descripcion ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY
            COALESCE(numero_cuota, 0),
            (fecha_vencimiento IS NULL),
            fecha_vencimiento ASC,
            id DESC
        LIMIT p_limite
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$function$
