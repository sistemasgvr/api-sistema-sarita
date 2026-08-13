DROP FUNCTION IF EXISTS age_listar_actividades_proximas(INTEGER);

CREATE OR REPLACE FUNCTION age_listar_actividades_proximas(
    p_minutos_adelante INTEGER DEFAULT 60
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_ahora TIME;
    v_hasta TIME;
    p_minutos INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    p_minutos := GREATEST(COALESCE(p_minutos_adelante, 60), 5);
    v_ahora := LOCALTIME;
    v_hasta := v_ahora + make_interval(mins => p_minutos);

    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.hora_inicio_estimada), '[]'::JSON)
    INTO v_registros
    FROM (
        SELECT
            act.id,
            act.titulo,
            act.descripcion,
            act.fecha_programada,
            act.hora_inicio_estimada,
            act.hora_fin_estimada,
            act.id_tipo_actividad,
            ta.nombre AS nombre_tipo_actividad,
            act.id_prioridad,
            pr.nombre AS nombre_prioridad,
            act.id_cliente,
            c.razon_social AS razon_social_cliente,
            dir.latitud AS latitud_cliente,
            dir.longitud AS longitud_cliente,
            act.id_usuario_responsable,
            u.nombre AS nombre_usuario_responsable,
            act.id_chofer_responsable,
            TRIM(CONCAT_WS(' ', ch.nombres, ch.apellido_paterno, ch.apellido_materno)) AS nombre_chofer_responsable,
            act.id_estado_actividad,
            ea.nombre AS nombre_estado_actividad,
            act.id_comprobante,
            vc.serie AS serie_comprobante,
            vc.numero AS numero_comprobante,
            CASE
                WHEN act.hora_inicio_estimada IS NOT NULL
                     AND act.hora_fin_estimada IS NOT NULL
                     AND v_ahora >= act.hora_inicio_estimada
                     AND v_ahora < act.hora_fin_estimada
                THEN TRUE
                ELSE FALSE
            END AS en_curso
        FROM age_actividad act
        LEFT JOIN gen_lista_opciones ta ON act.id_tipo_actividad = ta.id
        LEFT JOIN gen_lista_opciones pr ON act.id_prioridad = pr.id
        LEFT JOIN gen_lista_opciones ea ON act.id_estado_actividad = ea.id
        LEFT JOIN cli_clientes c ON act.id_cliente = c.id
        LEFT JOIN LATERAL (
            SELECT cd.latitud, cd.longitud
            FROM cli_direcciones cd
            WHERE cd.id_cliente = act.id_cliente
              AND cd.estado = 1
            ORDER BY cd.es_principal DESC NULLS LAST, cd.id DESC
            LIMIT 1
        ) dir ON TRUE
        LEFT JOIN auth_usuarios u ON act.id_usuario_responsable = u.id
        LEFT JOIN gen_chofer ch ON act.id_chofer_responsable = ch.id
        LEFT JOIN ven_comprobante vc ON act.id_comprobante = vc.id
        WHERE act.estado = 1
          AND act.fecha_programada = CURRENT_DATE
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('REALIZADA', 'CANCELADA')
          AND act.hora_inicio_estimada IS NOT NULL
          AND (
              (act.hora_fin_estimada IS NOT NULL
               AND v_ahora >= act.hora_inicio_estimada
               AND v_ahora < act.hora_fin_estimada)
              OR (act.hora_inicio_estimada >= v_ahora AND act.hora_inicio_estimada < v_hasta)
          )
    ) t;

    RETURN json_build_object('registros', v_registros);
END;
$function$;
