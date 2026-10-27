-- Valida la combinación de medio de pago y cuenta bancaria; devuelve el error o NULL
DROP FUNCTION IF EXISTS public.fin_validar_cuenta_medio_pago (
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer
);

CREATE OR REPLACE FUNCTION public.fin_validar_cuenta_medio_pago (
  p_id_medio_pago integer,
  p_id_cuenta_bancaria integer DEFAULT NULL::integer
) RETURNS text LANGUAGE plpgsql STABLE AS $function$
DECLARE
    v_nombre_medio VARCHAR;
    v_requiere BOOLEAN;
    v_es_efectivo BOOLEAN;
    v_es_credito BOOLEAN;
    v_cuenta RECORD;
BEGIN
    IF p_id_medio_pago IS NULL THEN
        IF p_id_cuenta_bancaria IS NOT NULL THEN
            RETURN 'No se puede indicar una cuenta bancaria sin medio de pago.';
        END IF;
        RETURN NULL;
    END IF;

    SELECT nombre INTO v_nombre_medio FROM gen_lista_opciones WHERE id = p_id_medio_pago;
    IF v_nombre_medio IS NULL THEN
        RETURN format('El medio de pago indicado (id %s) no existe.', p_id_medio_pago);
    END IF;

    v_requiere    := fin_medio_pago_flag(p_id_medio_pago, 'REQUIERE_CUENTA_BANCARIA');
    v_es_efectivo := fin_medio_pago_flag(p_id_medio_pago, 'ES_EFECTIVO');
    v_es_credito  := fin_medio_pago_flag(p_id_medio_pago, 'ES_CREDITO');

    IF p_id_cuenta_bancaria IS NULL THEN
        IF v_requiere THEN
            RETURN format(
                'El medio de pago %s exige indicar la cuenta bancaria de la empresa del movimiento.',
                v_nombre_medio
            );
        END IF;
        RETURN NULL;
    END IF;

    IF v_es_efectivo OR v_es_credito THEN
        RETURN format('El medio de pago %s no admite cuenta bancaria.', v_nombre_medio);
    END IF;

    SELECT cb.id, cb.ambito, cb.estado, cb.titular
    INTO v_cuenta
    FROM gen_cuenta_bancaria cb
    WHERE cb.id = p_id_cuenta_bancaria;

    IF NOT FOUND THEN
        RETURN format('La cuenta bancaria indicada (id %s) no existe.', p_id_cuenta_bancaria);
    END IF;

    IF v_cuenta.estado <> 1 THEN
        RETURN format('La cuenta bancaria "%s" está inactiva.', COALESCE(v_cuenta.titular, '?'));
    END IF;

    IF v_cuenta.ambito <> 'EMPRESA' THEN
        RETURN format(
            'La cuenta "%s" es una cuenta de cliente. El dinero cobrado debe ir a una cuenta de la empresa.',
            COALESCE(v_cuenta.titular, '?')
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_cuenta_medio_pago cm
        WHERE cm.id_cuenta_bancaria = p_id_cuenta_bancaria
          AND cm.id_medio_pago = p_id_medio_pago
          AND cm.estado = 1
    ) THEN
        RETURN format(
            'La cuenta "%s" no tiene asociado el medio de pago %s. Asócialo en Configuración → Cuentas bancarias o elige otra cuenta.',
            COALESCE(v_cuenta.titular, '?'), v_nombre_medio
        );
    END IF;

    RETURN NULL;
END;
$function$;
