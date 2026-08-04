-- Resuelve el id de gen_lista_opciones para EstadoContenidoBalon (LLENO / VACIO / DESCONOCIDO).
CREATE OR REPLACE FUNCTION bal_id_estado_contenido(p_nombre VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT lo.id INTO v_id
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoContenidoBalon'
      AND lo.nombre = UPPER(TRIM(p_nombre))
      AND lo.estado = 1
    LIMIT 1;

    RETURN v_id;
END;
$function$;
