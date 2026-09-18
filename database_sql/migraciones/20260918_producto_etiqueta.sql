-- Etiqueta adhesiva del producto: función de lectura propia para GET /productos/:id/etiqueta.pdf
BEGIN;
-- Function: pro_obtener_etiqueta_producto
-- Datos mínimos para imprimir la etiqueta adhesiva del producto (50 × 25 mm):
-- código, nombre, categoría, subcategoría y código de barras.
-- Separada de pro_obtener_producto para no arrastrar precios, stock ni auditoría.
-- (pro_etiqueta_producto ya existe y devuelve solo el texto "código — nombre" para mensajes.)

CREATE OR REPLACE FUNCTION pro_obtener_etiqueta_producto(p_id integer)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_registro JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT row_to_json(t) INTO v_registro
    FROM (
        SELECT
            p.id,
            p.codigo,
            p.nombre,
            p.codigo_barra,
            p.codigo_ubicacion,
            p.marca,
            p.presentacion,
            p.id_sub_categoria,
            sc.nombre AS nombre_sub_categoria,
            sc.id_categoria,
            c.nombre AS nombre_categoria
        FROM pro_producto p
        LEFT JOIN pro_sub_categoria sc ON sc.id = p.id_sub_categoria
        LEFT JOIN pro_categoria c ON c.id = sc.id_categoria
        WHERE p.id = p_id AND p.estado = 1
    ) t;

    RETURN json_build_object('registro', v_registro);
END;
$function$;
COMMIT;
