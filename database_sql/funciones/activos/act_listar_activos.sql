DROP FUNCTION IF EXISTS act_listar_activos(
    INTEGER,
    INTEGER,
    INTEGER,
    DATE,
    DATE,
    NUMERIC,
    NUMERIC,
    VARCHAR,
    INTEGER,
    INTEGER
);

CREATE OR REPLACE FUNCTION act_listar_activos(
    p_estado        INTEGER DEFAULT NULL,   -- 1 activos, 0 inactivos, NULL = todos
    p_id_tipo       INTEGER DEFAULT NULL,
    p_id_sucursal   INTEGER DEFAULT NULL,
    p_fecha_desde   DATE    DEFAULT NULL,
    p_fecha_hasta   DATE    DEFAULT NULL,
    p_importe_min   NUMERIC DEFAULT NULL,
    p_importe_max   NUMERIC DEFAULT NULL,
    p_buscar        VARCHAR DEFAULT '',
    p_limite        INTEGER DEFAULT 10,
    p_offset        INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total     BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_total
    FROM act_activos a
    WHERE (p_estado IS NULL OR a.estado = p_estado)
      AND (p_id_tipo IS NULL OR a.id_tipo = p_id_tipo)
      AND (p_id_sucursal IS NULL OR a.id_sucursal = p_id_sucursal)
      AND (p_fecha_desde IS NULL OR a.fecha_compra >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR a.fecha_compra <= p_fecha_hasta)
      AND (p_importe_min IS NULL OR a.importe >= p_importe_min)
      AND (p_importe_max IS NULL OR a.importe <= p_importe_max)
      AND (
          p_buscar = ''
          OR gen_texto_coincide(a.descripcion, p_buscar)
          OR gen_texto_coincide(COALESCE(a.marca, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(a.modelo, ''), p_buscar)
          OR gen_texto_coincide(COALESCE(a.numero_serie, ''), p_buscar)
      );

    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            a.id,
            a.id_tipo,
            tp.nombre   AS nombre_tipo,
            a.descripcion,
            a.fecha_compra,
            a.importe,
            a.id_sucursal,
            s.nombre    AS nombre_sucursal,
            a.marca,
            a.modelo,
            a.numero_serie,
            a.id_trabajador_responsable,
            CONCAT_WS(' ', tr.nombres, tr.apellido_paterno, tr.apellido_materno) AS nombre_trabajador_responsable,
            a.imagen_principal_ruta,
            a.estado,
            a.fecha_creacion,
            a.fecha_modificacion
        FROM act_activos a
        LEFT JOIN gen_lista_opciones tp ON a.id_tipo = tp.id
        LEFT JOIN gen_sucursal s        ON a.id_sucursal = s.id
        LEFT JOIN tra_trabajadores tr   ON a.id_trabajador_responsable = tr.id
        WHERE (p_estado IS NULL OR a.estado = p_estado)
          AND (p_id_tipo IS NULL OR a.id_tipo = p_id_tipo)
          AND (p_id_sucursal IS NULL OR a.id_sucursal = p_id_sucursal)
          AND (p_fecha_desde IS NULL OR a.fecha_compra >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR a.fecha_compra <= p_fecha_hasta)
          AND (p_importe_min IS NULL OR a.importe >= p_importe_min)
          AND (p_importe_max IS NULL OR a.importe <= p_importe_max)
          AND (
              p_buscar = ''
              OR gen_texto_coincide(a.descripcion, p_buscar)
              OR gen_texto_coincide(COALESCE(a.marca, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(a.modelo, ''), p_buscar)
              OR gen_texto_coincide(COALESCE(a.numero_serie, ''), p_buscar)
          )
        ORDER BY a.descripcion ASC
        LIMIT p_limite
        OFFSET p_offset
    ) r;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
