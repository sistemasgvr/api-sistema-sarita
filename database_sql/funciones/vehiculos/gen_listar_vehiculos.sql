DROP FUNCTION IF EXISTS gen_listar_vehiculos(VARCHAR, INTEGER, INTEGER, INTEGER, BOOLEAN);

CREATE OR REPLACE FUNCTION gen_listar_vehiculos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_cliente INTEGER DEFAULT NULL,
    p_solo_flota_propia BOOLEAN DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM gen_vehiculo v
    WHERE v.estado = 1
      AND (p_id_cliente IS NULL OR v.id_cliente = p_id_cliente)
      AND (
          p_solo_flota_propia IS NULL
          OR (p_solo_flota_propia IS TRUE AND v.id_cliente IS NULL)
          OR (p_solo_flota_propia IS FALSE AND v.id_cliente IS NOT NULL)
      )
      AND (
          p_busqueda = ''
          OR LOWER(v.placa) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(v.placa2, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(v.marca, '')) LIKE LOWER('%' || p_busqueda || '%')
          OR LOWER(COALESCE(v.modelo, '')) LIKE LOWER('%' || p_busqueda || '%')
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            v.id,
            v.id_cliente,
            COALESCE(c.razon_social, c.nombres) AS nombre_cliente,
            v.id_tipo_vehiculo,
            tv.nombre AS nombre_tipo_vehiculo,
            v.placa,
            v.placa2,
            v.marca,
            v.marca2,
            v.modelo,
            v.anio,
            v.color,
            v.certificado_inscripcion,
            v.certificado2,
            v.estado,
            v.fecha_creacion,
            v.fecha_modificacion,
            v.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            v.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM gen_vehiculo v
        LEFT JOIN cli_clientes c ON v.id_cliente = c.id
        LEFT JOIN gen_lista_opciones tv ON v.id_tipo_vehiculo = tv.id
        LEFT JOIN auth_usuarios uc ON v.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON v.id_usuario_modificacion = um.id
        WHERE v.estado = 1
          AND (p_id_cliente IS NULL OR v.id_cliente = p_id_cliente)
          AND (
              p_solo_flota_propia IS NULL
              OR (p_solo_flota_propia IS TRUE AND v.id_cliente IS NULL)
              OR (p_solo_flota_propia IS FALSE AND v.id_cliente IS NOT NULL)
          )
          AND (
              p_busqueda = ''
              OR LOWER(v.placa) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(v.placa2, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(v.marca, '')) LIKE LOWER('%' || p_busqueda || '%')
              OR LOWER(COALESCE(v.modelo, '')) LIKE LOWER('%' || p_busqueda || '%')
          )
        ORDER BY v.placa ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;