-- Fase 1 — SALIDA_MANTENIMIENTO ahora acepta p_id_cliente como proveedor externo
-- de mantenimiento (cli_clientes también modela proveedores, ver id_proveedor en
-- bal_mantenimiento/bal_movimiento_recarga/com_comprobante_compra/etc.). Si no se
-- indica, el comportamiento es igual al de antes (mantenimiento interno).

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: inv_registrar_movimiento
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.763Z
DROP FUNCTION IF EXISTS inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone, p_id_producto integer, p_id_balon integer, p_cantidad numeric, p_id_almacen_origen integer, p_id_almacen_destino integer, p_id_cliente integer, p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_glosa character varying, p_id_usuario_auditoria integer, p_id_movimiento_padre integer, p_sentido_ajuste character varying, p_forzar boolean);
DROP FUNCTION IF EXISTS inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone, p_id_producto integer, p_id_balon integer, p_cantidad numeric, p_id_almacen_origen integer, p_id_almacen_destino integer, p_id_cliente integer, p_codigo_tipo_documento_origen character varying, p_id_documento_origen integer, p_glosa character varying, p_id_usuario_auditoria integer, p_id_movimiento_padre integer, p_sentido_ajuste character varying, p_forzar boolean, p_id_documento_detalle integer);

CREATE OR REPLACE FUNCTION inv_registrar_movimiento(p_naturaleza character varying, p_codigo_tipo_movimiento character varying, p_fecha timestamp without time zone DEFAULT now(), p_id_producto integer DEFAULT NULL::integer, p_id_balon integer DEFAULT NULL::integer, p_cantidad numeric DEFAULT 0, p_id_almacen_origen integer DEFAULT NULL::integer, p_id_almacen_destino integer DEFAULT NULL::integer, p_id_cliente integer DEFAULT NULL::integer, p_codigo_tipo_documento_origen character varying DEFAULT NULL::character varying, p_id_documento_origen integer DEFAULT NULL::integer, p_glosa character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_movimiento_padre integer DEFAULT NULL::integer, p_sentido_ajuste character varying DEFAULT NULL::character varying, p_forzar boolean DEFAULT false, p_id_documento_detalle integer DEFAULT NULL::integer)
 RETURNS json
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
    v_signo INTEGER;
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
    v_id_estado_anterior INTEGER;
    v_id_cliente_anterior INTEGER;
    v_id_almacen_anterior INTEGER;
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

    -- Anti-duplicación: cabecera + detalle opcional + tipo + producto/balón.
    IF p_id_documento_origen IS NOT NULL AND v_id_tipo_doc IS NOT NULL AND NOT COALESCE(p_forzar, FALSE) THEN
        SELECT m.id INTO v_id_existente
        FROM inv_movimiento m
        WHERE m.estado = 1
          AND m.naturaleza = v_naturaleza
          AND m.id_tipo_documento_origen = v_id_tipo_doc
          AND m.id_documento_origen = p_id_documento_origen
          AND COALESCE(m.id_documento_detalle, -1) = COALESCE(p_id_documento_detalle, -1)
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
    v_signo := inv_signo_tipo_movimiento(v_id_tipo_mov);

    IF UPPER(v_nombre_tipo_mov) = 'AJUSTE' THEN
        IF UPPER(TRIM(COALESCE(p_sentido_ajuste, ''))) NOT IN ('MAS', 'MENOS') THEN
            RETURN json_build_object('error', 'El ajuste requiere sentido MAS o MENOS', 'registro', NULL);
        END IF;
        v_es_salida := UPPER(TRIM(p_sentido_ajuste)) = 'MENOS';
    ELSIF v_signo IS NULL THEN
        RETURN json_build_object(
            'error', format('Tipo de movimiento %s no tiene signo configurado', v_nombre_tipo_mov),
            'registro', NULL
        );
    ELSE
        v_es_salida := v_signo < 0 OR v_es_traslado;
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
            id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
            stock_anterior, stock_nuevo, glosa,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'PRODUCTO', p_id_producto, v_cantidad, v_id_unidad_medida,
            p_id_almacen_origen, p_id_almacen_destino, p_id_cliente,
            p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
            CASE WHEN v_afecta_stock THEN v_stock_anterior ELSE NULL END,
            CASE WHEN v_afecta_stock THEN v_stock_nuevo ELSE NULL END,
            p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

        RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
    END IF;

    -- ============== naturaleza = BALON ==============

    SELECT eb.nombre, b.id_almacen, b.id_estado_balon, b.id_cliente_ubicacion
    INTO v_nombre_estado_actual, v_id_almacen_balon, v_id_estado_anterior, v_id_cliente_anterior
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

    v_id_almacen_anterior := v_id_almacen_balon;

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
            -- p_id_cliente aquí es el proveedor externo de mantenimiento (cli_clientes
            -- también modela proveedores). Si no se indica, el balón sigue igual de
            -- almacén (mantenimiento interno en un almacén propio).
            v_codigo_estado_destino := 'EN_MANTENIMIENTO'; v_cliente_destino := p_id_cliente;
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
        id_documento_origen, id_tipo_documento_origen, id_documento_detalle, id_movimiento_padre,
        stock_anterior, stock_nuevo, id_estado_balon_snapshot,
        id_estado_balon_anterior, id_cliente_ubicacion_anterior, id_almacen_anterior,
        glosa, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        COALESCE(p_fecha, NOW()), v_id_tipo_mov, 'BALON', p_id_producto, p_id_balon, v_cantidad, v_id_unidad_medida,
        p_id_almacen_origen, p_id_almacen_destino, COALESCE(v_cliente_destino, p_id_cliente),
        p_id_documento_origen, v_id_tipo_doc, p_id_documento_detalle, p_id_movimiento_padre,
        v_stock_anterior, v_stock_nuevo, v_id_estado_balon,
        v_id_estado_anterior, v_id_cliente_anterior, v_id_almacen_anterior,
        p_glosa, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN (inv_obtener_movimiento(v_id)::JSONB || jsonb_build_object('creado', TRUE))::JSON;
END;
$function$
