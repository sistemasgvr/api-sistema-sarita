-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: bal_actualizar_tipo_balon
-- Overloads: 1
-- Generated: 2026-09-03T16:50:38.944Z
DROP FUNCTION IF EXISTS bal_actualizar_tipo_balon(p_id integer, p_nombre character varying, p_id_gas integer, p_capacidad numeric, p_capacidad_lb numeric, p_id_unidad_medida integer, p_peso numeric, p_vigencia_ph_anios integer, p_presion_llenado_psi numeric, p_peso_tara_lb numeric, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION bal_actualizar_tipo_balon(p_id integer, p_nombre character varying DEFAULT NULL::character varying, p_id_gas integer DEFAULT NULL::integer, p_capacidad numeric DEFAULT NULL::numeric, p_capacidad_lb numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_peso numeric DEFAULT NULL::numeric, p_vigencia_ph_anios integer DEFAULT NULL::integer, p_presion_llenado_psi numeric DEFAULT NULL::numeric, p_peso_tara_lb numeric DEFAULT NULL::numeric, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_nombre VARCHAR;
    v_peso NUMERIC;
    v_tara_lb NUMERIC;
BEGIN
    SET TIME ZONE 'America/Lima';

    v_nombre := NULLIF(TRIM(p_nombre), '');

    IF v_nombre IS NOT NULL AND EXISTS (
        SELECT 1 FROM bal_tipo_balon
        WHERE estado = 1 AND LOWER(TRIM(nombre)) = LOWER(v_nombre) AND id <> p_id
    ) THEN
        RETURN json_build_object('error', 'Ya existe otro tipo de balón con el nombre ' || v_nombre, 'registro', NULL);
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

    SELECT peso INTO v_peso FROM bal_tipo_balon WHERE id = p_id AND estado = 1;
    v_peso := COALESCE(p_peso, v_peso);
    v_tara_lb := COALESCE(
        NULLIF(p_peso_tara_lb, 0),
        CASE
            WHEN p_peso_tara_lb IS NULL AND p_peso IS NOT NULL AND p_peso > 0
                THEN ROUND(p_peso * 2.20462, 4)
            ELSE NULL
        END
    );

    UPDATE bal_tipo_balon
    SET
        nombre = COALESCE(v_nombre, nombre),
        id_gas = COALESCE(p_id_gas, id_gas),
        capacidad = COALESCE(p_capacidad, capacidad),
        capacidad_lb = COALESCE(p_capacidad_lb, capacidad_lb),
        id_unidad_medida = COALESCE(p_id_unidad_medida, id_unidad_medida),
        peso = COALESCE(p_peso, peso),
        vigencia_ph_anios = COALESCE(p_vigencia_ph_anios, vigencia_ph_anios),
        presion_llenado_psi = COALESCE(p_presion_llenado_psi, presion_llenado_psi),
        peso_tara_lb = COALESCE(v_tara_lb, peso_tara_lb),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN bal_obtener_tipo_balon(p_id);
END;
$function$;
