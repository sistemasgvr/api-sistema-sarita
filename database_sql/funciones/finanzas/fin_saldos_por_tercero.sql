-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: fin_saldos_por_tercero
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.690Z
DROP FUNCTION IF EXISTS fin_saldos_por_tercero(p_tipo character varying, p_fecha_corte date, p_buscar character varying, p_solo_pendientes integer, p_limite integer, p_offset integer);

CREATE OR REPLACE FUNCTION fin_saldos_por_tercero(p_tipo character varying DEFAULT 'COBRAR'::character varying, p_fecha_corte date DEFAULT CURRENT_DATE, p_buscar character varying DEFAULT NULL::character varying, p_solo_pendientes integer DEFAULT 1, p_limite integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo   INT;
    v_buscar    VARCHAR;
    v_corte     DATE;
    v_registros JSON;
    v_total     BIGINT;
    v_resumen   JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(COALESCE(p_buscar, '')), '');
    v_corte  := COALESCE(p_fecha_corte, CURRENT_DATE);

    SELECT glo.id INTO v_id_tipo
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'TipoCuentaFinanciera'
      AND glo.nombre = UPPER(p_tipo)
    LIMIT 1;

    WITH cuentas AS (
        SELECT
            fc.id,
            fc.id_tercero,
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                fc.tercero_nombre,
                'Tercero #' || fc.id
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            COALESCE(fc.id_tercero::text, LOWER(TRIM(COALESCE(fc.tercero_nombre, '')))) AS tercero_key,
            fc.monto_pendiente::NUMERIC AS debe,
            COALESCE((
                SELECT SUM(p.monto)
                FROM fin_pago p
                WHERE p.id_cuenta = fc.id
                  AND p.estado = 1
                  AND p.fecha_pago <= v_corte
            ), 0)::NUMERIC AS abonado
        FROM fin_cuenta fc
        LEFT JOIN cli_clientes ter ON ter.id = fc.id_tercero
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
          AND fc.numero_cuotas_total IS NULL
          AND (fc.fecha_emision IS NULL OR fc.fecha_emision <= v_corte)
          AND (
              v_buscar IS NULL
              OR gen_texto_coincide(COALESCE(ter.razon_social, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(ter.nombres, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(fc.tercero_nombre, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(ter.numero_documento, ''), v_buscar)
              OR gen_texto_coincide(COALESCE(fc.numero_comprobante, ''), v_buscar)
          )
    ),
    por_cuenta AS (
        SELECT
            *,
            GREATEST(debe - abonado, 0)::NUMERIC AS saldo
        FROM cuentas
    ),
    agrupado AS (
        SELECT
            MAX(id_tercero) AS id_tercero,
            MAX(tercero) AS tercero,
            MAX(documento_tercero) AS documento_tercero,
            tercero_key,
            COUNT(*)::INT AS cantidad_cuentas,
            SUM(debe)::NUMERIC AS debe,
            SUM(abonado)::NUMERIC AS abonado,
            SUM(saldo)::NUMERIC AS saldo
        FROM por_cuenta
        GROUP BY tercero_key
    ),
    filtrado AS (
        SELECT *
        FROM agrupado
        WHERE COALESCE(p_solo_pendientes, 1) = 0
           OR saldo > 0
    ),
    agregado AS (
        SELECT
            (SELECT COUNT(*) FROM filtrado) AS total,
            (
                SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON)
                FROM (
                    SELECT
                        id_tercero,
                        tercero,
                        documento_tercero,
                        cantidad_cuentas,
                        debe,
                        abonado,
                        saldo
                    FROM filtrado
                    ORDER BY saldo DESC, tercero ASC
                    LIMIT GREATEST(COALESCE(p_limite, 50), 1)
                    OFFSET GREATEST(COALESCE(p_offset, 0), 0)
                ) t
            ) AS registros,
            (
                SELECT json_build_object(
                    'fechaCorte', v_corte,
                    'totalDebe', COALESCE(SUM(debe), 0),
                    'totalAbonado', COALESCE(SUM(abonado), 0),
                    'totalSaldo', COALESCE(SUM(saldo), 0),
                    'cantidadTerceros', COUNT(*)
                )
                FROM filtrado
            ) AS resumen
    )
    SELECT a.total, a.registros, a.resumen
    INTO v_total, v_registros, v_resumen
    FROM agregado a;

    RETURN json_build_object(
        'registros', COALESCE(v_registros, '[]'::JSON),
        'total', COALESCE(v_total, 0),
        'resumen', COALESCE(
            v_resumen,
            json_build_object(
                'fechaCorte', v_corte,
                'totalDebe', 0,
                'totalAbonado', 0,
                'totalSaldo', 0,
                'cantidadTerceros', 0
            )
        )
    );
END;
$function$
