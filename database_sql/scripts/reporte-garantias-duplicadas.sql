-- Reporte SOLO DE LECTURA: ventas donde la garantía quedó registrada dos veces.
--
-- Antes del cambio de 20260905 el POS hacía dos cosas con el mismo dinero:
--   1. insertaba una línea "Garantía reembolsable — X" en ven_comprobante_detalle,
--      con lo que la garantía entraba al total del comprobante y a sus pagos; y
--   2. creaba la garantía real en ven_garantia + ven_garantia_movimiento (COBRO).
--
-- Efecto: fin_caja_calcular_totales suma ambas cosas, así que el arqueo del día
-- cuenta esa garantía dos veces. Este script NO corrige nada — solo lista los
-- comprobantes afectados para decidir caso por caso qué hacer con cada uno.
--
-- Uso:
--   psql "$DATABASE_URL" -f database_sql/scripts/reporte-garantias-duplicadas.sql
-- o, para acotar el rango, editar las fechas del WHERE de abajo.

SET TIME ZONE 'America/Lima';

WITH lineas_garantia AS (
    SELECT
        d.id_comprobante,
        COUNT(*)                AS lineas,
        SUM(COALESCE(d.importe, 0)) AS monto_en_venta
    FROM ven_comprobante_detalle d
    WHERE d.estado = 1
      AND COALESCE(d.descripcion, '') ~* 'garant[ií]a'
    GROUP BY d.id_comprobante
),
cobros_garantia AS (
    SELECT
        gm.id_comprobante,
        COUNT(*)              AS movimientos,
        SUM(gm.monto)         AS monto_en_garantia
    FROM ven_garantia_movimiento gm
    INNER JOIN gen_lista_opciones tm ON tm.id = gm.id_tipo_movimiento
    WHERE gm.estado = 1
      AND UPPER(tm.nombre) = 'COBRO'
      AND gm.id_comprobante IS NOT NULL
    GROUP BY gm.id_comprobante
)
SELECT
    c.id                                   AS id_comprobante,
    c.fecha,
    c.id_sucursal,
    su.nombre                              AS sucursal,
    tc.descripcion                         AS codigo_tipo_comprobante,
    c.serie || '-' || c.numero             AS documento,
    es.nombre                              AS estado_sunat,
    COALESCE(
        NULLIF(TRIM(cl.razon_social), ''),
        NULLIF(TRIM(CONCAT_WS(' ', cl.nombres, cl.apellido_paterno, cl.apellido_materno)), '')
    )                                      AS cliente,
    c.total_importe,
    lg.lineas                              AS lineas_garantia_en_venta,
    lg.monto_en_venta,
    cg.movimientos                         AS movimientos_cobro_garantia,
    cg.monto_en_garantia,
    LEAST(lg.monto_en_venta, cg.monto_en_garantia) AS monto_contado_dos_veces
FROM ven_comprobante c
INNER JOIN lineas_garantia lg ON lg.id_comprobante = c.id
INNER JOIN cobros_garantia cg ON cg.id_comprobante = c.id
LEFT JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
LEFT JOIN gen_sucursal su ON su.id = c.id_sucursal
LEFT JOIN cli_clientes cl ON cl.id = c.id_cliente
WHERE c.estado = 1
ORDER BY c.fecha DESC, c.id DESC;
