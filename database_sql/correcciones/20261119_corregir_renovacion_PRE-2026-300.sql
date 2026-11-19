-- Corrección de datos: renovación PRE-2026-300 (VSD01-00000234, cliente id 212 SIGIFREDO HIDELGARDO HONORIO CORDOVA).
-- Qué pasó: bal_renovar_prestamo, sin cilindro elegido, cambió solo el cilindro.
--   * 9762 (id 400) quedó DEVUELTO y DISPONIBLE en almacén 2, pero el cliente lo tiene.
--   * 2601001020 (id 684) quedó PRESTADO_CLIENTE al cliente 212, pero está en el almacén.
--   * Se generaron los movimientos 1938 (ENTRADA_DEVOLUCION del 9762) y 1939 (SALIDA_PRESTAMO del 2601001020).
-- Qué hace: deja el préstamo PRE-2026-300 con el 9762, devuelve el 2601001020 al almacén 2 y
-- anula los dos movimientos que no ocurrieron físicamente.
-- Seguro: verifica que todo siga EXACTAMENTE como se encontró; si algo cambió, aborta sin tocar nada.
BEGIN;

DO $$
DECLARE
    v_disponible INTEGER;
    v_prestado INTEGER;
BEGIN
    SELECT lo.id INTO v_disponible FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1 LIMIT 1;
    SELECT lo.id INTO v_prestado FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'PRESTADO_CLIENTE' AND lo.estado = 1 LIMIT 1;

    -- ── Verificaciones: el estado actual debe ser el que se diagnosticó ──
    IF NOT EXISTS (SELECT 1 FROM bal_prestamo_detalle WHERE id = 300 AND id_prestamo = 316 AND id_balon = 684
                   AND rol = 'ENTREGADO' AND estado = 1 AND fecha_devolucion IS NULL) THEN
        RAISE EXCEPTION 'ABORTA: el detalle 300 ya no es el 2601001020 activo en PRE-2026-300';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = 400 AND codigo_balon = '9762' AND estado = 1
                   AND id_estado_balon = v_disponible AND id_almacen = 2) THEN
        RAISE EXCEPTION 'ABORTA: el 9762 ya no está DISPONIBLE en el almacén 2 (¿se movió o se prestó?)';
    END IF;
    IF EXISTS (SELECT 1 FROM bal_prestamo_detalle pd JOIN bal_prestamo p ON p.id = pd.id_prestamo AND p.estado = 1
               WHERE pd.id_balon = 400 AND pd.estado = 1 AND pd.fecha_devolucion IS NULL) THEN
        RAISE EXCEPTION 'ABORTA: el 9762 ya está en otro préstamo activo';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM bal_balon WHERE id = 684 AND codigo_balon = '2601001020' AND estado = 1
                   AND id_estado_balon = v_prestado AND id_cliente_ubicacion = 212 AND id_almacen IS NULL) THEN
        RAISE EXCEPTION 'ABORTA: el 2601001020 ya no figura prestado al cliente 212';
    END IF;
    IF (SELECT count(*) FROM inv_movimiento WHERE id IN (1938, 1939) AND estado = 1) <> 2 THEN
        RAISE EXCEPTION 'ABORTA: los movimientos 1938/1939 ya no están vigentes';
    END IF;
    IF EXISTS (SELECT 1 FROM inv_movimiento WHERE id_balon IN (400, 684) AND estado = 1 AND id > 1939) THEN
        RAISE EXCEPTION 'ABORTA: hay movimientos posteriores de estos cilindros; revisar a mano';
    END IF;

    -- ── Corrección ──
    UPDATE bal_prestamo_detalle
    SET id_balon = 400,
        observacion = 'Mismo cilindro, préstamo renovado (corregido 19/11: se había asignado por error el 2601001020)',
        fecha_modificacion = NOW()
    WHERE id = 300;

    UPDATE bal_prestamo_detalle
    SET observacion = REPLACE(observacion, 'Renovado — cilindro reemplazado',
                              'Renovado sin cambio de cilindro (corregido 19/11)'),
        fecha_modificacion = NOW()
    WHERE id = 243;

    UPDATE bal_balon
    SET id_estado_balon = v_prestado, id_almacen = NULL, id_cliente_ubicacion = 212, fecha_modificacion = NOW()
    WHERE id = 400;

    UPDATE bal_balon
    SET id_estado_balon = v_disponible, id_almacen = 2, id_cliente_ubicacion = NULL, fecha_modificacion = NOW()
    WHERE id = 684;

    UPDATE inv_movimiento
    SET estado = 0,
        glosa = LEFT(COALESCE(glosa, '') || ' | ANULADO 19/11: la renovación PRE-2026-300 fue con el mismo cilindro', 300),
        fecha_modificacion = NOW()
    WHERE id IN (1938, 1939);

    RAISE NOTICE 'Corrección aplicada: PRE-2026-300 con 9762; 2601001020 disponible en almacén 2; movimientos 1938/1939 anulados';
END $$;

COMMIT;
