-- Ejecutar únicamente en una base temporal con empresa-emisora-schema.sql y la migración aplicada.
BEGIN;
CREATE OR REPLACE FUNCTION doc_obtener_salida(p_id integer) RETURNS json LANGUAGE sql AS $$
 SELECT json_build_object('registro', row_to_json(d)) FROM doc_salida d WHERE id = p_id;
$$;
CREATE TABLE doc_salida_referencia(id_doc_salida integer, id_comprobante integer, estado integer);
INSERT INTO gen_empresa VALUES (1, '20111111111', 1), (2, '20222222222', 1), (3, '20333333333', 0);
INSERT INTO gen_lista_opciones(id, nombre) VALUES (1, 'GENERADA');
INSERT INTO doc_salida(id, numero, id_tipo_orden, id_estado_ciclo, id_sucursal, id_almacen, fecha)
VALUES (1,'OS-1',1,1,1,1,CURRENT_DATE), (2,'OS-2',1,1,1,1,CURRENT_DATE);
UPDATE doc_salida SET id_empresa = 1 WHERE id = 1;
DO $$
DECLARE result json;
BEGIN
 result := doc_convertir_a_gre(1, 1, 'T001', p_id_empresa => NULL);
 ASSERT result->>'error' IS NOT NULL, 'Debe exigir emisor';
 result := doc_convertir_a_gre(1, 1, 'T001', p_id_empresa => 3);
 ASSERT result->>'error' IS NOT NULL, 'Debe rechazar empresa inactiva';
 result := doc_convertir_a_gre(1, 1, 'T001', p_id_empresa => 2);
 ASSERT result->>'error' IS NULL, result::text;
 ASSERT (SELECT id_empresa = 2 FROM doc_salida WHERE id = 1), 'Debe guardar la empresa elegida';
 result := doc_convertir_a_gre(1, 1, 'T001', p_id_empresa => 1);
 ASSERT result->>'error' IS NOT NULL, 'Debe impedir cambiar el emisor';
 ASSERT (SELECT id_empresa = 2 FROM doc_salida WHERE id = 1), 'Debe conservar el emisor';
 UPDATE doc_salida SET ticket_sunat = 'ticket-historico' WHERE id = 2;
 result := doc_convertir_a_gre(2, 1, 'T001', p_id_empresa => 1);
 ASSERT result->>'error' IS NOT NULL, 'No debe reasignar una guía histórica con ticket';
 RAISE NOTICE 'OK: comprobaciones de vinculación e integridad del emisor';
END $$;
ROLLBACK;
