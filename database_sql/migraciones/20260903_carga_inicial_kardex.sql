-- Respalda con kardex los saldos de pro_stock que existían antes de Fase 1.
--
-- Situación: inv_movimiento estaba vacío mientras pro_stock tenía 17 filas con saldo
-- (seeds y/o pro_crear_stock, que insertaba la cantidad directo). El criterio de
-- aceptación de F1 —"el saldo cuadra con la suma de inv_movimiento"— no se cumplía.
--
-- Método: NO se insertan movimientos a mano. Cada fila se pone en 0 y la cantidad
-- original se vuelve a aplicar con inv_registrar_movimiento (AJUSTE), que es el único
-- punto de escritura de pro_stock. Saldo final idéntico, ahora con kardex detrás.
--
-- Idempotente: solo toca filas cuyo saldo no está respaldado por movimientos.

BEGIN;

DO $$
DECLARE
    r RECORD;
    v_delta_kardex NUMERIC;
    v_original NUMERIC;
    v_mov JSON;
    v_n INTEGER := 0;
BEGIN
    FOR r IN
        SELECT s.id, s.id_producto, s.id_almacen, s.stock, p.nombre AS producto
        FROM pro_stock s
        JOIN pro_producto p ON p.id = s.id_producto
        WHERE s.estado = 1 AND s.stock <> 0
        ORDER BY s.id
    LOOP
        -- Movimiento neto ya registrado para ese producto/almacén.
        SELECT COALESCE(SUM(
                   CASE WHEN m.stock_nuevo IS NOT NULL AND m.stock_anterior IS NOT NULL
                        THEN m.stock_nuevo - m.stock_anterior ELSE 0 END), 0)
        INTO v_delta_kardex
        FROM inv_movimiento m
        WHERE m.estado = 1
          AND m.id_producto = r.id_producto
          AND COALESCE(m.id_almacen_origen, m.id_almacen_destino) = r.id_almacen;

        CONTINUE WHEN ROUND(r.stock - v_delta_kardex, 4) = 0;

        v_original := r.stock;

        -- Se parte del saldo ya respaldado por el kardex y se aplica la diferencia
        -- como AJUSTE, de modo que el saldo final no cambia.
        UPDATE pro_stock
        SET stock = v_delta_kardex, fecha_modificacion = NOW()
        WHERE id = r.id;

        v_mov := inv_registrar_movimiento(
            p_naturaleza             => 'PRODUCTO',
            p_codigo_tipo_movimiento => 'AJUSTE',
            p_id_producto            => r.id_producto,
            p_cantidad               => ABS(v_original - v_delta_kardex),
            p_id_almacen_origen      => r.id_almacen,
            p_glosa                  => 'Carga inicial de stock (regularización Fase 1)',
            p_sentido_ajuste         => CASE WHEN v_original - v_delta_kardex > 0 THEN 'MAS' ELSE 'MENOS' END
        );

        IF v_mov->>'error' IS NOT NULL THEN
            RAISE EXCEPTION 'Regularizando % (stock %): %', r.producto, v_original, v_mov->>'error';
        END IF;

        v_n := v_n + 1;
    END LOOP;

    RAISE NOTICE 'Filas de stock regularizadas: %', v_n;
END $$;

COMMIT;
