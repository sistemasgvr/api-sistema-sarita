CREATE OR REPLACE FUNCTION bal_obtener_ph_historial(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            h.id,
            h.id_balon,
            b.codigo_balon,
            h.fecha_prueba,
            h.vigencia_anios,
            h.fecha_proxima,
            h.id_organo_inspector,
            oi.nombre AS nombre_organo_inspector,
            h.organo_inspector_no_aplica,
            h.numero_certificado,
            h.id_mantenimiento,
            h.id_movimiento_recarga,
            h.es_vigente,
            h.observacion,
            h.estado,
            h.fecha_creacion,
            h.fecha_modificacion
        FROM bal_balon_ph_historial h
        INNER JOIN bal_balon b ON h.id_balon = b.id
        LEFT JOIN gen_lista_opciones oi ON h.id_organo_inspector = oi.id
        WHERE h.id = p_id AND h.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
