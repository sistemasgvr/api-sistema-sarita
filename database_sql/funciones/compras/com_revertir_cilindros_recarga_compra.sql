-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: com_revertir_cilindros_recarga_compra
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.640Z
DROP FUNCTION IF EXISTS com_revertir_cilindros_recarga_compra(p_id_recarga_planta integer, p_id_comprobante integer, p_id_usuario integer);

CREATE OR REPLACE FUNCTION com_revertir_cilindros_recarga_compra(p_id_recarga_planta integer, p_id_comprobante integer, p_id_usuario integer DEFAULT NULL::integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_det RECORD;
    v_estado VARCHAR;
    v_id_recarga_ext INTEGER;
    v_id_tipo_doc_compra INTEGER;
    v_id_tipo_doc_recarga INTEGER;
BEGIN
    SELECT lo.id INTO v_id_recarga_ext
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoBalon' AND lo.nombre = 'EN_RECARGA_EXTERNA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_compra
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'COMPRA' AND lo.estado = 1
    LIMIT 1;

    SELECT lo.id INTO v_id_tipo_doc_recarga
    FROM gen_lista_opciones lo
    INNER JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = 'RECARGA' AND lo.estado = 1
    LIMIT 1;

    FOR v_det IN
        SELECT d.id_balon
        FROM bal_recarga_planta_detalle d
        WHERE d.id_recarga_planta = p_id_recarga_planta
          AND d.estado = 1
    LOOP
        SELECT eb.nombre INTO v_estado
        FROM bal_balon b
        LEFT JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
        WHERE b.id = v_det.id_balon AND b.estado = 1;

        IF COALESCE(v_estado, '') NOT IN ('EN_ALMACEN', 'EN_RECARGA_EXTERNA') THEN
            RAISE EXCEPTION
                'No se puede anular la compra: el cilindro % ya no está en almacén ni en recarga externa (estado %).',
                v_det.id_balon,
                COALESCE(v_estado, 'sin estado');
        END IF;

        IF COALESCE(v_estado, '') = 'EN_ALMACEN' AND v_id_recarga_ext IS NOT NULL THEN
            UPDATE bal_balon
            SET
                id_estado_balon = v_id_recarga_ext,
                id_almacen = NULL,
                id_usuario_modificacion = p_id_usuario,
                fecha_modificacion = NOW()
            WHERE id = v_det.id_balon AND estado = 1;
        END IF;
    END LOOP;

    -- Entradas de cilindro ya repuntadas a COMPRA: reapuntar solo naturaleza BALON
    -- (no tocar INGRESO de producto; com_anular_compra lo compensa con SALIDA)
    -- para poder revertirlas con inv_revertir_por_documento('RECARGA', orden).
    IF v_id_tipo_doc_compra IS NOT NULL AND v_id_tipo_doc_recarga IS NOT NULL THEN
        UPDATE inv_movimiento m
        SET
            id_documento_origen = p_id_recarga_planta,
            id_tipo_documento_origen = v_id_tipo_doc_recarga,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE m.estado = 1
          AND m.naturaleza = 'BALON'
          AND m.id_tipo_documento_origen = v_id_tipo_doc_compra
          AND m.id_documento_origen = p_id_comprobante
          AND m.id_balon IN (
              SELECT d.id_balon
              FROM bal_recarga_planta_detalle d
              WHERE d.id_recarga_planta = p_id_recarga_planta
                AND d.estado = 1
          )
          AND m.id_tipo_movimiento IN (
              SELECT lo.id
              FROM gen_lista_opciones lo
              INNER JOIN gen_lista l ON l.id = lo.id_lista
              WHERE l.nombre = 'TipoMovBalon'
                AND lo.nombre IN ('ENTRADA_LLENADO', 'ENTRADA_PLANTA_EXTERNA')
                AND lo.estado = 1
          );
    END IF;

    -- Revierte entradas aún bajo RECARGA (orden) y las que acabamos de reapuntar.
    PERFORM inv_revertir_por_documento('RECARGA', p_id_recarga_planta, p_id_usuario);

    -- inv_revertir deja cilindros en EN_ALMACEN; al anular compra deben volver a EN_RECARGA_EXTERNA.
    IF v_id_recarga_ext IS NOT NULL THEN
        UPDATE bal_balon b
        SET
            id_estado_balon = v_id_recarga_ext,
            id_almacen = NULL,
            id_usuario_modificacion = p_id_usuario,
            fecha_modificacion = NOW()
        WHERE b.estado = 1
          AND b.id IN (
              SELECT d.id_balon
              FROM bal_recarga_planta_detalle d
              WHERE d.id_recarga_planta = p_id_recarga_planta
                AND d.estado = 1
          );
    END IF;
END;
$function$
