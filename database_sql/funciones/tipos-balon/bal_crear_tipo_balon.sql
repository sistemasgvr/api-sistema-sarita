-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_crear_tipo_balon
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.539Z
DROP FUNCTION IF EXISTS bal_crear_tipo_balon(p_nombre character varying, p_id_gas integer, p_capacidad numeric, p_capacidad_lb numeric, p_id_unidad_medida integer, p_peso numeric, p_vigencia_ph_anios integer, p_presion_llenado_psi numeric, p_peso_tara_lb numeric, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_crear_tipo_balon(p_nombre character varying, p_id_gas integer DEFAULT NULL::integer, p_capacidad numeric DEFAULT NULL::numeric, p_capacidad_lb numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso numeric DEFAULT NULL::numeric, p_vigencia_ph_anios integer DEFAULT 5, p_presion_llenado_psi numeric DEFAULT NULL::numeric, p_peso_tara_lb numeric DEFAULT NULL::numeric, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
    v_tara_lb NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_nombre IS NULL OR TRIM(p_nombre) = '' THEN
        RETURN json_build_object('error', 'El nombre del tipo de balón es obligatorio', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM bal_tipo_balon
        WHERE estado = 1 AND LOWER(TRIM(nombre)) = LOWER(TRIM(p_nombre))
    ) THEN
        RETURN json_build_object('error', 'Ya existe un tipo de balón activo con el nombre ' || TRIM(p_nombre), 'registro', NULL);
    END IF;

    IF p_id_gas IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_gas AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El gas indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_unidad_medida IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_unidad_medida AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'La unidad de medida indicada no existe o está inactiva', 'registro', NULL);
    END IF;

    IF p_capacidad_lb IS NOT NULL AND p_capacidad_lb <= 0 THEN
        RETURN json_build_object('error', 'La capacidad en lb debe ser mayor a 0', 'registro', NULL);
    END IF;

    IF p_presion_llenado_psi IS NOT NULL AND p_presion_llenado_psi <= 0 THEN
        RETURN json_build_object('error', 'La presión de llenado (PSI) debe ser mayor a 0', 'registro', NULL);
    END IF;

    v_tara_lb := COALESCE(
        NULLIF(p_peso_tara_lb, 0),
        CASE WHEN p_peso IS NOT NULL AND p_peso > 0 THEN ROUND(p_peso * 2.20462, 4) ELSE NULL END
    );

    INSERT INTO bal_tipo_balon (
        nombre, id_gas, capacidad, capacidad_lb, id_unidad_medida, peso, vigencia_ph_anios,
        presion_llenado_psi, peso_tara_lb,
        id_usuario_creacion, id_usuario_modificacion
    )
    VALUES (
        TRIM(p_nombre), p_id_gas, p_capacidad, p_capacidad_lb, p_id_unidad_medida, p_peso,
        COALESCE(p_vigencia_ph_anios, 5),
        p_presion_llenado_psi, v_tara_lb,
        p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN bal_obtener_tipo_balon(v_id);
END;
$function$
