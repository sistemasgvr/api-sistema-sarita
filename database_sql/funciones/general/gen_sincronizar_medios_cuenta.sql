-- Sincroniza los medios de pago asociados a una cuenta bancaria
DROP FUNCTION IF EXISTS public.gen_sincronizar_medios_cuenta (
  p_id_cuenta_bancaria integer,
  p_medios json,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.gen_sincronizar_medios_cuenta (
  p_id_cuenta_bancaria integer,
  p_medios json DEFAULT NULL::json,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS text LANGUAGE plpgsql AS $function$
DECLARE
    v_ambito VARCHAR;
    v_error TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_medios IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT ambito INTO v_ambito FROM gen_cuenta_bancaria WHERE id = p_id_cuenta_bancaria;

    IF v_ambito IS NULL THEN
        RETURN format('La cuenta bancaria (id %s) no existe.', p_id_cuenta_bancaria);
    END IF;

    IF json_array_length(p_medios) > 0 AND v_ambito <> 'EMPRESA' THEN
        RETURN 'Solo las cuentas bancarias de la empresa pueden tener medios de pago asociados.';
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS tmp_medios_cuenta (
        id_medio_pago INTEGER,
        es_predeterminada BOOLEAN
    ) ON COMMIT DROP;
    DELETE FROM tmp_medios_cuenta;

    INSERT INTO tmp_medios_cuenta (id_medio_pago, es_predeterminada)
    SELECT
        CASE
            WHEN json_typeof(e.valor) = 'number' THEN (e.valor #>> '{}')::INTEGER
            ELSE (e.valor ->> 'idMedioPago')::INTEGER
        END,
        CASE
            WHEN json_typeof(e.valor) = 'number' THEN FALSE
            ELSE COALESCE((e.valor ->> 'esPredeterminada')::BOOLEAN, FALSE)
        END
    FROM json_array_elements(p_medios) AS e(valor);

    SELECT string_agg(DISTINCT t.id_medio_pago::TEXT, ', ')
    INTO v_error
    FROM tmp_medios_cuenta t
    WHERE NOT EXISTS (
        SELECT 1
        FROM gen_lista_opciones o
        JOIN gen_lista l ON l.id = o.id_lista AND l.nombre = 'MedioPago'
        WHERE o.id = t.id_medio_pago AND o.estado = 1
    );

    IF v_error IS NOT NULL THEN
        RETURN format('Medios de pago inválidos: %s', v_error);
    END IF;

    SELECT string_agg(o.nombre, ', ')
    INTO v_error
    FROM tmp_medios_cuenta t
    JOIN gen_lista_opciones o ON o.id = t.id_medio_pago
    WHERE fin_medio_pago_flag(t.id_medio_pago, 'ES_EFECTIVO')
       OR fin_medio_pago_flag(t.id_medio_pago, 'ES_CREDITO');

    IF v_error IS NOT NULL THEN
        RETURN format(
            'Estos medios de pago no van a una cuenta bancaria: %s.', v_error
        );
    END IF;

    UPDATE gen_cuenta_medio_pago cm
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE cm.id_cuenta_bancaria = p_id_cuenta_bancaria
      AND cm.estado = 1
      AND NOT EXISTS (SELECT 1 FROM tmp_medios_cuenta t WHERE t.id_medio_pago = cm.id_medio_pago);

    UPDATE gen_cuenta_medio_pago cm
    SET estado = 1,
        es_predeterminada = t.es_predeterminada,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM tmp_medios_cuenta t
    WHERE cm.id_cuenta_bancaria = p_id_cuenta_bancaria
      AND cm.id_medio_pago = t.id_medio_pago;

    INSERT INTO gen_cuenta_medio_pago (
        id_cuenta_bancaria, id_medio_pago, es_predeterminada,
        id_usuario_creacion, id_usuario_modificacion
    )
    SELECT p_id_cuenta_bancaria, t.id_medio_pago, t.es_predeterminada,
           p_id_usuario_auditoria, p_id_usuario_auditoria
    FROM tmp_medios_cuenta t
    WHERE NOT EXISTS (
        SELECT 1 FROM gen_cuenta_medio_pago cm
        WHERE cm.id_cuenta_bancaria = p_id_cuenta_bancaria AND cm.id_medio_pago = t.id_medio_pago
    );

    UPDATE gen_cuenta_medio_pago cm
    SET es_predeterminada = FALSE,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE cm.estado = 1
      AND cm.es_predeterminada
      AND cm.id_cuenta_bancaria <> p_id_cuenta_bancaria
      AND cm.id_medio_pago IN (SELECT id_medio_pago FROM tmp_medios_cuenta WHERE es_predeterminada);

    DELETE FROM tmp_medios_cuenta;
    RETURN NULL;
END;
$function$;
