-- Lista cuentas financieras (por COBRAR o por PAGAR) con paginación y filtros.
-- Comparte la tabla fin_cuenta; el tipo se resuelve por nombre (COBRAR/PAGAR).

DROP FUNCTION IF EXISTS fin_listar_cuentas(VARCHAR, INT, VARCHAR, INT, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION fin_listar_cuentas(
    p_tipo            VARCHAR DEFAULT NULL,   -- 'COBRAR' | 'PAGAR'
    p_id_tercero      INT     DEFAULT NULL,
    p_estado          VARCHAR DEFAULT NULL,   -- PENDIENTE | PARCIAL | VENCIDO | PAGADO
    p_solo_pendientes INT     DEFAULT NULL,   -- 1 = solo cuentas con saldo > 0
    p_buscar          VARCHAR DEFAULT NULL,
    p_limite          INT     DEFAULT 10,
    p_offset          INT     DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
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
            COALESCE(
                NULLIF(TRIM(ter.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', ter.nombres, ter.apellido_paterno, ter.apellido_materno)), ''),
                'Tercero #' || fc.id_tercero
            ) AS tercero,
            ter.numero_documento AS documento_tercero,
            fc.id_comprobante_venta,
            fc.id_comprobante_compra,
            COALESCE(
                NULLIF(CONCAT_WS('-', vc.serie, vc.numero), '-'),
                NULLIF(CONCAT_WS('-', cc.serie, cc.numero), '-')
            ) AS comprobante,
            fc.fecha_emision,
            fc.fecha_vencimiento,
            fc.monto_pendiente,
            COALESCE(fc.monto_abonado, 0) AS monto_abonado,
            COALESCE(fc.monto_saldo, fc.monto_pendiente - COALESCE(fc.monto_abonado, 0)) AS saldo,
            fc.observacion
        FROM fin_cuenta fc
        JOIN cli_clientes ter ON ter.id = fc.id_tercero
        LEFT JOIN ven_comprobante vc ON vc.id = fc.id_comprobante_venta
        LEFT JOIN com_comprobante_compra cc ON cc.id = fc.id_comprobante_compra
        WHERE fc.estado = 1
          AND (v_id_tipo IS NULL OR fc.id_tipo_cuenta = v_id_tipo)
          AND (p_id_tercero IS NULL OR fc.id_tercero = p_id_tercero)
    ),
    calculado AS (
        SELECT b.*,
            CASE
                WHEN b.saldo <= 0 THEN 'PAGADO'
                WHEN b.fecha_vencimiento IS NOT NULL AND b.fecha_vencimiento < CURRENT_DATE THEN 'VENCIDO'
                WHEN b.monto_abonado > 0 THEN 'PARCIAL'
                ELSE 'PENDIENTE'
            END AS estado_calculado,
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
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY (fecha_vencimiento IS NULL), fecha_vencimiento ASC, id DESC
        LIMIT p_limite
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;
