-- Function: gen_listar_cuentas_bancarias
-- Fase 3: filtro por ámbito (CLIENTE / EMPRESA) y por medio de pago asociado.
--
-- El filtro histórico `p_id_cliente = -1` ("cuentas sin cliente") se mantiene por
-- compatibilidad, pero lo correcto ahora es p_ambito = 'EMPRESA'.

DROP FUNCTION IF EXISTS gen_listar_cuentas_bancarias(p_solo_activos integer, p_buscar character varying, p_limite integer, p_offset integer, p_id_cliente integer);
DROP FUNCTION IF EXISTS gen_listar_cuentas_bancarias(p_solo_activos integer, p_buscar character varying, p_limite integer, p_offset integer, p_id_cliente integer, p_ambito character varying, p_id_medio_pago integer);

CREATE OR REPLACE FUNCTION gen_listar_cuentas_bancarias(
    p_solo_activos integer DEFAULT NULL::integer,
    p_buscar character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 10,
    p_offset integer DEFAULT 0,
    p_id_cliente integer DEFAULT NULL::integer,
    p_ambito character varying DEFAULT NULL::character varying,
    p_id_medio_pago integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_ambito VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_ambito := UPPER(NULLIF(TRIM(p_ambito), ''));

    CREATE TEMP TABLE IF NOT EXISTS tmp_cuentas_filtradas (id INTEGER) ON COMMIT DROP;
    DELETE FROM tmp_cuentas_filtradas;

    INSERT INTO tmp_cuentas_filtradas (id)
    SELECT cb.id
    FROM gen_cuenta_bancaria cb
    WHERE (p_solo_activos IS NULL OR cb.estado = p_solo_activos)
      AND (v_ambito IS NULL OR cb.ambito = v_ambito)
      AND (
          p_id_cliente IS NULL
          OR cb.id_cliente = p_id_cliente
          OR (p_id_cliente = -1 AND cb.id_cliente IS NULL)
      )
      AND (
          p_id_medio_pago IS NULL
          OR EXISTS (
              SELECT 1 FROM gen_cuenta_medio_pago cm
              WHERE cm.id_cuenta_bancaria = cb.id
                AND cm.id_medio_pago = p_id_medio_pago
                AND cm.estado = 1
          )
      )
      AND (
          p_buscar = ''
          OR gen_texto_coincide(COALESCE(cb.titular, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(cb.alias, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(cb.numero_cuenta, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(cb.numero_cuenta_interbancaria, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(cb.telefono_billetera, ''), p_buscar)
      );

    SELECT COUNT(*) INTO v_total FROM tmp_cuentas_filtradas;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            cb.id,
            cb.ambito,
            cb.alias,
            cb.id_empresa,
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
        JOIN tmp_cuentas_filtradas f ON f.id = cb.id
        LEFT JOIN cli_clientes c ON cb.id_cliente = c.id
        LEFT JOIN gen_lista_opciones b ON cb.id_banco = b.id
        LEFT JOIN gen_lista_opciones tc ON cb.id_tipo_cuenta = tc.id
        LEFT JOIN auth_usuarios uc ON cb.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON cb.id_usuario_modificacion = um.id
        ORDER BY cb.es_principal DESC, cb.id ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    DELETE FROM tmp_cuentas_filtradas;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
