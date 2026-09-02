-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_actualizar_producto
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.768Z
DROP FUNCTION IF EXISTS pro_actualizar_producto(p_id integer, p_codigo character varying, p_codigo_barra character varying, p_nombre character varying, p_id_sub_categoria integer, p_id_unidad_medida integer, p_marca character varying, p_presentacion character varying, p_es_gas boolean, p_es_servicio boolean, p_es_alquilable boolean, p_afecta_stock boolean, p_precio numeric, p_codigo_ubicacion character varying, p_id_usuario_auditoria integer, p_precio_compra numeric, p_precio_garantia numeric, p_factor_kg_m3 numeric, p_factor_lb_m3 numeric, p_es_mantenimiento boolean);
DROP FUNCTION IF EXISTS pro_actualizar_producto(p_id integer, p_codigo character varying, p_codigo_barra character varying, p_nombre character varying, p_id_sub_categoria integer, p_id_unidad_medida integer, p_marca character varying, p_presentacion character varying, p_es_gas boolean, p_es_servicio boolean, p_es_alquilable boolean, p_afecta_stock boolean, p_precio numeric, p_codigo_ubicacion character varying, p_id_usuario_auditoria integer, p_precio_compra numeric, p_precio_garantia numeric, p_factor_kg_m3 numeric, p_factor_lb_m3 numeric, p_es_mantenimiento boolean, p_convertir_stock boolean);

CREATE OR REPLACE FUNCTION pro_actualizar_producto(p_id integer, p_codigo character varying DEFAULT NULL::character varying, p_codigo_barra character varying DEFAULT NULL::character varying, p_nombre character varying DEFAULT NULL::character varying, p_id_sub_categoria integer DEFAULT NULL::integer, p_id_unidad_medida integer DEFAULT NULL::integer, p_marca character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_es_gas boolean DEFAULT NULL::boolean, p_es_servicio boolean DEFAULT NULL::boolean, p_es_alquilable boolean DEFAULT NULL::boolean, p_afecta_stock boolean DEFAULT NULL::boolean, p_precio numeric DEFAULT NULL::numeric, p_codigo_ubicacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_precio_compra numeric DEFAULT NULL::numeric, p_precio_garantia numeric DEFAULT NULL::numeric, p_factor_kg_m3 numeric DEFAULT NULL::numeric, p_factor_lb_m3 numeric DEFAULT NULL::numeric, p_es_mantenimiento boolean DEFAULT NULL::boolean, p_convertir_stock boolean DEFAULT false)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_codigo VARCHAR;
    v_nombre VARCHAR;
    v_codigo_ubicacion VARCHAR;
    v_es_alquilable BOOLEAN;
    -- Cambio de unidad de medida (decisión 3 del plan).
    v_unidad_anterior INTEGER;
    v_nombre_unidad_anterior VARCHAR;
    v_nombre_unidad_nueva VARCHAR;
    v_cambia_unidad BOOLEAN := FALSE;
    v_stock_total NUMERIC := 0;
    v_almacenes_con_stock INTEGER := 0;
    v_tiene_movimientos BOOLEAN := FALSE;
    v_es_gas_final BOOLEAN;
    v_nombre_producto VARCHAR;
    v_stock RECORD;
    v_tipo RECORD;
    v_convertido NUMERIC;
    v_delta NUMERIC;
    v_mov JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_codigo := NULLIF(TRIM(p_codigo), '');
    v_nombre := NULLIF(TRIM(p_nombre), '');
    v_codigo_ubicacion := CASE
        WHEN p_codigo_ubicacion IS NULL THEN NULL
        ELSE NULLIF(TRIM(p_codigo_ubicacion), '')
    END;

    IF v_codigo IS NOT NULL AND EXISTS (
        SELECT 1 FROM pro_producto
        WHERE LOWER(TRIM(codigo)) = LOWER(v_codigo)
          AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro producto con el código ' || v_codigo, 'registro', NULL);
    END IF;

    IF p_codigo_ubicacion IS NOT NULL
       AND v_codigo_ubicacion IS NOT NULL
       AND EXISTS (
           SELECT 1 FROM pro_producto
           WHERE LOWER(TRIM(codigo_ubicacion)) = LOWER(v_codigo_ubicacion)
             AND id <> p_id
       ) THEN
        RETURN json_build_object(
            'error', 'Ya existe otro producto con el código de ubicación ' || v_codigo_ubicacion,
            'registro', NULL
        );
    END IF;

    IF p_id_sub_categoria IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_sub_categoria WHERE id = p_id_sub_categoria AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La subcategoría indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_id_unidad_medida IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_unidad_medida AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La unidad de medida indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_factor_kg_m3 IS NOT NULL AND p_factor_kg_m3 <= 0 THEN
        RETURN json_build_object('error', 'El factor kg→m³ debe ser mayor a 0', 'registro', NULL);
    END IF;

    IF p_factor_lb_m3 IS NOT NULL AND p_factor_lb_m3 <= 0 THEN
        RETURN json_build_object('error', 'El factor lb→m³ debe ser mayor a 0', 'registro', NULL);
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- Cambio de unidad de medida (decisión 3 del plan).
    -- pro_stock NO guarda unidad: su saldo se lee siempre en la unidad ACTUAL del
    -- producto. Cambiarla sin más reinterpreta el saldo en silencio (12 KG pasarían
    -- a leerse como 12 MT3). Se bloquea salvo que se pida convertir explícitamente.
    -- ─────────────────────────────────────────────────────────────────────────
    SELECT id_unidad_medida, nombre INTO v_unidad_anterior, v_nombre_producto
    FROM pro_producto WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    v_cambia_unidad := p_id_unidad_medida IS NOT NULL
                       AND p_id_unidad_medida IS DISTINCT FROM v_unidad_anterior;

    IF v_cambia_unidad THEN
        SELECT COALESCE(SUM(s.stock), 0), COUNT(*) FILTER (WHERE s.stock <> 0)
        INTO v_stock_total, v_almacenes_con_stock
        FROM pro_stock s WHERE s.id_producto = p_id AND s.estado = 1;

        SELECT EXISTS (
            SELECT 1 FROM inv_movimiento WHERE id_producto = p_id AND estado = 1
        ) INTO v_tiene_movimientos;

        SELECT UPPER(TRIM(COALESCE(nombre, ''))) INTO v_nombre_unidad_anterior
        FROM gen_lista_opciones WHERE id = v_unidad_anterior;
        SELECT UPPER(TRIM(COALESCE(nombre, ''))) INTO v_nombre_unidad_nueva
        FROM gen_lista_opciones WHERE id = p_id_unidad_medida;

        IF (v_almacenes_con_stock > 0 OR v_tiene_movimientos)
           AND NOT COALESCE(p_convertir_stock, FALSE) THEN
            RETURN json_build_object(
                'error',
                format(
                    'No se puede cambiar la unidad de %s de %s a %s: el producto tiene %s en %s almacén(es)%s. '
                    || 'El saldo de stock se lee en la unidad del producto, así que el cambio lo reinterpretaría. '
                    || 'Confirma la conversión del saldo para continuar.',
                    COALESCE(v_nombre_producto, '#' || p_id),
                    COALESCE(NULLIF(v_nombre_unidad_anterior, ''), '(sin unidad)'),
                    COALESCE(NULLIF(v_nombre_unidad_nueva, ''), '(sin unidad)'),
                    gen_formato_cantidad(v_stock_total) || ' ' || COALESCE(NULLIF(v_nombre_unidad_anterior, ''), ''),
                    v_almacenes_con_stock,
                    CASE WHEN v_tiene_movimientos THEN ' y movimientos registrados' ELSE '' END
                ),
                'requiere_confirmacion', TRUE,
                'stock_total', v_stock_total,
                'almacenes_con_stock', v_almacenes_con_stock,
                'unidad_actual', v_nombre_unidad_anterior,
                'unidad_nueva', v_nombre_unidad_nueva,
                'registro', NULL
            );
        END IF;
    END IF;

    SELECT COALESCE(p_es_alquilable, es_alquilable)
    INTO v_es_alquilable
    FROM pro_producto
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    UPDATE pro_producto
    SET
        codigo = COALESCE(v_codigo, codigo),
        codigo_barra = COALESCE(p_codigo_barra, codigo_barra),
        codigo_ubicacion = CASE
            WHEN p_codigo_ubicacion IS NULL THEN codigo_ubicacion
            ELSE v_codigo_ubicacion
        END,
        nombre = COALESCE(v_nombre, nombre),
        id_sub_categoria = COALESCE(p_id_sub_categoria, id_sub_categoria),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        marca = COALESCE(p_marca, marca),
        presentacion = COALESCE(p_presentacion, presentacion),
        es_gas = COALESCE(p_es_gas, es_gas),
        es_servicio = COALESCE(p_es_servicio, es_servicio),
        es_alquilable = v_es_alquilable,
        es_mantenimiento = CASE
            WHEN COALESCE(p_es_servicio, es_servicio)
                 AND NOT COALESCE(p_es_gas, es_gas)
                 AND NOT v_es_alquilable
            THEN COALESCE(p_es_mantenimiento, es_mantenimiento)
            ELSE FALSE
        END,
        -- Desde la Fase 1 el gas ES un producto con stock (pro_stock). Antes se
        -- forzaba FALSE aquí, lo que apagaba el control de stock de un gas en cuanto
        -- se editaba cualquier campo suyo. Solo los servicios quedan sin stock.
        afecta_stock = CASE
            WHEN COALESCE(p_es_servicio, es_servicio) THEN FALSE
            WHEN COALESCE(p_es_gas, es_gas) THEN TRUE
            ELSE COALESCE(p_afecta_stock, afecta_stock)
        END,
        precio = COALESCE(p_precio, precio),
        precio_compra = COALESCE(p_precio_compra, precio_compra),
        precio_garantia = COALESCE(p_precio_garantia, precio_garantia),
        factor_kg_m3 = CASE
            WHEN COALESCE(p_es_gas, es_gas) THEN COALESCE(p_factor_kg_m3, factor_kg_m3)
            ELSE NULL
        END,
        factor_lb_m3 = CASE
            WHEN COALESCE(p_es_gas, es_gas) THEN COALESCE(p_factor_lb_m3, factor_lb_m3)
            ELSE NULL
        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    PERFORM pro_asegurar_stock_producto(p_id, p_id_usuario_auditoria);

    SELECT COALESCE(es_gas, FALSE) INTO v_es_gas_final FROM pro_producto WHERE id = p_id;

    -- ─────────────────────────────────────────────────────────────────────────
    -- Conversión del saldo tras cambiar la unidad (confirmada con p_convertir_stock).
    -- El saldo NO se toca a mano: se calcula el delta y se aplica con
    -- inv_registrar_movimiento, que sigue siendo el único punto de escritura de
    -- pro_stock y deja el ajuste visible en el kardex.
    -- ─────────────────────────────────────────────────────────────────────────
    IF v_cambia_unidad AND COALESCE(p_convertir_stock, FALSE) THEN
        FOR v_stock IN
            SELECT s.id_almacen, s.stock
            FROM pro_stock s
            WHERE s.id_producto = p_id AND s.estado = 1 AND s.stock <> 0
        LOOP
            -- La unidad del producto ya es la nueva, así que convertir "desde la
            -- unidad anterior" devuelve el saldo expresado en la nueva.
            v_convertido := inv_convertir_a_unidad_producto(p_id, v_stock.stock, v_unidad_anterior);
            v_delta := ROUND(COALESCE(v_convertido, v_stock.stock) - v_stock.stock, 4);

            IF v_delta <> 0 THEN
                v_mov := inv_registrar_movimiento(
                    p_naturaleza             => 'PRODUCTO',
                    p_codigo_tipo_movimiento => 'AJUSTE',
                    p_id_producto            => p_id,
                    p_cantidad               => ABS(v_delta),
                    p_id_almacen_origen      => v_stock.id_almacen,
                    p_glosa                  => format(
                        'Conversión de unidad %s → %s (%s %s = %s %s)',
                        COALESCE(NULLIF(v_nombre_unidad_anterior, ''), '?'),
                        COALESCE(NULLIF(v_nombre_unidad_nueva, ''), '?'),
                        gen_formato_cantidad(v_stock.stock),
                        COALESCE(NULLIF(v_nombre_unidad_anterior, ''), ''),
                        gen_formato_cantidad(v_convertido),
                        COALESCE(NULLIF(v_nombre_unidad_nueva, ''), '')
                    ),
                    p_id_usuario_auditoria   => p_id_usuario_auditoria,
                    p_sentido_ajuste         => CASE WHEN v_delta > 0 THEN 'MAS' ELSE 'MENOS' END
                );

                IF v_mov->>'error' IS NOT NULL THEN
                    RAISE EXCEPTION '%', v_mov->>'error';
                END IF;
            END IF;
        END LOOP;
    END IF;

    -- ─────────────────────────────────────────────────────────────────────────
    -- Un gas con tipos de balón catalogados en otra unidad NO puede quedarse sin
    -- factor de conversión: las recargas fallarían después, lejos de la causa.
    -- Se revalida reutilizando la misma conversión que usa el flujo real.
    -- ─────────────────────────────────────────────────────────────────────────
    IF v_es_gas_final THEN
        FOR v_tipo IN
            SELECT tb.id, tb.nombre, tb.capacidad, tb.id_unidad_medida
            FROM bal_tipo_balon tb
            WHERE tb.id_gas = p_id
              AND tb.estado = 1
              AND tb.id_unidad_medida IS DISTINCT FROM (
                  SELECT id_unidad_medida FROM pro_producto WHERE id = p_id
              )
        LOOP
            BEGIN
                PERFORM inv_convertir_a_unidad_producto(
                    p_id, COALESCE(NULLIF(v_tipo.capacidad, 0), 1), v_tipo.id_unidad_medida
                );
            EXCEPTION WHEN OTHERS THEN
                RAISE EXCEPTION
                    'El tipo de balón "%" usa otra unidad que este gas y la conversión no es posible: %. '
                    'Configura el factor correspondiente antes de guardar.',
                    v_tipo.nombre, SQLERRM;
            END;
        END LOOP;
    END IF;

    RETURN pro_obtener_producto(p_id);
END;
$function$
