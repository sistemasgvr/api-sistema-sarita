-- Prueba de lectura: listado y detalle deben exponer la licencia del chofer,
-- aunque su identidad provenga de un trabajador.
DO $$
DECLARE
    v_list json;
    v_chofer json;
    v_detail json;
    v_expected gen_licencia%ROWTYPE;
    v_count integer := 0;
    v_distinct integer;
BEGIN
    v_list := gen_listar_choferes(1, '', 100000, 0, NULL);
    SELECT count(DISTINCT (x->>'id')::integer) INTO v_distinct
    FROM json_array_elements(v_list->'registros') x;
    ASSERT v_distinct = json_array_length(v_list->'registros'), 'Choferes duplicados por múltiples licencias';
    FOR v_chofer IN SELECT * FROM json_array_elements(v_list->'registros') LOOP
        ASSERT v_chofer::jsonb ? 'codigo_licencia', 'El listado no incluye la licencia';
        SELECT * INTO v_expected FROM gen_licencia
        WHERE id_chofer = (v_chofer->>'id')::integer AND estado = 1
        ORDER BY fecha_vencimiento DESC, fecha_emision DESC, id DESC LIMIT 1;
        ASSERT (v_chofer->>'codigo_licencia') IS NOT DISTINCT FROM v_expected.codigo,
            'El listado no devuelve la licencia activa del chofer';
        v_detail := gen_obtener_chofer((v_chofer->>'id')::integer)->'registro';
        ASSERT (v_chofer->>'id_licencia') IS NOT DISTINCT FROM (v_detail->>'id_licencia'),
            'Listado y detalle no coinciden';
        v_count := v_count + 1;
    END LOOP;
    RAISE NOTICE 'OK: % choferes verificados sin modificar datos', v_count;
END $$;
