-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_movimiento_aplicar_snapshot
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.580Z
DROP FUNCTION IF EXISTS bal_movimiento_aplicar_snapshot();

CREATE OR REPLACE FUNCTION bal_movimiento_aplicar_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_tipo TEXT;
    v_estado_codigo TEXT;
    v_contenido_codigo TEXT;
    v_id_estado INTEGER;
    v_id_contenido INTEGER;
    v_id_contenido_actual INTEGER;
    v_almacen INTEGER;
    v_cliente INTEGER;
BEGIN
    SELECT lo.nombre INTO v_tipo
    FROM gen_lista_opciones lo
    WHERE lo.id = NEW.id_tipo_movimiento;

    v_estado_codigo := NULL;
    v_contenido_codigo := NULL;
    v_almacen := NULL;
    v_cliente := NULL;

    CASE v_tipo
        WHEN 'SALIDA_PRESTAMO' THEN
            v_estado_codigo := 'PRESTADO_CLIENTE';
            v_cliente := NEW.id_cliente;
            v_contenido_codigo := 'LLENO';
        WHEN 'SALIDA_ALQUILER' THEN
            v_estado_codigo := 'ALQUILADO';
            v_cliente := NEW.id_cliente;
            v_contenido_codigo := 'LLENO';
        WHEN 'SALIDA_VENTA' THEN
            v_estado_codigo := 'EN_PODER_CLIENTE';
            v_cliente := NEW.id_cliente;
            v_contenido_codigo := 'LLENO';
        WHEN 'SALIDA_ENTREGA_CLIENTE' THEN
            v_estado_codigo := 'EN_PODER_CLIENTE';
            v_cliente := NEW.id_cliente;
            v_contenido_codigo := 'LLENO';
        WHEN 'SALIDA_MANTENIMIENTO' THEN
            v_estado_codigo := 'EN_MANTENIMIENTO';
            v_almacen := COALESCE(NEW.id_almacen_destino, NEW.id_almacen_origen);
        WHEN 'SALIDA_PLANTA_EXTERNA' THEN
            v_estado_codigo := 'EN_RECARGA_EXTERNA';
            v_contenido_codigo := 'VACIO';
        WHEN 'ENTRADA_DEVOLUCION' THEN
            v_estado_codigo := 'EN_ALMACEN';
            v_almacen := COALESCE(NEW.id_almacen_destino, NEW.id_almacen_origen);
            v_contenido_codigo := 'VACIO';
        WHEN 'ENTRADA_MANTENIMIENTO' THEN
            v_estado_codigo := 'EN_ALMACEN';
            v_almacen := COALESCE(NEW.id_almacen_destino, NEW.id_almacen_origen);
        WHEN 'ENTRADA_LLENADO' THEN
            v_estado_codigo := 'EN_ALMACEN';
            v_almacen := COALESCE(NEW.id_almacen_destino, NEW.id_almacen_origen);
            v_contenido_codigo := 'LLENO';
        WHEN 'ENTRADA_PLANTA_EXTERNA' THEN
            v_estado_codigo := 'EN_ALMACEN';
            v_almacen := COALESCE(NEW.id_almacen_destino, NEW.id_almacen_origen);
            v_contenido_codigo := 'LLENO';
        WHEN 'RECARGA_CLIENTE' THEN
            v_estado_codigo := 'EN_PODER_CLIENTE';
            v_cliente := NEW.id_cliente;
            v_contenido_codigo := 'DESCONOCIDO';
        WHEN 'TRASLADO_LIMA' THEN
            v_estado_codigo := 'EN_RUTA_LIMA';
        WHEN 'RETORNO_LIMA' THEN
            v_estado_codigo := 'EN_ALMACEN';
            v_almacen := COALESCE(NEW.id_almacen_destino, NEW.id_almacen_origen);
        ELSE
            NULL;
    END CASE;

    IF v_estado_codigo IS NOT NULL THEN
        SELECT lo.id INTO v_id_estado
        FROM gen_lista_opciones lo
        INNER JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'EstadoBalon'
          AND lo.nombre = v_estado_codigo
          AND lo.estado = 1
        LIMIT 1;
        NEW.id_estado_balon := v_id_estado;
    ELSE
        NEW.id_estado_balon := NULL;
    END IF;

    NEW.id_almacen_ubicacion := v_almacen;
    NEW.id_cliente_ubicacion := v_cliente;

    RETURN NEW;
END;
$function$
