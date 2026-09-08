-- Function: bal_obtener_lote_protocolo
-- Fase 5 — ficha ICP completa: cabecera + datos de análisis + envases aprobados.
DROP FUNCTION IF EXISTS bal_obtener_lote_protocolo(p_id integer);

CREATE OR REPLACE FUNCTION bal_obtener_lote_protocolo(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
    v_pruebas JSON;
    v_envases JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            lp.id,
            lp.numero_lote,
            lp.numero_protocolo,
            lp.id_proveedor,
            COALESCE(
                NULLIF(TRIM(pv.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', pv.nombres, pv.apellido_paterno, pv.apellido_materno)), ''),
                pv.numero_documento
            ) AS nombre_proveedor,
            lp.id_producto_gas,
            pg.nombre AS nombre_producto_gas,
            lp.descripcion_producto,
            lp.forma_farmaceutica,
            lp.presentacion,
            lp.norma_tecnica,
            lp.metodo_fabricacion,
            lp.fecha_analisis,
            lp.fecha_emision,
            lp.fecha_fabricacion,
            lp.fecha_vencimiento,
            (lp.fecha_vencimiento IS NOT NULL AND lp.fecha_vencimiento < CURRENT_DATE) AS vencido,
            lp.tamano_lote_m3,
            lp.cantidad_envases,
            lp.valoracion_o2_pct,
            lp.limite_co2_ppm,
            lp.limite_co_ppm,
            lp.cilindro_muestreado_serie,
            lp.temperatura_muestreo_c,
            lp.presion_muestreo_psi,
            lp.analista,
            lp.conclusion,
            lp.codigo_documento,
            lp.version_documento,
            lp.id_archivo_pdf,
            ar.ruta AS ruta_archivo_pdf,
            ar.nombre_original AS nombre_archivo_pdf,
            ar.bucket AS bucket_archivo_pdf,
            lp.observacion,
            (
                SELECT COUNT(*)::INT
                FROM bal_balon b
                WHERE b.id_lote_protocolo_vigente = lp.id AND b.estado = 1
            ) AS total_balones_vigentes,
            lp.fecha_creacion,
            lp.fecha_modificacion
        FROM bal_lote_protocolo lp
        LEFT JOIN cli_clientes pv ON pv.id = lp.id_proveedor
        LEFT JOIN pro_producto pg ON pg.id = lp.id_producto_gas
        LEFT JOIN gen_archivo ar ON ar.id = lp.id_archivo_pdf
        WHERE lp.id = p_id AND lp.estado = 1
    ) t;

    IF v_registro IS NULL THEN
        RETURN json_build_object('error', 'Ficha de lote y protocolo no encontrada', 'registro', NULL);
    END IF;

    SELECT COALESCE(json_agg(row_to_json(pr) ORDER BY pr.orden, pr.id), '[]'::JSON)
    INTO v_pruebas
    FROM (
        SELECT p.id, p.orden, p.prueba, p.especificacion, p.resultado
        FROM bal_lote_protocolo_prueba p
        WHERE p.id_lote_protocolo = p_id AND p.estado = 1
        ORDER BY p.orden, p.id
    ) pr;

    SELECT COALESCE(json_agg(row_to_json(en) ORDER BY en.serie_envase), '[]'::JSON)
    INTO v_envases
    FROM (
        SELECT
            e.id,
            e.serie_envase,
            e.id_balon,
            b.codigo_balon,
            tb.nombre AS nombre_tipo_balon,
            eb.nombre AS nombre_estado_balon,
            (b.id_lote_protocolo_vigente = p_id) AS es_lote_vigente
        FROM bal_lote_protocolo_envase e
        LEFT JOIN bal_balon b ON b.id = e.id_balon
        LEFT JOIN bal_tipo_balon tb ON tb.id = b.id_tipo_balon
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE e.id_lote_protocolo = p_id AND e.estado = 1
        ORDER BY e.serie_envase
    ) en;

    RETURN json_build_object(
        'error', NULL,
        'registro', (
            v_registro::JSONB
            || jsonb_build_object('pruebas', v_pruebas, 'envases', v_envases)
        )::JSON
    );
END;
$function$;
