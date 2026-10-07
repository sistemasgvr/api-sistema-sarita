-- Ejecutar después de 20261007_trabajador_licencia_al_editar.sql.
-- Solo verifica lecturas; no crea ni modifica trabajadores o licencias.
BEGIN;
DO $$
DECLARE
    trabajador RECORD;
    esperado RECORD;
    actual JSONB;
BEGIN
    FOR trabajador IN SELECT id FROM tra_trabajadores WHERE estado IN (0, 1) LOOP
        actual := tra_obtener_trabajador(trabajador.id)::jsonb -> 'registro';
        SELECT ch.telefono, l.codigo, l.id_tipo_licencia, l.id_categoria_licencia,
               l.fecha_emision, l.fecha_vencimiento INTO esperado
        FROM gen_chofer ch
        LEFT JOIN LATERAL (
            SELECT * FROM gen_licencia
            WHERE id_chofer = ch.id AND estado = 1
            ORDER BY fecha_vencimiento DESC, fecha_emision DESC, id DESC LIMIT 1
        ) l ON TRUE
        WHERE ch.id_trabajador = trabajador.id AND ch.estado = 1;
        IF NOT (actual ? 'codigo_licencia')
           OR (actual ->> 'codigo_licencia') IS DISTINCT FROM esperado.codigo
           OR (actual ->> 'telefono_chofer') IS DISTINCT FROM esperado.telefono
           OR (actual ->> 'id_tipo_licencia')::integer IS DISTINCT FROM esperado.id_tipo_licencia
           OR (actual ->> 'id_categoria_licencia')::integer IS DISTINCT FROM esperado.id_categoria_licencia
           OR (actual ->> 'fecha_emision_licencia')::date IS DISTINCT FROM esperado.fecha_emision
           OR (actual ->> 'fecha_vencimiento_licencia')::date IS DISTINCT FROM esperado.fecha_vencimiento THEN
            RAISE EXCEPTION 'Licencia omitida o incorrecta al editar trabajador %', trabajador.id;
        END IF;
    END LOOP;
END $$;
ROLLBACK;
