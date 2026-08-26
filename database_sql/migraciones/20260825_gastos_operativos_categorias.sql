UPDATE gen_lista_opciones
SET nombre = 'IMPUESTOS',
    descripcion = 'IGV, Renta, Planilla (detalle en observación del gasto)'
WHERE id = 254 AND id_lista = 55;

UPDATE gen_lista_opciones
SET nombre = 'UTILES_OFICINA'
WHERE id = 257 AND id_lista = 55;
INSERT INTO gen_lista_opciones (id_lista, nombre, descripcion, id_usuario_creacion)
SELECT 55, v.nombre, v.descripcion, 1
FROM (VALUES
    ('ALQUILER_LOCAL', 'Alquiler de local'),
    ('UTILES_LIMPIEZA', 'Útiles de limpieza'),
    ('SUELDOS', 'Sueldos y planilla de personal'),
    ('SERVICIOS_BASICOS', 'Luz, agua, teléfono, internet'),
    ('BIDONES_AGUA', 'Bidones de agua'),
    ('VIATICOS', 'Viáticos')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM gen_lista_opciones WHERE id_lista = 55 AND nombre = v.nombre
);

ALTER TABLE fin_caja_gasto
    DROP CONSTRAINT fin_caja_gasto_id_categoria_gasto_fkey;

ALTER TABLE fin_caja_gasto
    ADD CONSTRAINT fin_caja_gasto_id_categoria_gasto_fkey
    FOREIGN KEY (id_categoria_gasto) REFERENCES gen_lista_opciones(id);
