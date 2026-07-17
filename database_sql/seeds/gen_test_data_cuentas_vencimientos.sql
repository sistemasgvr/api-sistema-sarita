

-- Cuenta BCP empresa
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, numero_cuenta, numero_cuenta_interbancaria, es_principal, id_usuario_creacion)
SELECT 1, b.id, tc.id, 'RUIZ DE LOS SANTOS HAYDEE', '30515162800047', '00230511516280004713', TRUE, 1
FROM gen_lista_opciones b, gen_lista_opciones tc
WHERE b.nombre = 'BCP' AND tc.nombre = 'AHORROS'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE numero_cuenta = '30515162800047');

-- Cuenta BBVA empresa
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, numero_cuenta, numero_cuenta_interbancaria, es_principal, id_usuario_creacion)
SELECT 5, b.id, tc.id, 'VARIAS RUIZ GIANCARLO JAVIER', '001107960200180312', '01179600020018031207', FALSE, 1
FROM gen_lista_opciones b, gen_lista_opciones tc
WHERE b.nombre = 'BBVA' AND tc.nombre = 'CORRIENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE numero_cuenta = '001107960200180312');

-- Cuenta Interbank empresa
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, numero_cuenta, numero_cuenta_interbancaria, es_principal, id_usuario_creacion)
SELECT 1, b.id, tc.id, 'VARIAS RUIZ GIANCARLO JAVIER', '7123243857101', '00371201324385710171', FALSE, 1
FROM gen_lista_opciones b, gen_lista_opciones tc
WHERE b.nombre = 'INTERBANK' AND tc.nombre = 'AHORROS'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE numero_cuenta = '7123243857101');

-- Cuenta Scotiabank empresa
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, numero_cuenta, numero_cuenta_interbancaria, es_principal, id_usuario_creacion)
SELECT 14, b.id, tc.id, 'VARIAS RUIZ GIANCARLO JAVIER', '7208838719', '00940920720883871943', FALSE, 1
FROM gen_lista_opciones b, gen_lista_opciones tc
WHERE b.nombre = 'SCOTIABANK' AND tc.nombre = 'AHORROS'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE numero_cuenta = '7208838719');

-- Yape empresa
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, telefono_billetera, es_principal, id_usuario_creacion)
SELECT 1, NULL, tc.id, 'RUIZ DE LOS SANTOS HAYDEE', '964069607', FALSE, 1
FROM gen_lista_opciones tc
WHERE tc.nombre = 'YAPE'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE telefono_billetera = '964069607' AND id_tipo_cuenta = tc.id);

-- Plin empresa
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, telefono_billetera, es_principal, id_usuario_creacion)
SELECT 1, NULL, tc.id, 'VARIAS RUIZ GIANCARLO JAVIER', '964069607', FALSE, 1
FROM gen_lista_opciones tc
WHERE tc.nombre = 'PLIN'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE telefono_billetera = '964069607' AND id_tipo_cuenta = tc.id);

-- ============================================================
-- 3. gen_cuenta_bancaria — CUENTAS DE CLIENTES (id_cliente NOT NULL)
-- ============================================================
-- Reemplazar id_cliente con IDs reales de cli_clientes.

-- Cliente 1: BCP
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, numero_cuenta, numero_cuenta_interbancaria, es_principal, id_usuario_creacion)
SELECT c.id, b.id, tc.id, c.razon_social, '1234567890123456', '0021234567890123456789', TRUE, 1
FROM cli_clientes c, gen_lista_opciones b, gen_lista_opciones tc
WHERE c.id = 1 AND b.nombre = 'BCP' AND tc.nombre = 'CORRIENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE id_cliente = 1 AND numero_cuenta = '1234567890123456');

-- Cliente 1: Yape
INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, titular, telefono_billetera, es_principal, id_usuario_creacion)
SELECT c.id, NULL, tc.id, c.razon_social, '987654321', FALSE, 1
FROM cli_clientes c, gen_lista_opciones tc
WHERE c.id = 1 AND tc.nombre = 'YAPE'
  AND NOT EXISTS (SELECT 1 FROM gen_cuenta_bancaria WHERE id_cliente = 1 AND telefono_billetera = '987654321');

-- ============================================================
-- 4. gen_documento_vencimiento
-- ============================================================
-- Ajustar id_categoria / id_estado según IDs reales.
-- id_vehiculo NOT NULL = asociado a un vehículo; NULL = documento general.

-- SOAT CAMION (asumiendo que existe un vehículo con placa M4F782)
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, fecha_renovacion, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'CAMION - SOAT', v.id, '2025-08-26', '2025-07-01', 'SOAT-2025-001', est.id, 1
FROM gen_lista_opciones cat, gen_vehiculo v, gen_lista_opciones est
WHERE cat.nombre = 'SOAT' AND v.placa = 'T3R-890' AND est.nombre = 'VIGENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion = 'CAMION - SOAT');

-- Inspección vehicular CAMION
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, fecha_renovacion, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'CAMION - INSPECCION VEHICULAR', v.id, '2025-01-24', NULL, 'ITV-2025-001', est.id, 1
FROM gen_lista_opciones cat, gen_vehiculo v, gen_lista_opciones est
WHERE cat.nombre = 'INSPECCION' AND v.placa = 'M4F782' AND est.nombre = 'VENCIDO'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion = 'CAMION - INSPECCION VEHICULAR');

-- SOAT MOTO CARGUERA
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'MOTO CARGUERA - SOAT', v.id, '2025-05-08', 'SOAT-2025-002', est.id, 1
FROM gen_lista_opciones cat, gen_vehiculo v, gen_lista_opciones est
WHERE cat.nombre = 'SOAT' AND v.placa = 'ABF-123' AND est.nombre = 'VIGENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion = 'MOTO CARGUERA - SOAT');

-- SOAT MOTOTAXI
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'MOTOTAXI - SOAT', v.id, '2025-01-22', 'SOAT-2025-003', est.id, 1
FROM gen_lista_opciones cat, gen_vehiculo v, gen_lista_opciones est
WHERE cat.nombre = 'SOAT' AND v.placa = 'ABD-EMMANUEL' AND est.nombre = 'VENCIDO'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion = 'MOTOTAXI - SOAT');

-- SOAT MOTO LINEAL
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'MOTO LINEAL - SOAT', v.id, '2025-06-06', 'SOAT-2025-004', est.id, 1
FROM gen_lista_opciones cat, gen_vehiculo v, gen_lista_opciones est
WHERE cat.nombre = 'SOAT' AND v.placa = 'ABF-123' AND est.nombre = 'POR_VENCER'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion = 'MOTO LINEAL - SOAT');

-- Certificado de Salubridad (documento general, sin vehículo)
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'CERTIFICADO DE SALUBRIDAD', NULL, '2025-09-06', 'SALUB-2025-001', est.id, 1
FROM gen_lista_opciones cat, gen_lista_opciones est
WHERE cat.nombre = 'CERTIFICADO' AND est.nombre = 'VIGENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion = 'CERTIFICADO DE SALUBRIDAD');

-- BPA (documento general)
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'BPA - BUENAS PRACTICAS DE ALMACENAMIENTO', NULL, '2026-10-06', 'BPA-2024-001', est.id, 1
FROM gen_lista_opciones cat, gen_lista_opciones est
WHERE cat.nombre = 'CERTIFICADO' AND est.nombre = 'VIGENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion LIKE 'BPA%');

-- Extintor
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, fecha_renovacion, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'EXTINTOR - LOCAL PRINCIPAL', NULL, '2025-12-01', '2025-11-15', 'EXT-2025-001', est.id, 1
FROM gen_lista_opciones cat, gen_lista_opciones est
WHERE cat.nombre = 'SEGURIDAD' AND est.nombre = 'VIGENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion = 'EXTINTOR - LOCAL PRINCIPAL');

-- Inspección técnica municipal
INSERT INTO gen_documento_vencimiento (id_categoria, descripcion, id_vehiculo, fecha_vencimiento, numero_documento, id_estado, id_usuario_creacion)
SELECT cat.id, 'CERTIFICADO DE INSPECCION TECNICA - MUNICIPALIDAD', NULL, '2026-09-03', 'MUNI-2026-001', est.id, 1
FROM gen_lista_opciones cat, gen_lista_opciones est
WHERE cat.nombre = 'MUNICIPAL' AND est.nombre = 'VIGENTE'
  AND NOT EXISTS (SELECT 1 FROM gen_documento_vencimiento WHERE descripcion LIKE '%INSPECCION TECNICA%');

SELECT 'TEST DATA INSERTED SUCCESSFULLY' AS mensaje;
