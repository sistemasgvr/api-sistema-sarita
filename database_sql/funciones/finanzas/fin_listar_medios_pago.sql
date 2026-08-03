-- Opciones de la lista MedioPago (para el selector al registrar un pago).

DROP FUNCTION IF EXISTS fin_listar_medios_pago();

CREATE OR REPLACE FUNCTION fin_listar_medios_pago()
RETURNS JSON
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(
        json_agg(
            json_build_object('id', glo.id, 'nombre', glo.nombre)
            ORDER BY glo.id
        ),
        '[]'::json
    )
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    WHERE gl.nombre = 'MedioPago';
$$;
