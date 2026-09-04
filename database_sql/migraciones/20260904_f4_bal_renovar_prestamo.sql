-- ⚠️ NO EJECUTAR sin revisión — dejar aplicado a mano con apply-migration.js cuando el usuario lo confirme.
-- Aplicar DESPUÉS de las migraciones de Fase 4 ya aplicadas (esquema id_prestamo_origen/
-- rol, bal_crear_prestamo_detalle con p_rol).
--
-- Fase 4 (apunte 1.c.ix) — nueva función bal_renovar_prestamo. Ver comentario propio
-- del archivo para el diseño completo (canje con balón disponible vs extensión sin
-- canje, y por qué bal_prestamo_aplicar_salida_cilindro ya tolera ambos casos sin
-- cambios).

-- Function: bal_renovar_prestamo
-- Fase 4 (apunte 1.c.ix) — cliente que ya tiene un préstamo vigente (dejó su
-- balón en garantía o no) y pide una nueva recarga:
--   - Si hay un balón EN_ALMACEN de las mismas características (mismo
--     id_tipo_balon + id_producto_gas) disponible → se entrega ese balón
--     nuevo, se cierra (devuelve) el detalle ENTREGADO del préstamo anterior,
--     y se abre un préstamo nuevo encadenado (id_prestamo_origen) con el
--     balón nuevo como ENTREGADO.
--   - Si no hay disponible → se abre igual un préstamo nuevo encadenado, pero
--     reutilizando el MISMO balón como ENTREGADO (extensión: el cilindro
--     nunca cambia de custodia, sigue con el cliente).
-- En ambos casos, si el préstamo anterior tenía un detalle GARANTIA (cilindro
-- que el cliente dejó como colateral, ver 20260904_f4_ven_aplicar_efectos_pos_garantia_balon.sql),
-- se re-enlaza al préstamo nuevo sin tocar su custodia (sigue en Sarita).
-- El préstamo anterior queda CERRADO al final.
--
-- p_id_balon_nuevo es opcional: si el cajero ya vio en el POS qué balón usar,
-- se lo pasa; si no, la función busca uno por su cuenta.

DROP FUNCTION IF EXISTS bal_renovar_prestamo(p_id_prestamo integer, p_id_balon_nuevo integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION bal_renovar_prestamo(p_id_prestamo integer, p_id_balon_nuevo integer DEFAULT NULL::integer, p_id_usuario integer DEFAULT NULL::integer)
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
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT p.*
    INTO v_prestamo
    FROM bal_prestamo p
    WHERE p.id = p_id_prestamo AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
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
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
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
        v_id_balon_swap := p_id_balon_nuevo;
    ELSE
        SELECT lo.id INTO v_id_estado_en_almacen
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON lo.id_lista = l.id
        WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_ALMACEN' AND lo.estado = 1
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
        p_titulo                => 'Renovación · ' || COALESCE(v_prestamo.titulo, v_prestamo.numero_prestamo),
        p_observacion           => 'Renovación del préstamo ' || COALESCE(v_prestamo.numero_prestamo, p_id_prestamo::text),
        p_id_estado             => v_id_estado_prestamo_activo,
        p_id_comprobante_venta  => v_prestamo.id_comprobante_venta,
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
    -- sigue PRESTADO_CLIENTE (no exige que esté EN_ALMACEN), así que funciona
    -- igual en los dos casos.
    v_result := bal_crear_prestamo_detalle(
        p_id_prestamo            => v_id_prestamo_nuevo,
        p_id_balon               => COALESCE(v_id_balon_swap, v_detalle_entregado.id_balon),
        p_id_producto            => v_detalle_entregado.id_producto,
        p_fecha_entregado        => CURRENT_DATE,
        p_fecha_prestamo         => CURRENT_DATE,
        p_observacion            => CASE
            WHEN v_id_balon_swap IS NOT NULL THEN 'Cilindro de reemplazo por renovación'
            ELSE 'Mismo cilindro, préstamo renovado'
        END,
        p_id_usuario_auditoria   => p_id_usuario,
        p_rol                    => 'ENTREGADO'
    );
    PERFORM ven_raise_si_error(v_result);

    -- 4. El cilindro de garantía (si hay) se re-enlaza al préstamo nuevo — no
    -- se mueve físicamente, sigue en custodia de Sarita.
    IF v_id_detalle_garantia IS NOT NULL THEN
        UPDATE bal_prestamo_detalle
        SET id_prestamo = v_id_prestamo_nuevo,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE id = v_id_detalle_garantia;
    END IF;

    -- 5. Cierra el préstamo anterior (ya no le queda detalle pendiente).
    PERFORM bal_prestamo_cerrar_si_completo(
        p_id_prestamo          => p_id_prestamo,
        p_id_usuario_auditoria => p_id_usuario
    );

    RETURN bal_obtener_prestamo(v_id_prestamo_nuevo);
END;
$function$;
