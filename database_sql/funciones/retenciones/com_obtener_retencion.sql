-- Function: com_obtener_retencion
-- Obtener una retención con su detalle

CREATE OR REPLACE FUNCTION com_obtener_retencion(p_id integer)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_retencion JSONB;
    v_detalles JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Además de la fila: nombre del estado SUNAT y del proveedor (cli_clientes),
    -- que la pantalla y el payload necesitan sin consultas adicionales.
    SELECT to_jsonb(r.*) || jsonb_build_object(
        'nombre_estado_sunat', es.nombre,
        'nombre_proveedor', COALESCE(NULLIF(TRIM(c.razon_social), ''),
                              NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')),
        'documento_proveedor', c.numero_documento,
        'tipo_documento_proveedor', td.nombre
    ) INTO v_retencion
    FROM com_retencion r
    LEFT JOIN gen_lista_opciones es ON es.id = r.id_estado_sunat
    LEFT JOIN cli_clientes c ON c.id = r.id_proveedor
    LEFT JOIN gen_lista_opciones td ON td.id = c.id_tipo_documento
    WHERE r.id = p_id AND r.estado = 1;

    IF v_retencion IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Retención no encontrada');
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(d.*)), '[]'::jsonb) INTO v_detalles
    FROM com_retencion_detalle d
    WHERE d.id_retencion = p_id AND d.estado = 1;

    v_retencion := v_retencion || jsonb_build_object('detalles', v_detalles);

    RETURN json_build_object('registro', v_retencion);
END;
$function$;
