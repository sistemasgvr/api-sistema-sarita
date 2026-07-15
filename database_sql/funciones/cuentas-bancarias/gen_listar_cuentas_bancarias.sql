DROP FUNCTION IF EXISTS gen_listar_cuentas_bancarias(INTEGER, VARCHAR, INTEGER, INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION gen_listar_cuentas_bancarias(
    p_solo_activos INT DEFAULT NULL,
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_pagina INTEGER DEFAULT 1,
    p_id_cliente INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_offset INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';
    v_offset := (p_pagina - 1) * p_limite;

    SELECT COUNT(*) INTO v_total
    FROM gen_cuenta_bancaria cb
    WHERE (p_solo_activos IS NULL OR cb.estado = p_solo_activos)
      AND (p_id_cliente IS NULL OR cb.id_cliente = p_id_cliente OR (p_id_cliente = -1 AND cb.id_cliente IS NULL))
      AND (
          p_busqueda = ''
          OR LOWER(COALESCE(cb.titular, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cb.numero_cuenta, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cb.numero_cuenta_interbancaria, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(cb.telefono_billetera, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
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
        WHERE (p_solo_activos IS NULL OR cb.estado = p_solo_activos)
          AND (p_id_cliente IS NULL OR cb.id_cliente = p_id_cliente OR (p_id_cliente = -1 AND cb.id_cliente IS NULL))
          AND (
              p_busqueda = ''
              OR LOWER(COALESCE(cb.titular, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cb.numero_cuenta, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cb.numero_cuenta_interbancaria, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(cb.telefono_billetera, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY cb.es_principal DESC, cb.id ASC
        LIMIT p_limite
        OFFSET v_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
