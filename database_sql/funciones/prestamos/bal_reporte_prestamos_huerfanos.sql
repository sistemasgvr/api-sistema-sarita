CREATE OR REPLACE FUNCTION bal_reporte_prestamos_huerfanos()
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COALESCE(
            json_agg(
                json_build_object(
                    'id', p.id,
                    'numero_prestamo', p.numero_prestamo,
                    'id_tipo_prestamo', p.id_tipo_prestamo,
                    'nombre_tipo', tp.nombre,
                    'id_cliente', p.id_cliente,
                    'id_comprobante_venta', p.id_comprobante_venta,
                    'id_comprobante_compra', p.id_comprobante_compra,
                    'total_detalles', (
                        SELECT COUNT(*) FROM bal_prestamo_detalle pd
                        WHERE pd.id_prestamo = p.id AND pd.estado = 1
                    ),
                    'total_detalles_con_balon', (
                        SELECT COUNT(*) FROM bal_prestamo_detalle pd
                        WHERE pd.id_prestamo = p.id AND pd.estado = 1 AND pd.id_balon IS NOT NULL
                    ),
                    'fecha_retorno_pactada', p.fecha_retorno_pactada
                )
            ),
            '[]'::JSON
        ),
        COUNT(*)
    INTO v_registros, v_total
    FROM bal_prestamo p
    LEFT JOIN gen_lista_opciones tp ON tp.id = p.id_tipo_prestamo
    WHERE p.estado = 1
      AND p.id_comprobante_venta IS NULL
      AND p.id_comprobante_compra IS NULL
      AND EXISTS (
          SELECT 1 FROM bal_prestamo_detalle pd
          WHERE pd.id_prestamo = p.id AND pd.estado = 1 AND pd.id_balon IS NULL
      );

    RETURN json_build_object(
        'ok', TRUE,
        'total', v_total,
        'registros', v_registros
    );
END;
$function$;
