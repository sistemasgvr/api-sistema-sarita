-- =============================================================================
-- 04 INSERT BALONES (bal_balon)
-- Generado desde LlenadoDatos.xlsx / hoja Balones
-- Listas: exports/dump-2026-09-29-21-16-37
-- Ejecutar DESPUES de 01_clientes, 02_prerequisitos, 03_plantas
-- =============================================================================
-- Aceptados: 643 | Rechazados: 0 | Omitidos propano: 14
-- (Propano se carga como stock de producto en 05_stock_inicial_propano.sql)
-- =============================================================================

BEGIN;
SET TIME ZONE 'America/Lima';

-- Excel fila 5: FC019089 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019089', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC019089', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 6: FC018103 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC018103', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC018103', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 7: FC019173 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019173', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC019173', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 8: FC020017 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC020017', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC020017', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 9: FC019187 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019187', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC019187', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 10: FC019088 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019088', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC019088', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 11: FC017152 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC017152', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC017152', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 12: FC017120 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC017120', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2026-08-18', NULL,
  'FC017120', NULL, NULL, FALSE,
  2026, 8,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 13: 20K301192 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301192', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  NULL, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K301192', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 14: 20K301112 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301112', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10483897940' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K301112', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 15: 20K303051 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K303051', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612446106' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K303051', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 16: B20168 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'B20168', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20608737848' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'B20168', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 17: K4615182 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4615182', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20614101939' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4615182', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 18: 22K035086 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035086', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480319860' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K035086', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 19: 22K034022 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K034022', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480319860' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K034022', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 20: 22K035004 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035004', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '22K035004', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 21: 20K646128 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646128', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480319860' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K646128', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 22: 22K034131 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K034131', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480319860' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K034131', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 23: 303206Y / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303206Y', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2025-08-01', NULL,
  '303206Y', NULL, 67, FALSE,
  2025, 8,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 24: 20K301113 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301113', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2025-09-01', NULL,
  '20K301113', 59, NULL, FALSE,
  2025, 9,
  2800.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 25: P106037 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'P106037', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20514134155' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'P106037', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 26: K5409161 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409161', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '76881055' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5409161', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 27: FC017086 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC017086', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  '2026-08-01', NULL,
  'FC017086', 34, NULL, FALSE,
  2026, 8,
  2800.0, 'AMERICANA', 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 28: 22K035085 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035085', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K035085', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 29: GA972064 / EMPRESA / Argón Estándar  6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA972064', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10477042347' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA972064', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 30: 4156931 / EMPRESA / Argón Estándar  6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '4156931', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '4156931', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 31: GA785012 / EMPRESA / Argón Estándar  6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA785012', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'GA785012', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 32: GA971194 / EMPRESA / Argón Estándar  6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA971194', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '45370902' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA971194', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 33: 301730 / EMPRESA / Argón Estándar  6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '301730', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10440281074' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '301730', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 34: 7164 / EMPRESA / Argón Estándar  6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '7164', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '27392599' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '7164', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 35: GTA048104 / EMPRESA / Argón Estándar  3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA048104', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20338570041' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  221, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA048104', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 36: 56130178 / EMPRESA / Argón Estándar  3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '56130178', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '56130178', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 37: A2389140 / EMPRESA / Argón Estándar  3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389140', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '41079206' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'A2389140', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 38: 22R557074 / EMPRESA / Argón Estándar  3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22R557074', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20600017412' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22R557074', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 39: A2389118 / EMPRESA / Argón Estándar  3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389118', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'A2389118', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 40: GTA048105 / EMPRESA / Argón Estándar  3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA048105', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10471465572' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA048105', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 41: 26CQ004013 / EMPRESA / Argón Estándar  3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26CQ004013', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar  3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '26CQ004013', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 42: 22K035162 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035162', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '22K035162', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 43: FC018188 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC018188', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC018188', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 44: FC020069 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC020069', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC020069', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 45: FC019144 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019144', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC019144', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 46: FC018088 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC018088', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC018088', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 47: FC019113 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019113', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC019113', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 48: FC020086 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC020086', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC020086', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 49: FC019175 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019175', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC019175', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 50: 21X416099 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X416099', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21X416099', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 51: 20K304180 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K304180', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20608006738' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K304180', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 52: 1052372 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1052372', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20602694853' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1052372', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 53: 20X153103 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20X153103', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20602694853' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20X153103', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 54: 20K463096 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K463096', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20602694853' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K463096', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 55: 22K034144 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K034144', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103626448' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K034144', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 56: 20K625109 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K625109', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K625109', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 57: K5409156 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409156', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5409156', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 58: 36774047 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '36774047', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '36774047', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 59: 20S290066 / EMPRESA / Nitrógeno 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290066', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561169404' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S290066', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 60: 9528490 / EMPRESA / Nitrógeno 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '9528490', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20609474671' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '9528490', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 61: A2389001 / EMPRESA / Nitrógeno 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389001', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20609474671' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'A2389001', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 62: 26CQ004140 / EMPRESA / Nitrógeno 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26CQ004140', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '26CQ004140', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 63: LH03097 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'LH03097', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612446106' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'LH03097', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 64: 20K301185 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301185', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612446106' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K301185', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 65: 22K035044 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035044', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612446106' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K035044', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 66: 22K035087 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035087', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607980358' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K035087', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 67: 6041A / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6041A', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612446106' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '6041A', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 68: 161950 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '161950', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612446106' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '161950', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 69: 303206 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303206', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612446106' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303206', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 70: GTA217110 / EMPRESA / Dióxido de carbono 25 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217110', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480192932' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 25 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA217110', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 71: 21S495142 / EMPRESA / Dióxido de carbono 13 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21S495142', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20555041137' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 13 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21S495142', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 72: 20Y455019 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20Y455019', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20Y455019', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 73: 21X566177 / PLANTA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X566177', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21X566177', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 74: 21X647144 / PLANTA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X647144', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21X647144', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 75: J25635113 / PLANTA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'J25635113', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'J25635113', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 76: GTA217185 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217185', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-12-01', NULL,
  'GTA217185', NULL, NULL, FALSE,
  2020, 12,
  2000.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 77: YA20Y120160 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'YA20Y120160', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-06-01', NULL,
  'YA20Y120160', 56, NULL, FALSE,
  2020, 6,
  2800.0, 'CHINA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 78: 20S288088 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S288088', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20S288088', 59, NULL, FALSE,
  2020, 9,
  2000.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 79: 20E458094 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20E458094', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-07-01', NULL,
  '20E458094', 59, 67, FALSE,
  2020, 7,
  2800.0, 'CHINA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 80: 19S207165 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S207165', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-02-01', NULL,
  '19S207165', 59, 67, FALSE,
  2025, 2,
  2000.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 81: 539654 / EMPRESA / Dióxido de carbono 25 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '539654', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 25 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  '2024-05-01', NULL,
  '539654', NULL, 67, FALSE,
  2024, 5,
  NULL, 'AMERICANA', 'PH DE LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 82: 21Y734080 / PLANTA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y734080', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y734080', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 83: K4852107 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852107', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  'K4852107', 33, NULL, FALSE,
  2020, 8,
  NULL, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 84: YA20Y350143 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'YA20Y350143', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-10-01', NULL,
  'YA20Y350143', 56, NULL, FALSE,
  2025, 10,
  2800.0, 'CHINA', 'PH DE OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 85: 20K706112 / CLIENTE / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K706112', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20523386469' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K706112', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 86: 2748 / EMPRESA / Nitrógeno 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '2748', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-08-01', NULL,
  '2748', 60, NULL, FALSE,
  2025, 8,
  2000.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 87: 20K301091 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301091', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-09-01', NULL,
  '20K301091', 59, 67, FALSE,
  2025, 9,
  2800.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 88: 1479 / EMPRESA / Nitrógeno 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1479', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2026-03-01', NULL,
  '1479', NULL, NULL, FALSE,
  2026, 3,
  2000.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 89: 1530927 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1530927', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-03-01', NULL,
  '1530927', 57, NULL, FALSE,
  2025, 3,
  2800.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 90: 785002 / EMPRESA / Dióxido de carbono 25 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '785002', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 25 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  '2026-04-01', NULL,
  '785002', NULL, 67, FALSE,
  2026, 4,
  NULL, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 91: 774047 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '774047', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-03-01', NULL,
  '774047', 33, NULL, FALSE,
  2025, 3,
  2800.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 92: 1203370Y / EMPRESA / Nitrógeno 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1203370Y', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2023-10-01', NULL,
  '1203370Y', 60, 67, FALSE,
  2023, 10,
  2400.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 93: 20K301125 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301125', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  '2020-05-01', NULL,
  '20K301125', 59, 67, FALSE,
  2020, 5,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 94: 22K035041 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035041', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K035041', 59, 67, FALSE,
  2022, 1,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 95: V706007 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'V706007', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  '2021-05-01', NULL,
  'V706007', 33, NULL, FALSE,
  2021, 5,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 96: 263A / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '263A', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  '2023-10-01', NULL,
  '263A', NULL, NULL, FALSE,
  2023, 10,
  NULL, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 97: K4615199 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4615199', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  '2025-10-01', NULL,
  'K4615199', 33, NULL, FALSE,
  2025, 10,
  NULL, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 98: 336998 / EMPRESA / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '336998', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  '2025-08-01', NULL,
  '336998', NULL, 67, FALSE,
  2025, 8,
  NULL, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 99: J25635046 / PLANTA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'J25635046', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'J25635046', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 100: J25635025 / PLANTA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'J25635025', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'J25635025', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 101: K4860045 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860045', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-09-01', NULL,
  'K4860045', 33, 67, FALSE,
  2025, 9,
  2800.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 102: 22K035053 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035053', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K035053', 59, 67, FALSE,
  2022, 1,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 103: 21Y592193 / CLIENTE / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y592193', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y592193', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 104: K4780017 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4780017', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2026-04-01', NULL,
  'K4780017', 56, NULL, FALSE,
  2026, 4,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 105: J25055143 / PLANTA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'J25055143', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'J25055143', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 106: 780630 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '780630', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2023-07-01', NULL,
  '780630', 61, 67, FALSE,
  2023, 7,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 107: K4616006 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616006', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2020-07-01', NULL,
  'K4616006', 33, NULL, FALSE,
  2020, 7,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 108: 21Y788153 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y788153', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2022-02-01', NULL,
  '21Y788153', 56, NULL, FALSE,
  2022, 2,
  2800.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 109: 22K034018 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K034018', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K034018', 59, 67, FALSE,
  2022, 1,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 110: 21Y735053 / PLANTA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y735053', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y735053', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 111: 21X647186 / PLANTA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X647186', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21X647186', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 112: 21X631115 / PLANTA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X631115', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21X631115', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 113: 19S165083 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S165083', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-02-01', NULL,
  '19S165083', 59, NULL, FALSE,
  2025, 2,
  2000.0, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 114: 358165 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '358165', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '358165', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 115: 303195 (1475) / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303195 (1475)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '303195 (1475)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 116: 5068 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '5068', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '5068', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 117: 303212 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303212', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '303212', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 118: 303198 (303108) / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303198 (303108)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '303198 (303108)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 119: 13841769 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '13841769', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '13841769', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 120: 303187 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303187', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '303187', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 121: 206 (3A2015) / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '206 (3A2015)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '206 (3A2015)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 122: 50421 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '50421', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '50421', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 123: 21Y300121 / CLIENTE / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y300121', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20608134001' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y300121', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'CLINICA CURAY',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 124: K3481141 / CLIENTE / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K3481141', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '44556460' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K3481141', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 125: 4145 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '4145', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '4145', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 126: 397845 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '397845', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '397845', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 127: 3707 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '3707', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '3707', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PASADIZO',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 128: 21X085082 / CLIENTE / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X085082', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21X085082', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'OYOTUN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 129: 121Y359059 / CLIENTE / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y359059', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y359059', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'OYOTUN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 130: K5416001 / CLIENTE / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5416001', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5416001', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'OYOTUN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 131: K5714056 / CLIENTE / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5714056', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5714056', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'OYOTUN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 132: 3096270 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '3096270', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2023-07-01', NULL,
  '3096270', NULL, NULL, FALSE,
  2023, 7,
  NULL, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 133: 22X054098 / PLANTA / Etil 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22X054098', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Etil 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ETILENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '22X054098', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 134: 22X054048 / PLANTA / Etil 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22X054048', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Etil 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ETILENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '22X054048', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 135: 4193123 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '4193123', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2025-01-01', NULL,
  '4193123', 33, NULL, FALSE,
  2025, 1,
  2800.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 136: 31041 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '31041', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '31041', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 137: 22K034058 / CLIENTE / Dióxido de carbono 30 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K034058', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20607980358' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 30 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '22K034058', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 138: 1513416 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1513416', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-08-01', NULL,
  '1513416', NULL, NULL, FALSE,
  2025, 8,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 139: 20Y180078 / CLIENTE / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20Y180078', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20Y180078', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 140: 15454330 / CLIENTE / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '15454330', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '15454330', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 141: K5714095 / CLIENTE / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5714095', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5714095', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'OYOTUN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 142: 21Y195129 / CLIENTE / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y195129', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y195129', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'OYOTUN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 143: 121Y433048 / CLIENTE / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y433048', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20602694853' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y433048', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 144: 121Y252083 / CLIENTE / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y252083', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20602694853' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y252083', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 145: 121Y249091 / CLIENTE / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y249091', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20602694853' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y249091', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 146: 22K035123 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035123', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K035123', 59, NULL, FALSE,
  2022, 1,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 147: 20K646078 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646078', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20K646078', 59, 67, FALSE,
  2020, 9,
  2800.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 148: 6684734Y / CLIENTE / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6684734Y', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '000001' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-10-01', NULL,
  '6684734Y', NULL, 67, FALSE,
  2020, 10,
  2800.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 149: 20S287199 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S287199', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20S287199', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 150: Y303207 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y303207', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2020-10-01', NULL,
  'Y303207', NULL, 67, FALSE,
  2020, 10,
  NULL, 'AMERICANA', 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 151: 20S129171 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S129171', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '17621023' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  '2025-07-01', NULL,
  '20S129171', 59, NULL, FALSE,
  2025, 7,
  2000.0, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 152: 20S132010 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S132010', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-07-01', NULL,
  '20S132010', 59, NULL, FALSE,
  2025, 7,
  2000.0, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 153: 20E528088 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20E528088', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-10-01', NULL,
  '20E528088', NULL, NULL, FALSE,
  2025, 10,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 154: K4854158 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4854158', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-09-01', NULL,
  'K4854158', 33, NULL, FALSE,
  2025, 9,
  2800.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 155: 20K646182 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646182', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20K646182', 59, 67, FALSE,
  2020, 9,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 156: N847171 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N847171', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  'N847171', 58, 67, FALSE,
  2020, 9,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 157: 20K650053 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650053', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20K650053', 59, 62, FALSE,
  2020, 9,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 158: 20K467113 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K467113', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-07-01', NULL,
  '20K467113', 59, NULL, FALSE,
  2020, 7,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 159: 101354P / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '101354P', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '101354P', 61, 67, FALSE,
  2020, 9,
  2800.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 160: 20Y120137 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20Y120137', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-11-01', NULL,
  '20Y120137', 56, NULL, FALSE,
  2023, 11,
  2800.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 161: Y5204092 / PLANTA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y5204092', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-01-01', NULL,
  'Y5204092', NULL, NULL, FALSE,
  2025, 1,
  NULL, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 162: 20K301120 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301120', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-11-01', NULL,
  '20K301120', 59, NULL, FALSE,
  2025, 11,
  2800.0, NULL, 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 163: FC018030 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC018030', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2026-08-01', NULL,
  'FC018030', 34, NULL, FALSE,
  2026, 8,
  2800.0, NULL, 'PH ICP',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 164: 19S165153 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S165153', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-02-01', NULL,
  '19S165153', 59, 67, FALSE,
  2025, 2,
  2000.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 165: GA373195 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA373195', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  '2024-02-01', NULL,
  'GA373195', 33, 67, FALSE,
  2024, 2,
  2000.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 166: GTA217122 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217122', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  '2020-12-01', NULL,
  'GTA217122', 33, NULL, FALSE,
  2020, 12,
  2000.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 167: GA373132 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA373132', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2024-05-01', NULL,
  'GA373132', 33, NULL, FALSE,
  2024, 5,
  2000.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 168: GTA217074 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217074', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-11-01', NULL,
  'GTA217074', 33, 62, FALSE,
  2023, 11,
  2000.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 169: 20S290016 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290016', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20S290016', 59, NULL, FALSE,
  2020, 9,
  2000.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 170: GA373196 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA373196', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2024-05-01', NULL,
  'GA373196', 33, NULL, FALSE,
  2024, 5,
  2000.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 171: GTA217090 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217090', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-09-01', NULL,
  'GTA217090', 59, NULL, FALSE,
  2023, 9,
  2000.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 172: 20S288030 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S288030', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20S288030', 59, NULL, FALSE,
  2020, 9,
  2000.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 173: GA546105 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA546105', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2024-03-01', NULL,
  'GA546105', 33, 67, FALSE,
  2024, 3,
  2000.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 174: 19S207125 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S207125', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-02-01', NULL,
  '19S207125', 59, 67, FALSE,
  2025, 2,
  2000.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 175: GTA269186 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA269186', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2016-08-01', NULL,
  'GTA269186', 33, 67, FALSE,
  2016, 8,
  2000.0, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 176: 1001104 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1001104', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-09-01', NULL,
  '1001104', NULL, NULL, FALSE,
  2023, 9,
  NULL, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 177: 6658179Y / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6658179Y', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  '6658179Y', NULL, NULL, FALSE,
  2020, 8,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 178: J25642064 / PLANTA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'J25642064', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  225, NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607948675' AND estado = 1 LIMIT 1),
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'J25642064', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 179: 20K646017 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646017', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20K646017', 59, 67, FALSE,
  2020, 9,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 180: K4860070 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860070', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  'K4860070', 33, NULL, FALSE,
  2020, 8,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 181: FC019121 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019121', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-03-01', NULL,
  'FC019121', 34, NULL, FALSE,
  2021, 3,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 182: K4852041 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852041', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  'K4852041', 33, NULL, FALSE,
  2020, 8,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 183: K4871069 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4871069', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  'K4871069', 33, NULL, FALSE,
  2020, 9,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 184: 21Y281015 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y281015', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-05-01', NULL,
  '21Y281015', 56, NULL, FALSE,
  2021, 5,
  2800.0, 'CHINA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 185: 19X218057 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19X218057', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2019-09-01', NULL,
  '19X218057', NULL, 67, FALSE,
  2019, 9,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 186: 21K270141 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21K270141', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-04-01', NULL,
  '21K270141', 59, NULL, FALSE,
  2021, 4,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 187: 17K544050 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '17K544050', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-07-01', NULL,
  '17K544050', NULL, NULL, FALSE,
  2025, 7,
  2800.0, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 188: K5409130 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409130', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-02-01', NULL,
  'K5409130', NULL, NULL, FALSE,
  2021, 2,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 189: 20Y319140 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20Y319140', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  '20Y319140', NULL, NULL, FALSE,
  2020, 8,
  2800.0, 'CHINA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 190: 20E623128 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20E623128', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20E623128', NULL, 67, FALSE,
  2020, 9,
  2800.0, 'CHINA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 191: K5409170 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409170', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-02-01', NULL,
  'K5409170', 33, NULL, FALSE,
  2021, 2,
  2800.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 192: FC020080 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC020080', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-03-01', NULL,
  'FC020080', 34, NULL, FALSE,
  2021, 3,
  2800.0, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 193: FC019183 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019183', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-03-01', NULL,
  'FC019183', 34, NULL, FALSE,
  2021, 3,
  2800.0, 'CHINA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 194: 20X158065 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20X158065', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-07-01', NULL,
  '20X158065', 56, 67, FALSE,
  2020, 7,
  2800.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 195: K4853068 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853068', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  'K4853068', 33, NULL, FALSE,
  2020, 8,
  2800.0, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 196: A2389040 / EMPRESA / Oxígeno Medicinal 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389040', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2018-05-01', NULL,
  'A2389040', 33, NULL, FALSE,
  2018, 5,
  2000.0, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 197: A2389122 / EMPRESA / Oxígeno Medicinal 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389122', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2018-08-01', NULL,
  'A2389122', 33, NULL, FALSE,
  2018, 6,
  2000.0, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 198: 16927 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '16927', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '16927', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, 'CHINA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 199: A2389158 / EMPRESA / Oxígeno Medicinal 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389158', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2018-07-01', NULL,
  'A2389158', 33, NULL, FALSE,
  2018, 7,
  2000.0, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 200: 20Y446006 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20Y446006', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '41390177' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20Y446006', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 201: K4860100 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860100', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '41037767' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4860100', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 202: 121Y319060 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y319060', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16482081' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y319060', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 203: 303173 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303173', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '1997-05-01', NULL,
  '303173', NULL, NULL, FALSE,
  1997, 5,
  NULL, 'AMERICANA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 204: K4046581 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4046581', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2026-07-01', NULL,
  'K4046581', NULL, NULL, FALSE,
  2026, 7,
  NULL, 'AMERICANA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 205: 694554 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '694554', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2018-05-01', NULL,
  '694554', 58, NULL, FALSE,
  2018, 5,
  NULL, 'AMERICANA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 206: 18532 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '18532', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2016-01-01', NULL,
  '18532', NULL, NULL, FALSE,
  2016, 1,
  NULL, 'AMERICANA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 207: 413467 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '413467', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '41554093' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  '2016-10-01', NULL,
  '413467', NULL, NULL, FALSE,
  2016, 10,
  NULL, 'AMERICANA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 208: 20S290047 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290047', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20S290047', 59, NULL, FALSE,
  2020, 9,
  NULL, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 209: 331883 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '331883', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2019-12-01', NULL,
  '331883', NULL, NULL, FALSE,
  2019, 12,
  NULL, 'AMERICANA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 210: 2156 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '2156', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '2156', 60, NULL, FALSE,
  NULL, NULL,
  NULL, 'AMERICANA', 'CILINDROS PARA CANJE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 211: 21E426004 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21E426004', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2026-09-01', NULL,
  '21E426004', NULL, 67, FALSE,
  2026, 9,
  NULL, 'CHINA', 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 212: 380950 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '380950', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '380950', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, 'CHINA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 213: 1869 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1869', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2018-05-01', NULL,
  '1869', NULL, NULL, FALSE,
  2018, 5,
  NULL, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 214: 977491 / CLIENTE / DIOXIDO DE CARBONO 9 KG
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '977491', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20555041137' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('DIOXIDO DE CARBONO 9 KG')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '977491', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 215: 250034034 / CLIENTE / Acetileno de 8kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '250034034', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20451534107' AND estado = 1 LIMIT 1),
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20451534107' AND estado = 1 LIMIT 1), NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESPECIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '250034034', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 216: 5502016 / CLIENTE / Acetileno de 1 - 4 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '5502016', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '20103448591' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 1 - 4 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '5502016', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 217: N22650 (M411193) / CLIENTE / Acetileno de 1 - 4 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N22650 (M411193)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  224, (SELECT id FROM cli_clientes WHERE numero_documento = '17430623' AND estado = 1 LIMIT 1), NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 1 - 4 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'N22650 (M411193)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 218: M559533 / EMPRESA / Acetileno de 3.5 - 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M559533', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'M559533', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 219: 7352270 / EMPRESA / Acetileno de 8 - 10 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '7352270', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  '2017-01-01', NULL,
  '7352270', NULL, NULL, FALSE,
  2017, 1,
  NULL, NULL, 'VERIFICAR EL PH',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 220: M559503 / EMPRESA / Acetileno 1 - 3 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M559503', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno 1 - 3 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'M559503', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 221: M559499 / EMPRESA / Acetileno 1 - 3 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M559499', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  NULL, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno 1 - 3 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'M559499', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'NO SE ENCUENTRA EN ALMACÉN- EXCEL TIENE FECHA DE ÚLTIMO MOVIMIENTO 12-10-23 | POR VERIFICAR (carga inicial)',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 222: M559508 / EMPRESA / Acetileno 0 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M559508', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno 0 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'M559508', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 223: 15908 / EMPRESA / Acetileno 0 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '15908', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  221, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno 0 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '15908', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PACHECO NILTON 24-2-2026',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 224: 143525ED / EMPRESA / Acetileno de 3.5 - 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '143525ED', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20270453679' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '143525ED', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PODER DE CLIENTE DESDE 6-11-2025',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 225: 611437 / EMPRESA / Acetileno de 8 - 10 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '611437', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '611437', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 226: M735872 / EMPRESA / Acetileno de 3.5 - 5.5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M735872', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604078866' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5.5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'M735872', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'PODER DE CLIENTE DESDE 5-01-2026',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 227: 6046 / EMPRESA / Acetileno de 6 - 8 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6046', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 6 - 8 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '6046', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 228: 331161 / EMPRESA / Acetileno de 6 - 7.5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '331161', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20144364059' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 6 - 7.5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '331161', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 229: 0213336 / EMPRESA / Acetileno de 6 - 7.5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '0213336', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10190310839' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 6 - 7.5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '0213336', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 230: 673384 / EMPRESA / Acetileno de 7 - 9 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '673384', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103448591' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 7 - 9 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '673384', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 231: 666062 / EMPRESA / Acetileno de 7 - 9 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '666062', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20526140151' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 7 - 9 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '666062', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 232: 21748 / EMPRESA / Acetileno de 8 - 10 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21748', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21748', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 233: M559512 / EMPRESA / Acetileno de 3.5 - 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M559512', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'M559512', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 234: 434097 / EMPRESA / Acetileno de 4 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '434097', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 4 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '434097', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 235: 735228 / EMPRESA / Acetileno de 8 - 10 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '735228', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103626448' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '735228', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 236: 135 / EMPRESA / Acetileno 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '135', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480192932' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '135', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 237: 143451ED / EMPRESA / Acetileno de 3.5 - 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '143451ED', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20518304233' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '143451ED', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 238: M559534 / EMPRESA / Acetileno de 6 - 7.5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M559534', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103448591' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 6 - 7.5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'M559534', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 239: M427046 / EMPRESA / Acetileno de 8 - 10 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M427046', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'M427046', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 240: 666042 / EMPRESA / Acetileno de 7 - 9 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '666042', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 7 - 9 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '666042', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 241: 661053 / EMPRESA / Acetileno de 1 - 4 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '661053', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 1 - 4 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '661053', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 242: 673238 / EMPRESA / Acetileno de 7 - 9 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '673238', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 7 - 9 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '673238', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 243: 735229 / EMPRESA / Acetileno de 8 - 10 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '735229', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '735229', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 244: 58022 / EMPRESA / Acetileno de 6 - 7.5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '58022', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480823860' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 6 - 7.5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '58022', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 245: 143493ED / EMPRESA / Acetileno 1 - 3 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '143493ED', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno 1 - 3 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '143493ED', NULL, NULL, FALSE,
  2014, 11,
  NULL, NULL, 'REVISAR PH',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 246: 666070 / EMPRESA / Acetileno de 7 - 9 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '666070', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 7 - 9 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '666070', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 247: 242649 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '242649', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '242649', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 248: GA373138 / EMPRESA / Stargold Estandar de 7 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA373138', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16671957' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 7 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA373138', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 249: N846419 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N846419', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20174513245' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'N846419', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 250: GA972046 / EMPRESA / Stargold Estandar de 7 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA972046', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20602257470' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 7 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA972046', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 251: 114323 / EMPRESA / Stargold Estandar de 6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '114323', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10439328482' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '114323', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 252: 20K301188 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301188', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607756121' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K301188', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 253: 21K028015 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21K028015', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10448235012' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21K028015', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 254: 973008 / EMPRESA / Stargold Estandar de 7 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '973008', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480748710' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 7 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '973008', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 255: 20S129200 / EMPRESA / Stargold Estandar de 6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S129200', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10471465572' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S129200', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 256: 1222302 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1222302', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10448235012' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1222302', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 257: 20K304134 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K304134', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10448235012' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K304134', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 258: 291379 (2265) / EMPRESA / Stargold Estandar de 6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '291379 (2265)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '291379 (2265)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 259: 303214 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303214', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604078866' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303214', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 260: 20S130154 / EMPRESA / Stargold Estandar de 7 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S130154', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 7 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20S130154', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 261: K4852081 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852081', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20523386469' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4852081', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 262: Y8893054 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y8893054', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'Y8893054', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 263: 21Y737164 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y737164', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20610651691' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21Y737164', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 264: 26CQ002107 / EMPRESA / Stargold Estandar de 3 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26CQ002107', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20610025707' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 3 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '26CQ002107', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 265: 143441ED / EMPRESA / Acetileno de 3.5 - 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '143441ED', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '143441ED', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 266: 673174 / EMPRESA / Acetileno de 7 - 9 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '673174', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 7 - 9 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '673174', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 267: M559522 / EMPRESA / Acetileno de 3.5 - 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M559522', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'M559522', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 268: 251367 / EMPRESA / Acetileno de 6 - 7.5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '251367', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 6 - 7.5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '251367', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 269: M735785 / EMPRESA / Acetileno de 3.5 - 5 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M735785', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 3.5 - 5 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'M735785', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, 'REVISAR PH',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 270: 661088 / EMPRESA / Acetileno de 1 - 4 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '661088', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 1 - 4 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '661088', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 271: 661036 / EMPRESA / Acetileno de 1 - 4 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '661036', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 1 - 4 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '661036', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 272: 22323 / EMPRESA / Acetileno de 8 - 10 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22323', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604549401' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Acetileno de 8 - 10 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ACETILENO ESTANDAR')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '22323', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 273: 20E0457074 / EMPRESA / Stargold Estandar de 6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20E0457074', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20E0457074', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 274: 20S130147 / EMPRESA / Stargold Estandar de 6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S130147', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20563657376' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S130147', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 275: 20K304015 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K304015', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K304015', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 276: 265039 / EMPRESA / Stargold Estandar de 6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '265039', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '265039', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 277: K4853185 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853185', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '42080968' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4853185', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 278: GTA217086 / EMPRESA / Stargold Estandar de 7 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217086', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 7 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'GTA217086', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 279: K4616082 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616082', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4616082', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 280: 6187 / EMPRESA / Stargold Estandar de 6 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6187', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 6 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '6187', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 281: K4616094 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616094', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4616094', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 282: P126117 / EMPRESA / Stargold Estandar de 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'P126117', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Stargold Estandar de 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('STARGOLD ESTANDAR')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'P126117', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 283: 21X631099 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X631099', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21X631099', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 284: K4854098 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4854098', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4854098', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 285: FC018186 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC018186', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC018186', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 286: 116795 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '116795', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '116795', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 287: 6641000Y / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6641000Y', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '6641000Y', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 288: K4852153 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852153', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4852153', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 289: 672991 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '672991', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '672991', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 290: 50456 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '50456', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2008-04-01', NULL,
  '50456', NULL, NULL, FALSE,
  2008, 4,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 291: 653901 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '653901', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2011-05-01', NULL,
  '653901', NULL, NULL, FALSE,
  2011, 5,
  NULL, 'AMERICANA', NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 292: 1393 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1393', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2015-08-01', NULL,
  '1393', NULL, NULL, FALSE,
  2015, 8,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 294: 303174 / EMPRESA / Oxigeno Industrial 8 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303174', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-11-01', NULL,
  '303174', NULL, NULL, FALSE,
  2023, 11,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 295: 14858 / EMPRESA / Oxigeno Industrial 8 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '14858', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-11-02', NULL,
  '14858', NULL, 67, FALSE,
  2023, 11,
  NULL, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 296: K4852168 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852168', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-07-01', NULL,
  'K4852168', 33, NULL, FALSE,
  2025, 7,
  NULL, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 297: 20K624180 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K624180', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-09-01', NULL,
  '20K624180', 59, NULL, FALSE,
  2020, 9,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 298: K4806045 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4806045', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  'K4806045', 33, NULL, FALSE,
  2020, 8,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 299: FC0190675 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC0190675', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-03-01', NULL,
  'FC0190675', 34, NULL, FALSE,
  2021, 3,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 300: 8892053 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '8892053', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2022-07-01', NULL,
  '8892053', NULL, NULL, FALSE,
  2022, 7,
  NULL, 'AMERICANA', 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 302: 22K035139 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035139', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K035139', 59, NULL, FALSE,
  2022, 1,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 303: 22K036051 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K036051', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K036051', 59, NULL, FALSE,
  2022, 1,
  NULL, 'AMERICANA', 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 304: 21Y593075 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y593075', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2022-02-01', NULL,
  '21Y593075', 56, NULL, FALSE,
  2022, 2,
  NULL, 'AMERICANA', 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 305: 20K301197 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K301197', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-09-01', NULL,
  '20K301197', 59, NULL, FALSE,
  2025, 9,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 306: 22K035132 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035132', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K035132', 59, NULL, FALSE,
  2022, 1,
  NULL, 'AMERICANA', 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 307: 396522 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '396522', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-02-01', NULL,
  '396522', NULL, NULL, FALSE,
  2025, 2,
  NULL, 'AMERICANA', 'PH OXIGENO CRISTIAN',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 308: 157298 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '157298', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2025-07-01', NULL,
  '157298', NULL, 67, FALSE,
  2025, 7,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 309: K4852112 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852112', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2020-08-01', NULL,
  'K4852112', 33, NULL, FALSE,
  2020, 8,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 311: 20K646094 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646094', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2026-04-01', NULL,
  '20K646094', 59, NULL, FALSE,
  2026, 4,
  NULL, 'AMERICANA', 'PH SWISSGAS',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 312: 22K035154 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035154', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  '2022-01-01', NULL,
  '22K035154', 59, NULL, FALSE,
  2022, 1,
  NULL, 'AMERICANA', 'PH ORIGINAL',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 313: 2071169013 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '2071169013', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-09-01', NULL,
  '2071169013', 56, NULL, FALSE,
  2023, 9,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 314: Y9679078 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y9679078', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2024-11-01', NULL,
  'Y9679078', 33, 67, FALSE,
  2024, 11,
  NULL, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 315: 21K022182 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21K022182', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  '2021-01-01', NULL,
  '21K022182', 59, 67, FALSE,
  2021, 1,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 316: 20Y345150 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20Y345150', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2025-10-01', NULL,
  '20Y345150', 56, NULL, FALSE,
  2025, 10,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 317: 303179 / EMPRESA / Oxigeno Industrial 7 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303179', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 7 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2023-11-01', NULL,
  '303179', 60, 67, FALSE,
  2023, 11,
  NULL, NULL, 'PH LINDE',
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 318: 158900 / EMPRESA / Oxigeno Industrial 8 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '158900', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2022-07-01', NULL,
  '158900', NULL, NULL, FALSE,
  2022, 7,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 319: N1003176 / EMPRESA / Oxigeno Industrial 8 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N1003176', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  '2021-02-01', NULL,
  'N1003176', NULL, NULL, FALSE,
  2021, 2,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 320: 349527 / EMPRESA / Oxigeno Industrial 8 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '349527', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '349527', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 321: Y8894060 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y8894060', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'Y8894060', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 322: K2020272 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K2020272', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K2020272', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 323: 303213 (M850112) / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303213 (M850112)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '303213 (M850112)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 324: K5378169 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5378169', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5378169', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 325: K4852090 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852090', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4852090', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 326: K5606096 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5606096', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5606096', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 327: 20X160062 (P22567) / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20X160062 (P22567)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20X160062 (P22567)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 328: 121Y320130 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y320130', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y320130', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 329: 121Y318115 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y318115', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y318115', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 330: 150838 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '150838', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '150838', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 331: K4867013 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4867013', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4867013', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 332: K4852042 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852042', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4852042', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 333: 20K646126 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646126', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K646126', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 334: 121Y319045 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y319045', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y319045', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 335: K4860200 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860200', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4860200', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 336: LJD9041 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'LJD9041', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'LJD9041', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 337: 20K647080 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K647080', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K647080', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 338: 6666931Y (6666931) / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6666931Y (6666931)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '6666931Y (6666931)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 339: 121Y319019 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y319019', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y319019', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 340: 26Y066073 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26Y066073', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '26Y066073', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 341: 26Y066009 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26Y066009', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '26Y066009', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 342: 26Y066045 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26Y066045', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '26Y066045', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 343: 26Y066014 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26Y066014', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '26Y066014', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 344: 260360093 / EMPRESA / Oxigeno Medicinal 1.5 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '260360093', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Medicinal 1.5 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '260360093', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 345: 20590 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20590', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20590', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 346: FC017176 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC017176', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC017176', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 347: FC019150 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019150', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC019150', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 348: FC019067 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019067', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC019067', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 349: 18444 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '18444', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '18444', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 350: 12121435 / EMPRESA / Oxigeno Industrial 8 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '12121435', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '12121435', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 351: 303182 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303182', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '303182', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 352: 20K646066 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646066', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K646066', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 353: K4854028 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4854028', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4854028', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 354: K4615164 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4615164', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4615164', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 355: K4852091 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852091', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4852091', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 356: 20K646055 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646055', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K646055', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 357: K4860142 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860142', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4860142', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 358: 20K650076 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650076', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K650076', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 359: 498L / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '498L', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '498L', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 360: MG1227 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'MG1227', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'MG1227', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 361: K4860001 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860001', NULL, NULL,
  NULL, NULL,
  223, NULL, NULL,
  218, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4860001', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 362: 481861 / EMPRESA / Oxigeno Medicinal 1.5 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '481861', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Medicinal 1.5 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '481861', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 363: 1867438Y / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1867438Y', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '1867438Y', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 364: K5392023 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5392023', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5392023', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 365: AS1401411 / EMPRESA / Oxigeno Medicinal 1 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'AS1401411', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Medicinal 1 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'AS1401411', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 366: E055 / EMPRESA / Oxigeno Industrial 1 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'E055', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 1 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'E055', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 367: PG16288 / EMPRESA / Oxigeno Medicinal 1.5 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'PG16288', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Medicinal 1.5 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'PG16288', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 368: 40819 / EMPRESA / Oxigeno Medicinal 1.5 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '40819', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Medicinal 1.5 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '40819', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 369: 943251 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '943251', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '943251', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 370: 20S290101 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290101', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20S290101', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 371: BW880448 / EMPRESA / Oxigeno Medicinal 1 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'BW880448', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Medicinal 1 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'BW880448', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 372: BW880483 / EMPRESA / Oxigeno Medicinal 1 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'BW880483', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Medicinal 1 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'BW880483', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 373: K4616007 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616007', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4616007', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 374: 19S205108 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S205108', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '19S205108', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 375: 149385 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '149385', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '149385', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 376: GTA048048 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA048048', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'GTA048048', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 377: 20S290094 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290094', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20S290094', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 378: 19S207078 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S207078', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '19S207078', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 385: K5382048 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5382048', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5382048', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 386: 303190 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303190', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '303190', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 387: 20S290030 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290030', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20S290030', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 388: 20S290095 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290095', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20S290095', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 389: 20S288024 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S288024', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20S288024', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 390: 20S290114 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290114', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20S290114', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 391: B251459 / EMPRESA / Oxigeno Industrial 4 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'B251459', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 4 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'B251459', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 392: M4141 (100010) / EMPRESA / Dióxido de carbono 7 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'M4141 (100010)', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 7 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'M4141 (100010)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 393: 20S129035 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S129035', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20S129035', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 394: 469064 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '469064', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '469064', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 395: K4860181 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860181', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4860181', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 396: K4860050 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860050', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4860050', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 397: D3953176 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'D3953176', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'D3953176', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 398: 704057 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '704057', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '704057', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 399: 20K646168 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646168', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K646168', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 400: P22564 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'P22564', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'P22564', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 401: 20S129076 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S129076', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '20S129076', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 402: YA21Y059160 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'YA21Y059160', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'YA21Y059160', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 403: K5409185 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409185', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5409185', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 404: 20K447145 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K447145', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K447145', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 413: GA546018 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA546018', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10748757070' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA546018', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 414: 303215 (199166) / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303215 (199166)', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10748757070' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303215 (199166)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 415: 121Y319040 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y319040', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '44436445' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y319040', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 416: 2845E061 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '2845E061', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '46979641' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '2845E061', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 417: 43148 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '43148', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612747726' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '43148', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 418: 121Y318009 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y318009', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20608134001' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y318009', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 419: 303199 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303199', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607333875' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303199', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 420: 696659 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '696659', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000051' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '696659', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 421: 9762 / EMPRESA / Oxigeno Industrial 2.5 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '9762', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '07558654' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 2.5 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '9762', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 422: 20E460009 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20E460009', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '17432701' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20E460009', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 423: K5409119 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409119', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '17432701' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5409119', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 424: 21X647131 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21X647131', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '17432701' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21X647131', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 425: 343868 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '343868', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20601073316' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '343868', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 426: 4823820 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '4823820', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000053' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '4823820', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 427: 611274 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '611274', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20613421492' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '611274', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 428: FC018006 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC018006', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20608316419' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'FC018006', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 429: 20K650016 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650016', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20514134155' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K650016', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 430: 20K646062 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646062', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20514134155' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K646062', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 431: YA20Y367017 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'YA20Y367017', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20514134155' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'YA20Y367017', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 432: GTA048024 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA048024', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20338570041' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  221, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA048024', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 433: GTA048126 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA048126', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20338570041' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  221, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA048126', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 434: N2611848 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N2611848', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20338570041' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'N2611848', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 435: 1162471 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1162471', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20338570041' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '1162471', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 436: 19S207088 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S207088', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '47487670' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S207088', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 437: 15660 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '15660', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000054' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '15660', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 438: 20S132008 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S132008', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '44089512' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S132008', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 439: 20S288123 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S288123', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16764812' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S288123', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 440: 126145 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '126145', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000055' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '126145', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 441: 1967938 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1967938', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000056' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1967938', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 442: 27 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '27', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000057' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '27', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 443: 19S208028 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S208028', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16454507' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S208028', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 444: N240039 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N240039', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20609158264' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'N240039', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 445: N825948 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N825948', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20601042151' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'N825948', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 446: EC043035 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'EC043035', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'EC043035', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 447: YA20Y504028 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'YA20Y504028', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'YA20Y504028', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 448: 8999060 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '8999060', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  '8999060', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 449: A2389096 / EMPRESA / Dióxido de carbono 13 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389096', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 13 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'A2389096', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 450: GA784176 / EMPRESA / Dióxido de carbono 25 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA784176', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20536698834' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dióxido de carbono 25 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 217,
  NULL, NULL,
  'GA784176', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 451: 303205 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303205', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20516367670' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303205', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 452: 303211 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303211', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20516367670' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303211', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 453: 303104 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303104', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20516367670' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303104', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 454: K4616092 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616092', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000058' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4616092', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 455: 121Y320062 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y320062', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607710385' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y320062', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 456: 20Y335128 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20Y335128', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '45831341' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20Y335128', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 457: 911145 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '911145', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20270453679' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '911145', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 458: FC019160 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC019160', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20607756121' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'FC019160', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 459: 39570 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '39570', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10165243299' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '39570', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 460: 20S129060 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S129060', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000059' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S129060', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 461: 19S206111 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S206111', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000059' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S206111', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 462: 20S130068 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S130068', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '44591416' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S130068', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 463: 156596 / EMPRESA / Oxigeno Industrial 8 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '156596', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16667648' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 8 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '156596', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 464: GTA217172 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217172', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16667648' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA217172', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 465: 1162125 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1162125', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000060' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1162125', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 466: 20S290064 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290064', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000061' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S290064', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 467: K4854156 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4854156', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20608006738' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4854156', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 468: Y9679068 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y9679068', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20608006738' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'Y9679068', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 469: Y8894112 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y8894112', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20608006738' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'Y8894112', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 470: K4860009 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860009', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16747813' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4860009', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 471: K4860024 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860024', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16747813' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4860024', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 472: K4632027 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4632027', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10448235012' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4632027', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 473: K4860088 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860088', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '29268940' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4860088', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 474: 21K024089 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21K024089', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000040' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21K024089', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 475: 20K454202 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K454202', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20523386469' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K454202', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 476: K4853076 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853076', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20523386469' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4853076', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 477: K4364150 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4364150', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20523386469' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4364150', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 478: K5409190 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409190', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20523386469' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5409190', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 479: 20S130032 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S130032', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16530972' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S130032', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 480: 20S290102 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290102', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20602375383' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S290102', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 481: AS1439247 / EMPRESA / Oxigeno Industrial 1 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'AS1439247', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20602375383' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 1 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'AS1439247', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 482: 1549 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1549', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20604078866' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1549', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 483: YA20X193181 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'YA20X193181', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20601783372' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'YA20X193181', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 484: 303183 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303183', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16563500' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303183', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 485: LHP3048 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'LHP3048', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20526140151' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'LHP3048', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 486: 194073116 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '194073116', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000041' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '194073116', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 487: 358308 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '358308', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176008763' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '358308', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 488: 1299 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1299', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000042' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1299', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 489: N540609 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N540609', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'N540609', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 490: GTA217117 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217117', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA217117', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 491: 20S290104 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290104', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S290104', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 492: GA546022 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA546022', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA546022', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 493: N352343 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N352343', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'N352343', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 494: 5568 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '5568', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '5568', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 495: 303172 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303172', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176242073' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303172', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 496: K4853175 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853175', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4853175', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 497: K4864082 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4864082', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4864082', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 498: K4852047 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852047', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4852047', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 499: EC210036 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'EC210036', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'EC210036', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 500: 20K647017 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K647017', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K647017', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 501: 22K035185 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035185', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '22K035185', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 502: 21Y598109 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y598109', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y598109', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 503: 20K650018 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650018', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K650018', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 504: Y8894049 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y8894049', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'Y8894049', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 505: 00575 / EMPRESA / DIOXIDO DE CARBONO 3 KG
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '00575', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('DIOXIDO DE CARBONO 3 KG')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '00575', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 506: K5713102 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5713102', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5713102', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 507: K5434104 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5434104', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5434104', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 508: 21Y058054 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y058054', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y058054', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 509: 22K036011 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K036011', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '22K036011', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 510: 24655 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '24655', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN LAMBAYEQUE')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '24655', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 511: K5392021 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5392021', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5392021', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 512: U388694 / EMPRESA / Oxigeno Industrial 2 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'U388694', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 2 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'U388694', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 513: GTA048137 / EMPRESA / DIOXIDO DE CARBONO 9 KG
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA048137', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('DIOXIDO DE CARBONO 9 KG')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'GTA048137', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 514: SG19934 / EMPRESA / Oxigeno Industrial de 1.5 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'SG19934', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial de 1.5 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'SG19934', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 515: E57888 / EMPRESA / Oxigeno Industrial de 1.5 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'E57888', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial de 1.5 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'E57888', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 516: K4852139 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852139', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4852139', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 517: K5409141 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409141', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5409141', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 518: 9622 / EMPRESA / Oxigeno Industrial 2.5 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '9622', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 2.5 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '9622', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 519: 816257 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '816257', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '816257', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 520: E337123 / EMPRESA / Oxigeno Industrial de 1.5 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'E337123', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial de 1.5 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'E337123', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 521: K4853006 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853006', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4853006', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 522: K5713054 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5713054', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5713054', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 523: 20X289026 (PW200) / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20X289026 (PW200)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20X289026 (PW200)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 524: H24919 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'H24919', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'H24919', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 525: A641 (GTA641) / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A641 (GTA641)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'A641 (GTA641)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 526: AS453840 / EMPRESA / Oxigeno Industrial de 1.5 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'AS453840', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial de 1.5 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'AS453840', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 527: 20S129201 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S129201', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20S129201', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 528: A592 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A592', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'A592', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 529: K5714008 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5714008', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5714008', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 530: 373680 / EMPRESA / Nitrógeno 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '373680', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '373680', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 531: 20K650038 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650038', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K650038', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 532: FC017042 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC017042', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'FC017042', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 533: 88800173 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '88800173', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '88800173', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 534: K392006 (303216) / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K392006 (303216)', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K392006 (303216)', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 535: AS3273644 / EMPRESA / DIOXIDO DE CARBONO 3 KG
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'AS3273644', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('DIOXIDO DE CARBONO 3 KG')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'AS3273644', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 536: K4853138 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853138', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4853138', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 537: 121Y318140 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y318140', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y318140', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 538: 121Y318059 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y318059', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '121Y318059', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 539: 134585 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '134585', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '134585', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 540: K4860139 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860139', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4860139', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 541: 20K646089 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646089', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K646089', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 542: 21Y060032 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21Y060032', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '21Y060032', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 543: 20K650005 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650005', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K650005', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 544: 20M089004 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20M089004', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20M089004', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 545: 1485989 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1485989', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '1485989', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 546: K4860090 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860090', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4860090', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 547: 20K646127 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646127', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K646127', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 548: K4854162 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4854162', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4854162', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 549: AS1449415 / EMPRESA / Oxigeno Industrial de 1.5 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'AS1449415', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial de 1.5 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'AS1449415', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 550: K5714052 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5714052', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5714052', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 551: 20K650007 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650007', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K650007', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 552: K4853140 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853140', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4853140', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 553: K5606146 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5606146', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K5606146', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 554: 20K646167 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646167', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '20K646167', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 555: 3135616 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '3135616', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  '3135616', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 556: K4861108 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4861108', NULL, NULL,
  (SELECT id FROM gen_almacen WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('ALMACEN PRINCIPAL')) AND estado = 1 LIMIT 1), NULL,
  223, NULL, NULL,
  219, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 358,
  NULL, NULL,
  'K4861108', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 557: 19S205140 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S205140', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '44491850' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S205140', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 558: 125398 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '125398', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10164549831' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '125398', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 559: 21K274118 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21K274118', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16739420' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21K274118', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 560: 9141253 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '9141253', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10167643812' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '9141253', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 561: 20K650031 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650031', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '29646105' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K650031', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 562: AS1290638 / EMPRESA / Oxigeno Industrial 1 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'AS1290638', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '44377974' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 1 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'AS1290638', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 563: 311116 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '311116', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176064183' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '311116', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 564: 4156802 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '4156802', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176064183' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '4156802', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 565: 194073111 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '194073111', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10037018738' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '194073111', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 566: 20K646041 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646041', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176032800' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K646041', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 567: EC059086 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'EC059086', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10176032800' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'EC059086', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 568: N261197 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'N261197', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000043' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'N261197', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 569: K4795010 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4795010', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4795010', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 570: Y5734141 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'Y5734141', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'Y5734141', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 571: 20X192063 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20X192063', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20X192063', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 572: K4853091 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853091', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4853091', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 573: K4854121 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4854121', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4854121', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 574: 121Y320093 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y320093', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y320093', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 575: 121Y319008 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y319008', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y319008', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 576: 121Y319050 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y319050', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103324948' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y319050', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 577: FC017178 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC017178', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561370762' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'FC017178', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 578: A2389171 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389171', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561370762' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'A2389171', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 579: 6641120Y / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6641120Y', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561359441' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '6641120Y', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 580: 121Y320102 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '121Y320102', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561359441' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '121Y320102', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 581: 20K650003 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650003', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561359441' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K650003', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 582: K4852108 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852108', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561359441' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4852108', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 583: 19S205054 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S205054', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16676149' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S205054', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 584: 389324 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '389324', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '389324', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 585: GA546159 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA546159', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA546159', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 586: 20S290056 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290056', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S290056', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 587: GA373149 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA373149', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA373149', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 588: 20S130092 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S130092', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480725931' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S130092', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 589: 382736 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '382736', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000044' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '382736', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 590: 96740 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '96740', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '47067456' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '96740', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 591: 156672 / EMPRESA / Oxigeno Industrial 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '156672', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10166403486' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '156672', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 592: FC018174 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'FC018174', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '90000386' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'FC018174', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 593: K4616144 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616144', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '90000386' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4616144', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 594: K4616154 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616154', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000045' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4616154', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 595: J25642136 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'J25642136', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '90000386' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'J25642136', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 596: 303194 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303194', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000046' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303194', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 597: 20X161130 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20X161130', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000047' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20X161130', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 598: 20S290065 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290065', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000048' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S290065', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 599: 20S130067 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S130067', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16456285' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S130067', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 600: 26CQ004189 / EMPRESA / Nitrógeno 3 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '26CQ004189', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20611929596' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 3 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '26CQ004189', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 601: 303209 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303209', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16688260' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303209', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 602: 5899 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '5899', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10403521197' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '5899', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 603: 19S207007 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S207007', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10403521197' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S207007', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 604: 302354 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '302354', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20612690007' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '302354', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 605: 19S206053 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S206053', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000049' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S206053', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 606: 20K646081 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646081', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10167238195' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K646081', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 607: K5409176 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409176', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20103626448' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5409176', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 608: 19S205109 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S205109', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000018' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S205109', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 609: A2389038 / EMPRESA / Dioxido de Carbono de 12 kg
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'A2389038', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000050' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Dioxido de Carbono de 12 kg')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('DIÓXIDO DE CARBONO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'A2389038', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 610: K4983032 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4983032', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480192932' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4983032', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 611: 20X306094 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20X306094', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480192932' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20X306094', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 612: 20S129184 / EMPRESA / Oxígeno Medicinal 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S129184', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20611122013' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S129184', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 613: GA784156 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA784156', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10402505643' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA784156', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 614: 1187759 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1187759', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10402505643' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1187759', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 615: 19S205079 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S205079', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561169404' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S205079', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 616: 4117403 / EMPRESA / Nitrógeno 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '4117403', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20561169404' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Nitrógeno 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('NITROGENO')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '4117403', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 617: 20S290071 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S290071', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '41026210' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S290071', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 618: GTA217121 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GTA217121', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10471465572' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GTA217121', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 619: 21K022117 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '21K022117', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16482081' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '21K022117', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 620: 20K650004 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K650004', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '44556460' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K650004', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 621: 20S288180 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20S288180', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '45172067' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20S288180', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 622: 19S207103 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S207103', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '17621023' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S207103', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 623: 19S165072 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S165072', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10477042347' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S165072', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 624: 1205 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '1205', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10477042347' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '1205', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 625: 20K633010 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K633010', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10433676349' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K633010', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 626: 214963 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '214963', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '42781779' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '214963', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 627: YA20Y334177 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'YA20Y334177', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '43626737' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'YA20Y334177', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 628: K4852160 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852160', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '43626737' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4852160', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 629: 303180 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303180', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16413826' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303180', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 630: 0303 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '0303', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000062' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '0303', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 631: 303181 / EMPRESA / Oxigeno Industrial 7 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303181', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '40518031' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 7 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303181', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 632: 303192 / EMPRESA / Oxigeno Industrial 7 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303192', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '40518031' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 7 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303192', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 633: 303196 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '303196', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '80542803' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '303196', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 634: 20K646192 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K646192', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20601110661' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K646192', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 635: 19S205168 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S205168', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16530919' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S205168', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 636: 20K684148 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K684148', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20174513245' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K684148', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 637: 20K709121 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '20K709121', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20174513245' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '20K709121', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 638: K4616005 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4616005', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20174513245' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4616005', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 639: K4842039 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4842039', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20174513245' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4842039', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 640: K4853011 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853011', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20174513245' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4853011', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 641: K4852092 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4852092', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20174513245' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4852092', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 642: 6679781Y / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6679781Y', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480319860' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '6679781Y', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 643: 155737 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '155737', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20480319860' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '155737', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 644: GA373189 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA373189', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '00001' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA373189', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 645: 14918 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '14918', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '00001' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '14918', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 646: AS1440000 / EMPRESA / Oxigeno Industrial 1 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'AS1440000', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '40446471' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 1 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'AS1440000', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 647: K5434029 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5434029', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '17522246' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5434029', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 648: EC044029 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'EC044029', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'EC044029', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 649: LH03191 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'LH03191', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'LH03191', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 650: K5392019 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5392019', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5392019', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 651: 6640848Y / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '6640848Y', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20615458440' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '6640848Y', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 652: 19S206027 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '19S206027', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10190310839' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '19S206027', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 653: 22K035136 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K035136', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20611355239' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K035136', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 654: K4860192 / EMPRESA / Argón Estándar 10 m3
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860192', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '20611355239' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Argón Estándar 10 m3')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('ARGON')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4860192', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 655: K4853132 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4853132', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '42715935' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4853132', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 656: K5409108 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5409108', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '42715935' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5409108', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 657: 99961 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '99961', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '000063' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '99961', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 658: 3949 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '3949', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '48189363' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '3949', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 659: GA547015 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA547015', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10483897940' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA547015', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 660: GA547012 / EMPRESA / Oxígeno Industrial 6 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'GA547012', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10483897940' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 6 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'GA547012', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 661: 22K034102 / EMPRESA / Oxígeno Industrial 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '22K034102', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '10483897940' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Industrial 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '22K034102', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 662: K4860167 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K4860167', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '16475399' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K4860167', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 663: 9704 / EMPRESA / Oxigeno Industrial 2.5 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  '9704', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '71201541' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxigeno Industrial 2.5 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO INDUSTRIAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  '9704', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;

-- Excel fila 664: K5715193 / EMPRESA / Oxígeno Medicinal 10 m³
INSERT INTO bal_balon (
  codigo_balon, libro_cilindro, pagina_libro,
  id_almacen, id_cliente_ubicacion,
  id_propietario, id_cliente_propietario, id_planta,
  id_referencia, id_tipo_balon, id_producto_gas, id_estado_balon,
  fecha_ultima_prueba_hidrostatica, fecha_proxima_prueba_hidrostatica,
  numero_serie, id_marca_cilindro, id_organo_inspector, organo_inspector_no_aplica,
  anio_fabricacion, mes_fabricacion,
  presion_actual, tipo_valvula, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  'K5715193', NULL, NULL,
  NULL, (SELECT id FROM cli_clientes WHERE numero_documento = '71201541' AND estado = 1 LIMIT 1),
  223, NULL, NULL,
  220, (SELECT id FROM bal_tipo_balon WHERE UPPER(TRIM(nombre)) = UPPER(TRIM('Oxígeno Medicinal 10 m³')) AND estado = 1 LIMIT 1), (SELECT id FROM pro_producto WHERE es_gas = TRUE AND UPPER(TRIM(nombre)) = UPPER(TRIM('OXIGENO MEDICINAL')) AND estado = 1 LIMIT 1), 191,
  NULL, NULL,
  'K5715193', NULL, NULL, FALSE,
  NULL, NULL,
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (codigo_balon) DO NOTHING;
SELECT setval(pg_get_serial_sequence('bal_balon', 'id'), COALESCE((SELECT MAX(id) FROM bal_balon), 1), true);

COMMIT;
