-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: dash_historico_ventas_compras
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.956Z
DROP FUNCTION IF EXISTS dash_historico_ventas_compras(p_anio integer);

CREATE OR REPLACE FUNCTION dash_historico_ventas_compras(p_anio integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_anio   INT := COALESCE(p_anio, EXTRACT(YEAR FROM CURRENT_DATE)::INT);
    v_result JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH meses AS (
        SELECT generate_series(1, 12) AS mes
    ),
    ventas AS (
        SELECT EXTRACT(MONTH FROM vc.fecha)::INT AS mes, SUM(vc.total_importe) AS total
        FROM ven_comprobante vc
        WHERE vc.estado = 1
          AND EXISTS (
              SELECT 1
              FROM gen_lista_opciones tipo
              JOIN gen_lista lista ON lista.id = tipo.id_lista AND lista.nombre = 'TipoComprobante'
              JOIN gen_lista_opciones interno ON interno.id = vc.id_estado
              JOIN gen_lista lista_interno ON lista_interno.id = interno.id_lista AND lista_interno.nombre = 'EstadoDocumento'
              JOIN gen_lista_opciones sunat ON sunat.id = vc.id_estado_sunat
              JOIN gen_lista lista_sunat ON lista_sunat.id = sunat.id_lista AND lista_sunat.nombre = 'EstadoSunat'
              WHERE tipo.id = vc.id_tipo_comprobante
                AND interno.nombre IN ('PENDIENTE', 'PAGADO')
                AND (
                    (tipo.descripcion IN ('01', '03') AND sunat.nombre = 'ACEPTADO')
                    OR (tipo.descripcion = 'VSD' AND sunat.nombre = 'NO_APLICA')
                )
          )
          AND EXTRACT(YEAR FROM vc.fecha) = v_anio
        GROUP BY 1
    ),
    compras AS (
        SELECT EXTRACT(MONTH FROM cc.fecha)::INT AS mes, SUM(cc.total_importe) AS total
        FROM com_comprobante_compra cc
        WHERE cc.estado = 1
          AND EXTRACT(YEAR FROM cc.fecha) = v_anio
        GROUP BY 1
    )
    SELECT json_build_object(
        'anio', v_anio,
        'meses', json_agg(
            json_build_object(
                'mes', m.mes,
                'nombreMes', TO_CHAR(TO_DATE(m.mes::text, 'MM'), 'Mon'),
                'ventas', COALESCE(v.total, 0),
                'compras', COALESCE(c.total, 0)
            )
            ORDER BY m.mes
        )
    )
    INTO v_result
    FROM meses m
    LEFT JOIN ventas v ON v.mes = m.mes
    LEFT JOIN compras c ON c.mes = m.mes;

    RETURN v_result;
END;
$function$;
