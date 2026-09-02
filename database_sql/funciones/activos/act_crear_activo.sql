-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: act_crear_activo
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.471Z
DROP FUNCTION IF EXISTS act_crear_activo(p_id_tipo integer, p_descripcion character varying, p_fecha_compra date, p_importe numeric, p_id_sucursal integer, p_marca character varying, p_modelo character varying, p_numero_serie character varying, p_id_trabajador_responsable integer, p_imagen_principal_ruta character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION act_crear_activo(p_id_tipo integer DEFAULT NULL::integer, p_descripcion character varying DEFAULT NULL::character varying, p_fecha_compra date DEFAULT NULL::date, p_importe numeric DEFAULT NULL::numeric, p_id_sucursal integer DEFAULT NULL::integer, p_marca character varying DEFAULT NULL::character varying, p_modelo character varying DEFAULT NULL::character varying, p_numero_serie character varying DEFAULT NULL::character varying, p_id_trabajador_responsable integer DEFAULT NULL::integer, p_imagen_principal_ruta character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    BEGIN
        INSERT INTO act_activos (
            id_tipo, descripcion, fecha_compra, importe,
            id_sucursal, marca, modelo, numero_serie,
            id_trabajador_responsable, imagen_principal_ruta,
            id_usuario_creacion, id_usuario_modificacion
        )
        VALUES (
            p_id_tipo, p_descripcion, p_fecha_compra, p_importe,
            p_id_sucursal, p_marca, p_modelo, p_numero_serie,
            p_id_trabajador_responsable, p_imagen_principal_ruta,
            p_id_usuario_auditoria, p_id_usuario_auditoria
        )
        RETURNING id INTO v_id;

    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN json_build_object('error', 'Uno de los datos de catálogo, sucursal o responsable no es válido', 'registro', NULL);
        WHEN OTHERS THEN
            RETURN json_build_object('error', 'No se pudo crear el activo: ' || SQLERRM, 'registro', NULL);
    END;

    RETURN act_obtener_activo(v_id);
END;
$function$
