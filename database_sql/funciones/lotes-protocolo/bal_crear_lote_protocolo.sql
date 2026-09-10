-- Function: bal_crear_lote_protocolo
-- Fase 5 — alta de una ficha ICP. Los datos de análisis y la relación de envases
-- llegan como JSON en el mismo llamado: la ficha no tiene sentido a medias.
DROP FUNCTION IF EXISTS bal_crear_lote_protocolo(p_numero_lote character varying, p_numero_protocolo character varying, p_id_proveedor integer, p_id_producto_gas integer, p_descripcion_producto character varying, p_forma_farmaceutica character varying, p_presentacion character varying, p_norma_tecnica character varying, p_metodo_fabricacion character varying, p_fecha_analisis date, p_fecha_emision date, p_fecha_fabricacion date, p_fecha_vencimiento date, p_tamano_lote_m3 numeric, p_cantidad_envases integer, p_valoracion_o2_pct numeric, p_limite_co2_ppm numeric, p_limite_co_ppm numeric, p_cilindro_muestreado_serie character varying, p_temperatura_muestreo_c numeric, p_presion_muestreo_psi numeric, p_analista character varying, p_conclusion character varying, p_codigo_documento character varying, p_version_documento character varying, p_id_archivo_pdf integer, p_observacion character varying, p_pruebas json, p_envases json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_lote_protocolo(p_numero_lote character varying, p_numero_protocolo character varying DEFAULT NULL::character varying, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_descripcion_producto character varying DEFAULT NULL::character varying, p_forma_farmaceutica character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_norma_tecnica character varying DEFAULT NULL::character varying, p_metodo_fabricacion character varying DEFAULT NULL::character varying, p_fecha_analisis date DEFAULT NULL::date, p_fecha_emision date DEFAULT NULL::date, p_fecha_fabricacion date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_tamano_lote_m3 numeric DEFAULT NULL::numeric, p_cantidad_envases integer DEFAULT NULL::integer, p_valoracion_o2_pct numeric DEFAULT NULL::numeric, p_limite_co2_ppm numeric DEFAULT NULL::numeric, p_limite_co_ppm numeric DEFAULT NULL::numeric, p_cilindro_muestreado_serie character varying DEFAULT NULL::character varying, p_temperatura_muestreo_c numeric DEFAULT NULL::numeric, p_presion_muestreo_psi numeric DEFAULT NULL::numeric, p_analista character varying DEFAULT NULL::character varying, p_conclusion character varying DEFAULT NULL::character varying, p_codigo_documento character varying DEFAULT NULL::character varying, p_version_documento character varying DEFAULT NULL::character varying, p_id_archivo_pdf integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_pruebas json DEFAULT NULL::json, p_envases json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_numero_lote VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_numero_lote := NULLIF(TRIM(p_numero_lote), '');

    IF v_numero_lote IS NULL THEN
        RETURN json_build_object('error', 'El número de lote es obligatorio', 'registro', NULL);
    END IF;

    IF p_fecha_vencimiento IS NULL THEN
        RETURN json_build_object(
            'error',
            'La fecha de vencimiento de la ficha ICP es obligatoria',
            'registro',
            NULL
        );
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_lote_protocolo lp
        WHERE lp.estado = 1
          AND UPPER(TRIM(lp.numero_lote)) = UPPER(v_numero_lote)
          AND COALESCE(lp.id_proveedor, 0) = COALESCE(p_id_proveedor, 0)
    ) THEN
        RETURN json_build_object(
            'error', format('Ya existe una ficha activa con el lote %s para ese proveedor', v_numero_lote),
            'registro', NULL
        );
    END IF;

    -- Una ficha vigente (con vencimiento futuro) o abierta (sin vencimiento) bloquea otra
    -- del mismo proveedor y gas.
    IF EXISTS (
        SELECT 1
        FROM bal_lote_protocolo lp
        WHERE lp.estado = 1
          AND COALESCE(lp.id_proveedor, 0) = COALESCE(p_id_proveedor, 0)
          AND COALESCE(lp.id_producto_gas, 0) = COALESCE(p_id_producto_gas, 0)
          AND (
            lp.fecha_vencimiento IS NULL
            OR lp.fecha_vencimiento >= CURRENT_DATE
          )
    ) THEN
        RETURN json_build_object(
            'error', (
                SELECT format(
                    'Ya hay una ficha vigente/abierta para este proveedor y gas: lote %s%s. No se puede registrar otra hasta que venza o se cierre.',
                    lp.numero_lote,
                    CASE
                        WHEN lp.fecha_vencimiento IS NULL THEN ' (sin vencimiento)'
                        ELSE ', vence ' || TO_CHAR(lp.fecha_vencimiento, 'MM/YYYY')
                    END
                )
                FROM bal_lote_protocolo lp
                WHERE lp.estado = 1
                  AND COALESCE(lp.id_proveedor, 0) = COALESCE(p_id_proveedor, 0)
                  AND COALESCE(lp.id_producto_gas, 0) = COALESCE(p_id_producto_gas, 0)
                  AND (
                    lp.fecha_vencimiento IS NULL
                    OR lp.fecha_vencimiento >= CURRENT_DATE
                  )
                ORDER BY lp.fecha_vencimiento DESC NULLS FIRST
                LIMIT 1
            ),
            'registro', NULL
        );
    END IF;

    INSERT INTO bal_lote_protocolo (
        numero_lote, numero_protocolo, id_proveedor, id_producto_gas,
        descripcion_producto, forma_farmaceutica, presentacion, norma_tecnica,
        metodo_fabricacion, fecha_analisis, fecha_emision, fecha_fabricacion,
        fecha_vencimiento, tamano_lote_m3, cantidad_envases, valoracion_o2_pct,
        limite_co2_ppm, limite_co_ppm, cilindro_muestreado_serie,
        temperatura_muestreo_c, presion_muestreo_psi, analista, conclusion,
        codigo_documento, version_documento, id_archivo_pdf, observacion,
        estado, id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        v_numero_lote, NULLIF(TRIM(p_numero_protocolo), ''), p_id_proveedor, p_id_producto_gas,
        p_descripcion_producto, p_forma_farmaceutica, p_presentacion, p_norma_tecnica,
        p_metodo_fabricacion, p_fecha_analisis, p_fecha_emision, p_fecha_fabricacion,
        p_fecha_vencimiento, p_tamano_lote_m3, p_cantidad_envases, p_valoracion_o2_pct,
        p_limite_co2_ppm, p_limite_co_ppm, NULLIF(TRIM(p_cilindro_muestreado_serie), ''),
        p_temperatura_muestreo_c, p_presion_muestreo_psi, p_analista, p_conclusion,
        p_codigo_documento, p_version_documento, p_id_archivo_pdf, p_observacion,
        1, p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    PERFORM bal_reemplazar_lote_protocolo_detalle(v_id, p_pruebas, p_envases, p_id_usuario_auditoria);

    RETURN bal_obtener_lote_protocolo(v_id);
END;
$function$;
