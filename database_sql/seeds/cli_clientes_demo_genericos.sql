-- Clientes genéricos de prueba para DEV (oxígeno medicinal / industrial).
-- Idempotente por codigo_interno DEMO-C01 … DEMO-C15.
-- No tocar CLIENTES VARIOS (CVARIOS).

DO $$
DECLARE
  v_tipo_cliente INT;
  v_tipo_paciente INT;
  v_tipo_proveedor INT;
  v_tipo_ambos INT;
  v_persona_nat INT;
  v_persona_jur INT;
  v_doc_dni INT;
  v_doc_ruc INT;
  v_id_pais INT;
  v_id_dep INT;
  v_id_prov INT;
  v_id_dist_sjl INT;
  v_id_dist_comas INT;
  v_id_dist_ate INT;
  v_id_dist_chorrillos INT;
  v_id_dist_lima INT;
  v_id_dist_breña INT;
  v_id_cliente INT;
BEGIN
  SELECT lo.id INTO v_tipo_cliente FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoCliente' AND lo.nombre = 'Cliente' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_tipo_paciente FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoCliente' AND lo.nombre = 'Paciente' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_tipo_proveedor FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoCliente' AND lo.nombre = 'Proveedor' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_tipo_ambos FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoCliente' AND lo.nombre = 'Cliente / Proveedor' AND lo.estado = 1 LIMIT 1;

  SELECT lo.id INTO v_persona_nat FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoPersona' AND lo.nombre = 'Persona Natural' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_persona_jur FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoPersona' AND lo.nombre = 'Persona Jurídica' AND lo.estado = 1 LIMIT 1;

  SELECT lo.id INTO v_doc_dni FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoDocumento' AND upper(lo.nombre) = 'DNI' AND lo.estado = 1 LIMIT 1;
  SELECT lo.id INTO v_doc_ruc FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
   WHERE l.nombre = 'TipoDocumento' AND upper(lo.nombre) = 'RUC' AND lo.estado = 1 LIMIT 1;

  SELECT id INTO v_id_pais FROM gen_pais ORDER BY id LIMIT 1;
  SELECT dep.id, p.id INTO v_id_dep, v_id_prov
    FROM gen_departamento dep
    JOIN gen_provincia p ON p.id_departamento = dep.id
   WHERE dep.nombre ILIKE 'Lima' AND p.nombre ILIKE 'Lima'
   LIMIT 1;

  SELECT id INTO v_id_dist_lima FROM gen_distrito WHERE id_provincia = v_id_prov AND nombre = 'Lima' LIMIT 1;
  SELECT id INTO v_id_dist_comas FROM gen_distrito WHERE id_provincia = v_id_prov AND nombre = 'Comas' LIMIT 1;
  SELECT id INTO v_id_dist_ate FROM gen_distrito WHERE id_provincia = v_id_prov AND nombre = 'Ate' LIMIT 1;
  SELECT id INTO v_id_dist_chorrillos FROM gen_distrito WHERE id_provincia = v_id_prov AND nombre = 'Chorrillos' LIMIT 1;
  SELECT id INTO v_id_dist_breña FROM gen_distrito WHERE id_provincia = v_id_prov AND nombre = 'Breña' LIMIT 1;
  SELECT id INTO v_id_dist_sjl FROM gen_distrito WHERE id_provincia = v_id_prov AND nombre ILIKE 'San Juan de Lurigancho' LIMIT 1;
  IF v_id_dist_sjl IS NULL THEN v_id_dist_sjl := v_id_dist_comas; END IF;

  -- Helper inline: insert cliente + dirección si no existe codigo
  -- C01–C08 pacientes/clientes persona natural (DNI)
  -- C09–C11 empresas/clínicas cliente (RUC)
  -- C12–C13 plantas proveedor (RUC)
  -- C14 cliente/proveedor
  -- C15 paciente adicional

  -- C01
  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C01') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C01', NULL, v_tipo_paciente, v_persona_nat, 'María Elena', 'Quispe', 'Huamán', v_doc_dni, '40123401', '987654301', 'maria.quispe.demo@example.com', 'Av. Universitaria 1200', 'Paciente oxígeno domiciliario (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Universitaria 1200', 'Frente a parque', v_id_pais, v_id_dep, v_id_prov, v_id_dist_comas, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C02') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C02', NULL, v_tipo_paciente, v_persona_nat, 'José Luis', 'Ramírez', 'Torres', v_doc_dni, '40123402', '987654302', 'jose.ramirez.demo@example.com', 'Jr. Los Álamos 455', 'Paciente COPD (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Jr. Los Álamos 455', 'Casa de dos pisos', v_id_pais, v_id_dep, v_id_prov, v_id_dist_sjl, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C03') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C03', NULL, v_tipo_cliente, v_persona_nat, 'Ana Lucía', 'Vargas', 'Mendoza', v_doc_dni, '40123403', '987654303', 'ana.vargas.demo@example.com', 'Calle Las Flores 88', 'Cliente mostrador frecuente (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Calle Las Flores 88', NULL, v_id_pais, v_id_dep, v_id_prov, v_id_dist_ate, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C04') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C04', NULL, v_tipo_paciente, v_persona_nat, 'Pedro', 'Castillo', 'Rojas', v_doc_dni, '40123404', '987654304', 'pedro.castillo.demo@example.com', 'Av. Primavera 210', 'Alquiler concentrador (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Primavera 210', 'Dpto 302', v_id_pais, v_id_dep, v_id_prov, v_id_dist_chorrillos, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C05') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C05', NULL, v_tipo_cliente, v_persona_nat, 'Rosa María', 'Flores', 'Paredes', v_doc_dni, '40123405', '987654305', 'rosa.flores.demo@example.com', 'Jr. Huancavelica 150', 'Recargas periódicas (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Jr. Huancavelica 150', 'Cerca a mercado', v_id_pais, v_id_dep, v_id_prov, v_id_dist_breña, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C06') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C06', NULL, v_tipo_paciente, v_persona_nat, 'Carlos Alberto', 'Gutiérrez', 'Silva', v_doc_dni, '40123406', '987654306', 'carlos.gutierrez.demo@example.com', 'Mz B Lt 12 Urb. Los Olivos', 'Préstamo de balón (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Mz B Lt 12 Urb. Los Olivos', 'Portón negro', v_id_pais, v_id_dep, v_id_prov, COALESCE(v_id_dist_sjl, v_id_dist_comas), TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C07') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C07', NULL, v_tipo_cliente, v_persona_nat, 'Lucía', 'Espinoza', 'Cruz', v_doc_dni, '40123407', '987654307', 'lucia.espinoza.demo@example.com', 'Av. Argentina 890', 'Cliente industrial pequeño (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Argentina 890', 'Taller mecánico', v_id_pais, v_id_dep, v_id_prov, v_id_dist_lima, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C08') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C08', NULL, v_tipo_paciente, v_persona_nat, 'Miguel Ángel', 'Soto', 'Díaz', v_doc_dni, '40123408', '987654308', 'miguel.soto.demo@example.com', 'Calle 7 Mz F Lt 3', 'Ruta pueblos / delivery (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Calle 7 Mz F Lt 3', 'Casa esquina', v_id_pais, v_id_dep, v_id_prov, v_id_dist_ate, TRUE, 1);
  END IF;

  -- Empresas / clínicas (RUC)
  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C09') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C09', 'CLÍNICA SANTA LUCÍA S.A.C.', v_tipo_cliente, v_persona_jur, v_doc_ruc, '20100000091', '014567891', 'compras@santalucia.demo', 'Av. Brasil 2450', 'Clínica — facturación RUC (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Brasil 2450', 'Almacén de gases', v_id_pais, v_id_dep, v_id_prov, v_id_dist_breña, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C10') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C10', 'CENTRO MÉDICO EL OLIVAR E.I.R.L.', v_tipo_cliente, v_persona_jur, v_doc_ruc, '20100000101', '014567892', 'logistica@olivar.demo', 'Av. Javier Prado Este 3200', 'Centro médico — pedidos semanales (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Javier Prado Este 3200', 'Sótano gases', v_id_pais, v_id_dep, v_id_prov, v_id_dist_ate, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C11') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C11', 'SOLDADURAS ANDINAS S.R.L.', v_tipo_cliente, v_persona_jur, v_doc_ruc, '20100000111', '014567893', 'almacen@andinassold.demo', 'Av. Argentina 1500', 'Oxígeno industrial / soldadura (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Argentina 1500', 'Planta metalmecánica', v_id_pais, v_id_dep, v_id_prov, v_id_dist_lima, TRUE, 1);
  END IF;

  -- Plantas externas (proveedor)
  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C12') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C12', 'PLANTA GASES DEL SUR S.A.C.', v_tipo_proveedor, v_persona_jur, v_doc_ruc, '20100000121', '015678901', 'despacho@gasesdelsur.demo', 'Carretera Central Km 18', 'Proveedor recarga planta externa (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Carretera Central Km 18', 'Planta de llenado', v_id_pais, v_id_dep, v_id_prov, v_id_dist_ate, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C13') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C13', 'OXÍGENO LIMA INDUSTRIAL S.A.', v_tipo_proveedor, v_persona_jur, v_doc_ruc, '20100000131', '015678902', 'planta@oxilima.demo', 'Av. Néstor Gambetta 4500', 'Proveedor medicinal a granel (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Néstor Gambetta 4500', 'Callao / planta', v_id_pais, v_id_dep, v_id_prov, v_id_dist_lima, TRUE, 1);
  END IF;

  -- Cliente / Proveedor
  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C14') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C14', 'DISTRIBUIDORA NORTESUR E.I.R.L.', COALESCE(v_tipo_ambos, v_tipo_cliente), v_persona_jur, v_doc_ruc, '20100000141', '014567894', 'ops@nortesur.demo', 'Av. Tomás Valle 800', 'Compra y reventa de balones (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Av. Tomás Valle 800', 'Almacén principal', v_id_pais, v_id_dep, v_id_prov, v_id_dist_comas, TRUE, 1);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM cli_clientes WHERE codigo_interno = 'DEMO-C15') THEN
    INSERT INTO cli_clientes (codigo_interno, razon_social, id_tipo_cliente, id_tipo_persona, nombres, apellido_paterno, apellido_materno, id_tipo_documento, numero_documento, telefono, email, direccion, observacion, estado)
    VALUES ('DEMO-C15', NULL, v_tipo_paciente, v_persona_nat, 'Elena', 'Paredes', 'Lozano', v_doc_dni, '40123415', '987654315', 'elena.paredes.demo@example.com', 'Jr. Cusco 220', 'Paciente nuevo — primera entrega (demo)', 1)
    RETURNING id INTO v_id_cliente;
    INSERT INTO cli_direcciones (id_cliente, direccion, referencia, id_pais, id_departamento, id_provincia, id_distrito, es_principal, estado)
    VALUES (v_id_cliente, 'Jr. Cusco 220', 'Dpto 101', v_id_pais, v_id_dep, v_id_prov, v_id_dist_lima, TRUE, 1);
  END IF;
END $$;
