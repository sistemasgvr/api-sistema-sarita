-- bal_actualizar_balon y bal_crear_balon quedaron con dos versiones
-- (overloads) coexistiendo en la base: en algún momento se les agregó un
-- parámetro (p_id_estado_contenido) sin actualizar el DROP FUNCTION del
-- inicio de cada archivo, así que CREATE OR REPLACE nunca reemplazó a la
-- versión vieja (firma distinta = función distinta para Postgres) — solo
-- agregó una nueva al lado. Resultado: cualquier llamada con parámetros
-- nombrados que no cubra el 100% de las columnas revienta con
-- "is not unique" (42725), porque ambas firmas son candidatas válidas.
--
-- bal_finalizar_recarga_planta y com_crear_compra se agregan a esta misma
-- limpieza porque sus firmas también cambiaron (a la primera se le sumó
-- p_id_proveedor y luego p_guardar_balones_almacen; a la segunda,
-- p_id_recarga_planta y p_guardar_balones_almacen) en varios pasos de
-- desarrollo — mismo riesgo de quedar duplicadas o con una versión vieja
-- (incompatible, de un compañero de equipo) coexistiendo.
--
-- Este bloque elimina TODAS las versiones existentes de estas funciones sin
-- necesidad de conocer sus firmas exactas. Es seguro volver a correrlo las
-- veces que haga falta. Después de correrlo hay que volver a ejecutar
-- bal_actualizar_balon.sql, bal_crear_balon.sql,
-- bal_finalizar_recarga_planta.sql y com_crear_compra.sql para recrear la
-- versión vigente de cada una (bal_actualizar_balon.sql y bal_crear_balon.sql
-- ya no traen un DROP con firma fija, para que esto no se repita si el
-- número de parámetros vuelve a cambiar).
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT oid::regprocedure AS firma
        FROM pg_proc
        WHERE proname IN (
            'bal_actualizar_balon',
            'bal_crear_balon',
            'bal_finalizar_recarga_planta',
            'com_crear_compra'
        )
    LOOP
        EXECUTE format('DROP FUNCTION %s', r.firma);
    END LOOP;
END $$;
