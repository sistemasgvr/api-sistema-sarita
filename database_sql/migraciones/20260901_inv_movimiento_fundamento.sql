-- Fase 1 (hito 1) — Fundamento de inv_movimiento unificado + habilitar gas en pro_stock.
-- Aditivo: no toca pro_movimientos ni bal_movimiento. Ver docs/plan-reestructuracion-oxigeno-sarita.md
-- y el hito 1 registrado en el plan de implementación (roadmap hitos 2-5 pendientes).
--
-- NO reejecutar este archivo para reconstruir. El cuerpo incrusta una versión
-- antigua de inv_registrar_movimiento (usa columnas ya dropeadas). Para un
-- esquema desde 0: node database_sql/scripts/rebuild-schema-from-repo.js --full --wipe
-- (tablas/ + funciones/ actuales + seeds/). En DEV vivo usar --functions.

-- ============================================================
-- CATALOGO: TipoMovInvUnificado (union de TipoMovInv + TipoMovBalon)
-- ============================================================

INSERT INTO gen_lista (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('TipoMovInvUnificado', 'Tipos de movimiento de inv_movimiento (producto y balon unificados)')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre
);

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, v.nombre, v.descripcion
FROM (
    VALUES
        ('INGRESO', 'Ingreso de producto a almacen'),
        ('SALIDA', 'Salida de producto de almacen'),
        ('TRASLADO', 'Traslado de producto entre almacenes'),
        ('AJUSTE', 'Ajuste manual de stock'),
        ('SALIDA_VENTA', 'Salida de balon por venta'),
        ('SALIDA_PRESTAMO', 'Salida de balon por prestamo'),
        ('SALIDA_ALQUILER', 'Salida de balon por alquiler'),
        ('SALIDA_MANTENIMIENTO', 'Salida de balon a mantenimiento'),
        ('SALIDA_PLANTA_EXTERNA', 'Salida de balon a planta externa'),
        ('ENTRADA_DEVOLUCION', 'Entrada de balon por devolucion'),
        ('ENTRADA_MANTENIMIENTO', 'Entrada de balon desde mantenimiento'),
        ('SALIDA_ENTREGA_CLIENTE', 'Salida de balon por entrega a cliente'),
        ('ENTRADA_LLENADO', 'Entrada de balon lleno'),
        ('ENTRADA_PLANTA_EXTERNA', 'Entrada de balon desde planta externa'),
        ('RECARGA_CLIENTE', 'Recarga de balon en mostrador para cliente'),
        ('TRASLADO_LIMA', 'Traslado de balon en ruta a Lima'),
        ('RETORNO_LIMA', 'Retorno de balon desde Lima')
) AS v(nombre, descripcion)
CROSS JOIN gen_lista l
WHERE l.nombre = 'TipoMovInvUnificado'
  AND NOT EXISTS (
    SELECT 1 FROM gen_lista_opciones lo WHERE lo.id_lista = l.id AND lo.nombre = v.nombre
);

-- ============================================================
-- TABLA: inv_movimiento
-- ============================================================

CREATE TABLE IF NOT EXISTS inv_movimiento (
    id SERIAL PRIMARY KEY,
    fecha TIMESTAMP NOT NULL DEFAULT NOW(),
    id_tipo_movimiento INTEGER NOT NULL REFERENCES gen_lista_opciones(id),
    naturaleza VARCHAR(10) NOT NULL CHECK (naturaleza IN ('PRODUCTO', 'BALON')),
    id_producto INTEGER REFERENCES pro_producto(id),
    id_balon INTEGER REFERENCES bal_balon(id),
    cantidad NUMERIC(12,4) NOT NULL DEFAULT 0,
    id_unidad_medida INTEGER REFERENCES gen_lista_opciones(id),
    id_almacen_origen INTEGER REFERENCES gen_almacen(id),
    id_almacen_destino INTEGER REFERENCES gen_almacen(id),
    id_cliente INTEGER REFERENCES cli_clientes(id),
    id_documento_origen INTEGER,
    id_tipo_documento_origen INTEGER REFERENCES gen_lista_opciones(id),
    id_movimiento_padre INTEGER REFERENCES inv_movimiento(id),
    stock_anterior NUMERIC(12,4),
    stock_nuevo NUMERIC(12,4),
    id_estado_balon_snapshot INTEGER REFERENCES gen_lista_opciones(id),
    glosa VARCHAR(300),
    estado INTEGER NOT NULL DEFAULT 1,
    id_usuario_creacion INTEGER REFERENCES auth_usuarios(id),
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW(),
    id_usuario_modificacion INTEGER REFERENCES auth_usuarios(id),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT chk_inv_movimiento_naturaleza CHECK (
        (naturaleza = 'PRODUCTO' AND id_producto IS NOT NULL AND id_balon IS NULL)
        OR (naturaleza = 'BALON' AND id_balon IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_inv_movimiento_doc ON inv_movimiento (id_tipo_documento_origen, id_documento_origen);
CREATE INDEX IF NOT EXISTS idx_inv_movimiento_balon ON inv_movimiento (id_balon, fecha);
CREATE INDEX IF NOT EXISTS idx_inv_movimiento_producto ON inv_movimiento (id_producto, id_almacen_origen, fecha);
CREATE INDEX IF NOT EXISTS idx_inv_movimiento_padre ON inv_movimiento (id_movimiento_padre);

-- ============================================================
-- FUNCIONES: inventario-movimientos (funciones/inventario-movimientos/*.sql)
-- ============================================================

-- ===== database_sql/funciones/inventario-movimientos/inv_obtener_movimiento.sql =====
CREATE OR REPLACE FUNCTION inv_obtener_movimiento(p_id INTEGER)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.naturaleza,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            m.id_balon,
            b.numero_serie AS numero_serie_balon,
            m.cantidad,
            m.id_unidad_medida,
            umed.nombre AS nombre_unidad_medida,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.id_cliente,
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), ''),
                cli.numero_documento
            ) AS nombre_cliente,
            m.id_documento_origen,
            m.id_tipo_documento_origen,
            tdo.nombre AS nombre_tipo_documento_origen,
            m.id_movimiento_padre,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_estado_balon_snapshot,
            eb.nombre AS nombre_estado_balon_snapshot,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            m.id_usuario_modificacion,
            um.nombre AS nombre_usuario_modificacion
        FROM inv_movimiento m
        LEFT JOIN pro_producto p ON p.id = m.id_producto
        LEFT JOIN bal_balon b ON b.id = m.id_balon
        LEFT JOIN gen_lista_opciones umed ON umed.id = m.id_unidad_medida
        LEFT JOIN gen_almacen ao ON ao.id = m.id_almacen_origen
        LEFT JOIN gen_almacen ad ON ad.id = m.id_almacen_destino
        LEFT JOIN cli_clientes cli ON cli.id = m.id_cliente
        LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        LEFT JOIN gen_lista_opciones tdo ON tdo.id = m.id_tipo_documento_origen
        LEFT JOIN gen_lista_opciones eb ON eb.id = m.id_estado_balon_snapshot
        LEFT JOIN auth_usuarios uc ON uc.id = m.id_usuario_creacion
        LEFT JOIN auth_usuarios um ON um.id = m.id_usuario_modificacion
        WHERE m.id = p_id AND m.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ===== database_sql/funciones/inventario-movimientos/inv_registrar_movimiento.sql =====
-- Punto único de escritura de inv_movimiento (Fase 1, hito 1).
-- naturaleza='PRODUCTO': mueve pro_stock (misma lógica que pro_crear_movimiento).
-- naturaleza='BALON': mueve custodia de bal_balon (misma lógica que bal_aplicar_custodia_tipo_movimiento);
--   si además viene p_id_producto (gas), también mueve pro_stock de ese gas.
-- Idempotente por (naturaleza, id_tipo_documento_origen, id_documento_origen, id_producto/id_balon, id_tipo_movimiento)
-- cuando se informa documento origen y no se fuerza.
CREATE OR REPLACE FUNCTION inv_registrar_movimiento(
    p_naturaleza VARCHAR,
    p_codigo_tipo_movimiento VARCHAR,
    p_fecha TIMESTAMP DEFAULT NOW(),
    p_id_producto INTEGER DEFAULT NULL,
    p_id_balon INTEGER DEFAULT NULL,
    p_cantidad NUMERIC DEFAULT 0,
    p_id_almacen_origen INTEGER DEFAULT NULL,
    p_id_almacen_destino INTEGER DEFAULT NULL,
    p_id_cliente INTEGER DEFAULT NULL,
    p_codigo_tipo_documento_origen VARCHAR DEFAULT NULL,
    p_id_documento_origen INTEGER DEFAULT NULL,
    p_glosa VARCHAR DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL,
    p_id_movimiento_padre INTEGER DEFAULT NULL,
    p_sentido_ajuste VARCHAR DEFAULT NULL,
    p_forzar BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_naturaleza VARCHAR;
    v_id_tipo_mov INTEGER;
    v_nombre_tipo_mov VARCHAR;
    v_id_tipo_doc INTEGER;
    v_id_existente INTEGER;
    v_cantidad NUMERIC(12,4);
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id INTEGER;
    -- rama PRODUCTO
    v_afecta_stock BOOLEAN;
    v_id_unidad_medida INTEGER;
    v_id_stock INTEGER;
    v_id_stock_dest INTEGER;
    v_stock_anterior NUMERIC(12,4);
    v_stock_nuevo NUMERIC(12,4);
    v_stock_dest_ant NUMERIC(12,4);
    -- rama BALON
    v_nombre_estado_actual VARCHAR;
    v_codigo_estado_destino VARCHAR;
    v_cliente_destino INTEGER;
    v_limpiar_almacen BOOLEAN;
    v_codigo_contenido VARCHAR;
    v_id_estado_balon INTEGER;
    v_id_almacen_balon INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_naturaleza := UPPER(TRIM(COALESCE(p_naturaleza, '')));
    IF v_naturaleza NOT IN ('PRODUCTO', 'BALON') THEN
        RETURN json_build_object('error', 'naturaleza debe ser PRODUCTO o BALON', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'PRODUCTO' AND p_id_producto IS NULL THEN
        RETURN json_build_object('error', 'id_producto es obligatorio para naturaleza PRODUCTO', 'registro', NULL);
    END IF;

    IF v_naturaleza = 'BALON' AND p_id_balon IS NULL THEN
        RETURN json_build_object('error', 'id_balon es obligatorio para naturaleza BALON', 'registro', NULL);
    END IF;

    IF p_codigo_tipo_movimiento IS NULL OR TRIM(p_codigo_tipo_movimiento) = '' THEN
        RETURN json_build_object('error', 'El tipo de movimiento es obligatorio', 'registro', NULL);
    END IF;

    SELECT lo.id, lo.nombre INTO v_id_tipo_mov, v_nombre_tipo_mov
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovInvUnificado'
      AND lo.nombre = UPPER(TRIM(p_codigo_tipo_movimiento))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_mov IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no configurado', UPPER(TRIM(p_codigo_tipo_movimiento))),
            'registro', NULL
        );
    END IF;

    IF p_codigo_tipo_documento_origen IS NOT NULL AND TRIM(p_codigo_tipo_documento_origen) <> '' THEN
        SELECT lo.id INTO v_id_tipo_doc
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef'
          AND lo.nombre = UPPER(TRIM(p_codigo_tipo_documento_origen))
          AND lo.estado = 1
        LIMIT 1;

        IF v_id_tipo_doc IS NULL THEN
            RETURN json_build_object(
                'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(p_codigo_tipo_documento_origen))),
                'registro', NULL
            );
        END IF;
    END IF;

    -- Anti-duplicación: mismo documento + mismo tipo + mismo producto/balón ya registrado.
    IF p_id_documento_origen IS NOT NULL AND v_id_tipo_doc IS NOT NULL AND NOT COALESCE(p_forzar, FALSE) THEN
        SELECT m.id INTO v_id_existente
        FROM inv_movimiento m
        WHERE m.estado = 1
          AND m.naturaleza = v_naturaleza
          AND m.id_tipo_documento_origen = v_id_tipo_doc
          AND m.id_documento_origen = p_id_documento_origen
          AND m.id_tipo_movimiento = v_id_tipo_mov
          AND (v_naturaleza <> 'PRODUCTO' OR m.id_producto = p_id_producto)
          AND (v_naturaleza <> 'BALON' OR m.id_balon = p_id_balon)
        ORDER BY m.id
        LIMIT 1;

        IF v_id_existente IS NOT NULL THEN
            RETURN (inv_obtener_movimiento(v_id_existente)::JSONB || jsonb_build_object('creado', FALSE))::JSON;
        END IF;
    END IF;

    v_cantidad := ABS(COALESCE(p_cantidad, 0));
    v_es_traslado := (v_naturaleza = 'PRODUCTO' AND UPPER(v_nombre_tipo_mov) = 'TRASLADO');
    -- RECARGA_CLIENTE no lleva el prefijo SALIDA_ pero sí es salida de gas hacia el cliente.
    v_es_salida := v_nombre_tipo_mov ILIKE '%SALIDA%' OR UPPER(v_nombre_tipo_mov) = 'RECARGA_CLIENTE';

    IF UPPER(v_nombre_tipo_mov) = 'AJUSTE' AND UPPER(TRIM(COALESCE(p_sentido_ajuste, ''))) = 'MENOS' THEN
        v_es_salida := TRUE;
    END IF;

    IF v_naturaleza = 'PRODUCTO' THEN
        IF v_cantidad <= 0 THEN
            RETURN json_build_object('error', 'La cantidad debe ser mayor a cero', 'registro', NULL);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1) THEN
            RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        IF p_id_almacen_origen IS NULL OR NOT EXISTS (
            SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_origen AND estado = 1
        ) THEN
            RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
        END IF;

        SELECT COALESCE(afecta_stock, FALSE), id_unidad_medida
        INTO v_afecta_stock, v_id_unidad_medida
        FROM pro_producto WHERE id = p_id_producto;

        IF v_es_traslado THEN
            IF p_id_almacen_destino IS NULL THEN
                RETURN json_build_object('error', 'El traslado requiere almacén de destino', 'registro', NULL);
            END IF;
            IF p_id_almacen_destino = p_id_almacen_origen THEN
                RETURN json_build_object('error', 'El almacén de destino debe ser distinto al de origen', 'registro', NULL);
            END IF;
            IF NOT EXISTS (SELECT 1 FROM gen_almacen WHERE id = p_id_almacen_destino AND estado = 1) THEN
                RETURN json_build_object('error', 'El almacén de destino no existe o está inactivo', 'registro', NULL);
            END IF;
        END IF;

        v_stock_anterior := 0;
        v_stock_nuevo := 0;

        IF v_afecta_stock THEN
            SELECT id, stock INTO v_id_stock, v_stock_anterior
            FROM pro_stock
            WHERE id_almacen = p_id_almacen_origen AND id_producto = p_id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                VALUES (p_id_almacen_origen, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                RETURNING id, stock INTO v_id_stock, v_stock_anterior;
            END IF;

            IF v_es_salida THEN
                v_stock_nuevo := v_stock_anterior - v_cantidad;
            ELSE
                v_stock_nuevo := v_stock_anterior + v_cantidad;
            END IF;

            IF v_stock_nuevo < 0 THEN
                RETURN json_build_object('error', 'Stock insuficiente para registrar la salida', 'registro', NULL);
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;

            IF v_es_traslado THEN
                SELECT id, stock INTO v_id_stock_dest, v_stock_dest_ant
                FROM pro_stock
                WHERE id_almacen = p_id_almacen_destino AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock_dest IS NULL THEN
                    INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                    VALUES (p_id_almacen_destino, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                    RETURNING id, stock INTO v_id_stock_dest, v_stock_dest_ant;
                END IF;

                UPDATE pro_stock
                SET stock = COALESCE(v_stock_dest_ant, 0) + v_cantidad,
                    id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock_dest;
            END IF;
        END IF;

        INSERT INTO inv_movimiento (
            fecha, id_tipo_movimiento, naturaleza, id_producto, cantidad, id_unidad_medida,
            id_almacen_origen, id_almacen_destino, id_cliente,
            id_documento_origen, id_tipo_documento_origen, id_movimiento_padre,
            stock_anterior, stock_nuevo, glosa,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'PRODUCTO', p_id_producto, v_cantidad, v_id_unidad_medida,
            p_id_almacen_origen, p_id_almacen_destino, p_id_cliente,
            p_id_documento_origen, v_id_tipo_doc, p_id_movimiento_padre,
            CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
            CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
            p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

        RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
    END IF;

    -- ============== naturaleza = BALON ==============

    SELECT eb.nombre, b.id_almacen
    INTO v_nombre_estado_actual, v_id_almacen_balon
    FROM bal_balon b
    LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE b.id = p_id_balon AND b.estado = 1
    FOR UPDATE OF b;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El cilindro indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF COALESCE(v_nombre_estado_actual, '') IN ('DADO_DE_BAJA', 'ROBO') THEN
        RETURN json_build_object(
            'error', 'No se puede registrar movimiento de un cilindro dado de baja o reportado como robo',
            'registro', NULL
        );
    END IF;

    -- Mismo mapeo tipo→estado que bal_aplicar_custodia_tipo_movimiento (custodia "Libro").
    v_limpiar_almacen := FALSE;
    v_codigo_contenido := NULL;
    v_cliente_destino := NULL;
    CASE v_nombre_tipo_mov
        WHEN 'SALIDA_PRESTAMO' THEN
            v_codigo_estado_destino := 'PRESTADO_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ALQUILER' THEN
            v_codigo_estado_destino := 'ALQUILADO'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_VENTA' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_ENTREGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'SALIDA_MANTENIMIENTO' THEN
            v_codigo_estado_destino := 'EN_MANTENIMIENTO';
        WHEN 'SALIDA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'EN_RECARGA_EXTERNA'; v_limpiar_almacen := TRUE; v_codigo_contenido := 'VACIO';
        WHEN 'ENTRADA_DEVOLUCION', 'ENTRADA_MANTENIMIENTO', 'RETORNO_LIMA' THEN
            v_codigo_estado_destino := 'EN_ALMACEN';
        WHEN 'ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA' THEN
            v_codigo_estado_destino := 'EN_ALMACEN'; v_codigo_contenido := 'LLENO';
        WHEN 'RECARGA_CLIENTE' THEN
            v_codigo_estado_destino := 'EN_PODER_CLIENTE'; v_cliente_destino := p_id_cliente; v_limpiar_almacen := TRUE;
        WHEN 'TRASLADO_LIMA' THEN
            v_codigo_estado_destino := 'EN_RUTA_LIMA'; v_limpiar_almacen := TRUE;
        ELSE
            v_codigo_estado_destino := NULL;
    END CASE;

    IF v_codigo_estado_destino IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_balon
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = v_codigo_estado_destino AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_balon IS NULL THEN
            RETURN json_build_object('error', format('Estado %s no configurado', v_codigo_estado_destino), 'registro', NULL);
        END IF;

        UPDATE bal_balon
        SET
            id_estado_balon = v_id_estado_balon,
            id_cliente_ubicacion = CASE WHEN v_cliente_destino IS NOT NULL THEN v_cliente_destino ELSE NULL END,
            id_almacen = CASE
                WHEN v_limpiar_almacen THEN NULL
                ELSE COALESCE(p_id_almacen_destino, p_id_almacen_origen, id_almacen)
            END,
            id_estado_contenido = CASE
                WHEN v_codigo_contenido IS NOT NULL THEN COALESCE(bal_id_estado_contenido(v_codigo_contenido), id_estado_contenido)
                ELSE id_estado_contenido
            END,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = p_id_balon AND estado = 1;
    END IF;

    -- Si el movimiento del balón también mueve gas, se refleja en pro_stock del gas.
    v_stock_anterior := NULL;
    v_stock_nuevo := NULL;
    IF p_id_producto IS NOT NULL AND v_cantidad > 0 THEN
        DECLARE
            v_id_almacen_gas INTEGER;
        BEGIN
            v_id_almacen_gas := COALESCE(
                CASE WHEN v_es_salida THEN p_id_almacen_origen ELSE p_id_almacen_destino END,
                p_id_almacen_origen, p_id_almacen_destino, v_id_almacen_balon
            );

            IF v_id_almacen_gas IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_anterior
                FROM pro_stock
                WHERE id_almacen = v_id_almacen_gas AND id_producto = p_id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NULL THEN
                    INSERT INTO pro_stock (id_almacen, id_producto, stock, stock_minimo, id_usuario_creacion, id_usuario_modificacion)
                    VALUES (v_id_almacen_gas, p_id_producto, 0, 0, p_id_usuario_auditoria, p_id_usuario_auditoria)
                    RETURNING id, stock INTO v_id_stock, v_stock_anterior;
                END IF;

                IF v_es_salida THEN
                    v_stock_nuevo := v_stock_anterior - v_cantidad;
                ELSE
                    v_stock_nuevo := v_stock_anterior + v_cantidad;
                END IF;

                IF v_stock_nuevo < 0 THEN
                    RETURN json_build_object('error', 'Stock de gas insuficiente para registrar la salida', 'registro', NULL);
                END IF;

                UPDATE pro_stock
                SET stock = v_stock_nuevo, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                WHERE id = v_id_stock;
            END IF;
        END;
    END IF;

    SELECT id_unidad_medida INTO v_id_unidad_medida FROM pro_producto WHERE id = p_id_producto;

    INSERT INTO inv_movimiento (
        fecha, id_tipo_movimiento, naturaleza, id_producto, id_balon, cantidad, id_unidad_medida,
        id_almacen_origen, id_almacen_destino, id_cliente,
        id_documento_origen, id_tipo_documento_origen, id_movimiento_padre,
        stock_anterior, stock_nuevo, id_estado_balon_snapshot, glosa,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'BALON', p_id_producto, p_id_balon, v_cantidad, v_id_unidad_medida,
        p_id_almacen_origen, p_id_almacen_destino, COALESCE(v_cliente_destino, p_id_cliente),
        p_id_documento_origen, v_id_tipo_doc, p_id_movimiento_padre,
        v_stock_anterior, v_stock_nuevo, v_id_estado_balon, p_glosa,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
END;
$function$;

-- ===== database_sql/funciones/inventario-movimientos/inv_revertir_por_documento.sql =====
-- Revierte todos los inv_movimiento activos ligados a un documento origen
-- (stock de producto/gas + custodia de balón), y los da de baja lógica.
CREATE OR REPLACE FUNCTION inv_revertir_por_documento(
    p_codigo_tipo_documento_origen VARCHAR,
    p_id_documento_origen INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_tipo_doc INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_mov RECORD;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_almacen_stock INTEGER;
    v_count INTEGER := 0;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_documento_origen IS NULL THEN
        RETURN json_build_object('revertidos', 0, 'error', 'id_documento_origen es obligatorio');
    END IF;

    SELECT lo.id INTO v_id_tipo_doc
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef'
      AND lo.nombre = UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, '')))
      AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_doc IS NULL THEN
        RETURN json_build_object(
            'revertidos', 0,
            'error', format('Tipo de documento origen %s no configurado', UPPER(TRIM(COALESCE(p_codigo_tipo_documento_origen, ''))))
        );
    END IF;

    FOR v_mov IN
        SELECT * FROM inv_movimiento
        WHERE estado = 1
          AND id_tipo_documento_origen = v_id_tipo_doc
          AND id_documento_origen = p_id_documento_origen
        ORDER BY id
        FOR UPDATE
    LOOP
        SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
        v_es_salida := (v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo < v_mov.stock_anterior)
                       OR (v_nombre_tipo_mov ILIKE '%SALIDA%');
        v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
        IF v_es_traslado THEN
            v_es_salida := TRUE;
        END IF;

        -- Revertir stock (producto, o gas cargado por un movimiento de balón).
        IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
            -- PRODUCTO siempre mueve el almacén origen. BALON+gas puede haber movido el destino
            -- (p.ej. ENTRADA_LLENADO), según la misma resolución que usó inv_registrar_movimiento.
            IF v_mov.naturaleza = 'PRODUCTO' THEN
                v_id_almacen_stock := v_mov.id_almacen_origen;
            ELSE
                v_id_almacen_stock := COALESCE(
                    CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                    v_mov.id_almacen_origen,
                    v_mov.id_almacen_destino
                );
            END IF;

            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NOT NULL THEN
                v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
                IF v_stock_revertido >= 0 THEN
                    UPDATE pro_stock
                    SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                    WHERE id = v_id_stock;
                END IF;
            END IF;

            IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
                SELECT id, stock INTO v_id_stock, v_stock_actual
                FROM pro_stock
                WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
                FOR UPDATE;

                IF v_id_stock IS NOT NULL THEN
                    v_stock_revertido := v_stock_actual - v_mov.cantidad;
                    IF v_stock_revertido >= 0 THEN
                        UPDATE pro_stock
                        SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
                        WHERE id = v_id_stock;
                    END IF;
                END IF;
            END IF;
        END IF;

        -- Revertir custodia de balón a EN_ALMACEN.
        IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
            SELECT lo.id INTO v_id_estado_en_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON l.id = lo.id_lista
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
            LIMIT 1;

            IF v_id_estado_en_almacen IS NOT NULL THEN
                UPDATE bal_balon
                SET
                    id_estado_balon = v_id_estado_en_almacen,
                    id_cliente_ubicacion = NULL,
                    id_almacen = COALESCE(v_mov.id_almacen_origen, v_mov.id_almacen_destino, id_almacen),
                    id_usuario_modificacion = p_id_usuario_auditoria,
                    fecha_modificacion = NOW()
                WHERE id = v_mov.id_balon AND estado = 1;
            END IF;
        END IF;

        UPDATE inv_movimiento
        SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_mov.id;

        v_count := v_count + 1;
    END LOOP;

    RETURN json_build_object('revertidos', v_count);
END;
$function$;

-- ===== database_sql/funciones/inventario-movimientos/inv_stock_producto.sql =====
-- Saldo actual de un producto en un almacén (punto único de consulta de stock).
CREATE OR REPLACE FUNCTION inv_stock_producto(p_id_producto INTEGER, p_id_almacen INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $function$
DECLARE
    v_stock NUMERIC(12,4);
BEGIN
    SELECT stock INTO v_stock
    FROM pro_stock
    WHERE id_producto = p_id_producto AND id_almacen = p_id_almacen AND estado = 1;

    RETURN COALESCE(v_stock, 0);
END;
$function$;

-- ===== database_sql/funciones/inventario-movimientos/inv_saldo_gas.sql =====
-- Alias semántico de inv_stock_producto para productos de gas (mismo pro_stock).
-- Pensado como reemplazo directo de bal_listar_stock_gas / bal_capacidad_disponible_balon
-- cuando esos flujos se corten hacia inv_movimiento (hito 4 del roadmap de Fase 1).
CREATE OR REPLACE FUNCTION inv_saldo_gas(p_id_producto_gas INTEGER, p_id_almacen INTEGER)
RETURNS NUMERIC
LANGUAGE plpgsql
STABLE
AS $function$
BEGIN
    RETURN inv_stock_producto(p_id_producto_gas, p_id_almacen);
END;
$function$;

-- ===== database_sql/funciones/inventario-movimientos/inv_listar_movimientos.sql =====
CREATE OR REPLACE FUNCTION inv_listar_movimientos(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_naturaleza VARCHAR DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_id_balon INTEGER DEFAULT NULL,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_tipo_movimiento INTEGER DEFAULT NULL,
    p_id_tipo_documento_origen INTEGER DEFAULT NULL,
    p_id_documento_origen INTEGER DEFAULT NULL,
    p_fecha_desde DATE DEFAULT NULL,
    p_fecha_hasta DATE DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT
        COUNT(*),
        json_build_object(
            'total', COUNT(*),
            'producto', COUNT(*) FILTER (WHERE m.naturaleza = 'PRODUCTO'),
            'balon', COUNT(*) FILTER (WHERE m.naturaleza = 'BALON'),
            'salidas', COUNT(*) FILTER (WHERE tm.nombre ILIKE '%SALIDA%'),
            'entradas', COUNT(*) FILTER (WHERE tm.nombre ILIKE '%ENTRADA%' OR tm.nombre = 'INGRESO')
        )
    INTO v_total, v_resumen
    FROM inv_movimiento m
    LEFT JOIN pro_producto p ON p.id = m.id_producto
    LEFT JOIN bal_balon b ON b.id = m.id_balon
    LEFT JOIN gen_almacen a ON a.id = m.id_almacen_origen
    LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
    WHERE m.estado = 1
      AND (p_naturaleza IS NULL OR m.naturaleza = UPPER(TRIM(p_naturaleza)))
      AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
      AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
      AND (p_id_almacen IS NULL OR m.id_almacen_origen = p_id_almacen OR m.id_almacen_destino = p_id_almacen)
      AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
      AND (p_id_tipo_documento_origen IS NULL OR m.id_tipo_documento_origen = p_id_tipo_documento_origen)
      AND (p_id_documento_origen IS NULL OR m.id_documento_origen = p_id_documento_origen)
      AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
          OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            m.id,
            m.fecha,
            m.naturaleza,
            m.id_tipo_movimiento,
            tm.nombre AS nombre_tipo_movimiento,
            m.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            m.id_balon,
            b.numero_serie AS numero_serie_balon,
            m.cantidad,
            umed.nombre AS nombre_unidad_medida,
            m.id_almacen_origen,
            ao.nombre AS nombre_almacen_origen,
            m.id_almacen_destino,
            ad.nombre AS nombre_almacen_destino,
            m.id_cliente,
            COALESCE(
                NULLIF(TRIM(cli.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', cli.nombres, cli.apellido_paterno, cli.apellido_materno)), ''),
                cli.numero_documento
            ) AS nombre_cliente,
            m.stock_anterior,
            m.stock_nuevo,
            m.id_documento_origen,
            m.id_tipo_documento_origen,
            tdo.nombre AS nombre_tipo_documento_origen,
            m.id_movimiento_padre,
            (m.id_documento_origen IS NULL) AS puede_anular,
            m.glosa,
            m.estado,
            m.fecha_creacion,
            m.fecha_modificacion,
            m.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion
        FROM inv_movimiento m
        LEFT JOIN pro_producto p ON p.id = m.id_producto
        LEFT JOIN bal_balon b ON b.id = m.id_balon
        LEFT JOIN gen_lista_opciones umed ON umed.id = m.id_unidad_medida
        LEFT JOIN gen_almacen ao ON ao.id = m.id_almacen_origen
        LEFT JOIN gen_almacen ad ON ad.id = m.id_almacen_destino
        LEFT JOIN gen_almacen a ON a.id = m.id_almacen_origen
        LEFT JOIN cli_clientes cli ON cli.id = m.id_cliente
        LEFT JOIN gen_lista_opciones tm ON tm.id = m.id_tipo_movimiento
        LEFT JOIN gen_lista_opciones tdo ON tdo.id = m.id_tipo_documento_origen
        LEFT JOIN auth_usuarios uc ON uc.id = m.id_usuario_creacion
        WHERE m.estado = 1
          AND (p_naturaleza IS NULL OR m.naturaleza = UPPER(TRIM(p_naturaleza)))
          AND (p_id_producto IS NULL OR m.id_producto = p_id_producto)
          AND (p_id_balon IS NULL OR m.id_balon = p_id_balon)
          AND (p_id_almacen IS NULL OR m.id_almacen_origen = p_id_almacen OR m.id_almacen_destino = p_id_almacen)
          AND (p_id_tipo_movimiento IS NULL OR m.id_tipo_movimiento = p_id_tipo_movimiento)
          AND (p_id_tipo_documento_origen IS NULL OR m.id_tipo_documento_origen = p_id_tipo_documento_origen)
          AND (p_id_documento_origen IS NULL OR m.id_documento_origen = p_id_documento_origen)
          AND (p_fecha_desde IS NULL OR m.fecha >= p_fecha_desde)
          AND (p_fecha_hasta IS NULL OR m.fecha <= p_fecha_hasta)
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(COALESCE(m.glosa, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.codigo, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(p.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(b.numero_serie, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(a.nombre, ''), p_busqueda)
              OR gen_texto_coincide(COALESCE(tm.nombre, ''), p_busqueda)
          )
        ORDER BY m.fecha DESC, m.id DESC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;

-- ===== database_sql/funciones/inventario-movimientos/inv_eliminar_movimiento.sql =====
-- Anula un movimiento manual (sin documento origen): revierte stock/custodia y da de baja lógica.
-- Los movimientos ligados a un documento (venta, compra, GRE, préstamo, etc.) se anulan
-- revirtiendo el documento origen (inv_revertir_por_documento), no aquí.
CREATE OR REPLACE FUNCTION inv_eliminar_movimiento(
    p_id INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_mov inv_movimiento%ROWTYPE;
    v_nombre_tipo_mov VARCHAR;
    v_es_salida BOOLEAN;
    v_es_traslado BOOLEAN;
    v_id_stock INTEGER;
    v_stock_actual NUMERIC(12,4);
    v_stock_revertido NUMERIC(12,4);
    v_id_estado_en_almacen INTEGER;
    v_id_almacen_stock INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT * INTO v_mov FROM inv_movimiento WHERE id = p_id AND estado = 1 FOR UPDATE;

    IF NOT FOUND THEN
        RETURN json_build_object('eliminado', FALSE, 'id', p_id);
    END IF;

    IF v_mov.id_documento_origen IS NOT NULL THEN
        RETURN json_build_object(
            'eliminado', FALSE, 'id', p_id,
            'error', 'No se puede anular un movimiento vinculado a un documento; anula el documento origen'
        );
    END IF;

    SELECT nombre INTO v_nombre_tipo_mov FROM gen_lista_opciones WHERE id = v_mov.id_tipo_movimiento;
    v_es_salida := (v_mov.stock_nuevo IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo < v_mov.stock_anterior)
                   OR (v_nombre_tipo_mov ILIKE '%SALIDA%');
    v_es_traslado := (v_mov.naturaleza = 'PRODUCTO' AND UPPER(COALESCE(v_nombre_tipo_mov, '')) = 'TRASLADO');
    IF v_es_traslado THEN
        v_es_salida := TRUE;
    END IF;

    IF v_mov.id_producto IS NOT NULL AND v_mov.stock_anterior IS NOT NULL AND v_mov.stock_nuevo IS NOT NULL THEN
        -- PRODUCTO siempre mueve el almacén origen. BALON+gas puede haber movido el destino
        -- (p.ej. ENTRADA_LLENADO), según la misma resolución que usó inv_registrar_movimiento.
        IF v_mov.naturaleza = 'PRODUCTO' THEN
            v_id_almacen_stock := v_mov.id_almacen_origen;
        ELSE
            v_id_almacen_stock := COALESCE(
                CASE WHEN v_es_salida THEN v_mov.id_almacen_origen ELSE v_mov.id_almacen_destino END,
                v_mov.id_almacen_origen,
                v_mov.id_almacen_destino
            );
        END IF;

        SELECT id, stock INTO v_id_stock, v_stock_actual
        FROM pro_stock
        WHERE id_almacen = v_id_almacen_stock AND id_producto = v_mov.id_producto AND estado = 1
        FOR UPDATE;

        IF v_id_stock IS NULL THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el registro de stock para revertir el movimiento');
        END IF;

        v_stock_revertido := v_stock_actual + (CASE WHEN v_es_salida THEN v_mov.cantidad ELSE -v_mov.cantidad END);
        IF v_stock_revertido < 0 THEN
            RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el movimiento porque revertiría un stock negativo');
        END IF;

        UPDATE pro_stock
        SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
        WHERE id = v_id_stock;

        IF v_es_traslado AND v_mov.id_almacen_destino IS NOT NULL THEN
            SELECT id, stock INTO v_id_stock, v_stock_actual
            FROM pro_stock
            WHERE id_almacen = v_mov.id_almacen_destino AND id_producto = v_mov.id_producto AND estado = 1
            FOR UPDATE;

            IF v_id_stock IS NULL THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se encontró el stock de destino para revertir el traslado');
            END IF;

            v_stock_revertido := v_stock_actual - v_mov.cantidad;
            IF v_stock_revertido < 0 THEN
                RETURN json_build_object('eliminado', FALSE, 'id', p_id, 'error', 'No se puede anular el traslado porque el destino ya no tiene esa cantidad');
            END IF;

            UPDATE pro_stock
            SET stock = v_stock_revertido, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
            WHERE id = v_id_stock;
        END IF;
    END IF;

    IF v_mov.naturaleza = 'BALON' AND v_mov.id_balon IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
        LIMIT 1;

        IF v_id_estado_en_almacen IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_estado_en_almacen,
                id_cliente_ubicacion = NULL,
                id_almacen = COALESCE(v_mov.id_almacen_origen, v_mov.id_almacen_destino, id_almacen),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_mov.id_balon AND estado = 1;
        END IF;
    END IF;

    UPDATE inv_movimiento
    SET estado = 0, id_usuario_modificacion = p_id_usuario_auditoria, fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN json_build_object('eliminado', TRUE, 'id', p_id);
END;
$function$;

-- ============================================================
-- HABILITAR GAS EN pro_stock (funciones/stock/*.sql)
-- ============================================================

-- ===== database_sql/funciones/stock/pro_crear_stock.sql =====
CREATE OR REPLACE FUNCTION pro_crear_stock(
    p_id_almacen INTEGER,
    p_id_producto INTEGER,
    p_stock NUMERIC DEFAULT 0,
    p_stock_minimo NUMERIC DEFAULT 0,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_inactivo INTEGER;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (
        SELECT 1 FROM gen_almacen WHERE id = p_id_almacen AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El almacén indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM pro_stock
        WHERE id_almacen = p_id_almacen
          AND id_producto = p_id_producto
          AND estado = 1
    ) THEN
        RETURN json_build_object(
            'error',
            'Ya existe un registro de stock activo para este producto en el almacén',
            'registro',
            NULL
        );
    END IF;

    IF COALESCE(p_stock, 0) < 0 OR COALESCE(p_stock_minimo, 0) < 0 THEN
        RETURN json_build_object('error', 'El stock y el stock mínimo no pueden ser negativos', 'registro', NULL);
    END IF;

    SELECT
        REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
        COALESCE(p.es_gas, FALSE)
    INTO v_nombre_unidad, v_es_gas
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = p_id_producto;

    -- Gases (m³) pueden ser decimales aunque la U.M. esté mal catalogada como UNID.
    IF NOT COALESCE(v_es_gas, FALSE)
       AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
    THEN
        IF COALESCE(p_stock, 0) <> TRUNC(COALESCE(p_stock, 0)) THEN
            RETURN json_build_object(
                'error',
                'El stock debe ser entero (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;
        IF COALESCE(p_stock_minimo, 0) <> TRUNC(COALESCE(p_stock_minimo, 0)) THEN
            RETURN json_build_object(
                'error',
                'El stock mínimo debe ser entero (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;
    END IF;

    -- Si hubo baja lógica previa, UNIQUE(id_almacen, id_producto) bloquea el INSERT:
    -- reactivar y actualizar cantidades.
    SELECT id
    INTO v_id_inactivo
    FROM pro_stock
    WHERE id_almacen = p_id_almacen
      AND id_producto = p_id_producto
      AND estado = 0
    LIMIT 1;

    IF v_id_inactivo IS NOT NULL THEN
        UPDATE pro_stock
        SET
            stock = COALESCE(p_stock, 0),
            stock_minimo = COALESCE(p_stock_minimo, 0),
            estado = 1,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id = v_id_inactivo;

        RETURN pro_obtener_stock(v_id_inactivo);
    END IF;

    INSERT INTO pro_stock (
        id_almacen,
        id_producto,
        stock,
        stock_minimo,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_almacen,
        p_id_producto,
        COALESCE(p_stock, 0),
        COALESCE(p_stock_minimo, 0),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_stock(v_id);
END;
$function$;

-- ===== database_sql/funciones/stock/pro_actualizar_stock.sql =====
CREATE OR REPLACE FUNCTION pro_actualizar_stock(
    p_id INTEGER,
    p_stock NUMERIC DEFAULT NULL,
    p_stock_minimo NUMERIC DEFAULT NULL,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_producto INTEGER;
    v_nombre_unidad VARCHAR;
    v_es_gas BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- La cantidad solo cambia por movimientos de inventario.
    IF p_stock IS NOT NULL THEN
        RETURN json_build_object(
            'error',
            'La cantidad de stock solo se modifica con movimientos (ingreso, salida o ajuste). Aquí solo puedes cambiar el stock mínimo.',
            'registro',
            NULL
        );
    END IF;

    IF p_stock_minimo IS NOT NULL AND p_stock_minimo < 0 THEN
        RETURN json_build_object('error', 'El stock mínimo no puede ser negativo', 'registro', NULL);
    END IF;

    SELECT s.id_producto
    INTO v_id_producto
    FROM pro_stock s
    WHERE s.id = p_id AND s.estado = 1;

    IF v_id_producto IS NULL THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    SELECT
        REGEXP_REPLACE(UPPER(TRIM(COALESCE(um.nombre, ''))), '\.+$', ''),
        COALESCE(p.es_gas, FALSE)
    INTO v_nombre_unidad, v_es_gas
    FROM pro_producto p
    LEFT JOIN gen_lista_opciones um ON um.id = p.id_unidad_medida
    WHERE p.id = v_id_producto;

    IF NOT COALESCE(v_es_gas, FALSE)
       AND v_nombre_unidad IN ('UNID', 'NIU', 'UND', 'UNI', 'UNIDAD', 'UNIDADES', 'PZ', 'PZA', 'PIEZA', 'PIEZAS')
    THEN
        IF p_stock_minimo IS NOT NULL AND p_stock_minimo <> TRUNC(p_stock_minimo) THEN
            RETURN json_build_object(
                'error',
                'El stock mínimo debe ser entero (unidad de medida UNID)',
                'registro',
                NULL
            );
        END IF;
    END IF;

    UPDATE pro_stock
    SET
        stock_minimo = COALESCE(p_stock_minimo, stock_minimo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN pro_obtener_stock(p_id);
END;
$function$;

-- ===== database_sql/funciones/stock/pro_asegurar_stock_producto.sql =====
CREATE OR REPLACE FUNCTION pro_asegurar_stock_producto(
    p_id_producto INTEGER,
    p_id_usuario_auditoria INTEGER DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_producto IS NULL THEN
        RETURN;
    END IF;

    -- Cualquier producto con afecta_stock (accesorios y, desde Fase 1, también gas). Nunca servicios.
    IF NOT EXISTS (
        SELECT 1
        FROM pro_producto p
        WHERE p.id = p_id_producto
          AND p.estado = 1
          AND COALESCE(p.afecta_stock, FALSE) = TRUE
          AND COALESCE(p.es_servicio, FALSE) = FALSE
    ) THEN
        RETURN;
    END IF;

    -- Reactivar filas inactivas (UNIQUE id_almacen + id_producto).
    UPDATE pro_stock s
    SET
        estado = 1,
        stock = CASE WHEN s.estado = 0 THEN 0 ELSE s.stock END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    FROM gen_almacen a
    WHERE s.id_almacen = a.id
      AND s.id_producto = p_id_producto
      AND a.estado = 1
      AND s.estado = 0;

    INSERT INTO pro_stock (
        id_almacen,
        id_producto,
        stock,
        stock_minimo,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    SELECT
        a.id,
        p_id_producto,
        0,
        0,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    FROM gen_almacen a
    WHERE a.estado = 1
      AND NOT EXISTS (
          SELECT 1
          FROM pro_stock s
          WHERE s.id_almacen = a.id
            AND s.id_producto = p_id_producto
      );
END;
$function$;

-- ===== database_sql/funciones/stock/pro_listar_stock.sql =====
DROP FUNCTION IF EXISTS pro_listar_stock(VARCHAR, INTEGER, INTEGER, INTEGER, INTEGER, BOOLEAN);

CREATE OR REPLACE FUNCTION pro_listar_stock(
    p_busqueda VARCHAR DEFAULT '',
    p_limite INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_id_almacen INTEGER DEFAULT NULL,
    p_id_producto INTEGER DEFAULT NULL,
    p_solo_bajo_minimo BOOLEAN DEFAULT NULL,
    p_solo_activos INTEGER DEFAULT 1
)
RETURNS JSON
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registros JSON;
    v_total BIGINT;
    v_resumen JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    -- Stock de productos: accesorios y, desde Fase 1, también gas (pro_stock unificado).
    SELECT
        COUNT(*),
        json_build_object(
            'total_items', COUNT(*),
            'bajo_minimo', COUNT(*) FILTER (WHERE s.stock <= s.stock_minimo),
            'ok', COUNT(*) FILTER (WHERE s.stock > s.stock_minimo),
            'stock_total', COALESCE(SUM(s.stock), 0)
        )
    INTO v_total, v_resumen
    FROM pro_stock s
    INNER JOIN gen_almacen a ON s.id_almacen = a.id
    INNER JOIN pro_producto p ON s.id_producto = p.id
    WHERE (p_solo_activos IS NULL OR s.estado = p_solo_activos)
      AND (p_solo_activos IS DISTINCT FROM 1 OR (a.estado = 1 AND p.estado = 1))
      AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
      AND (p_id_producto IS NULL OR s.id_producto = p_id_producto)
      AND (
          p_solo_bajo_minimo IS NULL
          OR (p_solo_bajo_minimo = TRUE AND s.stock <= s.stock_minimo)
          OR (p_solo_bajo_minimo = FALSE AND s.stock > s.stock_minimo)
      )
      AND (
          p_busqueda = ''
          OR gen_texto_coincide(a.nombre, p_busqueda)
          OR gen_texto_coincide(p.codigo, p_busqueda)
          OR gen_texto_coincide(p.nombre, p_busqueda)
      );

    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::JSON) INTO v_registros
    FROM (
        SELECT
            s.id,
            s.id_almacen,
            a.nombre AS nombre_almacen,
            a.id_sucursal,
            suc.nombre AS nombre_sucursal,
            s.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            COALESCE(p.es_gas, FALSE) AS es_gas,
            p.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            sc.id AS id_sub_categoria,
            sc.nombre AS nombre_sub_categoria,
            cat.id AS id_categoria,
            cat.nombre AS nombre_categoria,
            s.stock,
            s.stock_minimo,
            (s.stock <= s.stock_minimo) AS bajo_minimo,
            s.estado,
            s.fecha_creacion,
            s.fecha_modificacion,
            s.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            s.id_usuario_modificacion,
            um2.nombre AS nombre_usuario_modificacion
        FROM pro_stock s
        INNER JOIN gen_almacen a ON s.id_almacen = a.id
        INNER JOIN gen_sucursal suc ON a.id_sucursal = suc.id
        INNER JOIN pro_producto p ON s.id_producto = p.id
        LEFT JOIN pro_sub_categoria sc ON p.id_sub_categoria = sc.id
        LEFT JOIN pro_categoria cat ON sc.id_categoria = cat.id
        LEFT JOIN gen_lista_opciones um ON p.id_unidad_medida = um.id
        LEFT JOIN auth_usuarios uc ON s.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios um2 ON s.id_usuario_modificacion = um2.id
        WHERE (p_solo_activos IS NULL OR s.estado = p_solo_activos)
          AND (p_solo_activos IS DISTINCT FROM 1 OR (a.estado = 1 AND p.estado = 1))
          AND (p_id_almacen IS NULL OR s.id_almacen = p_id_almacen)
          AND (p_id_producto IS NULL OR s.id_producto = p_id_producto)
          AND (
              p_solo_bajo_minimo IS NULL
              OR (p_solo_bajo_minimo = TRUE AND s.stock <= s.stock_minimo)
              OR (p_solo_bajo_minimo = FALSE AND s.stock > s.stock_minimo)
          )
          AND (
              p_busqueda = ''
              OR gen_texto_coincide(a.nombre, p_busqueda)
              OR gen_texto_coincide(p.codigo, p_busqueda)
              OR gen_texto_coincide(p.nombre, p_busqueda)
          )
        ORDER BY a.nombre ASC, p.nombre ASC
        LIMIT p_limite
        OFFSET p_offset
    ) t;

    RETURN json_build_object(
        'registros', v_registros,
        'total', v_total,
        'resumen', v_resumen
    );
END;
$function$;

