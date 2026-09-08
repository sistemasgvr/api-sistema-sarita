-- Function: bal_actualizar_lote_protocolo
-- Fase 5 — edición de la ficha ICP. Los campos NULL no se tocan (COALESCE);
-- pruebas y envases se reemplazan solo si vienen en el llamado.
DROP FUNCTION IF EXISTS bal_actualizar_lote_protocolo(p_id integer, p_numero_lote character varying, p_numero_protocolo character varying, p_id_proveedor integer, p_id_producto_gas integer, p_descripcion_producto character varying, p_forma_farmaceutica character varying, p_presentacion character varying, p_norma_tecnica character varying, p_metodo_fabricacion character varying, p_fecha_analisis date, p_fecha_emision date, p_fecha_fabricacion date, p_fecha_vencimiento date, p_tamano_lote_m3 numeric, p_cantidad_envases integer, p_valoracion_o2_pct numeric, p_limite_co2_ppm numeric, p_limite_co_ppm numeric, p_cilindro_muestreado_serie character varying, p_temperatura_muestreo_c numeric, p_presion_muestreo_psi numeric, p_analista character varying, p_conclusion character varying, p_codigo_documento character varying, p_version_documento character varying, p_id_archivo_pdf integer, p_observacion character varying, p_pruebas json, p_envases json, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_lote_protocolo(p_id integer, p_numero_lote character varying DEFAULT NULL::character varying, p_numero_protocolo character varying DEFAULT NULL::character varying, p_id_proveedor integer DEFAULT NULL::integer, p_id_producto_gas integer DEFAULT NULL::integer, p_descripcion_producto character varying DEFAULT NULL::character varying, p_forma_farmaceutica character varying DEFAULT NULL::character varying, p_presentacion character varying DEFAULT NULL::character varying, p_norma_tecnica character varying DEFAULT NULL::character varying, p_metodo_fabricacion character varying DEFAULT NULL::character varying, p_fecha_analisis date DEFAULT NULL::date, p_fecha_emision date DEFAULT NULL::date, p_fecha_fabricacion date DEFAULT NULL::date, p_fecha_vencimiento date DEFAULT NULL::date, p_tamano_lote_m3 numeric DEFAULT NULL::numeric, p_cantidad_envases integer DEFAULT NULL::integer, p_valoracion_o2_pct numeric DEFAULT NULL::numeric, p_limite_co2_ppm numeric DEFAULT NULL::numeric, p_limite_co_ppm numeric DEFAULT NULL::numeric, p_cilindro_muestreado_serie character varying DEFAULT NULL::character varying, p_temperatura_muestreo_c numeric DEFAULT NULL::numeric, p_presion_muestreo_psi numeric DEFAULT NULL::numeric, p_analista character varying DEFAULT NULL::character varying, p_conclusion character varying DEFAULT NULL::character varying, p_codigo_documento character varying DEFAULT NULL::character varying, p_version_documento character varying DEFAULT NULL::character varying, p_id_archivo_pdf integer DEFAULT NULL::integer, p_observacion character varying DEFAULT NULL::character varying, p_pruebas json DEFAULT NULL::json, p_envases json DEFAULT NULL::json, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero_lote VARCHAR;
    v_id_proveedor INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT EXISTS (SELECT 1 FROM bal_lote_protocolo WHERE id = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'Ficha de lote y protocolo no encontrada', 'registro', NULL);
    END IF;

    SELECT
        COALESCE(NULLIF(TRIM(p_numero_lote), ''), lp.numero_lote),
        COALESCE(p_id_proveedor, lp.id_proveedor)
    INTO v_numero_lote, v_id_proveedor
    FROM bal_lote_protocolo lp
    WHERE lp.id = p_id;

    IF EXISTS (
        SELECT 1 FROM bal_lote_protocolo lp
        WHERE lp.estado = 1
          AND lp.id <> p_id
          AND UPPER(TRIM(lp.numero_lote)) = UPPER(v_numero_lote)
          AND COALESCE(lp.id_proveedor, 0) = COALESCE(v_id_proveedor, 0)
    ) THEN
        RETURN json_build_object(
            'error', format('Ya existe otra ficha activa con el lote %s para ese proveedor', v_numero_lote),
            'registro', NULL
        );
    END IF;

    UPDATE bal_lote_protocolo
    SET numero_lote               = v_numero_lote,
        numero_protocolo          = COALESCE(NULLIF(TRIM(p_numero_protocolo), ''), numero_protocolo),
        id_proveedor              = COALESCE(p_id_proveedor, id_proveedor),
        id_producto_gas           = COALESCE(p_id_producto_gas, id_producto_gas),
        descripcion_producto      = COALESCE(p_descripcion_producto, descripcion_producto),
        forma_farmaceutica        = COALESCE(p_forma_farmaceutica, forma_farmaceutica),
        presentacion              = COALESCE(p_presentacion, presentacion),
        norma_tecnica             = COALESCE(p_norma_tecnica, norma_tecnica),
        metodo_fabricacion        = COALESCE(p_metodo_fabricacion, metodo_fabricacion),
        fecha_analisis            = COALESCE(p_fecha_analisis, fecha_analisis),
        fecha_emision             = COALESCE(p_fecha_emision, fecha_emision),
        fecha_fabricacion         = COALESCE(p_fecha_fabricacion, fecha_fabricacion),
        fecha_vencimiento         = COALESCE(p_fecha_vencimiento, fecha_vencimiento),
        tamano_lote_m3            = COALESCE(p_tamano_lote_m3, tamano_lote_m3),
        cantidad_envases          = COALESCE(p_cantidad_envases, cantidad_envases),
        valoracion_o2_pct         = COALESCE(p_valoracion_o2_pct, valoracion_o2_pct),
        limite_co2_ppm            = COALESCE(p_limite_co2_ppm, limite_co2_ppm),
        limite_co_ppm             = COALESCE(p_limite_co_ppm, limite_co_ppm),
        cilindro_muestreado_serie = COALESCE(NULLIF(TRIM(p_cilindro_muestreado_serie), ''), cilindro_muestreado_serie),
        temperatura_muestreo_c    = COALESCE(p_temperatura_muestreo_c, temperatura_muestreo_c),
        presion_muestreo_psi      = COALESCE(p_presion_muestreo_psi, presion_muestreo_psi),
        analista                  = COALESCE(p_analista, analista),
        conclusion                = COALESCE(p_conclusion, conclusion),
        codigo_documento          = COALESCE(p_codigo_documento, codigo_documento),
        version_documento         = COALESCE(p_version_documento, version_documento),
        id_archivo_pdf            = COALESCE(p_id_archivo_pdf, id_archivo_pdf),
        observacion               = COALESCE(p_observacion, observacion),
        id_usuario_modificacion   = p_id_usuario_auditoria,
        fecha_modificacion        = NOW()
    WHERE id = p_id;

    PERFORM bal_reemplazar_lote_protocolo_detalle(p_id, p_pruebas, p_envases, p_id_usuario_auditoria);

    RETURN bal_obtener_lote_protocolo(p_id);
END;
$function$;
