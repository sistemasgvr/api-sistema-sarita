CREATE OR REPLACE FUNCTION cli_obtener_por_id_cliente(
    p_id INT
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.id_tipo_cliente,
            tc.nombre AS nombre_tipo_cliente,
            c.id_tipo_persona,
            tp.nombre AS nombre_tipo_persona,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            c.numero_documento,
            c.direccion,
            c.referencia,
            c.telefono,
            c.email,
            c.id_departamento,
            dep.nombre AS nombre_departamento,
            c.id_provincia,
            prov.nombre AS nombre_provincia,
            c.id_distrito,
            dist.nombre AS nombre_distrito,
            c.id_pais,
            c.es_agente_percepcion,
            c.es_buen_contribuyente,
            c.es_agente_retenedor,
            c.afecto_rus,
            c.situacion_sunat,
            c.estado_contribuyente_sunat,
            c.observacion,
            c.estado,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            c.fecha_creacion,
            c.fecha_modificacion
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_cliente = tc.id
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        LEFT JOIN gen_lista_opciones td ON c.id_tipo_documento = td.id
        LEFT JOIN gen_departamento dep ON c.id_departamento = dep.id
        LEFT JOIN gen_provincia prov ON c.id_provincia = prov.id
        LEFT JOIN gen_distrito dist ON c.id_distrito = dist.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id
        WHERE c.id = p_id
    ) t;

    RETURN json_build_object(
        'registro', v_registro,
        'error', NULL
    );
END;
$$;
