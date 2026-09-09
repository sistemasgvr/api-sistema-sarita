-- Renovación de préstamo: fecha de retorno pactada y traspaso de la garantía.
--
-- 1) La fecha de retorno que se pacta en el POS se perdía al renovar. El préstamo
--    de renovación nace con la fecha (y el detalle del cilindro con su
--    vencimiento), igual que un préstamo nuevo.
--
-- 2) La garantía dejaba de existir para el préstamo cerrado: se re-apuntaba con
--    un UPDATE al préstamo nuevo. Ahora se cierra y se abre otra encadenada —
--    el mismo patrón que ya usa el préstamo — apuntando al detalle del cilindro
--    entregado. Sin movimiento de caja: el dinero ya está en la empresa.
--
-- Aplicar con:
--   node database_sql/scripts/apply-migration.js database_sql/migraciones/20260909_prestamo_renovacion_fecha_y_garantia.sql

-- ---------------------------------------------------------------------------
-- 1. Catálogos
-- ---------------------------------------------------------------------------

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, 'TRANSFERIDA', 'Garantía cerrada porque su saldo pasó al préstamo que renueva'
FROM gen_lista l
WHERE l.nombre = 'EstadoGarantia'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = 'TRANSFERIDA'
  );

INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion)
SELECT l.id, 'TRANSFERENCIA', 'Traspaso del saldo entre garantías por renovación (no mueve caja)'
FROM gen_lista l
WHERE l.nombre = 'TipoMovimientoGarantia'
  AND NOT EXISTS (
      SELECT 1 FROM gen_lista_opciones lo
      WHERE lo.id_lista = l.id AND lo.nombre = 'TRANSFERENCIA'
  );

-- ---------------------------------------------------------------------------
-- 2. Columnas de ven_garantia
-- ---------------------------------------------------------------------------

ALTER TABLE ven_garantia ADD COLUMN IF NOT EXISTS id_prestamo_detalle integer;
ALTER TABLE ven_garantia ADD COLUMN IF NOT EXISTS id_garantia_origen integer;
ALTER TABLE ven_garantia ADD COLUMN IF NOT EXISTS monto_transferido numeric(12,4) DEFAULT 0 NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ven_garantia_id_prestamo_detalle_fkey'
    ) THEN
        ALTER TABLE ven_garantia
            ADD CONSTRAINT ven_garantia_id_prestamo_detalle_fkey
            FOREIGN KEY (id_prestamo_detalle) REFERENCES bal_prestamo_detalle(id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ven_garantia_id_garantia_origen_fkey'
    ) THEN
        ALTER TABLE ven_garantia
            ADD CONSTRAINT ven_garantia_id_garantia_origen_fkey
            FOREIGN KEY (id_garantia_origen) REFERENCES ven_garantia(id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ven_garantia_origen
    ON ven_garantia USING btree (id_garantia_origen)
    WHERE (id_garantia_origen IS NOT NULL);


-- ---------------------------------------------------------------------------
-- 3. ven_transferir_garantia_prestamo (nueva)
-- ---------------------------------------------------------------------------

-- Function: ven_transferir_garantia_prestamo
-- Creada por database_sql/migraciones/20260909_prestamo_renovacion_fecha_y_garantia.sql
--
-- Pasa una garantía viva del préstamo que se renueva al préstamo nuevo. No hay
-- movimiento de dinero: el cliente no vuelve a pagar ni se le devuelve nada, así
-- que el saldo sale de la garantía origen (que queda TRANSFERIDA) y entra en una
-- garantía nueva, encadenada por id_garantia_origen y apuntando al detalle del
-- cilindro que respalda.
--
-- Es el mismo patrón que usa bal_renovar_prestamo con el préstamo: cerrar y
-- abrir encadenado, en vez de re-apuntar el registro anterior. Así cada préstamo
-- conserva la garantía que tuvo y la cadena queda auditable.
--
-- Los movimientos se registran con TipoMovimientoGarantia.TRANSFERENCIA, que
-- fin_caja_calcular_totales no suma (solo mira COBRO y DEVOLUCION), para que un
-- traspaso interno no aparezca como dinero entrando o saliendo de caja.

DROP FUNCTION IF EXISTS ven_transferir_garantia_prestamo(integer, integer, integer, integer);

CREATE OR REPLACE FUNCTION ven_transferir_garantia_prestamo(p_id_garantia integer, p_id_prestamo_destino integer, p_id_prestamo_detalle integer DEFAULT NULL::integer, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_garantia RECORD;
    v_id_estado_transferida INTEGER;
    v_id_estado_activa INTEGER;
    v_id_tipo_transferencia INTEGER;
    v_id_sucursal INTEGER;
    v_monto NUMERIC(12,4);
    v_id_nueva INTEGER;
    v_numero_prestamo VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_garantia IS NULL OR p_id_prestamo_destino IS NULL THEN
        RETURN json_build_object(
            'error', 'La garantía y el préstamo destino son obligatorios',
            'registro', NULL
        );
    END IF;

    SELECT g.* INTO v_garantia
    FROM ven_garantia g
    WHERE g.id = p_id_garantia AND g.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'La garantía indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    v_monto := COALESCE(v_garantia.monto_saldo, 0);

    IF v_monto <= 0 THEN
        RETURN json_build_object(
            'error', 'La garantía no tiene saldo por transferir',
            'registro', NULL
        );
    END IF;

    SELECT p.numero_prestamo, a.id_sucursal
    INTO v_numero_prestamo, v_id_sucursal
    FROM bal_prestamo p
    LEFT JOIN gen_almacen a ON a.id = p.id_almacen
    WHERE p.id = p_id_prestamo_destino AND p.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object(
            'error', 'El préstamo destino no existe o está inactivo',
            'registro', NULL
        );
    END IF;

    IF p_id_prestamo_detalle IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo_detalle pd
        WHERE pd.id = p_id_prestamo_detalle
          AND pd.id_prestamo = p_id_prestamo_destino
          AND pd.estado = 1
    ) THEN
        RETURN json_build_object(
            'error', 'El detalle indicado no pertenece al préstamo destino',
            'registro', NULL
        );
    END IF;

    SELECT lo.id INTO v_id_estado_transferida
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'TRANSFERIDA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_transferida IS NULL THEN
        RETURN json_build_object('error', 'Falta opción EstadoGarantia.TRANSFERIDA en catálogo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_activa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'ACTIVA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_activa IS NULL THEN
        RETURN json_build_object('error', 'Falta opción EstadoGarantia.ACTIVA en catálogo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_transferencia
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'TRANSFERENCIA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_transferencia IS NULL THEN
        RETURN json_build_object('error', 'Falta opción TipoMovimientoGarantia.TRANSFERENCIA en catálogo', 'registro', NULL);
    END IF;

    -- 1. Cierra la garantía origen. El saldo no se devuelve: se marca como
    -- transferido, de modo que monto_saldo = cobrado - devuelto - transferido
    -- sigue cuadrando y los reportes de devoluciones no se contaminan.
    UPDATE ven_garantia
    SET monto_transferido = COALESCE(monto_transferido, 0) + v_monto,
        monto_saldo = 0,
        id_estado = v_id_estado_transferida,
        observacion = TRIM(COALESCE(observacion || ' — ', '')
            || 'Transferida al préstamo ' || COALESCE(v_numero_prestamo, p_id_prestamo_destino::TEXT)),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id_garantia;

    INSERT INTO ven_garantia_movimiento (
        id_garantia, id_tipo_movimiento, fecha, monto, observacion,
        id_sucursal, id_medio_pago, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        p_id_garantia,
        v_id_tipo_transferencia,
        CURRENT_DATE,
        -v_monto,
        'Salida por renovación del préstamo',
        COALESCE(v_id_sucursal, NULL),
        v_garantia.id_medio_pago,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    -- 2. Garantía nueva en el préstamo destino, con el mismo saldo y sin cobro.
    INSERT INTO ven_garantia (
        id_cliente,
        id_prestamo,
        id_prestamo_detalle,
        id_garantia_origen,
        id_alquiler,
        ubicacion,
        id_producto,
        cantidad_venta,
        id_unidad_medida,
        fecha_registro,
        monto_cobrado,
        monto_devuelto,
        monto_transferido,
        monto_saldo,
        id_estado,
        observacion,
        id_medio_pago,
        id_cuenta_bancaria,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_garantia.id_cliente,
        p_id_prestamo_destino,
        p_id_prestamo_detalle,
        p_id_garantia,
        NULL,
        v_garantia.ubicacion,
        v_garantia.id_producto,
        v_garantia.cantidad_venta,
        v_garantia.id_unidad_medida,
        CURRENT_DATE,
        v_monto,
        0,
        0,
        v_monto,
        v_id_estado_activa,
        'Garantía que viene del préstamo anterior (sin nuevo cobro)',
        v_garantia.id_medio_pago,
        v_garantia.id_cuenta_bancaria,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id_nueva;

    INSERT INTO ven_garantia_movimiento (
        id_garantia, id_tipo_movimiento, fecha, monto, observacion,
        id_sucursal, id_medio_pago, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_id_nueva,
        v_id_tipo_transferencia,
        CURRENT_DATE,
        v_monto,
        'Entrada por renovación del préstamo',
        COALESCE(v_id_sucursal, NULL),
        v_garantia.id_medio_pago,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(v_id_nueva);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. ven_crear_garantia — guarda el detalle del cilindro
-- ---------------------------------------------------------------------------

-- Function: ven_crear_garantia
-- Fase 3 (apunte 1.c.vi): la garantía de venta se liga a la cuenta bancaria de
-- la empresa cuando el medio de pago no es efectivo. La cuenta se guarda tanto
-- en la garantía como en su movimiento de COBRO, que es la fila que leen los
-- resúmenes de caja.
-- Actualizada por database_sql/migraciones/20260909_prestamo_renovacion_fecha_y_garantia.sql:
-- guarda el detalle del cilindro que respalda (id_prestamo_detalle).

DROP FUNCTION IF EXISTS ven_crear_garantia(p_id_cliente integer, p_monto numeric, p_id_comprobante integer, p_id_prestamo integer, p_id_producto integer, p_ubicacion character varying, p_cantidad_venta numeric, p_id_unidad_medida integer, p_fecha_registro date, p_observacion character varying, p_id_usuario_auditoria integer, p_id_alquiler integer, p_id_medio_pago integer);
DROP FUNCTION IF EXISTS ven_crear_garantia(p_id_cliente integer, p_monto numeric, p_id_comprobante integer, p_id_prestamo integer, p_id_producto integer, p_ubicacion character varying, p_cantidad_venta numeric, p_id_unidad_medida integer, p_fecha_registro date, p_observacion character varying, p_id_usuario_auditoria integer, p_id_alquiler integer, p_id_medio_pago integer, p_id_cuenta_bancaria integer, p_numero_operacion character varying);

CREATE OR REPLACE FUNCTION ven_crear_garantia(p_id_cliente integer, p_monto numeric, p_id_comprobante integer DEFAULT NULL::integer, p_id_prestamo integer DEFAULT NULL::integer, p_id_producto integer DEFAULT NULL::integer, p_ubicacion character varying DEFAULT NULL::character varying, p_cantidad_venta numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_fecha_registro date DEFAULT NULL::date, p_observacion character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer, p_id_alquiler integer DEFAULT NULL::integer, p_id_medio_pago integer DEFAULT NULL::integer, p_id_cuenta_bancaria integer DEFAULT NULL::integer, p_numero_operacion character varying DEFAULT NULL::character varying, p_id_prestamo_detalle integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_id_estado_activa INTEGER;
    v_id_tipo_cobro INTEGER;
    v_monto NUMERIC(12,4);
    v_fecha DATE;
    v_id_sucursal INTEGER;
    v_err_caja TEXT;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_cliente IS NULL THEN
        RETURN json_build_object('error', 'El cliente es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE id = p_id_cliente AND estado = 1) THEN
        RETURN json_build_object('error', 'El cliente indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_monto := ROUND(COALESCE(p_monto, 0)::NUMERIC, 4);
    IF v_monto <= 0 THEN
        RETURN json_build_object('error', 'El monto de garantía debe ser mayor a cero', 'registro', NULL);
    END IF;

    IF p_id_prestamo IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_prestamo WHERE id = p_id_prestamo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El préstamo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_alquiler IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_alquiler WHERE id = p_id_alquiler AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El alquiler indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_producto IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_comprobante IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM ven_comprobante WHERE id = p_id_comprobante AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El comprobante indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_medio_pago IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_medio_pago AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El método de pago indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    v_err_caja := fin_validar_cuenta_medio_pago(p_id_medio_pago, p_id_cuenta_bancaria);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_estado_activa
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoGarantia' AND lo.nombre = 'ACTIVA' AND lo.estado = 1
    LIMIT 1;

    IF v_id_estado_activa IS NULL THEN
        RETURN json_build_object('error', 'Falta opción EstadoGarantia.ACTIVA en catálogo', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_cobro
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoMovimientoGarantia' AND lo.nombre = 'COBRO' AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_cobro IS NULL THEN
        RETURN json_build_object('error', 'Falta opción TipoMovimientoGarantia.COBRO en catálogo', 'registro', NULL);
    END IF;

    v_fecha := COALESCE(p_fecha_registro, CURRENT_DATE);

    IF p_id_comprobante IS NOT NULL THEN
        SELECT c.id_sucursal INTO v_id_sucursal
        FROM ven_comprobante c
        WHERE c.id = p_id_comprobante AND c.estado = 1;
    END IF;

    IF v_id_sucursal IS NULL AND p_id_prestamo IS NOT NULL THEN
        SELECT a.id_sucursal INTO v_id_sucursal
        FROM bal_prestamo p
        INNER JOIN gen_almacen a ON a.id = p.id_almacen
        WHERE p.id = p_id_prestamo AND p.estado = 1;
    END IF;

    IF v_id_sucursal IS NULL AND p_id_alquiler IS NOT NULL THEN
        SELECT a.id_sucursal INTO v_id_sucursal
        FROM bal_alquiler al
        INNER JOIN gen_almacen a ON a.id = al.id_almacen
        WHERE al.id = p_id_alquiler AND al.estado = 1;
    END IF;

    v_err_caja := fin_caja_assert_abierta(v_fecha, v_id_sucursal);
    IF v_err_caja IS NOT NULL THEN
        RETURN json_build_object('error', v_err_caja, 'registro', NULL);
    END IF;

    INSERT INTO ven_garantia (
        id_cliente,
        id_prestamo,
        id_prestamo_detalle,
        id_alquiler,
        ubicacion,
        id_producto,
        cantidad_venta,
        id_unidad_medida,
        fecha_registro,
        monto_cobrado,
        monto_devuelto,
        monto_saldo,
        id_estado,
        observacion,
        id_medio_pago,
        id_cuenta_bancaria,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_cliente,
        p_id_prestamo,
        p_id_prestamo_detalle,
        p_id_alquiler,
        NULLIF(TRIM(COALESCE(p_ubicacion, '')), ''),
        p_id_producto,
        p_cantidad_venta,
        p_id_unidad_medida,
        v_fecha,
        v_monto,
        0,
        v_monto,
        v_id_estado_activa,
        NULLIF(TRIM(COALESCE(p_observacion, '')), ''),
        p_id_medio_pago,
        p_id_cuenta_bancaria,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    INSERT INTO ven_garantia_movimiento (
        id_garantia,
        id_tipo_movimiento,
        id_comprobante,
        fecha,
        monto,
        observacion,
        id_sucursal,
        id_medio_pago,
        id_cuenta_bancaria,
        numero_operacion,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        v_id,
        v_id_tipo_cobro,
        p_id_comprobante,
        v_fecha,
        v_monto,
        'Cobro inicial de garantía',
        v_id_sucursal,
        p_id_medio_pago,
        p_id_cuenta_bancaria,
        NULLIF(TRIM(COALESCE(p_numero_operacion, '')), ''),
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    );

    RETURN ven_obtener_garantia(v_id);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. ven_obtener_garantia — expone cadena y detalle
-- ---------------------------------------------------------------------------

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: ven_obtener_garantia
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.966Z
-- Actualizada por database_sql/migraciones/20260909_prestamo_renovacion_fecha_y_garantia.sql:
-- expone el detalle del cilindro que respalda, la garantía de la que viene y
-- el monto transferido a la renovación.

DROP FUNCTION IF EXISTS ven_obtener_garantia(p_id integer);

CREATE OR REPLACE FUNCTION ven_obtener_garantia(p_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            g.id,
            g.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), '')
            ) AS nombre_cliente,
            c.numero_documento AS documento_cliente,
            g.id_prestamo,
            g.id_prestamo_detalle,
            g.id_garantia_origen,
            pr.numero_prestamo,
            pr.titulo AS titulo_prestamo,
            g.id_alquiler,
            al.numero_alquiler,
            g.ubicacion,
            g.id_producto,
            p.codigo AS codigo_producto,
            p.nombre AS nombre_producto,
            p.precio_garantia AS precio_garantia_producto,
            g.cantidad_venta,
            g.id_unidad_medida,
            um.nombre AS nombre_unidad_medida,
            g.fecha_registro,
            g.monto_cobrado,
            g.monto_devuelto,
            g.monto_transferido,
            g.monto_saldo,
            g.id_estado,
            eg.nombre AS nombre_estado,
            g.observacion,
            g.id_medio_pago,
            mp.nombre AS medio_pago,
            g.id_cuenta_bancaria,
            COALESCE(cb.alias, cb.titular, cb.numero_cuenta) AS cuenta_bancaria,
            g.fecha_reembolso,
            g.id_medio_reembolso,
            mr.nombre AS medio_reembolso,
            g.id_cuenta_bancaria_reembolso,
            COALESCE(cbr.alias, cbr.titular, cbr.numero_cuenta) AS cuenta_bancaria_reembolso,
            g.observacion_reembolso,
            g.id_usuario_reembolso,
            g.estado,
            g.fecha_creacion,
            g.fecha_modificacion,
            CASE
                WHEN g.id_prestamo IS NOT NULL THEN 'PRESTAMO'
                WHEN g.id_alquiler IS NOT NULL THEN 'ALQUILER'
                WHEN EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                ) THEN 'POS'
                ELSE 'MANUAL'
            END AS origen,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS es_manual,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND COALESCE(g.monto_devuelto, 0) = 0
                AND g.fecha_reembolso IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS puede_editar,
            (
                g.id_prestamo IS NULL
                AND g.id_alquiler IS NULL
                AND NOT EXISTS (
                    SELECT 1
                    FROM ven_garantia_movimiento gm
                    WHERE gm.id_garantia = g.id
                      AND gm.estado = 1
                      AND gm.id_comprobante IS NOT NULL
                )
            ) AS puede_eliminar,
            (
                SELECT CASE
                    WHEN vc.id IS NULL THEN NULL
                    ELSE CONCAT_WS('-', vc.serie, vc.numero)
                END
                FROM ven_garantia_movimiento gm
                LEFT JOIN ven_comprobante vc ON vc.id = gm.id_comprobante
                WHERE gm.id_garantia = g.id
                  AND gm.estado = 1
                  AND gm.id_comprobante IS NOT NULL
                ORDER BY gm.fecha ASC, gm.id ASC
                LIMIT 1
            ) AS comprobante_cobro,
            g.id_usuario_creacion,
            uc.nombre AS nombre_usuario_creacion,
            g.id_usuario_modificacion,
            umod.nombre AS nombre_usuario_modificacion,
            (
                SELECT COALESCE(json_agg(row_to_json(m) ORDER BY m.fecha DESC, m.id DESC), '[]'::JSON)
                FROM (
                    SELECT
                        gm.id,
                        gm.id_garantia,
                        gm.id_tipo_movimiento,
                        tm.nombre AS nombre_tipo_movimiento,
                        gm.id_comprobante,
                        vc.serie AS serie_comprobante,
                        vc.numero AS numero_comprobante,
                        CASE
                            WHEN vc.id IS NULL THEN NULL
                            ELSE CONCAT_WS('-', vc.serie, vc.numero)
                        END AS comprobante,
                        gm.fecha,
                        gm.monto,
                        gm.observacion,
                        gm.fecha_creacion
                    FROM ven_garantia_movimiento gm
                    LEFT JOIN gen_lista_opciones tm ON gm.id_tipo_movimiento = tm.id
                    LEFT JOIN ven_comprobante vc ON gm.id_comprobante = vc.id
                    WHERE gm.id_garantia = g.id AND gm.estado = 1
                ) m
            ) AS movimientos
        FROM ven_garantia g
        LEFT JOIN cli_clientes c ON g.id_cliente = c.id
        LEFT JOIN bal_prestamo pr ON g.id_prestamo = pr.id
        LEFT JOIN bal_alquiler al ON g.id_alquiler = al.id
        LEFT JOIN pro_producto p ON g.id_producto = p.id
        LEFT JOIN gen_lista_opciones um ON g.id_unidad_medida = um.id
        LEFT JOIN gen_lista_opciones eg ON g.id_estado = eg.id
        LEFT JOIN gen_lista_opciones mp ON g.id_medio_pago = mp.id
        LEFT JOIN gen_lista_opciones mr ON g.id_medio_reembolso = mr.id
        LEFT JOIN gen_cuenta_bancaria cb  ON cb.id = g.id_cuenta_bancaria
        LEFT JOIN gen_cuenta_bancaria cbr ON cbr.id = g.id_cuenta_bancaria_reembolso
        LEFT JOIN auth_usuarios uc ON g.id_usuario_creacion = uc.id
        LEFT JOIN auth_usuarios umod ON g.id_usuario_modificacion = umod.id
        WHERE g.id = p_id AND g.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 6. bal_renovar_prestamo — fecha de retorno + traspaso de garantía
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- 7. ven_aplicar_efectos_pos — pasa la fecha y el detalle
-- ---------------------------------------------------------------------------

-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Actualizada por database_sql/migraciones/20260909_prestamo_renovacion_fecha_y_garantia.sql:
-- la renovación recibe la fecha de retorno pactada (antes se perdía) y la
-- garantía queda ligada al detalle del cilindro que respalda.

-- Function: ven_aplicar_efectos_pos
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.965Z
--
-- Actualizada por database_sql/migraciones/20260905_pos_garantia_cuenta_y_catalogos.sql:
-- la garantia (de prestamo y de alquiler) se crea con su cuenta bancaria y su
-- numero de operacion, que antes nunca llegaban a ven_crear_garantia.
DROP FUNCTION IF EXISTS ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer);

CREATE OR REPLACE FUNCTION ven_aplicar_efectos_pos(p_id_comprobante integer, p_efectos json, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id_cliente INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_item JSON;
    v_arr JSON;
    v_result JSON;
    v_id_prestamo INTEGER;
    v_id_alquiler INTEGER;
    v_id_baja INTEGER;
    v_garantia JSON;
    v_periodo JSON;
    v_id_producto INTEGER;
    v_id_prestamo_detalle INTEGER;
    v_arr_detalles JSONB := '[]'::JSONB;
    v_garantia_balon JSON;
    v_id_balon_garantia INTEGER;
    v_id_propietario_garantia INTEGER;
    v_vigencia_ph_garantia INTEGER;
    v_fecha_ultima_ph_garantia DATE;
    v_fecha_proxima_ph_garantia DATE;
    v_observacion_balon_garantia VARCHAR;
    v_mov_garantia JSON;
    v_id_estado_balon_almacen INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_id_comprobante IS NULL OR p_efectos IS NULL OR p_efectos::TEXT IN ('null', '{}', '[]') THEN
        RETURN;
    END IF;

    SELECT id_cliente, serie, numero
    INTO v_id_cliente, v_serie, v_numero
    FROM ven_comprobante
    WHERE id = p_id_comprobante AND estado = 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El comprobante no existe o está inactivo';
    END IF;

    -- Recargas mostrador
    v_arr := CASE WHEN json_typeof(p_efectos->'recargas') = 'array' THEN p_efectos->'recargas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_vincular_recarga_cliente_comprobante(
            p_id_comprobante,
            v_id_cliente,
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idProducto', '')::INTEGER,
            NULLIF(v_item->>'capacidad', '')::NUMERIC,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'idBalonOrigen', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Préstamos de cilindro (+ garantía opcional)
    v_arr := CASE WHEN json_typeof(p_efectos->'prestamos') = 'array' THEN p_efectos->'prestamos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        IF NULLIF(v_item->>'idPrestamoRenovar', '') IS NOT NULL THEN
            -- Fase 4 (apunte 1.c.ix): renovación — cierra el préstamo indicado
            -- (canjeando el cilindro si hay uno disponible, o extendiéndolo con
            -- el mismo) y abre uno nuevo encadenado, ligado a ESTA venta. Por
            -- defecto reutiliza la garantía (dinero y/o cilindro) del préstamo
            -- anterior; si mantenerGarantiaPrestamo es false, el bloque de
            -- garantia/garantiaBalon más abajo registra una nueva.
            v_result := bal_renovar_prestamo(
                p_id_prestamo                => (v_item->>'idPrestamoRenovar')::INTEGER,
                p_id_balon_nuevo             => NULLIF(v_item->>'idBalon', '')::INTEGER,
                p_id_usuario                 => p_id_usuario,
                p_id_comprobante_venta_nuevo => p_id_comprobante,
                p_mantener_garantia          => COALESCE((v_item->>'mantenerGarantiaPrestamo')::BOOLEAN, TRUE),
                p_fecha_retorno_pactada      => NULLIF(v_item->>'fechaRetornoPactada', '')::DATE
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo := (v_result->'registro'->>'id')::INTEGER;
            IF v_id_prestamo IS NULL THEN
                RAISE EXCEPTION 'No se pudo renovar el préstamo';
            END IF;

            SELECT pd.id INTO v_id_prestamo_detalle
            FROM bal_prestamo_detalle pd
            WHERE pd.id_prestamo = v_id_prestamo
              AND pd.rol = 'ENTREGADO'
              AND pd.estado = 1
            ORDER BY pd.id DESC
            LIMIT 1;
        ELSE
            v_result := bal_crear_prestamo(
                NULLIF(v_item->>'idTipoPrestamo', '')::INTEGER,
                NULL,
                v_id_cliente,
                NULL,
                NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                NULLIF(v_item->>'fechaSalida', '')::DATE,
                NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
                NULL,
                NULLIF(TRIM(COALESCE(v_item->>'titulo', '')), ''),
                NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
                NULLIF(v_item->>'idEstado', '')::INTEGER,
                p_id_comprobante,
                NULL,
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo := (v_result->'registro'->>'id')::INTEGER;
            IF v_id_prestamo IS NULL THEN
                RAISE EXCEPTION 'No se pudo crear el préstamo POS';
            END IF;

            v_result := bal_crear_prestamo_detalle(
                v_id_prestamo,
                NULLIF(v_item->>'idBalon', '')::INTEGER,
                NULLIF(v_item->>'idProducto', '')::INTEGER,
                NULL,
                NULLIF(COALESCE(v_item->>'fechaEntregado', v_item->>'fechaSalida'), '')::DATE,
                NULLIF(COALESCE(v_item->>'fechaPrestamo', v_item->>'fechaSalida'), '')::DATE,
                30,
                NULLIF(COALESCE(v_item->>'fechaVencimiento', v_item->>'fechaRetornoPactada'), '')::DATE,
                NULL, NULL, NULL, NULL, NULL,
                NULLIF(v_item->>'idEstadoDetalle', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_item->>'observacionDetalle', '')), ''),
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_prestamo_detalle := (v_result->'registro'->>'id')::INTEGER;
        END IF;

        -- Auto-recojo: el préstamo ya tiene fecha de retorno pactada, por lo que se
        -- programa el recojo sin pasar por la pantalla de programación manual.
        -- El cilindro se queda PRESTADO_CLIENTE hasta que el chófer inicia la ruta.
        IF v_id_prestamo_detalle IS NOT NULL
           AND NULLIF(v_item->>'idBalon', '') IS NOT NULL
           AND NULLIF(v_item->>'fechaRetornoPactada', '') IS NOT NULL
        THEN
            v_arr_detalles := jsonb_build_array(
                jsonb_build_object(
                    'idPrestamoDetalle', v_id_prestamo_detalle,
                    'observacion', 'Recojo automático generado al vender el préstamo'
                )
            );

            v_result := bal_crear_recojo(
                v_id_cliente,
                v_id_prestamo,
                NULL,
                NULL,
                NULLIF(v_item->>'fechaRetornoPactada', '')::DATE,
                NULL::TIME,
                NULL::INTEGER,
                'Recojo automático generado al vender el préstamo',
                v_arr_detalles::JSON,
                p_id_usuario,
                FALSE
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                v_id_prestamo,
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                NULL,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER,
                NULLIF(v_garantia->>'idCuentaBancaria', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_garantia->>'numeroOperacion', '')), ''),
                v_id_prestamo_detalle
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        -- Fase 4 (apunte 1.c.viii) — préstamo con garantía de balón: el cliente deja
        -- su propio cilindro como colateral y se lleva uno de Sarita recargado.
        -- Distinto de v_garantia (dinero): aquí se registra un balón físico nuevo,
        -- de propietario CLIENTE (el envase sigue siendo suyo y se le devuelve),
        -- con su propia fila de detalle (rol GARANTIA) enlazada al mismo préstamo
        -- que ya tiene el detalle ENTREGADO creado arriba. Es esa fila —y no el
        -- propietario— la que dice que lo tenemos en garantía y de qué préstamo.
        v_garantia_balon := v_item->'garantiaBalon';
        IF json_typeof(v_garantia_balon) = 'object'
           AND NULLIF(v_garantia_balon->>'codigoBalon', '') IS NOT NULL
        THEN
            v_vigencia_ph_garantia := COALESCE(
                NULLIF(v_garantia_balon->>'vigenciaPruebaHidrostaticaAnios', '')::INTEGER, 5
            );
            v_fecha_ultima_ph_garantia := NULLIF(v_garantia_balon->>'fechaUltimaPruebaHidrostatica', '')::DATE;
            v_fecha_proxima_ph_garantia := CASE
                WHEN v_fecha_ultima_ph_garantia IS NOT NULL
                THEN (v_fecha_ultima_ph_garantia + (v_vigencia_ph_garantia || ' years')::INTERVAL)::DATE
                ELSE NULL
            END;

            v_observacion_balon_garantia := NULLIF(TRIM(COALESCE(v_garantia_balon->>'observacion', '')), '');
            IF v_fecha_proxima_ph_garantia IS NOT NULL AND v_fecha_proxima_ph_garantia < CURRENT_DATE THEN
                v_observacion_balon_garantia := TRIM(
                    COALESCE(v_observacion_balon_garantia || ' — ', '')
                    || 'Prueba hidrostática vencida al recibir en garantía ('
                    || TO_CHAR(v_fecha_proxima_ph_garantia, 'DD/MM/YYYY') || ')'
                );
            END IF;

            SELECT lo.id INTO v_id_propietario_garantia
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'PropietarioBalon' AND lo.nombre = 'CLIENTE' AND lo.estado = 1
            LIMIT 1;

            IF v_id_propietario_garantia IS NULL THEN
                RAISE EXCEPTION 'Falta la opción CLIENTE en el catálogo PropietarioBalon';
            END IF;

            SELECT lo.id INTO v_id_estado_balon_almacen
            FROM gen_lista_opciones lo
            INNER JOIN gen_lista l ON lo.id_lista = l.id
            WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'DISPONIBLE' AND lo.estado = 1
            LIMIT 1;

            v_result := bal_crear_balon(
                p_codigo_balon                          => TRIM(v_garantia_balon->>'codigoBalon'),
                p_fecha_registro                        => CURRENT_DATE,
                p_id_almacen                             => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_propietario                        => v_id_propietario_garantia,
                p_id_cliente_propietario                => v_id_cliente,
                p_id_tipo_balon                         => NULLIF(v_garantia_balon->>'idTipoBalon', '')::INTEGER,
                p_id_producto_gas                       => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_id_estado_balon                       => v_id_estado_balon_almacen,
                p_fecha_ultima_prueba_hidrostatica      => v_fecha_ultima_ph_garantia,
                p_vigencia_prueba_hidrostatica_anios    => v_vigencia_ph_garantia,
                p_fecha_proxima_prueba_hidrostatica     => v_fecha_proxima_ph_garantia,
                p_observacion                            => v_observacion_balon_garantia,
                p_numero_serie                          => NULLIF(v_garantia_balon->>'numeroSerie', ''),
                p_id_usuario_auditoria                  => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
            v_id_balon_garantia := (v_result->'registro'->>'id')::INTEGER;

            IF v_id_balon_garantia IS NULL THEN
                RAISE EXCEPTION 'No se pudo registrar el cilindro de garantía';
            END IF;

            v_mov_garantia := inv_registrar_movimiento(
                p_naturaleza                    => 'BALON',
                p_codigo_tipo_movimiento        => 'ENTRADA_GARANTIA',
                p_id_balon                      => v_id_balon_garantia,
                p_cantidad                      => 1,
                p_id_almacen_destino            => NULLIF(v_item->>'idAlmacen', '')::INTEGER,
                p_id_cliente                    => v_id_cliente,
                p_codigo_tipo_documento_origen  => 'PRESTAMO',
                p_id_documento_origen           => v_id_prestamo,
                p_glosa                         => 'Cilindro dejado en garantía por el cliente',
                p_id_usuario_auditoria          => p_id_usuario
            );
            PERFORM ven_raise_si_error(v_mov_garantia);

            v_result := bal_crear_prestamo_detalle(
                p_id_prestamo            => v_id_prestamo,
                p_id_balon               => v_id_balon_garantia,
                p_id_producto            => NULLIF(v_garantia_balon->>'idProductoGas', '')::INTEGER,
                p_observacion            => 'Cilindro recibido en garantía',
                p_id_usuario_auditoria   => p_id_usuario,
                p_rol                    => 'GARANTIA'
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- GRE solo si el usuario lo pidió (opt-in). Sin flag no se emite.
    IF COALESCE(
        NULLIF(p_efectos->>'generarGre', '')::BOOLEAN,
        NULLIF(p_efectos->>'generar_gre', '')::BOOLEAN,
        FALSE
    ) THEN
        PERFORM ven_pos_crear_guia_remision(p_id_comprobante, p_id_usuario);
    END IF;

    -- Alquiler de regulador/accesorio (+ periodo + garantía)
    v_arr := CASE WHEN json_typeof(p_efectos->'alquileres') = 'array' THEN p_efectos->'alquileres' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_alquiler(
            NULL,
            v_id_cliente,
            NULLIF(v_item->>'idAlmacen', '')::INTEGER,
            NULLIF(v_item->>'fechaInicio', '')::DATE,
            NULLIF(v_item->>'fechaFinPactada', '')::DATE,
            NULL,
            COALESCE(NULLIF(v_item->>'tarifaDiaria', '')::NUMERIC, 0),
            COALESCE(NULLIF(v_item->>'totalCobrado', '')::NUMERIC, 0),
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_comprobante,
            NULLIF(v_item->>'idProductoRegulador', '')::INTEGER,
            NULLIF(v_item->>'idProductoStock', '')::INTEGER,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_alquiler := (v_result->'registro'->>'id')::INTEGER;
        IF v_id_alquiler IS NULL THEN
            RAISE EXCEPTION 'No se pudo crear el alquiler POS';
        END IF;

        v_periodo := v_item->'periodo';
        IF json_typeof(v_periodo) = 'object' THEN
            v_result := bal_registrar_alquiler_periodo(
                v_id_alquiler,
                NULLIF(v_periodo->>'fechaInicio', '')::DATE,
                NULLIF(v_periodo->>'fechaFin', '')::DATE,
                COALESCE(NULLIF(v_periodo->>'monto', '')::NUMERIC, 0),
                NULLIF(v_periodo->>'idProducto', '')::INTEGER,
                p_id_comprobante,
                NULLIF(TRIM(COALESCE(v_periodo->>'observacion', '')), ''),
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;

        v_garantia := v_item->'garantia';
        IF json_typeof(v_garantia) = 'object'
           AND COALESCE(NULLIF(v_garantia->>'monto', '')::NUMERIC, 0) > 0
        THEN
            v_id_producto := COALESCE(
                NULLIF(v_garantia->>'idProducto', '')::INTEGER,
                NULLIF(v_item->>'idProductoRegulador', '')::INTEGER
            );
            v_result := ven_crear_garantia(
                v_id_cliente,
                (v_garantia->>'monto')::NUMERIC,
                p_id_comprobante,
                NULL,
                v_id_producto,
                NULL,
                COALESCE(NULLIF(v_garantia->>'cantidadVenta', '')::NUMERIC, 1),
                NULLIF(v_garantia->>'idUnidadMedida', '')::INTEGER,
                NULLIF(v_garantia->>'fechaRegistro', '')::DATE,
                NULLIF(TRIM(COALESCE(v_garantia->>'observacion', '')), ''),
                p_id_usuario,
                v_id_alquiler,
                NULLIF(v_garantia->>'idMedioPago', '')::INTEGER,
                NULLIF(v_garantia->>'idCuentaBancaria', '')::INTEGER,
                NULLIF(TRIM(COALESCE(v_garantia->>'numeroOperacion', '')), '')
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;

    -- Mantenimientos
    v_arr := CASE WHEN json_typeof(p_efectos->'mantenimientos') = 'array' THEN p_efectos->'mantenimientos' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_crear_mantenimiento(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'fechaIngreso', '')::DATE,
            NULLIF(v_item->>'idTipoMantenimiento', '')::INTEGER,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'descripcion', '')), ''),
            COALESCE(NULLIF(v_item->>'costo', '')::NUMERIC, 0),
            FALSE,
            NULL,
            NULL,
            p_id_comprobante,
            NULL,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            p_id_usuario,
            NULL,
            NULL,
            NULL,
            NULL
        );
        PERFORM ven_raise_si_error(v_result);
    END LOOP;

    -- Baja por venta de cilindro
    v_arr := CASE WHEN json_typeof(p_efectos->'bajas') = 'array' THEN p_efectos->'bajas' ELSE '[]'::JSON END;
    FOR v_item IN SELECT value FROM json_array_elements(v_arr)
    LOOP
        v_result := bal_dar_baja_balon(
            NULLIF(v_item->>'idBalon', '')::INTEGER,
            NULLIF(v_item->>'idMotivoBaja', '')::INTEGER,
            p_id_usuario,
            NULL,
            NULL,
            v_id_cliente,
            p_id_comprobante,
            v_serie,
            v_numero,
            NULLIF(v_item->>'montoVenta', '')::NUMERIC,
            NULLIF(TRIM(COALESCE(v_item->>'observacion', '')), ''),
            NULLIF(v_item->>'fechaBaja', '')::DATE,
            p_id_usuario
        );
        PERFORM ven_raise_si_error(v_result);
        v_id_baja := (v_result->'registro'->>'id')::INTEGER;

        IF COALESCE((v_item->>'aprobar')::BOOLEAN, FALSE) AND v_id_baja IS NOT NULL THEN
            v_result := bal_aprobar_baja_balon(
                v_id_baja,
                p_id_usuario,
                p_id_usuario
            );
            PERFORM ven_raise_si_error(v_result);
        END IF;
    END LOOP;
END;
$function$;

