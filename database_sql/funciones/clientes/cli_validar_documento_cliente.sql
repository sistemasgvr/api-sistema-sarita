-- Indica si ya existe otro cliente con el número de documento dado
DROP FUNCTION IF EXISTS public.cli_validar_documento_cliente (
  p_numero_documento character varying,
  p_id_excluir integer
);

CREATE OR REPLACE FUNCTION public.cli_validar_documento_cliente (
  p_numero_documento character varying,
  p_id_excluir integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM cli_clientes
        WHERE numero_documento = p_numero_documento
          AND (p_id_excluir IS NULL OR id <> p_id_excluir)
    ) INTO v_existe;

    RETURN json_build_object('existe', v_existe);
END;
$function$;
