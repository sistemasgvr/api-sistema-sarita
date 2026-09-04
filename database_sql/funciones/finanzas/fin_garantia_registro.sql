-- Function: fin_garantia_registro
-- Proyección única de una garantía de finanzas.
--
-- El mismo bloque row_to_json estaba copiado en fin_crear_garantia,
-- fin_actualizar_garantia, fin_reembolsar_garantia y fin_anular_reembolso_garantia.
-- Al añadir la cuenta bancaria en Fase 3 habría que haberlo tocado en cuatro
-- sitios, así que se extrae aquí.

DROP FUNCTION IF EXISTS fin_garantia_registro(p_id integer);

CREATE OR REPLACE FUNCTION fin_garantia_registro(p_id integer)
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
    SELECT row_to_json(t) FROM (
        SELECT
            g.id, g.fecha,
            g.id_cliente,
            COALESCE(NULLIF(TRIM(c.razon_social), ''),
                     NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                     'Cliente #' || g.id_cliente) AS cliente,
            c.numero_documento AS documento_cliente,
            g.id_medio_pago, mp.nombre AS medio_pago,
            g.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            g.importe, g.observacion,
            g.fecha_reembolso,
            g.id_medio_reembolso, mr.nombre AS medio_reembolso,
            g.id_cuenta_bancaria_reembolso,
            COALESCE(cbr.alias, cbr.titular, cbr.numero_cuenta) AS cuenta_bancaria_reembolso,
            g.observacion_reembolso,
            g.id_estado, est.nombre AS estado_texto,
            g.fecha_creacion
        FROM fin_garantia g
        JOIN cli_clientes c ON c.id = g.id_cliente
        LEFT JOIN gen_lista_opciones mp  ON mp.id = g.id_medio_pago
        LEFT JOIN gen_lista_opciones mr  ON mr.id = g.id_medio_reembolso
        LEFT JOIN gen_lista_opciones est ON est.id = g.id_estado
        LEFT JOIN gen_cuenta_bancaria cb  ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN gen_cuenta_bancaria cbr ON cbr.id = g.id_cuenta_bancaria_reembolso
        WHERE g.id = p_id
    ) t;
$function$;
