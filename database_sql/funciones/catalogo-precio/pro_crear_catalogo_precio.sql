-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: pro_crear_catalogo_precio
-- Overloads: 1
-- Generated: 2026-09-02T21:31:03.771Z
DROP FUNCTION IF EXISTS pro_crear_catalogo_precio(p_id_tipo_catalogo integer, p_nombre_item character varying, p_periodo character varying, p_id_producto integer, p_id_tipo_balon integer, p_id_proveedor integer, p_clasificacion character varying, p_modelo character varying, p_capacidad numeric, p_id_unidad_medida integer, p_descripcion_presentacion character varying, p_costo_producto numeric, p_costo_flete numeric, p_porcentaje_margen numeric, p_precio_final numeric, p_precio_garantia numeric, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION pro_crear_catalogo_precio(p_id_tipo_catalogo integer, p_nombre_item character varying, p_periodo character varying DEFAULT NULL::character varying, p_id_producto integer DEFAULT NULL::integer, p_id_tipo_balon integer DEFAULT NULL::integer, p_id_proveedor integer DEFAULT NULL::integer, p_clasificacion character varying DEFAULT NULL::character varying, p_modelo character varying DEFAULT NULL::character varying, p_capacidad numeric DEFAULT NULL::numeric, p_id_unidad_medida integer DEFAULT NULL::integer, p_descripcion_presentacion character varying DEFAULT NULL::character varying, p_costo_producto numeric DEFAULT 0, p_costo_flete numeric DEFAULT 0, p_porcentaje_margen numeric DEFAULT NULL::numeric, p_precio_final numeric DEFAULT NULL::numeric, p_precio_garantia numeric DEFAULT NULL::numeric, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_id INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_nombre_item IS NULL OR TRIM(p_nombre_item) = '' THEN
        RETURN json_build_object('error', 'El nombre del ítem es obligatorio', 'registro', NULL);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM gen_lista_opciones WHERE id = p_id_tipo_catalogo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de catálogo indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_producto IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM pro_producto WHERE id = p_id_producto AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El producto indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_tipo_balon IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM bal_tipo_balon WHERE id = p_id_tipo_balon AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El tipo de balón indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    IF p_id_proveedor IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM cli_clientes WHERE id = p_id_proveedor AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'El proveedor indicado no existe o está inactivo', 'registro', NULL);
    END IF;

    INSERT INTO pro_catalogo_precio (
        id_tipo_catalogo,
        periodo,
        nombre_item,
        id_producto,
        id_tipo_balon,
        id_proveedor,
        clasificacion,
        modelo,
        capacidad,
        id_unidad_medida,
        descripcion_presentacion,
        costo_producto,
        costo_flete,
        porcentaje_margen,
        precio_final,
        precio_garantia,
        id_usuario_creacion,
        id_usuario_modificacion
    )
    VALUES (
        p_id_tipo_catalogo,
        p_periodo,
        TRIM(p_nombre_item),
        p_id_producto,
        p_id_tipo_balon,
        p_id_proveedor,
        p_clasificacion,
        p_modelo,
        p_capacidad,
        p_id_unidad_medida,
        p_descripcion_presentacion,
        COALESCE(p_costo_producto, 0),
        COALESCE(p_costo_flete, 0),
        p_porcentaje_margen,
        p_precio_final,
        p_precio_garantia,
        p_id_usuario_auditoria,
        p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN pro_obtener_catalogo_precio(v_id);
END;
$function$
