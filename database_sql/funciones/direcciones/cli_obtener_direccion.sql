DROP FUNCTION IF EXISTS cli_obtener_por_id_direccion(INTEGER);
CREATE OR REPLACE FUNCTION cli_obtener_por_id_direccion(p_id INTEGER)
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
            d.id,
            d.id_cliente,
            COALESCE(c.razon_social, c.nombres) AS nombre_cliente,
            d.descripcion,
            d.direccion,
            d.id_pais,
            pa.nombre AS nombre_pais,
            d.id_departamento,
            dep.nombre AS nombre_departamento,
            d.id_provincia,
            prov.nombre AS nombre_provincia,
            d.id_distrito,
            dist.nombre AS nombre_distrito,
            d.referencia,
            d.es_principal,
            d.estado,
            d.fecha_creacion,
            d.fecha_modificacion,
            d.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            d.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM cli_direcciones d
        INNER JOIN cli_clientes c ON d.id_cliente = c.id
        LEFT JOIN gen_pais pa ON d.id_pais = pa.id
        LEFT JOIN gen_departamento dep ON d.id_departamento = dep.id
        LEFT JOIN gen_provincia prov ON d.id_provincia = prov.id
        LEFT JOIN gen_distrito dist ON d.id_distrito = dist.id
        LEFT JOIN auth_usuarios uc ON d.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON d.id_usuario_modificacion = um.id
        WHERE d.id = p_id AND d.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;