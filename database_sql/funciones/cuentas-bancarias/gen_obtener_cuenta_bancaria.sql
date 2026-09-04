-- Function: gen_obtener_cuenta_bancaria
-- Fase 3: incorpora ámbito, alias, empresa y los medios de pago asociados.

DROP FUNCTION IF EXISTS gen_obtener_cuenta_bancaria(p_id integer);

CREATE OR REPLACE FUNCTION gen_obtener_cuenta_bancaria(p_id integer)
 RETURNS json
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
            cb.ambito,
            cb.alias,
            cb.id_empresa,
            e.razon_social AS empresa_razon_social,
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
            COALESCE((
                SELECT json_agg(
                    json_build_object(
                        'idMedioPago', cm.id_medio_pago,
                        'medioPago', mp.nombre,
                        'esPredeterminada', cm.es_predeterminada
                    ) ORDER BY mpc.orden, cm.id_medio_pago
                )
                FROM gen_cuenta_medio_pago cm
                JOIN gen_lista_opciones mp ON mp.id = cm.id_medio_pago
                LEFT JOIN fin_medio_pago_config mpc ON mpc.id_medio_pago = cm.id_medio_pago
                WHERE cm.id_cuenta_bancaria = cb.id AND cm.estado = 1
            ), '[]'::json) AS medios_pago,
            cb.fecha_creacion,
            cb.fecha_modificacion,
            cb.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            cb.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_cuenta_bancaria cb
        LEFT JOIN cli_clientes c ON cb.id_cliente = c.id
        LEFT JOIN gen_empresa e ON e.id = cb.id_empresa
        LEFT JOIN gen_lista_opciones b ON cb.id_banco = b.id
        LEFT JOIN gen_lista_opciones tc ON cb.id_tipo_cuenta = tc.id
        LEFT JOIN auth_usuarios uc ON cb.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cb.id_usuario_modificacion = um.id
        WHERE cb.id = p_id AND cb.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
