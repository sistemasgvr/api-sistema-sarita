-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: act_actualizar_activo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.469Z
DROP FUNCTION IF EXISTS act_actualizar_activo(p_id integer, p_id_tipo integer, p_descripcion character varying, p_fecha_compra date, p_importe numeric, p_id_sucursal integer, p_marca character varying, p_modelo character varying, p_numero_serie character varying, p_id_trabajador_responsable integer, p_imagen_principal_ruta character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION act_actualizar_activo(p_id integer, p_id_tipo integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_fecha_compra date DEFAULT NULL::date, p_importe numeric DEFAULT NULL::numeric, p_id_sucursal integer DEFAULT NULL::integer, p_marca character varying DEFAULT NULL::character varying, p_modelo character varying DEFAULT NULL::character varying, p_numero_serie character varying DEFAULT NULL::character varying, p_id_trabajador_responsable integer DEFAULT NULL::integer, p_imagen_principal_ruta character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_existe INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT COUNT(*) INTO v_existe FROM act_activos WHERE id = p_id AND estado IN (0, 1);
    IF v_existe = 0 THEN
        RETURN json_build_object('registro', NULL, 'error', 'No existe un activo con id ' || p_id);
    END IF;

    BEGIN
        UPDATE act_activos
        SET
            id_tipo                     = COALESCE(p_id_tipo, id_tipo),
            descripcion                 = COALESCE(p_descripcion, descripcion),
            fecha_compra                = COALESCE(p_fecha_compra, fecha_compra),
            importe                     = COALESCE(p_importe, importe),
            id_sucursal                 = COALESCE(p_id_sucursal, id_sucursal),
            marca                       = COALESCE(p_marca, marca),
            modelo                      = COALESCE(p_modelo, modelo),
            numero_serie                = COALESCE(p_numero_serie, numero_serie),
            id_trabajador_responsable   = COALESCE(p_id_trabajador_responsable, id_trabajador_responsable),
            imagen_principal_ruta       = COALESCE(p_imagen_principal_ruta, imagen_principal_ruta),
            id_usuario_modificacion     = p_id_usuario_auditoria,
            fecha_modificacion          = NOW()
        WHERE id = p_id AND estado IN (0, 1);

    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo, sucursal o responsable no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo actualizar el activo: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN act_obtener_activo(p_id);
END;
$function$
