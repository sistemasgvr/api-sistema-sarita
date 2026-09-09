-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_renovar_prestamo
-- Overloads: 1
--
-- Actualizada por database_sql/migraciones/20260905_bal_renovar_prestamo_cilindro_comprometido.sql:
-- la busqueda de cilindro de canje descarta los que tienen un detalle de
-- prestamo abierto (por ejemplo, los recibidos en garantia).
--
-- Actualizada por database_sql/migraciones/20260909_prestamo_renovacion_fecha_y_garantia.sql:
-- (1) recibe la fecha de retorno pactada, que antes se perdia: el prestamo de
--     renovacion nacia sin vencimiento y quedaba fuera de los reportes de
--     antiguedad; (2) la garantia ya no se re-apunta con un UPDATE, sino que se
--     cierra y se abre otra encadenada al prestamo nuevo, apuntando al detalle
--     del cilindro entregado — el mismo patron que el prestamo.
DROP FUNCTION IF EXISTS bal_renovar_prestamo(p_id_prestamo integer, p_id_balon_nuevo integer, p_id_usuario integer);
DROP FUNCTION IF EXISTS bal_renovar_prestamo(p_id_prestamo integer, p_id_balon_nuevo integer, p_id_usuario integer, p_id_comprobante_venta_nuevo integer, p_mantener_garantia boolean);

CREATE OR REPLACE FUNCTION bal_renovar_prestamo(p_id_prestamo integer, p_id_balon_nuevo integer DEFAULT NULL::integer, p_id_usuario integer DEFAULT NULL::integer, p_id_comprobante_venta_nuevo integer DEFAULT NULL::integer, p_mantener_garantia boolean DEFAULT true, p_fecha_retorno_pactada date DEFAULT NULL::date)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prestamo RECORD;
    v_detalle_entregado RECORD;
    v_id_detalle_garantia INTEGER;
    v_id_balon_swap INTEGER;
    v_id_estado_en_almacen INTEGER;
    v_id_estado_detalle_devuelto INTEGER;
    v_id_estado_prestamo_activo INTEGER;
    v_result JSON;
    v_id_prestamo_nuevo INTEGER;
    v_fecha_retorno DATE;
    v_id_detalle_entregado_nuevo INTEGER;
    v_detalle_garantia RECORD;
    v_id_estado_detalle_transferido INTEGER;
    v_garantia RECORD;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT p.*
    INTO v_prestamo
    FROM bal_prestamo p
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    -- La fecha que pactó el mostrador manda; si no llega, se hereda la del
    -- préstamo que se renueva para no dejar el nuevo sin vencimiento.
    v_fecha_retorno := COALESCE(p_fecha_retorno_pactada, v_prestamo.fecha_retorno_pactada);

    IF v_fecha_retorno IS NOT NULL AND v_fecha_retorno < CURRENT_DATE THEN
        RETURN json_build_object(
            'error', 'La fecha de retorno pactada no puede ser anterior a hoy',
            'registro', NULL
        );
    END IF;

    SELECT pd.*
    INTO v_detalle_entregado
    FROM bal_prestamo_detalle pd
    WHERE pd.id_prestamo = p_id_prestamo
      AND pd.rol = 'ENTREGADO'
      AND pd.estado = 1
      AND pd.fecha_devolucion IS NULL
    ORDER BY pd.id DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'El préstamo no tiene un cilindro entregado activo para renovar',
            'registro', NULL
        );
    END IF;

    SELECT pd.id INTO v_id_detalle_garantia
    FROM bal_prestamo_detalle pd
    WHERE pd.id_prestamo = p_id_prestamo
      AND pd.rol = 'GARANTIA'
      AND pd.estado = 1
      AND pd.fecha_devolucion IS NULL
    ORDER BY pd.id DESC
    LIMIT 1;

    -- Balón nuevo: el que pasó el cajero, o el primero disponible de las
    -- mismas características (mismo tipo + gas) en el almacén del préstamo.
    IF p_id_balon_nuevo IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        IF NOT EXISTS (
            SELECT 1 FROM bal_balon b
            WHERE b.id = p_id_balon_nuevo AND b.estado = 1 AND b.id_estado_balon = v_id_estado_en_almacen
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro indicado no está disponible en almacén',
                'registro', NULL
            );
        END IF;

        -- Mismo criterio que la busqueda automatica, pero con un mensaje que
        -- explica el caso en vez del generico de bal_crear_prestamo_detalle.
        IF EXISTS (
            SELECT 1
            FROM bal_prestamo_detalle pd_ocupado
            INNER JOIN bal_prestamo p_ocupado
                ON p_ocupado.id = pd_ocupado.id_prestamo AND p_ocupado.estado = 1
            WHERE pd_ocupado.id_balon = p_id_balon_nuevo
              AND pd_ocupado.estado = 1
              AND pd_ocupado.fecha_devolucion IS NULL
        ) THEN
            RETURN json_build_object(
                'error', 'El cilindro indicado está comprometido en otro préstamo '
                         || '(por ejemplo, recibido en garantía). Elige otro o devuélvelo primero.',
                'registro', NULL
            );
        END IF;
        v_id_balon_swap := p_id_balon_nuevo;
    ELSE
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
        LIMIT 1;

        SELECT b.id INTO v_id_balon_swap
        FROM bal_balon b
        INNER JOIN bal_balon origen ON origen.id = v_detalle_entregado.id_balon
        WHERE b.estado = 1
          AND b.id_estado_balon = v_id_estado_en_almacen
          AND b.id <> origen.id
          AND b.id_tipo_balon = origen.id_tipo_balon
          AND COALESCE(b.id_producto_gas, -1) = COALESCE(origen.id_producto_gas, -1)
          AND (v_prestamo.id_almacen IS NULL OR b.id_almacen = v_prestamo.id_almacen)
          -- Un cilindro con detalle de prestamo abierto no esta libre aunque
          -- figure DISPONIBLE: el caso tipico es el que el propio cliente dejo
          -- en garantia, que esta fisicamente en la empresa pero comprometido
          -- (rol GARANTIA). Sin este filtro la renovacion lo elegia como
          -- reemplazo y moria en bal_crear_prestamo_detalle con "El cilindro ya
          -- tiene un prestamo activo sin devolver" — es decir, un cliente que
          -- dejo su balon no podia renovar.
          AND NOT EXISTS (
              SELECT 1
              FROM bal_prestamo_detalle pd_ocupado
              INNER JOIN bal_prestamo p_ocupado
                  ON p_ocupado.id = pd_ocupado.id_prestamo AND p_ocupado.estado = 1
              WHERE pd_ocupado.id_balon = b.id
                AND pd_ocupado.estado = 1
                AND pd_ocupado.fecha_devolucion IS NULL
          )
        ORDER BY b.fecha_registro ASC NULLS LAST, b.id ASC
        LIMIT 1;
    END IF;

    -- 1. Cierra el detalle ENTREGADO del préstamo anterior.
    IF v_id_balon_swap IS NOT NULL THEN
        -- Canje: el cilindro viejo vuelve físicamente al almacén.
        v_result := bal_devolver_prestamo_detalle(
            v_detalle_entregado.id,
            CURRENT_DATE,
            v_prestamo.id_almacen,
            p_id_usuario,
            'VACIO',
            'Renovado — cilindro reemplazado'
        );
        IF v_result->>'error' IS NOT NULL THEN
            RETURN json_build_object('error', v_result->>'error', 'registro', NULL);
        END IF;
    ELSE
        -- Extensión: el cilindro nunca cambia de custodia, solo se cierra el
        -- detalle administrativamente (sin pasar por bal_prestamo_aplicar_retorno_cilindro,
        -- que devolvería el balón al almacén — aquí el cliente lo sigue teniendo).
        SELECT lo.id INTO v_id_estado_detalle_devuelto
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
        LIMIT 1;

        UPDATE bal_prestamo_detalle
        SET fecha_devolucion = CURRENT_DATE,
            id_estado = v_id_estado_detalle_devuelto,
            observacion = TRIM(COALESCE(observacion || ' — ', '') || 'Renovado sin cambio de cilindro'),
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_detalle_entregado.id;
    END IF;

    -- 2. Préstamo nuevo, encadenado al anterior.
    SELECT lo.id INTO v_id_estado_prestamo_activo
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON lo.id_lista = l.id
    WHERE l.nombre = 'EstadoPrestamo' AND lo.nombre = 'ACTIVO' AND lo.estado = 1
    LIMIT 1;

    v_result := bal_crear_prestamo(
        p_id_tipo_prestamo      => v_prestamo.id_tipo_prestamo,
        p_id_cliente            => v_prestamo.id_cliente,
        p_id_proveedor          => v_prestamo.id_proveedor,
        p_id_almacen            => v_prestamo.id_almacen,
        p_fecha_salida          => CURRENT_DATE,
        p_fecha_retorno_pactada => v_fecha_retorno,
        p_titulo                => 'Renovación · ' || COALESCE(v_prestamo.titulo, v_prestamo.numero_prestamo),
        p_observacion           => 'Renovación del préstamo ' || COALESCE(v_prestamo.numero_prestamo, p_id_prestamo::text),
        p_id_estado             => v_id_estado_prestamo_activo,
        p_id_comprobante_venta  => COALESCE(p_id_comprobante_venta_nuevo, v_prestamo.id_comprobante_venta),
        p_id_usuario_auditoria  => p_id_usuario
    );
    PERFORM ven_raise_si_error(v_result);
    v_id_prestamo_nuevo := (v_result->'registro'->>'id')::INTEGER;

    IF v_id_prestamo_nuevo IS NULL THEN
        RAISE EXCEPTION 'No se pudo crear el préstamo de renovación';
    END IF;

    UPDATE bal_prestamo
    SET id_prestamo_origen = p_id_prestamo
    WHERE id = v_id_prestamo_nuevo;

    -- 3. Detalle ENTREGADO del préstamo nuevo — balón nuevo (canje) o el mismo
    -- (extensión). bal_prestamo_aplicar_salida_cilindro ya tolera un balón que
    -- sigue PRESTADO_CLIENTE (no exige que esté DISPONIBLE), así que funciona
    -- igual en los dos casos.
    v_result := bal_crear_prestamo_detalle(
        p_id_prestamo            => v_id_prestamo_nuevo,
        p_id_balon               => COALESCE(v_id_balon_swap, v_detalle_entregado.id_balon),
        p_id_producto            => v_detalle_entregado.id_producto,
        p_fecha_entregado        => CURRENT_DATE,
        p_fecha_prestamo         => CURRENT_DATE,
        p_fecha_vencimiento      => v_fecha_retorno,
        p_observacion            => CASE
            WHEN v_id_balon_swap IS NOT NULL THEN 'Cilindro de reemplazo por renovación'
            ELSE 'Mismo cilindro, préstamo renovado'
        END,
        p_id_usuario_auditoria   => p_id_usuario,
        p_rol                    => 'ENTREGADO'
    );
    PERFORM ven_raise_si_error(v_result);
    v_id_detalle_entregado_nuevo := (v_result->'registro'->>'id')::INTEGER;

    -- 4. Garantía del préstamo anterior — por defecto se reutiliza (dinero y/o
    -- cilindro), sin tocar su custodia. Si p_mantener_garantia es false, se deja
    -- tal cual en el préstamo anterior (ya cerrado) y el llamador es responsable
    -- de registrar una garantía nueva para el préstamo nuevo si corresponde.
    --
    -- Reutilizar no es re-apuntar el registro: igual que con el préstamo, la
    -- garantía del anterior se cierra y se abre otra en el nuevo, encadenada.
    -- Con el UPDATE anterior el préstamo cerrado se quedaba sin rastro de la
    -- garantía que sí tuvo, y no había forma de saber desde cuándo respalda al
    -- cilindro que está en la calle hoy.
    IF p_mantener_garantia THEN
        -- 4.a Cilindro que el cliente dejó en custodia (rol GARANTIA).
        IF v_id_detalle_garantia IS NOT NULL THEN
            SELECT pd.* INTO v_detalle_garantia
            FROM bal_prestamo_detalle pd
            WHERE pd.id = v_id_detalle_garantia;

            SELECT lo.id INTO v_id_estado_detalle_transferido
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoPrestamoDetalle' AND lo.nombre = 'DEVUELTO' AND lo.estado = 1
            LIMIT 1;

            -- Cierre administrativo: el cilindro no se mueve de la empresa, solo
            -- deja de colgar del préstamo viejo. Por eso no pasa por
            -- bal_devolver_prestamo_detalle, que lo devolvería al cliente.
            UPDATE bal_prestamo_detalle
            SET fecha_devolucion = CURRENT_DATE,
                id_estado = v_id_estado_detalle_transferido,
                observacion = TRIM(COALESCE(observacion || ' — ', '')
                    || 'Garantía trasladada a la renovación'),
                id_usuario_modificacion = p_id_usuario,
                fecha_modificacion = NOW()
            WHERE id = v_id_detalle_garantia;

            v_result := bal_crear_prestamo_detalle(
                p_id_prestamo            => v_id_prestamo_nuevo,
                p_id_balon               => v_detalle_garantia.id_balon,
                p_id_producto            => v_detalle_garantia.id_producto,
                p_fecha_entregado        => COALESCE(v_detalle_garantia.fecha_entregado, CURRENT_DATE),
                p_fecha_prestamo         => CURRENT_DATE,
                p_fecha_vencimiento      => v_fecha_retorno,
                p_observacion            => 'Garantía que viene del préstamo '
                    || COALESCE(v_prestamo.numero_prestamo, p_id_prestamo::TEXT),
                p_id_usuario_auditoria   => p_id_usuario,
                p_rol                    => 'GARANTIA'
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        -- 4.b Garantía en dinero: cada saldo vivo se cierra y se reabre en el
        -- préstamo nuevo, ligado al detalle del cilindro que respalda. No hay
        -- movimiento de caja: el dinero ya está en la empresa.
        FOR v_garantia IN
            SELECT g.id
            FROM ven_garantia g
            WHERE g.id_prestamo = p_id_prestamo
              AND g.estado = 1
              AND COALESCE(g.monto_saldo, 0) > 0
            ORDER BY g.id
        LOOP
            v_result := ven_transferir_garantia_prestamo(
                p_id_garantia          => v_garantia.id,
                p_id_prestamo_destino  => v_id_prestamo_nuevo,
                p_id_prestamo_detalle  => v_id_detalle_entregado_nuevo,
                p_id_usuario_auditoria => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END LOOP;
    END IF;

    -- 5. Cierra el préstamo anterior (ya no le queda detalle pendiente).
    PERFORM bal_prestamo_cerrar_si_completo(
        p_id_prestamo          => p_id_prestamo,
        p_id_usuario_auditoria => p_id_usuario
    );

    RETURN bal_obtener_prestamo(v_id_prestamo_nuevo);
END;
$function$;
