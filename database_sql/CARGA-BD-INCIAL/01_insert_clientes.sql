-- =============================================================================
-- Carga inicial de CLIENTES (cli_clientes + cli_direcciones principales)
-- Generado desde: LlenadoDatos.xlsx / hoja Clientes
-- Listas resueltas con: exports/dump-2026-09-29-21-16-37
-- =============================================================================
-- Mapeo de listas (solo estado=1):
--   TipoDocumento: {"DNI": 4, "RUC": 5, "CE": 6, "SD": 271}
--   TipoPersona:   {"PERSONA NATURAL": 176, "PERSONA JURÍDICA": 177}
--   TipoCliente:   {"CLIENTE": 1, "PACIENTE": 2, "PROVEEDOR": 3, "CLIENTE / PROVEEDOR": 175}
-- -----------------------------------------------------------------------------
-- Filas Excel leidas (desde fila 5): 257
-- Inserts generados: 256
-- Rechazadas: 1 (ver 01_insert_clientes_reporte.json)
-- Direcciones principales: 6
-- id_usuario_creacion: 1
-- =============================================================================

BEGIN;

SET TIME ZONE 'America/Lima';

-- Excel fila 5: ACEROX GUZMAN S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ACEROX GUZMAN S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20608006738',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 6: AGUILAR HERRERA EDILBERTO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'AGUILAR HERRERA EDILBERTO', 1, 177,
  NULL, NULL, NULL,
  5, '10448235012',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 7: AIRPROJECT & CARBIDE PERU S.A.C. - AIRPROJECT & CARBIDE S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'AIRPROJECT & CARBIDE PERU S.A.C. - AIRPROJECT & CARBIDE S.A.C.', 3, 177,
  NULL, NULL, NULL,
  5, '20604549401',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 8: ALIAZIONE COSTRUZIONE E SALDATURA E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ALIAZIONE COSTRUZIONE E SALDATURA E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20480823860',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 9: CARLOS ALBERTO ALFARO ACUÑA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CARLOS ALBERTO', 'ALFARO', 'ACUÑA',
  4, '41390177',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 10: JULIO CESAR SANTAMARIA CHAPOÑAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JULIO CESAR', 'SANTAMARIA', 'CHAPOÑAN',
  4, '41554093',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 11: MYRIAM ERLINDA SALDARRIAGA MEJIA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MYRIAM ERLINDA', 'SALDARRIAGA', 'MEJIA',
  4, '16482081',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 12: ROSARIO DEL PILAR ROJAS CABRERA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ROSARIO DEL PILAR', 'ROJAS', 'CABRERA',
  4, '41037767',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 13: ALTAVISTA INVERSIONES GLOBALES SOCIEDAD ANONIMA CERRADA - AIG S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ALTAVISTA INVERSIONES GLOBALES SOCIEDAD ANONIMA CERRADA - AIG S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20523386469',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 14: ANGELES CASTRO ELVIN WANDER
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ANGELES CASTRO ELVIN WANDER', 1, 176,
  NULL, NULL, NULL,
  4, '45370902',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 15: DAVID VALDERA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DAVID', 'VALDERA', NULL,
  271, '00001',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 16: ARGAMAX CONSTRUCTORA CORPORATION S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ARGAMAX CONSTRUCTORA CORPORATION S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20604078866',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 17: EDGAR RONAL BRAVO SANTAMARIA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'EDGAR RONAL', 'BRAVO', 'SANTAMARIA',
  4, '76881055',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 18: AUTOMAN CHICLAYO E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'AUTOMAN CHICLAYO E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20526140151',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 19: B & V CONSTRUCCIONES METALICAS Y SERVICIOS GENERALES S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'B & V CONSTRUCCIONES METALICAS Y SERVICIOS GENERALES S.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20480748710',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 20: BANCES DE LA CRUZ JUAN MANUEL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'BANCES DE LA CRUZ JUAN MANUEL', 1, 176,
  NULL, NULL, NULL,
  5, '10176242073',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 21: COMERCIAL FRIONORTE E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'COMERCIAL FRIONORTE E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20480725931',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 22: CONSTRUCTORA BRIAMONTE E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CONSTRUCTORA BRIAMONTE E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20602694853',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 23: CORREA QUINTOS JACINTO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CORREA QUINTOS JACINTO', 1, 176,
  NULL, NULL, NULL,
  4, '41079206',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 24: EL CANTARO DE JUANITA S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'EL CANTARO DE JUANITA S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20555041137',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 25: EMPRESA DE TRANSPORTES CHICLAYO S.A.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'EMPRESA DE TRANSPORTES CHICLAYO S.A.', 1, 177,
  NULL, NULL, NULL,
  5, '20103626448',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 26: EMPRESA PRESTADORA DE SERVICIOS DE SANEAMIENTO DE AGUA POTABLE Y ALCANTARILLADO DE LAMBAYEQUE S.A.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'EMPRESA PRESTADORA DE SERVICIOS DE SANEAMIENTO DE AGUA POTABLE Y ALCANTARILLADO DE LAMBAYEQUE S.A.', 1, 177,
  NULL, NULL, NULL,
  5, '20103448591',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 27: ENERGIAS RS E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ENERGIAS RS E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20608737848',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 28: ESCOBAR PROYECTOS GENERALES S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ESCOBAR PROYECTOS GENERALES S.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20614101939',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 29: ESSANT S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ESSANT S.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20608793080',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 30: FABRICACIONES Y SERVICIOS GUZMAN S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'FABRICACIONES Y SERVICIOS GUZMAN S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20480192932',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 31: FRIO CENTER YOVERA S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'FRIO CENTER YOVERA S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20561169404',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 32: FUERZA AEREA DEL PERU
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'FUERZA AEREA DEL PERU', 1, 177,
  NULL, NULL, NULL,
  5, '20144364059',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 33: GAMACMIN MINERO METALURGICA SOCIEDAD ANONIMA CERRADA - GAMACMIN S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GAMACMIN MINERO METALURGICA SOCIEDAD ANONIMA CERRADA - GAMACMIN S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20451534107',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 34: GLOBAL PROJECT SP S.A.C
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GLOBAL PROJECT SP S.A.C', 1, 177,
  NULL, NULL, NULL,
  5, '20601914469',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 35: GRUPO SALUD & ASOCIADOS S.A.C
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GRUPO SALUD & ASOCIADOS S.A.C', 1, 177,
  NULL, NULL, NULL,
  5, '20608134001',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 36: GUZMAN NIÑO SERGIO BRUNO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GUZMAN NIÑO SERGIO BRUNO', 1, 177,
  NULL, NULL, NULL,
  5, '10439328482',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 37: INDUSTRIAS CRIOGENICAS DEL PERU S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'INDUSTRIAS CRIOGENICAS DEL PERU S.A.C.', 3, 177,
  NULL, NULL, NULL,
  5, '20607948675',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 38: INDUSTRIAS DEL ACERO GUZMAN SOCIEDAD ANONIMA CERRADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'INDUSTRIAS DEL ACERO GUZMAN SOCIEDAD ANONIMA CERRADA', 1, 177,
  NULL, NULL, NULL,
  5, '20612446106',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 39: INNNOVATION MACHINERY INDUSTRIAL FENIX PERU S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'INNNOVATION MACHINERY INDUSTRIAL FENIX PERU S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20602257470',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 40: MARCO ANTONIO CHANAME CARBONEL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MARCO ANTONIO', 'CHANAME', 'CARBONEL',
  4, '17430623',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 41: LATERCER S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'LATERCER S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20514134155',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 42: LIGA DE CIRUGIA CONTRA LA OBESIDAD E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'LIGA DE CIRUGIA CONTRA LA OBESIDAD E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20607980358',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 43: LINDE PERU S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'LINDE PERU S.R.L.', 3, 177,
  NULL, NULL, NULL,
  5, '20338570041',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 44: MASTER FRIO SOLUCIONES E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MASTER FRIO SOLUCIONES E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20609474671',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 45: MORENO CASUSOL JOSE WILLIAM
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MORENO CASUSOL JOSE WILLIAM', 1, 177,
  NULL, NULL, NULL,
  5, '10803677714',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 46: NORT PARTS MULTILLANTAS Y SERVICIOS GENERALES E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'NORT PARTS MULTILLANTAS Y SERVICIOS GENERALES E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20600017412',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 47: OXIGENO CHRISTIAN S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'OXIGENO CHRISTIAN S.A.C.', 3, 177,
  NULL, NULL, NULL,
  5, '20536698834',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 48: OXIGENO SARITA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'OXIGENO SARITA', 1, 177,
  NULL, NULL, NULL,
  5, '10175332796',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 49: JOSE ALBERTO GOMEZ CASTILLO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE ALBERTO', 'GOMEZ', 'CASTILLO',
  4, '16671957',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 50: POTENZA GAS S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'POTENZA GAS S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20518304233',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 51: PRODUCTOS INDUSTRIALES SRL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'PRODUCTOS INDUSTRIALES SRL', 1, 177,
  NULL, NULL, NULL,
  5, '20270453679',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 52: PROYECTOS FINOX E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'PROYECTOS FINOX E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20607756121',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 53: RUIZ SEGURA SEGUNDO SEBASTIAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'RUIZ SEGURA SEGUNDO SEBASTIAN', 1, 176,
  NULL, NULL, NULL,
  4, '27392599',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 54: RUIZ TORRES WILSON
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'RUIZ TORRES WILSON', 1, 177,
  NULL, NULL, NULL,
  5, '10471465572',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 55: SANDOVAL SANTISTEBAN DANTE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SANDOVAL SANTISTEBAN DANTE', 1, 177,
  NULL, NULL, NULL,
  5, '10477042347',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 56: FERNANDO PERRIGO MAYTA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'FERNANDO', 'PERRIGO', 'MAYTA',
  4, '73829125',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 57: CESAR SANDOVAL INOÑAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CESAR', 'SANDOVAL', 'INOÑAN',
  4, '17621023',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 58: JUANA LINARES TORRES
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUANA', 'LINARES', 'TORRES',
  4, '45355947',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 59: SERVICIOS Y CONSTRUCCION.IMESUR S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SERVICIOS Y CONSTRUCCION.IMESUR S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20603383967',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 60: SEFABIN E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SEFABIN E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20610025707',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 61: TRUCKS AND MOTORS DEL PERU S.A. CERRADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'TRUCKS AND MOTORS DEL PERU S.A. CERRADA', 1, 177,
  NULL, NULL, NULL,
  5, '20174513245',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 62: V & F SAC
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'V & F SAC', 1, 177,
  NULL, NULL, NULL,
  5, '20480319860',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 63: TANANTA TANANTA TANANTA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'TANANTA', 'TANANTA', 'TANANTA',
  271, '000001',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 64: VICOLUX INGENIERIA Y CONSTRUCCION SOCIEDAD ANONIMA CERRADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VICOLUX INGENIERIA Y CONSTRUCCION SOCIEDAD ANONIMA CERRADA', 1, 177,
  NULL, NULL, NULL,
  5, '20615458440',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 65: AGRICOLA CERRO PRIETO S.A.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'AGRICOLA CERRO PRIETO S.A.', 1, 177,
  NULL, NULL, NULL,
  5, '20461642706',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 66: VIDAL MINCHOLA HILDER FANOR
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VIDAL MINCHOLA HILDER FANOR', 1, 177,
  NULL, NULL, NULL,
  5, '10190310839',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 67: VISUETA YACILA LUIS FREDERICK
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VISUETA YACILA LUIS FREDERICK', 1, 177,
  NULL, NULL, NULL,
  5, '10440281074',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 68: JUNIOR ESTIGUAR SANCHEZ DIAZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUNIOR ESTIGUAR', 'SANCHEZ', 'DIAZ',
  4, '44556460',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 69: ZARATE GALLARDO WILLIAM
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ZARATE GALLARDO WILLIAM', 1, 177,
  NULL, NULL, NULL,
  5, '10483897940',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 70: ZONA CAR CHICLAYO S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ZONA CAR CHICLAYO S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20610651691',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 71: JOSE CASTILLO COBEÑAS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE', 'CASTILLO', 'COBEÑAS',
  271, '000002',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 72: CACHAY BRUNO CARLOS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CACHAY BRUNO CARLOS', 1, 177,
  NULL, NULL, NULL,
  5, '10167643812',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 73: FERNANDO DELGADO MAZA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'FERNANDO', 'DELGADO', 'MAZA',
  271, '000003',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 74: MECANICA ELECTRICA DEL NORTE S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MECANICA ELECTRICA DEL NORTE S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20607793531',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 75: VOLVO DIESEL S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VOLVO DIESEL S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20603994818',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 76: HAMILTON ZUTA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'HAMILTON', 'ZUTA', NULL,
  271, '000004',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 77: ELQUIN HUAMANCHUMO LLONTOP
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ELQUIN', 'HUAMANCHUMO', 'LLONTOP',
  271, '000005',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 78: VALERA PASAPERA CESAR ARMANDO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VALERA PASAPERA CESAR ARMANDO', 1, 177,
  NULL, NULL, NULL,
  5, '10164621796',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 79: ORLANDO TICLIAHUANCA RAMOS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ORLANDO', 'TICLIAHUANCA', 'RAMOS',
  4, '42080968',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 80: ELIAS CAPUÑAY FLOR DE MARIA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ELIAS CAPUÑAY FLOR DE MARIA', 175, 177,
  NULL, NULL, NULL,
  5, '10167238195',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 81: MANSERVED DEALER S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MANSERVED DEALER S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20563657376',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 82: RUEDAMAX EMPRESA INDIVIDUAL DE RESPONSABILIDAD LIMITADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'RUEDAMAX EMPRESA INDIVIDUAL DE RESPONSABILIDAD LIMITADA', 1, 177,
  NULL, NULL, NULL,
  5, '20487607917',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 83: BORIS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'BORIS', NULL, NULL,
  271, '000006',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 84: CONSORCIO ROVELLA - PALORAMI
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CONSORCIO ROVELLA - PALORAMI', 1, 176,
  NULL, NULL, NULL,
  271, '000007',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 85: AMS POZOS DE VIDA S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'AMS POZOS DE VIDA S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20603674295',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 86: VEHICULOS & MAQUINAS SOCIEDAD ANONIMA CERRADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VEHICULOS & MAQUINAS SOCIEDAD ANONIMA CERRADA', 1, 177,
  NULL, NULL, NULL,
  5, '20600279735',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 87: DIEGO RAMIREZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DIEGO', 'RAMIREZ', NULL,
  271, '000008',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 88: CORONADO MERINO INGENIEROS SOCIEDAD ANONIMA CERRADA - COMEING S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CORONADO MERINO INGENIEROS SOCIEDAD ANONIMA CERRADA - COMEING S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20602110771',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 89: FRIOSYSTEM PERU S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'FRIOSYSTEM PERU S.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20600498470',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 90: JOSE FLORENTINO MORA CUEVA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE FLORENTINO', 'MORA', 'CUEVA',
  271, '000009',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 91: MULTISERVER CHICLAYO SAC
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MULTISERVER CHICLAYO SAC', 1, 177,
  NULL, NULL, NULL,
  5, '20480254806',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 92: EDWIN HUMBERTO NEYRA QUINTO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'EDWIN HUMBERTO', 'NEYRA', 'QUINTO',
  4, '46095699',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 93: PEDRO MANUEL ODIAGA HUAMAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'PEDRO MANUEL', 'ODIAGA', 'HUAMAN',
  4, '16708955',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 94: REFRIGERACION DEL NORTE S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'REFRIGERACION DEL NORTE S.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20487931005',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 95: ALDANA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ALDANA', NULL, NULL,
  271, '000010',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 96: JORGE SEGUNDO MENDOZA MORENO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JORGE SEGUNDO', 'MENDOZA', 'MORENO',
  4, '61180748',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 97: DIONISIO BARRETO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DIONISIO', 'BARRETO', NULL,
  271, '000011',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 98: JUAN RIOJAS MARTINEZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUAN', 'RIOJAS', 'MARTINEZ',
  271, '000012',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 99: ANGEL CORDOVA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ANGEL', 'CORDOVA', NULL,
  271, '000013',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 100: MARIA BERENISE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MARIA', 'BERENISE', NULL,
  271, '000014',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 101: MARIA MALCA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MARIA', 'MALCA', NULL,
  271, '000015',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 102: CASINALDO VERA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CASINALDO', 'VERA', NULL,
  271, '000016',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 103: ATO ASCENSORES NACIONALES S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ATO ASCENSORES NACIONALES S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20601783372',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 104: CHICOMA ROQUE PEDRO PABLO - CHAVEZ SERRATO MANUEL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CHICOMA ROQUE PEDRO PABLO - CHAVEZ SERRATO MANUEL', 1, 177,
  NULL, NULL, NULL,
  5, '10176064183',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 105: JARA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JARA', NULL, NULL,
  271, '000017',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 106: JAVIER ESCALONA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 177,
  'JAVIER', 'ESCALONA', NULL,
  271, '000018',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 107: ARREDONDO ARRIBASPLATA JOHN EDUARDO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ARREDONDO ARRIBASPLATA JOHN EDUARDO', 1, 177,
  NULL, NULL, NULL,
  5, '10167103923',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 108: AUGUSTO BALDERA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'AUGUSTO', 'BALDERA', NULL,
  271, '000019',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 109: PEDRO BANCES BANCES
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'PEDRO', 'BANCES', 'BANCES',
  271, '000020',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 110: JOILE AMABLE CACERES LOZANO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOILE AMABLE', 'CACERES', 'LOZANO',
  4, '28069256',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 111: DEVAR CALVAY PEÑA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DEVAR', 'CALVAY', 'PEÑA',
  271, '000021',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 112: CAMACHO ZELADA ANTERO VIDAL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CAMACHO ZELADA ANTERO VIDAL', 1, 177,
  NULL, NULL, NULL,
  5, '10277270213',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 113: JUAN DEL CANTO PATRONI
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUAN', 'DEL CANTO', 'PATRONI',
  4, '16688260',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 114: CASTILLO LEON ROBERT STEVE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CASTILLO LEON ROBERT STEVE', 1, 177,
  NULL, NULL, NULL,
  5, '10435901871',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 115: JOSE CHAPOÑAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE', 'CHAPOÑAN', NULL,
  271, '000022',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 116: RODRIGUEZ CHUQUE LUIS SAMUEL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'RODRIGUEZ CHUQUE LUIS SAMUEL', 1, 177,
  NULL, NULL, NULL,
  5, '10488481679',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 117: CLINICA DE OJOS GARCIA EMPRESA INDIVIDUAL DE RESPONSABILIDAD LIMITADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CLINICA DE OJOS GARCIA EMPRESA INDIVIDUAL DE RESPONSABILIDAD LIMITADA', 1, 177,
  NULL, NULL, NULL,
  5, '20604170991',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 118: CLINICA SERVISALUD SOLIDARIA S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CLINICA SERVISALUD SOLIDARIA S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20606641371',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 119: CONCRETERA DEL NORTE S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CONCRETERA DEL NORTE S.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20602271332',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 120: CONGREGACION DE LAS SIERVAS DE JESUS DE LA CARIDAD-PERU
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CONGREGACION DE LAS SIERVAS DE JESUS DE LA CARIDAD-PERU', 1, 177,
  NULL, NULL, NULL,
  5, '20501484831',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 121: CUBA MEDIC CHICLAYO S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CUBA MEDIC CHICLAYO S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20611952130',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 122: TALITA SOLEDAD DELGADO SOBERON
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'TALITA SOLEDAD', 'DELGADO', 'SOBERON',
  4, '16780162',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 123: CECILIA EMPERATRIZ GARCIA NUÑEZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CECILIA EMPERATRIZ', 'GARCIA', 'NUÑEZ',
  4, '16732020',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 124: GEOSOLUCIONES INTEGRALES DE PERFORACION S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GEOSOLUCIONES INTEGRALES DE PERFORACION S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20607539597',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 125: GIL ESPERANZA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'GIL', 'ESPERANZA', NULL,
  271, '000023',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 126: GRUPO VIRGEN DE LA MEDALLA MILAGROSA E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GRUPO VIRGEN DE LA MEDALLA MILAGROSA E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20602412416',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 127: PEDRO LEON
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'PEDRO', 'LEON', NULL,
  271, '000024',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 128: SEGUNDO LLATAS CONTRERAS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'SEGUNDO', 'LLATAS', 'CONTRERAS',
  271, '000025',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 129: JOEL LLUNCOR
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOEL', 'LLUNCOR', NULL,
  271, '000026',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 130: CINDY LOZADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CINDY', 'LOZADA', NULL,
  271, '000027',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 131: MADRE JUANA S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MADRE JUANA S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20487381765',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 132: CARLOS FERNANDO MONTENEGRO GOMEZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CARLOS FERNANDO', 'MONTENEGRO', 'GOMEZ',
  4, '16769129',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 133: MONTEZA CHAVEZ HENRY
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MONTEZA CHAVEZ HENRY', 1, 177,
  NULL, NULL, NULL,
  5, '10484251890',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 134: ENRIQUE MONTEZA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ENRIQUE', 'MONTEZA', NULL,
  271, '000028',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 135: ROMAN MONZON CALDERON
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ROMAN', 'MONZON', 'CALDERON',
  4, '18096175',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 136: MORENO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MORENO', NULL, NULL,
  271, '000029',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 137: NAHOMI
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'NAHOMI', NULL, NULL,
  271, '000030',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 138: FRANKLYN NEYRA CISNEROS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'FRANKLYN', 'NEYRA', 'CISNEROS',
  4, '16719442',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 139: MANUELA PALACIOS CUMPEN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MANUELA', 'PALACIOS', 'CUMPEN',
  4, '17609290',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 140: JOSE DANIEL PANTA HUANCAS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE DANIEL', 'PANTA', 'HUANCAS',
  4, '16480825',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 141: JOSELITO RIMAY VASQUEZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSELITO', 'RIMAY', 'VASQUEZ',
  4, '44435893',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 142: SANCHEZ MALDONADO JORGE LUIS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SANCHEZ MALDONADO JORGE LUIS', 1, 177,
  NULL, NULL, NULL,
  5, '10438424798',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 143: SANTOS MATIAS DOMINGO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SANTOS MATIAS DOMINGO', 1, 177,
  NULL, NULL, NULL,
  5, '10400805160',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 144: SERVICIOS EDUCATIVOS KEPLER COLLEGE S.A.C
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SERVICIOS EDUCATIVOS KEPLER COLLEGE S.A.C', 1, 177,
  NULL, NULL, NULL,
  5, '20487997529',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 145: SERVICIOS MEDICOS ESPECIALIZADOS DEL NORTE E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SERVICIOS MEDICOS ESPECIALIZADOS DEL NORTE E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20487981525',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 146: LINO SIESQUEN MORES
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'LINO', 'SIESQUEN', 'MORES',
  271, '000031',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 147: TAIPE YALO EFRAIN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'TAIPE YALO EFRAIN', 1, 177,
  NULL, NULL, NULL,
  5, '10166681028',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 148: TELLO RIVERA ROYER
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'TELLO RIVERA ROYER', 1, 177,
  NULL, NULL, NULL,
  5, '10438519977',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 149: BERNAOLA ELERA ROSA ELIANA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'BERNAOLA ELERA ROSA ELIANA', 1, 177,
  NULL, NULL, NULL,
  5, '10438675910',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 150: TORRES CANAZA JAVIER ANGEL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'TORRES CANAZA JAVIER ANGEL', 1, 177,
  NULL, NULL, NULL,
  5, '10096762190',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 151: UNIVERSIDAD CATOLICA SANTO TORIBIO DE MOGROVEJO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'UNIVERSIDAD CATOLICA SANTO TORIBIO DE MOGROVEJO', 1, 177,
  NULL, NULL, NULL,
  5, '20395492129',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 152: VALENTIN - FERREÑAFE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'VALENTIN - FERREÑAFE', NULL, NULL,
  271, '000032',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 153: WILLY EDWIN VILCAMANGO RAMOS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'WILLY EDWIN', 'VILCAMANGO', 'RAMOS',
  4, '16616978',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 154: JUAN YANAGUI CASTILLO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUAN', 'YANAGUI', 'CASTILLO',
  4, '06547378',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 155: ANGEL ZAMBRANO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ANGEL', 'ZAMBRANO', NULL,
  271, '000033',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 156: JORGE MENDOZA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JORGE', 'MENDOZA', NULL,
  271, '000034',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 157: PEDIACIX S.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'PEDIACIX S.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20607710385',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 158: I.E.D. GASTROCIX S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'I.E.D. GASTROCIX S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20605722238',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 159: CARLOS BECERRA VILCHEZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CARLOS', 'BECERRA', 'VILCHEZ',
  4, '73496013',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 160: BURGA SALINAS SANTOS CATALINA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'BURGA SALINAS SANTOS CATALINA', 1, 177,
  NULL, NULL, NULL,
  5, '10436580326',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 161: JOHEL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOHEL', NULL, NULL,
  271, '000035',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 162: DEYSI PILAR
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DEYSI PILAR', NULL, NULL,
  271, '000036',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 163: DIAZ PEREZ SANDALIANO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'DIAZ PEREZ SANDALIANO', 1, 177,
  NULL, NULL, NULL,
  5, '10273953677',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 164: SAMAME TARRILLO KARINA DEL PILAR
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SAMAME TARRILLO KARINA DEL PILAR', 1, 177,
  NULL, NULL, NULL,
  5, '10429005197',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 165: AGUSTIN MAGO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'AGUSTIN', 'MAGO', NULL,
  271, '000037',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 166: JHON DEYVI CASTELLANOS CORDOVA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JHON DEYVI', 'CASTELLANOS', 'CORDOVA',
  4, '47872576',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 167: MOZA PEREZ YODALIA CLARA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MOZA PEREZ YODALIA CLARA', 1, 177,
  NULL, NULL, NULL,
  5, '10280648448',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 168: SANTISTEBAN BALDERA PEDRO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SANTISTEBAN BALDERA PEDRO', 1, 177,
  NULL, NULL, NULL,
  5, '10176081967',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 169: JOSE SANTOS RINGA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE', 'SANTOS', 'RINGA',
  271, '000038',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 170: SR CLAUDIO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'SR CLAUDIO', NULL, NULL,
  271, '000039',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 171: UCULMANA LOPEZ ANA BEATRIZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'UCULMANA LOPEZ ANA BEATRIZ', 1, 177,
  NULL, NULL, NULL,
  5, '10074562162',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 172: VALDIVIESO ARBULU HARALD FREDDY
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VALDIVIESO ARBULU HARALD FREDDY', 1, 177,
  NULL, NULL, NULL,
  5, '10081132572',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 173: JUAN HECTOR ACOSTA SANDOVAL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUAN HECTOR', 'ACOSTA', 'SANDOVAL',
  4, '16747813',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 174: GEOVANA LUCY ALAYZA CARRERA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'GEOVANA LUCY', 'ALAYZA', 'CARRERA',
  4, '29268940',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 175: ALIAZIONE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ALIAZIONE', NULL, NULL,
  271, '000040',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 176: JUAN OSWALDO ALVARADO FIGUEROA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUAN OSWALDO', 'ALVARADO', 'FIGUEROA',
  4, '16530972',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 177: APU SALUD MEDICOS A DOMICILIO S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'APU SALUD MEDICOS A DOMICILIO S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20602375383',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 178: BELGY ATOCHE APONTE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'BELGY', 'ATOCHE', 'APONTE',
  4, '16563500',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 179: AUGUSTO VALDERA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'AUGUSTO', 'VALDERA', NULL,
  271, '000041',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 180: BALDERA CHAPOÑAN ANTERO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'BALDERA CHAPOÑAN ANTERO', 1, 177,
  NULL, NULL, NULL,
  5, '10176008763',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 181: AUGUSTO BALDERA CHERO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'AUGUSTO', 'BALDERA CHERO', NULL,
  271, '000042',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 182: ANA CECILIA CHAUANA SANCHAZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 177,
  'ANA CECILIA', 'CHAUANA', 'SANCHAZ',
  4, '29646105',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 183: HUGO BANCES SANDOVAL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'HUGO', 'BANCES', 'SANDOVAL',
  4, '44491850',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 184: BANCES VEGA WALTER ENRIQUE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'BANCES VEGA WALTER ENRIQUE', 1, 177,
  NULL, NULL, NULL,
  5, '10164549831',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 185: MANUEL EDILBERTO BARRETO PALOMINO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MANUEL EDILBERTO', 'BARRETO', 'PALOMINO',
  4, '16739420',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 186: DINA CHAPOÑAN MORALES
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DINA', 'CHAPOÑAN', 'MORALES',
  4, '44377974',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 187: CHUMAN BANCES ALEJANDRO JAIME
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CHUMAN BANCES ALEJANDRO JAIME', 1, 177,
  NULL, NULL, NULL,
  5, '10037018738',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 188: CHUMAN BANCES JOSE DEL CARMEN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CHUMAN BANCES JOSE DEL CARMEN', 1, 177,
  NULL, NULL, NULL,
  5, '10176032800',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 189: CHUZON ROMAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CHUZON', 'ROMAN', NULL,
  271, '000043',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 190: CLINICA CHICLAYO S.A.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CLINICA CHICLAYO S.A.', 1, 177,
  NULL, NULL, NULL,
  5, '20103324948',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 191: CLINICA DE FERTILIDAD DEL NORTE S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CLINICA DE FERTILIDAD DEL NORTE S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20561370762',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 192: CLINICA FLORIAN SOCIEDAD ANONIMA CERRADA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CLINICA FLORIAN SOCIEDAD ANONIMA CERRADA', 1, 177,
  NULL, NULL, NULL,
  5, '20561359441',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 193: SEGUNDO TEOFILO COLCHADO BECERRA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 177,
  'SEGUNDO TEOFILO', 'COLCHADO', 'BECERRA',
  4, '16676149',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 194: ORLANDO CORONADO GALAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ORLANDO', 'CORONADO', 'GALAN',
  271, '000044',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 195: GUSTAVO ENRIQUE CORONEL IDROGO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'GUSTAVO ENRIQUE', 'CORONEL', 'IDROGO',
  4, '47067456',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 196: CORONEL VASQUEZ MODESTO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CORONEL VASQUEZ MODESTO', 1, 177,
  NULL, NULL, NULL,
  5, '10166403486',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 197: CYNTHIA PAOLA COTRINA CORONADO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CYNTHIA PAOLA', 'COTRINA', 'CORONADO',
  4, '90000386',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 198: CORCORPORACION EVOCADORA PERU S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'CORCORPORACION EVOCADORA PERU S.A.C.', 1, 176,
  NULL, NULL, NULL,
  271, '000045',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 199: LUIS DAMIAN SANDOVAL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'LUIS', 'DAMIAN', 'SANDOVAL',
  271, '000046',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 200: DANY MACO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DANY', 'MACO', NULL,
  271, '000047',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 201: JOSE DAVILA MONTENEGRO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE', 'DAVILA', 'MONTENEGRO',
  271, '000048',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 202: ALFONZO DAVILA SAAVEDRA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ALFONZO', 'DAVILA', 'SAAVEDRA',
  4, '16456285',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 203: DC CADENA DE SERVICIOS GENERALES E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'DC CADENA DE SERVICIOS GENERALES E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20611929596',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 204: DIAZ RUIZ BELIZARIO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'DIAZ RUIZ BELIZARIO', 1, 177,
  NULL, NULL, NULL,
  5, '10403521197',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 205: ECOFUMIG SOLUCIONES S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'ECOFUMIG SOLUCIONES S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20612690007',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 206: ERICK EFFIO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ERICK', 'EFFIO', NULL,
  271, '000049',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 207: SAMUEL ESPICHE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 177,
  'SAMUEL', 'ESPICHE', NULL,
  271, '000050',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 208: FARANTRUJ E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'FARANTRUJ E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20611122013',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 209: FERNANDEZ BUSTAMANTE MARIO OSMAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'FERNANDEZ BUSTAMANTE MARIO OSMAN', 1, 177,
  NULL, NULL, NULL,
  5, '10402505643',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 210: GALLARDO TINEO VLADIMIR
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GALLARDO TINEO VLADIMIR', 1, 177,
  NULL, NULL, NULL,
  5, '10748757070',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 211: FIORELLA GARCIA AGUINAGA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'FIORELLA', 'GARCIA', 'AGUINAGA',
  4, '44436445',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 212: JULIA ANGEL GARCIA ALARCON
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JULIA ANGEL', 'GARCIA', 'ALARCON',
  4, '46979641',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 213: GRUPO FERRETERO CONTRATISTAS GENERALES E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GRUPO FERRETERO CONTRATISTAS GENERALES E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20612747726',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 214: GRUPO SALUD HOGAR S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'GRUPO SALUD HOGAR S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20607333875',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 216: ALEX HERRERA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ALEX', 'HERRERA', NULL,
  271, '000051',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 217: SIGIFREDO HIDELGARDO HONORIO CORDOVA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'SIGIFREDO HIDELGARDO', 'HONORIO', 'CORDOVA',
  4, '07558654',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 218: ELVIA LUZ HUAMAN TENORIO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ELVIA LUZ', 'HUAMAN', 'TENORIO',
  4, '17432701',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 219: INDUSTRIAS PALA S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'INDUSTRIAS PALA S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20601073316',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 220: JULIO INGA VASQUEZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JULIO', 'INGA', 'VASQUEZ',
  271, '000053',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 221: INGENIEROS MECANICOS & AUTOMATIZACIONES E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'INGENIEROS MECANICOS & AUTOMATIZACIONES E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20613421492',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 222: INVERSIONES R & C ALARCON S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'INVERSIONES R & C ALARCON S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20608316419',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 223: DEMETRIO LLAUCE CAJUSOL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'DEMETRIO', 'LLAUCE', 'CAJUSOL',
  4, '47487670',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 224: JOSE LLONTOP BANCES
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSE', 'LLONTOP', 'BANCES',
  271, '000054',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 225: JOSUE NEPTALI LLUNCOR PISFIL
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JOSUE NEPTALI', 'LLUNCOR', 'PISFIL',
  4, '44089512',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 226: PEDRO LOCONI SEYTUQUE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'PEDRO', 'LOCONI', 'SEYTUQUE',
  4, '16764812',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 227: BENANCIO LOYOLA VILELA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'BENANCIO', 'LOYOLA', 'VILELA',
  271, '000055',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 228: OSCAR LUNA LARIOS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'OSCAR', 'LUNA', 'LARIOS',
  271, '000056',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 229: MOLINO LOS ANGELES
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MOLINO LOS ANGELES', 1, 176,
  NULL, NULL, NULL,
  271, '000057',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 230: AGUSTIN ELEUTERIO MONTALVO MUNDACA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'AGUSTIN ELEUTERIO', 'MONTALVO', 'MUNDACA',
  4, '16454507',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 231: RIGOBERTO MONTEZA DIAZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'RIGOBERTO', 'MONTEZA', 'DIAZ',
  4, '47892541',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 232: MULTISERVICIOS Y RECTIFICACIONES JONATHAN SAC
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'MULTISERVICIOS Y RECTIFICACIONES JONATHAN SAC', 1, 176,
  NULL, NULL, NULL,
  5, '20609158264',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 233: NEFRO CIX S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'NEFRO CIX S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20601042151',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 234: OXYMAN COMERCIAL S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'OXYMAN COMERCIAL S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20516367670',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 235: ARON PAZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ARON', 'PAZ', NULL,
  271, '000058',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 236: GUSTAVO ALFREDO PEREZ BUSTAMANTE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'GUSTAVO ALFREDO', 'PEREZ', 'BUSTAMANTE',
  4, '45831341',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 237: QUIROZ CORONADO JUAN MARTIN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'QUIROZ CORONADO JUAN MARTIN', 1, 177,
  NULL, NULL, NULL,
  5, '10165243299',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 238: MARTIN (POSITOS) QUIROZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MARTIN (POSITOS)', 'QUIROZ', NULL,
  271, '000059',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 239: EDGAR RAMIREZ VASQUEZ
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'EDGAR', 'RAMIREZ', 'VASQUEZ',
  4, '44591416',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 240: CARLOS RODRIGUEZ CALLE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CARLOS', 'RODRIGUEZ', 'CALLE',
  4, '16667648',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 241: RUBIÑOS LAMBAYEQUE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'RUBIÑOS', 'LAMBAYEQUE', NULL,
  271, '000060',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 242: CLEINER RUIZ CIEZA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CLEINER', 'RUIZ', 'CIEZA',
  271, '000061',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 243: VICTOR MANUEL RUIZ CORO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'VICTOR MANUEL', 'RUIZ', 'CORO',
  4, '41026210',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 244: SANTISTEBAN ALAMO ALFREDO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'SANTISTEBAN ALAMO ALFREDO', 1, 177,
  NULL, NULL, NULL,
  5, '10433676349',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 245: CARLOS ALBERTO SANCHEZ MANAYALLE
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'CARLOS ALBERTO', 'SANCHEZ', 'MANAYALLE',
  4, '45172067',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 246: MANUEL SANTISTEBAN RIOJAS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MANUEL', 'SANTISTEBAN', 'RIOJAS',
  4, '42781779',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 247: NILSEN SATALAYA ROJAS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'NILSEN', 'SATALAYA', 'ROJAS',
  4, '43626737',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 248: JULIO SERQUEN UBILLUS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JULIO', 'SERQUEN', 'UBILLUS',
  4, '16413826',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 249: SIPION (ROBERTO)
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'SIPION (ROBERTO)', NULL, NULL,
  271, '000062',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 250: ABELARDO SOBERON VILLANUEVA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ABELARDO', 'SOBERON', 'VILLANUEVA',
  4, '40518031',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 251: JAIME TABOADA SERRATO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JAIME', 'TABOADA', 'SERRATO',
  4, '80542803',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 252: TENDENCIAS ARQUITECTURA Y DISEÑO E.I.R.L.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'TENDENCIAS ARQUITECTURA Y DISEÑO E.I.R.L.', 1, 177,
  NULL, NULL, NULL,
  5, '20601110661',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 253: ARNULFO ALIPIO TERAN BAZAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'ARNULFO ALIPIO', 'TERAN', 'BAZAN',
  4, '16530919',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 254: YURI VLADIMIR VALDIVIESO VILLENA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'YURI VLADIMIR', 'VALDIVIESO', 'VILLENA',
  4, '40446471',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 255: JUAN ALBERTO VEGA VARIOS
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JUAN ALBERTO', 'VEGA', 'VARIOS',
  4, '17522246',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 256: MIRIAN ROSANA ZUNINI VARONA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'MIRIAN ROSANA', 'ZUNINI', 'VARONA',
  4, '16475399',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 257: VIDRIOS ACEROS INOXIDABLES MUEBLERIA A & S S.A.C.
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, 'VIDRIOS ACEROS INOXIDABLES MUEBLERIA A & S S.A.C.', 1, 177,
  NULL, NULL, NULL,
  5, '20611355239',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 258: JESUS ENRIQUE YOVERA SANTISTEBAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'JESUS ENRIQUE', 'YOVERA', 'SANTISTEBAN',
  4, '42715935',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 259: LUIS ZACARIAS FARROÑAN
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'LUIS', 'ZACARIAS', 'FARROÑAN',
  271, '000063',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 260: RICHARD JHONSON ZAPATA PALOMINO
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'RICHARD JHONSON', 'ZAPATA', 'PALOMINO',
  4, '48189363',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- Excel fila 261: HENRY JHONATAN ZURITA CORREA
INSERT INTO cli_clientes (
  codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona,
  nombres, apellido_paterno, apellido_materno,
  id_tipo_documento, numero_documento,
  telefono, email, observacion,
  estado, id_usuario_creacion, id_usuario_modificacion
) VALUES (
  NULL, NULL, 1, 176,
  'HENRY JHONATAN', 'ZURITA', 'CORREA',
  4, '71201541',
  NULL, NULL, NULL,
  1, 1, 1
)
ON CONFLICT (numero_documento) DO NOTHING;

-- ===== DIRECCIONES PRINCIPALES =====

-- Direccion principal Excel fila 7 / doc 20604549401
INSERT INTO cli_direcciones (
  id_cliente, descripcion, direccion, referencia,
  es_principal, estado, id_usuario_creacion, id_usuario_modificacion
)
SELECT c.id, 'Principal', 'MZA. B LOTE. 8 OTR. CP SOL Y CAMPO (COSTADO GRIFO CAMPO SOL)', NULL,
       TRUE, 1, 1, 1
FROM cli_clientes c
WHERE c.numero_documento = '20604549401'
  AND NOT EXISTS (
    SELECT 1 FROM cli_direcciones d
    WHERE d.id_cliente = c.id AND d.es_principal = TRUE AND d.estado = 1
  );

-- Direccion principal Excel fila 16 / doc 20604078866
INSERT INTO cli_direcciones (
  id_cliente, descripcion, direccion, referencia,
  es_principal, estado, id_usuario_creacion, id_usuario_modificacion
)
SELECT c.id, 'Principal', 'CAL.FRANCISCO CUNEO NRO. 223 URB. PATAZCA', NULL,
       TRUE, 1, 1, 1
FROM cli_clientes c
WHERE c.numero_documento = '20604078866'
  AND NOT EXISTS (
    SELECT 1 FROM cli_direcciones d
    WHERE d.id_cliente = c.id AND d.es_principal = TRUE AND d.estado = 1
  );

-- Direccion principal Excel fila 26 / doc 20103448591
INSERT INTO cli_direcciones (
  id_cliente, descripcion, direccion, referencia,
  es_principal, estado, id_usuario_creacion, id_usuario_modificacion
)
SELECT c.id, 'Principal', 'AV. SAENZ PEÑA NRO. 1860 URB. LATINA L', NULL,
       TRUE, 1, 1, 1
FROM cli_clientes c
WHERE c.numero_documento = '20103448591'
  AND NOT EXISTS (
    SELECT 1 FROM cli_direcciones d
    WHERE d.id_cliente = c.id AND d.es_principal = TRUE AND d.estado = 1
  );

-- Direccion principal Excel fila 32 / doc 20144364059
INSERT INTO cli_direcciones (
  id_cliente, descripcion, direccion, referencia,
  es_principal, estado, id_usuario_creacion, id_usuario_modificacion
)
SELECT c.id, 'Principal', 'AV. LA PERUANIDAD NRO. SN CAMPO DE MARTE (NOTIF. A DIRECCION GENERAL DE ECONOMIA)', NULL,
       TRUE, 1, 1, 1
FROM cli_clientes c
WHERE c.numero_documento = '20144364059'
  AND NOT EXISTS (
    SELECT 1 FROM cli_direcciones d
    WHERE d.id_cliente = c.id AND d.es_principal = TRUE AND d.estado = 1
  );

-- Direccion principal Excel fila 51 / doc 20270453679
INSERT INTO cli_direcciones (
  id_cliente, descripcion, direccion, referencia,
  es_principal, estado, id_usuario_creacion, id_usuario_modificacion
)
SELECT c.id, 'Principal', 'AV. JOSE LEONARDO ORTIZ NRO. 428 RES. JOSE LEONARDO ORTIZ', NULL,
       TRUE, 1, 1, 1
FROM cli_clientes c
WHERE c.numero_documento = '20270453679'
  AND NOT EXISTS (
    SELECT 1 FROM cli_direcciones d
    WHERE d.id_cliente = c.id AND d.es_principal = TRUE AND d.estado = 1
  );

-- Direccion principal Excel fila 61 / doc 20174513245
INSERT INTO cli_direcciones (
  id_cliente, descripcion, direccion, referencia,
  es_principal, estado, id_usuario_creacion, id_usuario_modificacion
)
SELECT c.id, 'Principal', 'Lambayeque', NULL,
       TRUE, 1, 1, 1
FROM cli_clientes c
WHERE c.numero_documento = '20174513245'
  AND NOT EXISTS (
    SELECT 1 FROM cli_direcciones d
    WHERE d.id_cliente = c.id AND d.es_principal = TRUE AND d.estado = 1
  );

-- Reset sequences
SELECT setval(pg_get_serial_sequence('cli_clientes', 'id'), COALESCE((SELECT MAX(id) FROM cli_clientes), 1), true);
SELECT setval(pg_get_serial_sequence('cli_direcciones', 'id'), COALESCE((SELECT MAX(id) FROM cli_direcciones), 1), true);

COMMIT;

-- Resumen esperado:
--   clientes: 256
--   direcciones: 6
--   tipo_documento: {'RUC': 123, 'DNI': 70, 'SD': 63}
--   tipo_persona: {'Persona Jurídica': 125, 'Persona Natural': 131}
--   tipo_cliente: {'Cliente': 251, 'Proveedor': 4, 'Cliente / Proveedor': 1}
