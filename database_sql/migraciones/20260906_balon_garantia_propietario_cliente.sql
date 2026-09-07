-- =============================================================================
-- El cilindro que el cliente deja en garantía es del CLIENTE
-- =============================================================================
-- Hasta ahora el POS registraba ese envase con `PropietarioBalon = GARANTIA_CLIENTE`,
-- mezclando dos cosas distintas: de quién ES el cilindro (del cliente) y en qué
-- CONCEPTO lo tenemos (en garantía de un préstamo).
--
-- El propietario pasa a ser CLIENTE, que es la verdad: el envase sigue siendo
-- suyo y se lo devolveremos. El concepto ya estaba registrado donde toca, en
-- `bal_prestamo_detalle.rol = 'GARANTIA'`, que además lo ata al préstamo
-- concreto — algo que el propietario nunca pudo expresar.
--
-- No se pierde información: `bal_crear_balon` y `bal_actualizar_balon` ya
-- trataban ambos valores igual (los dos conservan `id_cliente_propietario`),
-- así que las reglas de validación siguen aplicando sin cambios.
--
-- Idempotente: se puede reejecutar.
-- =============================================================================

SET TIME ZONE 'America/Lima';

DO $$
DECLARE
    v_id_garantia_cliente INTEGER;
    v_id_cliente INTEGER;
    v_migrados INTEGER := 0;
BEGIN
    SELECT lo.id INTO v_id_garantia_cliente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PropietarioBalon' AND UPPER(lo.nombre) = 'GARANTIA_CLIENTE'
    LIMIT 1;

    SELECT lo.id INTO v_id_cliente
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'PropietarioBalon' AND UPPER(lo.nombre) = 'CLIENTE' AND lo.estado = 1
    LIMIT 1;

    IF v_id_garantia_cliente IS NULL THEN
        RAISE NOTICE 'No existe GARANTIA_CLIENTE: nada que migrar.';
        RETURN;
    END IF;

    IF v_id_cliente IS NULL THEN
        RAISE EXCEPTION 'Falta la opción CLIENTE en el catálogo PropietarioBalon';
    END IF;

    UPDATE bal_balon
    SET id_propietario = v_id_cliente,
        fecha_modificacion = NOW()
    WHERE id_propietario = v_id_garantia_cliente;

    GET DIAGNOSTICS v_migrados = ROW_COUNT;
    RAISE NOTICE 'Cilindros reasignados de GARANTIA_CLIENTE a CLIENTE: %', v_migrados;

    -- Se desactiva en vez de borrarse: es una opción de catálogo que pudo quedar
    -- referenciada en histórico, y desactivarla basta para que desaparezca de los
    -- desplegables de propietario.
    UPDATE gen_lista_opciones
    SET estado = 0,
        descripcion = COALESCE(descripcion, '')
            || ' [Obsoleto 2026-09-06: el propietario es CLIENTE; la garantía se'
            || ' registra en bal_prestamo_detalle.rol = GARANTIA]',
        fecha_modificacion = NOW()
    WHERE id = v_id_garantia_cliente AND estado = 1;
END $$;
