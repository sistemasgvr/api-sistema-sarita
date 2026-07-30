-- AI4: periodos quincenales / renovaciones del regulador
INSERT INTO gen_lista (nombre, descripcion)
SELECT 'EstadoAlquilerPeriodo', 'PENDIENTE, COBRADO, ANULADO'
WHERE NOT EXISTS (SELECT 1 FROM gen_lista WHERE nombre = 'EstadoAlquilerPeriodo');

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('PENDIENTE', 'Periodo generado sin cobro'),
        ('COBRADO', 'Periodo cobrado con comprobante'),
        ('ANULADO', 'Periodo anulado')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'EstadoAlquilerPeriodo'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
  );

CREATE TABLE IF NOT EXISTS bal_alquiler_periodo (
    id                      SERIAL PRIMARY KEY,
    id_alquiler             INT NOT NULL REFERENCES bal_alquiler(id),
    numero_periodo          INT NOT NULL,
    fecha_inicio            DATE NOT NULL,
    fecha_fin               DATE NOT NULL,
    monto                   NUMERIC(12,4) NOT NULL DEFAULT 0,
    id_producto             INT REFERENCES pro_producto(id),
    id_comprobante          INT REFERENCES ven_comprobante(id),
    id_estado               INT REFERENCES gen_lista_opciones(id),
    observacion             VARCHAR(500),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_alquiler, numero_periodo)
);

CREATE INDEX IF NOT EXISTS idx_bal_alquiler_periodo_alq
  ON bal_alquiler_periodo (id_alquiler)
  WHERE estado = 1;

CREATE INDEX IF NOT EXISTS idx_bal_alquiler_periodo_fin
  ON bal_alquiler_periodo (fecha_fin)
  WHERE estado = 1;

ALTER TABLE bal_alquiler
  ADD COLUMN IF NOT EXISTS dias_periodo INT NOT NULL DEFAULT 14;

COMMENT ON COLUMN bal_alquiler.dias_periodo IS 'Días del periodo de renovación del regulador (default 14 = quincenal).';
COMMENT ON TABLE bal_alquiler_periodo IS 'Historial de periodos/cobros del alquiler medicinal (kit = 1, renovaciones = 2+).';
CREATE OR REPLACE FUNCTION bal_listar_alquiler_periodos(
    p_id_alquiler INTEGER,
    p_limite INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_alquiler IS NULL THEN
        RETURN json_build_object('error', 'id_alquiler es obligatorio', 'registros', '[]'::JSON, 'total', 0);
    END IF;

    SELECT COUNT(*) INTO v_total
    FROM bal_alquiler_periodo p
    WHERE p.id_alquiler = p_id_alquiler AND p.estado = 1;

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            p.id,
            p.id_alquiler,
            p.numero_periodo,
            p.fecha_inicio,
            p.fecha_fin,
            p.monto,
            p.id_producto,
            pr.codigo AS codigo_producto,
            pr.nombre AS nombre_producto,
            p.id_comprobante,
            CASE
                WHEN cv.id IS NULL THEN NULL
                ELSE CONCAT_WS('-', cv.serie, cv.numero)
            END AS comprobante,
            p.id_estado,
            ea.nombre AS nombre_estado,
            p.observacion,
            p.fecha_creacion
        FROM bal_alquiler_periodo p
        LEFT JOIN pro_producto pr ON p.id_producto = pr.id
        LEFT JOIN ven_comprobante cv ON p.id_comprobante = cv.id
        LEFT JOIN gen_lista_opciones ea ON p.id_estado = ea.id
        WHERE p.id_alquiler = p_id_alquiler AND p.estado = 1
        ORDER BY p.numero_periodo DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object('registros', v_registros, 'total', v_total);
END;
$function$;
CREATE OR REPLACE FUNCTION bal_registrar_alquiler_periodo(
    p_id_alquiler INTEGER,
    p_fecha_inicio DATE,
    p_fecha_fin DATE,
    p_monto NUMERIC DEFAULT 0,
    p_id_producto INTEGER DEFAULT NULL,
    p_id_comprobante INTEGER DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero INTEGER;
    v_id INTEGER;
    v_id_estado INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_alquiler WHERE id = p_id_alquiler AND estado = 1) THEN
        RETURN json_build_object('error', 'Alquiler no encontrado', 'registro', NULL);
    END IF;

    IF p_fecha_inicio IS NULL OR p_fecha_fin IS NULL THEN
        RETURN json_build_object('error', 'Fechas de periodo obligatorias', 'registro', NULL);
    END IF;

    IF p_fecha_fin < p_fecha_inicio THEN
        RETURN json_build_object('error', 'fecha_fin debe ser >= fecha_inicio', 'registro', NULL);
    END IF;

    SELECT COALESCE(MAX(numero_periodo), 0) + 1 INTO v_numero
    FROM bal_alquiler_periodo
    WHERE id_alquiler = p_id_alquiler AND estado = 1;

    SELECT lo.id INTO v_id_estado
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoAlquilerPeriodo'
      AND lo.nombre = CASE WHEN p_id_comprobante IS NULL THEN 'PENDIENTE' ELSE 'COBRADO' END
      AND lo.estado = 1
    LIMIT 1;

    INSERT INTO bal_alquiler_periodo (
        id_alquiler, numero_periodo, fecha_inicio, fecha_fin, monto,
        id_producto, id_comprobante, id_estado, observacion,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_alquiler, v_numero, p_fecha_inicio, p_fecha_fin, COALESCE(p_monto, 0),
        p_id_producto, p_id_comprobante, v_id_estado, p_observacion,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    UPDATE bal_alquiler
    SET
        fecha_fin_pactada = GREATEST(COALESCE(fecha_fin_pactada, p_fecha_fin), p_fecha_fin),
        fecha_modificacion = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id_alquiler;

    RETURN json_build_object(
        'registro', (
            SELECT row_to_json(t)
            FROM (
                SELECT p.*, pr.codigo AS codigo_producto, pr.nombre AS nombre_producto
                FROM bal_alquiler_periodo p
                LEFT JOIN pro_producto pr ON p.id_producto = pr.id
                WHERE p.id = v_id
            ) t
        )
    );
END;
$function$;
CREATE OR REPLACE FUNCTION bal_renovar_alquiler(
    p_id_alquiler INTEGER,
    p_id_comprobante INTEGER,
    p_monto NUMERIC DEFAULT NULL,
    p_fecha_inicio DATE DEFAULT NULL,
    p_fecha_fin DATE DEFAULT NULL,
    p_observacion VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_alq RECORD;
    v_ultimo RECORD;
    v_inicio DATE;
    v_fin DATE;
    v_monto NUMERIC;
    v_dias INTEGER;
    v_periodo JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_alq
    FROM bal_alquiler
    WHERE id = p_id_alquiler AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'Alquiler no encontrado', 'registro', NULL);
    END IF;

    IF v_alq.id_producto_regulador IS NULL THEN
        RETURN json_build_object(
            'error', 'El alquiler no tiene regulador vinculado; no se puede renovar',
            'registro', NULL
        );
    END IF;

    IF p_id_comprobante IS NULL OR NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Comprobante de renovación inválido', 'registro', NULL);
    END IF;

    SELECT * INTO v_ultimo
    FROM bal_alquiler_periodo
    WHERE id_alquiler = p_id_alquiler AND estado = 1
    ORDER BY numero_periodo DESC
    LIMIT 1;

    v_dias := COALESCE(NULLIF(v_alq.dias_periodo, 0), 14);
    v_inicio := COALESCE(p_fecha_inicio, CASE
        WHEN v_ultimo.id IS NOT NULL THEN (v_ultimo.fecha_fin + 1)
        ELSE COALESCE(v_alq.fecha_fin_pactada, CURRENT_DATE) + 1
    END);
    v_fin := COALESCE(p_fecha_fin, v_inicio + (v_dias - 1));
    v_monto := COALESCE(p_monto, v_alq.tarifa_diaria, 0);

    v_periodo := bal_registrar_alquiler_periodo(
        p_id_alquiler,
        v_inicio,
        v_fin,
        v_monto,
        v_alq.id_producto_regulador,
        p_id_comprobante,
        COALESCE(p_observacion, 'Renovación regulador'),
        p_id_usuario_auditoria
    );

    IF (v_periodo->>'error') IS NOT NULL THEN
        RETURN v_periodo;
    END IF;

    UPDATE bal_alquiler
    SET
        total_cobrado = COALESCE(total_cobrado, 0) + v_monto,
        fecha_fin_pactada = v_fin,
        fecha_modificacion = NOW(),
        id_usuario_modificacion = p_id_usuario_auditoria
    WHERE id = p_id_alquiler;

    RETURN bal_obtener_alquiler(p_id_alquiler);
END;
$function$;
