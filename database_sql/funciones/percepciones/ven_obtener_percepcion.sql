-- Function: ven_obtener_percepcion
-- Obtener una percepción con su detalle

CREATE OR REPLACE FUNCTION ven_obtener_percepcion(p_id integer)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_percepcion JSONB;
    v_detalles JSONB;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Además de la fila: nombre del estado SUNAT y del cliente (cli_clientes),
    -- que la pantalla y el payload necesitan sin consultas adicionales.
    SELECT to_jsonb(p.*) || jsonb_build_object(
        'nombre_estado_sunat', es.nombre,
        'nombre_cliente', COALESCE(NULLIF(TRIM(c.razon_social), ''),
                            NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')),
        'documento_cliente', c.numero_documento,
        'tipo_documento_cliente', td.nombre
    ) INTO v_percepcion
    FROM ven_percepcion p
    LEFT JOIN gen_lista_opciones es ON es.id = p.id_estado_sunat
    LEFT JOIN cli_clientes c ON c.id = p.id_cliente
    LEFT JOIN gen_lista_opciones td ON td.id = c.id_tipo_documento
    WHERE p.id = p_id AND p.estado = 1;

    IF v_percepcion IS NULL THEN
        RETURN json_build_object('registro', NULL, 'error', 'Percepción no encontrada');
    END IF;

    SELECT COALESCE(jsonb_agg(to_jsonb(d.*)), '[]'::jsonb) INTO v_detalles
    FROM ven_percepcion_detalle d
    WHERE d.id_percepcion = p_id AND d.estado = 1;

    v_percepcion := v_percepcion || jsonb_build_object('detalles', v_detalles);

    RETURN json_build_object('registro', v_percepcion);
END;
$function$;
