CREATE OR REPLACE FUNCTION cli_texto_busqueda(p_cliente cli_clientes)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE PARALLEL SAFE
AS $function$
  SELECT concat_ws(' ',
    p_cliente.razon_social,
    p_cliente.nombres,
    p_cliente.apellido_paterno,
    p_cliente.apellido_materno,
    p_cliente.numero_documento,
    p_cliente.codigo_interno
  );
$function$;
