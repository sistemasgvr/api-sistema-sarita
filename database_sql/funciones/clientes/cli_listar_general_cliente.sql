DROP FUNCTION IF EXISTS cli_listar_clientes(INT, INT, VARCHAR, INT, INT);

CREATE OR REPLACE FUNCTION cli_listar_clientes(
    p_solo_activos    INT     DEFAULT NULL,
    p_id_tipo_cliente INT     DEFAULT NULL,
    p_buscar          VARCHAR DEFAULT NULL,
    p_limite          INT     DEFAULT 10,
    p_offset          INT     DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_resultado JSON;
    v_buscar    VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_buscar := NULLIF(TRIM(p_buscar), '');

    WITH filtrados AS (
        SELECT
            c.id,
            c.codigo_interno,
            c.razon_social,
            c.id_tipo_cliente,
            tc.nombre AS nombre_tipo_cliente,
            c.id_tipo_persona,
            tp.nombre AS nombre_tipo_persona,
            c.nombres,
            c.apellido_paterno,
            c.apellido_materno,
            c.id_tipo_documento,
            td.nombre AS nombre_tipo_documento,
            c.numero_documento,
            -- Dirección principal 
            dir.id            AS id_direccion,
            dir.direccion,
            dir.referencia,
            dir.latitud,
            dir.longitud,
            dir.id_departamento,
            dep.nombre         AS nombre_departamento,
            dir.id_provincia,
            prov.nombre        AS nombre_provincia,
            dir.id_distrito,
            dist.nombre        AS nombre_distrito,
            dir.id_pais,
            pa.nombre          AS nombre_pais,
            c.telefono,
            c.email,
            c.es_agente_percepcion,
            c.es_buen_contribuyente,
            c.es_agente_retenedor,
            c.afecto_rus,
            c.situacion_sunat,
            c.estado_contribuyente_sunat,
            c.observacion,
            c.estado,
            c.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            c.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion,
            c.fecha_creacion,
            c.fecha_modificacion,
            -- Datos de baja (si tiene solicitud pendiente/activa)
            bc.id AS id_baja_pendiente,
            ea.nombre AS estado_baja_aprobacion,
            bc.motivo_detalle AS motivo_baja_detalle,
            mb.nombre AS motivo_baja_opciones
        FROM cli_clientes c
        LEFT JOIN gen_lista_opciones tc ON c.id_tipo_cliente = tc.id
        LEFT JOIN gen_lista_opciones tp ON c.id_tipo_persona = tp.id
        LEFT JOIN gen_lista_opciones td ON c.id_tipo_documento = td.id
        LEFT JOIN auth_usuarios uc ON c.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um ON c.id_usuario_modificacion = um.id

        -- FIX: se reemplaza el LEFT JOIN directo por LATERAL + LIMIT 1
        -- para evitar duplicar la fila del cliente cuando existe más
        -- de un registro de baja con estado = 1 para el mismo cliente.
        LEFT JOIN LATERAL (
            SELECT b.*
            FROM cli_baja_cliente b
            WHERE b.id_cliente = c.id
              AND b.estado = 1
            ORDER BY b.id DESC
            LIMIT 1
        ) bc ON TRUE
        LEFT JOIN gen_lista_opciones ea ON bc.id_estado_aprobacion = ea.id
                                       AND ea.nombre = 'PENDIENTE'
        LEFT JOIN gen_lista_opciones mb ON bc.id_motivo_baja = mb.id

        LEFT JOIN LATERAL (
            SELECT cd.*
            FROM cli_direcciones cd
            WHERE cd.id_cliente = c.id
              AND cd.es_principal = TRUE
              AND cd.estado = 1
            ORDER BY cd.id DESC
            LIMIT 1
        ) dir ON TRUE

        LEFT JOIN gen_departamento dep  ON dir.id_departamento = dep.id
        LEFT JOIN gen_provincia    prov ON dir.id_provincia    = prov.id
        LEFT JOIN gen_distrito     dist ON dir.id_distrito     = dist.id
        LEFT JOIN gen_pais         pa   ON dir.id_pais          = pa.id

        WHERE (p_solo_activos IS NULL OR c.estado = p_solo_activos)
          AND (p_id_tipo_cliente IS NULL OR c.id_tipo_cliente = p_id_tipo_cliente)
          AND (
                v_buscar IS NULL
                OR c.razon_social ILIKE '%' || v_buscar || '%'
                OR c.nombres ILIKE '%' || v_buscar || '%'
                OR c.apellido_paterno ILIKE '%' || v_buscar || '%'
                OR c.apellido_materno ILIKE '%' || v_buscar || '%'
                OR c.numero_documento ILIKE '%' || v_buscar || '%'
                OR c.codigo_interno ILIKE '%' || v_buscar || '%'
                OR dir.direccion ILIKE '%' || v_buscar || '%'
              )
    ),
    total_count AS (
        SELECT COUNT(*) AS total FROM filtrados
    ),
    paginados AS (
        SELECT * FROM filtrados
        ORDER BY razon_social NULLS LAST, nombres NULLS LAST, id DESC
        LIMIT p_limite
        OFFSET p_offset
    )
    SELECT json_build_object(
        'total', COALESCE((SELECT total FROM total_count), 0),
        'registros', COALESCE((SELECT json_agg(row_to_json(p)) FROM paginados p), '[]'::json)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;