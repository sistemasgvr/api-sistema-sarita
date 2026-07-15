DROP FUNCTION IF EXISTS gen_obtener_cuenta_bancaria(INTEGER);

CREATE OR REPLACE FUNCTION gen_obtener_cuenta_bancaria(p_id INTEGER)
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
            cb.id,
            cb.id_cliente,
            c.razon_social AS cliente_razon_social,
            c.nombres AS cliente_nombres,
            c.apellido_paterno AS cliente_apellido_paterno,
            c.apellido_materno AS cliente_apellido_materno,
            c.numero_documento AS cliente_numero_documento,
            cb.id_banco,
            b.nombre AS nombre_banco,
            cb.id_tipo_cuenta,
            tc.nombre AS nombre_tipo_cuenta,
            cb.titular,
            cb.numero_cuenta,
            cb.numero_cuenta_interbancaria,
            cb.telefono_billetera,
            cb.es_principal,
            cb.estado,
            cb.fecha_creacion,
            cb.fecha_modificacion,
            cb.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cb.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_cuenta_bancaria cb
        LEFT JOIN cli_clientes c ON cb.id_cliente = c.id
        LEFT JOIN gen_lista_opciones b ON cb.id_banco = b.id
        LEFT JOIN gen_lista_opciones tc ON cb.id_tipo_cuenta = tc.id
        LEFT JOIN auth_usuarios uc ON cb.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cb.id_usuario_modificacion = um.id
        WHERE cb.id = p_id AND cb.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
