-- ============================================================
--  BASE DE DATOS - OXÍGENO SARITA
--  Versión 7.0 | Julio 2026
-- ============================================================
--
--  NEGOCIO
--  -------
--  Empresa distribuidora de gases industriales (Oxígeno, Nitrógeno, Argón,
--  Acetileno, CO2, etc.) ubicada en Perú. Opera con balones/cilindros propios
--  y de clientes. Compra gas a plantas proveedoras, lo almacena en cilindros
--  y lo comercializa a clientes industriales, médicos y particulares.
--
--  MÓDULOS (grupos de tablas)
--  --------------------------
--  1. AUTH        → Usuarios, roles, permisos y sesiones
--  2. GENERALES   → Catálogos (gen_lista/gen_lista_opciones), sucursales, almacenes,
--                   vehículos, choferes, cuentas bancarias, documentos con vencimiento,
--                   configuración SUNAT y servicios externos
--  3. CLIENTES    → Clientes y proveedores (misma tabla cli_clientes), contactos,
--                   direcciones de entrega y condiciones de pago
--  4. PRODUCTOS   → Categorías, subcategorías, productos (gases, accesorios, servicios),
--                   catálogo de precios con costo/flete/margen, stock por almacén y kardex
--  5. BALONES     → Maestro de balones/cilindros (bal_balon) con trazabilidad completa:
--                   movimientos físicos, recargas en planta, préstamos, alquiler,
--                   mantenimiento, historial PH (bal_balon_ph_historial),
--                   baja controlada (bal_baja_balon) y garantías cobradas/devueltas
--  6. VENTAS      → Comprobantes de venta con ciclo FE-SUNAT completo (xml_firmado,
--                   cdr_respuesta, NC/ND), detalle por línea con afectación IGV,
--                   cuotas de crédito y relación con GRE
--  7. GRE         → Guías de Remisión Electrónica (remitente 09 / transportista 31)
--                   con UBIGEO, motivo de traslado y ciclo XML/CDR SUNAT
--  8. FINANZAS    → Cuentas por cobrar y pagar (fin_cuenta + fin_pago),
--                   préstamos bancarios y cuotas (fin_prestamo_banco)
--  9. COMPRAS     → Comprobantes de compra/gasto con clasificación contable de 3 niveles,
--                   afectación de inventario y declaración SUNAT
--
--  FLUJOS DEL NEGOCIO
--  ------------------
--  A. RECARGA DE GAS EN MOSTRADOR (cliente trae su balón — ustedes son la planta)
--       bal_crear_recarga_cliente → bal_movimiento_recarga (tipo CLIENTE) +
--       ven_comprobante (boleta/factura con id_balon en detalle) +
--       bal_movimiento (RECARGA_CLIENTE) + actualización bal_balon
--
--  A2. VENTA DE ACCESORIOS (válvulas, mangueras, etc.)
--       ven_comprobante + ven_comprobante_detalle (productos es_gas=FALSE)
--
--  B. VENTA DE GAS + BALÓN EN PRÉSTAMO
--       bal_prestamo (garantía cobrada → id_comprobante_venta) +
--       bal_prestamo_detalle (cilindros entregados con GRE) +
--       ven_comprobante (factura gas) + gre_guia_remision (salida)
--       Al devolver: fecha devolución en bal_prestamo_detalle + GRE retorno
--
--  C. VENTA DE GAS + VENTA DE BALÓN (cliente compra el cilindro)
--       ven_comprobante con 2 líneas en ven_comprobante_detalle:
--         línea 1 → gas (es_gas=TRUE), línea 2 → balón (id_balon → bal_balon)
--       bal_balon.id_cliente_ubicacion actualizado al cliente comprador
--
--  D. ALQUILER DE BALÓN
--       bal_alquiler (tarifa diaria) + bal_alquiler_detalle (cilindros) +
--       gre_guia_remision (entrega/retiro) +
--       ven_comprobante periódico (id_comprobante_venta en bal_alquiler)
--
--  E. MANTENIMIENTO / REVISIÓN DE BALÓN
--       bal_mantenimiento + ven_comprobante (servicio cobrado al cliente)
--       o com_comprobante_compra (servicio contratado a tercero)
--
--  F. RECARGA EN PLANTA EXTERNA (balones propios enviados a tercero — uso excepcional)
--       bal_movimiento_recarga (tipo PLANTA_EXTERNA, lote + P.H.) +
--       gre_guia_remision salida + gre_guia_remision retorno +
--       com_comprobante_compra (factura de la planta)
--
--  G. CORRECCIÓN / ANULACIÓN DE COMPROBANTE (NC / ND)
--       ven_comprobante tipo 07/08 con id_comprobante_origen apuntando al original
--       y id_motivo_nota (01=Anulación, 07=Descuento, 08=Devolución, 13=Ajuste)
--
--  H. FACTURACIÓN ELECTRÓNICA SUNAT
--       ven_comprobante y gre_guia_remision almacenan:
--         xml_firmado, cdr_respuesta, hash_documento, ticket_sunat, id_estado_sunat
--       gen_configuracion_sunat guarda credenciales SOL y certificado digital
--       id_afectacion_igv por línea vía gen_lista (10 Gravado, 20 Exonerado, 30 Inafecto, 40 Exportación)
--       Ubigeo en gen_distrito.codigo_ubigeo para origen/destino de GREs
--
--  DECISIONES DE DISEÑO
--  --------------------
--  - Sin tablas snapshot ni columnas calculadas: todo se deriva con JOINs y vistas
--  - Clientes y proveedores en una sola tabla (cli_clientes); rol determinado por contexto
--  - Balón identificado por código único; lote solo en la recarga, no en el balón
--  - NC/ND como registros en ven_comprobante (no tabla separada)
--  - gen_chofer y gen_vehiculo usados tanto para flota propia (id_cliente NULL)
--    como para transportistas externos (id_cliente → cli_clientes)
-- ============================================================


-- ============================================================
-- GRUPO 1: AUTENTICACIÓN Y USUARIOS
-- ============================================================

CREATE TABLE auth_usuarios (
    id              SERIAL PRIMARY KEY,
    nombre          varchar(150) NOT NULL,
    correo          varchar(150) NOT NULL UNIQUE,
    contrasena      varchar(255) NOT NULL,
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_roles (
    id              SERIAL PRIMARY KEY,
    nombre          varchar(100) NOT NULL,
    descripcion     varchar(255),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_permisos (
    id              SERIAL PRIMARY KEY,
    nombre          varchar(100) NOT NULL,
    descripcion     varchar(255),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_usuarios_roles (
    id              SERIAL PRIMARY KEY,
    id_usuario       INT NOT NULL REFERENCES auth_usuarios(id),
    id_rol           INT NOT NULL REFERENCES auth_roles(id),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_roles_permisos (
    id              SERIAL PRIMARY KEY,
    id_rol           INT NOT NULL REFERENCES auth_roles(id),
    id_permiso       INT NOT NULL REFERENCES auth_permisos(id),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_sesiones (
    id              SERIAL PRIMARY KEY,
    id_usuario       INT NOT NULL REFERENCES auth_usuarios(id),
    token           varchar(512) NOT NULL,
    ip              varchar(45),
    user_agent       varchar(512),
    fecha_inicio     TIMESTAMP DEFAULT NOW(),
    fecha_fin        TIMESTAMP,
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 2: GENERALES / CATÁLOGOS BASE
-- ============================================================

CREATE TABLE gen_pais (
    id              SERIAL PRIMARY KEY,
    nombre          varchar(100) NOT NULL,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_departamento (
    id              SERIAL PRIMARY KEY,
    id_pais          INT NOT NULL REFERENCES gen_pais(id),
    nombre          varchar(100) NOT NULL,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_provincia (
    id              SERIAL PRIMARY KEY,
    id_departamento  INT NOT NULL REFERENCES gen_departamento(id),
    nombre          varchar(100) NOT NULL,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_distrito (
    id              SERIAL PRIMARY KEY,
    id_provincia     INT NOT NULL REFERENCES gen_provincia(id),
    nombre          varchar(100) NOT NULL,
    codigo_ubigeo    varchar(6),   -- SUNAT UBIGEO 6 dígitos (ej. 140101 = Chiclayo)
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Lista maestra de opciones (equivalente a tablas de tipo/estado)
-- Ejemplos de uso: TipoDocumento, TipoPersona, TipoCuenta, TipoMovimiento, etc.
CREATE TABLE gen_lista (
    id              SERIAL PRIMARY KEY,
    nombre          varchar(100) NOT NULL,
    descripcion     varchar(255),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_lista_opciones (
    id              SERIAL PRIMARY KEY,
    id_lista         INT NOT NULL REFERENCES gen_lista(id),
    nombre          varchar(150) NOT NULL,
    descripcion     varchar(255),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Sucursales de la empresa
CREATE TABLE gen_sucursal (
    id              SERIAL PRIMARY KEY,
    codigo          varchar(20) NOT NULL UNIQUE,
    nombre          varchar(150) NOT NULL,
    direccion       varchar(255),
    id_departamento  INT REFERENCES gen_departamento(id),
    id_provincia     INT REFERENCES gen_provincia(id),
    id_distrito      INT REFERENCES gen_distrito(id),
    telefono        varchar(30),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Almacenes vinculados a sucursal
CREATE TABLE gen_almacen (
    id              SERIAL PRIMARY KEY,
    id_sucursal      INT NOT NULL REFERENCES gen_sucursal(id),
    nombre          varchar(150) NOT NULL,
    ubicacion       varchar(255),
    descripcion     varchar(255),
    id_departamento  INT REFERENCES gen_departamento(id),
    id_provincia     INT REFERENCES gen_provincia(id),
    id_distrito      INT REFERENCES gen_distrito(id),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Condiciones de pago (CONTADO, CREDITO 10 DIAS, etc.)
CREATE TABLE gen_condicion_pago (
    id              SERIAL PRIMARY KEY,
    codigo          varchar(10) NOT NULL UNIQUE,
    nombre          varchar(100) NOT NULL,
    dias_credito     INT NOT NULL DEFAULT 0,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Datos fiscales de la empresa (RUC, razón social)
CREATE TABLE gen_empresa (
    id                  SERIAL PRIMARY KEY,
    ruc                 varchar(11) NOT NULL UNIQUE,
    razon_social         varchar(255),
    nombre_comercial     varchar(150) DEFAULT 'OXIGENO SARITA',
    direccion           varchar(255),
    telefono            varchar(30),
    email               varchar(150),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Metadatos de archivos en storage (Supabase u otro). Usar id como FK donde se necesite adjunto.
CREATE TABLE gen_archivo (
    id                      SERIAL PRIMARY KEY,
    nombre_original         VARCHAR(255) NOT NULL,
    nombre_almacenado       VARCHAR(255) NOT NULL,
    ruta                    VARCHAR(500) NOT NULL,
    bucket                  VARCHAR(100) NOT NULL,
    mime_type               VARCHAR(150),
    extension               VARCHAR(20),
    tamanio_bytes           BIGINT,
    id_empresa              INT REFERENCES gen_empresa(id),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW(),
    UNIQUE (bucket, ruta)
);

-- Credenciales SUNAT / facturación electrónica (SOL)
CREATE TABLE gen_configuracion_sunat (
    id                  SERIAL PRIMARY KEY,
    id_empresa           INT NOT NULL REFERENCES gen_empresa(id),
    usuario_sol          varchar(50) NOT NULL,
    clave_sol            varchar(255) NOT NULL,   -- cifrar en aplicación
    certificado_digital  varchar(255),             -- ruta o referencia al .pfx
    clave_certificado    varchar(255),             -- cifrar en aplicación
    id_ambiente          INT REFERENCES gen_lista_opciones(id),  -- (gen_lista: AmbienteSunat) BETA, PRODUCCION
    -- Credenciales genéricas del PSE/OSE (no atadas a un proveedor concreto)
    proveedor_pse        varchar(50),              -- ej. APISPERU
    pse_habilitado       BOOLEAN NOT NULL DEFAULT TRUE,
    api_base_url         varchar(255),
    api_token            TEXT,                     -- cifrar en aplicación
    api_usuario          varchar(150),
    api_clave            varchar(255),             -- cifrar en aplicación
    ruc_emisor           varchar(11),              -- override; si NULL usa gen_empresa.ruc
    client_id            varchar(255),             -- OAuth (ej. GRE SUNAT CPE)
    client_secret        varchar(255),             -- cifrar en aplicación
    timeout_ms           INTEGER,
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Credenciales de servicios externos (correo, WHEREX, etc.)
CREATE TABLE gen_configuracion_servicio (
    id                  SERIAL PRIMARY KEY,
    codigo              varchar(50) NOT NULL UNIQUE,  -- CORREO, WHEREX...
    nombre              varchar(100) NOT NULL,
    usuario             varchar(150),
    contrasena          varchar(255),                 -- cifrar en aplicación
    email               varchar(150),
    url                 varchar(255),
    observacion         varchar(255),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 3: CLIENTES Y PROVEEDORES
-- ============================================================

CREATE TABLE cli_clientes (
    id                  SERIAL PRIMARY KEY,
    codigo_interno       varchar(20) UNIQUE,        -- 141, 127, 0000002 (cuando no hay RUC/DNI)
    razon_social         varchar(300),              -- nombre completo: LATERCER S.A.C., BANCES DE LA CRUZ...
    id_tipo_cliente       INT REFERENCES gen_lista_opciones(id),  -- Cliente, Paciente, Proveedor...
    id_tipo_persona       INT REFERENCES gen_lista_opciones(id),  -- Natural / Jurídica
    nombres             varchar(200),
    apellido_paterno     varchar(100),
    apellido_materno     varchar(100),
    id_tipo_documento     INT REFERENCES gen_lista_opciones(id),  -- RUC / DNI
    numero_documento     varchar(20) UNIQUE,        -- RUC/DNI; puede ser NULL si solo hay codigo_interno
    direccion           varchar(255),
    referencia          varchar(255),                -- referencia de ubicación
    telefono            varchar(30),
    email               varchar(150),
    id_departamento      INT REFERENCES gen_departamento(id),
    id_provincia         INT REFERENCES gen_provincia(id),
    id_distrito          INT REFERENCES gen_distrito(id),
    id_pais              INT REFERENCES gen_pais(id),
    -- Flags tributarios
    es_agente_percepcion  BOOLEAN DEFAULT FALSE,
    es_buen_contribuyente BOOLEAN DEFAULT FALSE,
    es_agente_retenedor   BOOLEAN DEFAULT FALSE,
    afecto_rus           BOOLEAN DEFAULT FALSE,
    -- SUNAT (texto devuelto por consulta RUC; no es estado del comprobante electrónico)
    situacion_sunat      varchar(50),   -- HABIDO, NO HABIDO
    estado_contribuyente_sunat varchar(50),  -- ACTIVO, BAJA, SUSPENSION TEMPORAL
    observacion         varchar(500),
    -- Control
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Contactos del cliente (múltiples por cliente)
CREATE TABLE cli_contacto (
    id              SERIAL PRIMARY KEY,
    id_cliente       INT NOT NULL REFERENCES cli_clientes(id),
    nombre          varchar(150),
    apellido_paterno varchar(100),
    apellido_materno varchar(100),
    direccion       varchar(255),
    email           varchar(150),
    telefono1       varchar(20),
    telefono2       varchar(20),
    telefono3       varchar(20),
    es_principal     BOOLEAN DEFAULT FALSE,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Direcciones de entrega del cliente (para guías de remisión)
CREATE TABLE cli_direcciones (
    id              SERIAL PRIMARY KEY,
    id_cliente       INT NOT NULL REFERENCES cli_clientes(id),
    descripcion     varchar(150),
    direccion       varchar(255) NOT NULL,
    referencia      varchar(255),
    latitud         NUMERIC(10,8),
    longitud        NUMERIC(11,8),
    id_departamento  INT REFERENCES gen_departamento(id),
    id_provincia     INT REFERENCES gen_provincia(id),
    id_distrito      INT REFERENCES gen_distrito(id),
    id_pais          INT REFERENCES gen_pais(id),
    es_principal     BOOLEAN DEFAULT FALSE,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Vehículos de la empresa y de clientes/proveedores (GRE, flota propia)
-- id_cliente NULL = vehículo de la empresa | id_cliente NOT NULL = del cliente/proveedor
CREATE TABLE gen_vehiculo (
    id                      SERIAL PRIMARY KEY,
    id_cliente               INT REFERENCES cli_clientes(id),
    id_tipo_vehiculo          INT REFERENCES gen_lista_opciones(id),  -- MOTOTAXI, CAMION, MOTO CARGUERA...
    placa                   varchar(20) NOT NULL,
    placa2                  varchar(20),                             -- remolque / segundo vehículo
    marca                   varchar(100),
    marca2                  varchar(100),
    modelo                  varchar(100),
    anio                    INT,
    color                   varchar(50),
    certificado_inscripcion  varchar(50),
    certificado2            varchar(50),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);

-- Choferes de la empresa y de clientes/proveedores
-- id_cliente NULL = chofer de la empresa | id_cliente NOT NULL = del cliente/proveedor
CREATE TABLE gen_chofer (
    id                  SERIAL PRIMARY KEY,
    id_cliente           INT REFERENCES cli_clientes(id),
    apellido_paterno     varchar(100),
    apellido_materno     varchar(100),
    nombres             varchar(150) NOT NULL,
    id_tipo_documento     INT REFERENCES gen_lista_opciones(id),  -- SUNAT: 1=DNI, 4=CE, 7=Pasaporte
    numero_documento     varchar(20),   -- DNI, CE, Pasaporte según id_tipo_documento
    --brevete             varchar(30),
    telefono            varchar(20),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Cuentas bancarias y billeteras de la empresa y de clientes/proveedores
-- id_cliente NULL = cuenta de la empresa | id_cliente NOT NULL = del cliente/proveedor
CREATE TABLE gen_cuenta_bancaria (
    id                          SERIAL PRIMARY KEY,
    id_cliente                   INT REFERENCES cli_clientes(id),
    id_banco                     INT REFERENCES gen_lista_opciones(id),
    id_tipo_cuenta                INT REFERENCES gen_lista_opciones(id),  -- AHORROS, CCI, YAPE, PLIN...
    titular                     varchar(200),
    numero_cuenta                varchar(30),
    numero_cuenta_interbancaria   varchar(30),
    telefono_billetera           varchar(20),          -- YAPE / PLIN
    es_principal                 BOOLEAN DEFAULT FALSE,
    estado                      INT NOT NULL DEFAULT 1,
    id_usuario_creacion           INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion       INT REFERENCES auth_usuarios(id),
    fecha_creacion               TIMESTAMP DEFAULT NOW(),
    fecha_modificacion           TIMESTAMP DEFAULT NOW()
);

-- Vencimientos de documentos: SOAT, inspección vehicular, BPA, extintor, salubridad...
CREATE TABLE gen_documento_vencimiento (
    id                  SERIAL PRIMARY KEY,
    id_categoria        INT REFERENCES gen_lista_opciones(id),  -- VEHICULO, CERTIFICADO, SEGURIDAD...
    descripcion         varchar(255) NOT NULL,
    id_vehiculo          INT REFERENCES gen_vehiculo(id),
    fecha_vencimiento    DATE NOT NULL,
    fecha_renovacion     DATE,
    numero_documento     varchar(50),
    observacion         varchar(255),
    -- Estado: VIGENTE, POR_VENCER, VENCIDO
    id_estado            INT REFERENCES gen_lista_opciones(id),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Solicitudes de baja de clientes (flujo de aprobación)
CREATE TABLE cli_baja_cliente (
    id                  SERIAL PRIMARY KEY,
    id_cliente           INT NOT NULL REFERENCES cli_clientes(id),
    id_motivo_baja       INT REFERENCES gen_lista_opciones(id),  -- MotivoBajaCliente
    fecha_baja           DATE DEFAULT CURRENT_DATE,
    id_usuario_solicita  INT NOT NULL REFERENCES auth_usuarios(id),
    id_usuario_autoriza  INT REFERENCES auth_usuarios(id),
    fecha_autorizacion   TIMESTAMP,
    id_estado_aprobacion INT REFERENCES gen_lista_opciones(id),  -- EstadoAprobacion: PENDIENTE | APROBADA | RECHAZADA
    motivo_detalle       VARCHAR(500),
    estado               INT NOT NULL DEFAULT 1,
    id_usuario_creacion        INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion    INT REFERENCES auth_usuarios(id),
    fecha_creacion        TIMESTAMP DEFAULT NOW(),
    fecha_modificacion    TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_licencia(
    id Serial PRIMARY KEY,
    id_tipo_licencia INT REFERENCES gen_lista_opciones(id), --Vehiculo pesado, vehiculo ligero
    id_categoria_licencia INT REFERENCES gen_lista_opciones(id), --A1,A2,A3
    id_chofer INT REFERENCES gen_chofer(id), 
    codigo VARCHAR(20) NOT NULL UNIQUE, --BREVETE
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
)

-- ============================================================
-- GRUPO 4: PRODUCTOS E INVENTARIO
-- ============================================================

CREATE TABLE pro_categoria (
    id              SERIAL PRIMARY KEY,
    nombre          varchar(100) NOT NULL,
    descripcion     varchar(255),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);
-- Datos iniciales: Gases, Accesorios, Gastos Operativos, Gastos de otros Servicios

CREATE TABLE pro_sub_categoria (
    id              SERIAL PRIMARY KEY,
    id_categoria     INT NOT NULL REFERENCES pro_categoria(id),
    nombre          varchar(100) NOT NULL,
    descripcion     varchar(255),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);
-- Datos iniciales: Oxigeno, Nitrogeno, Argon, Acetileno, Soldadura, Reguladores,
--                 Valvulas, Manometros, Mantenimiento, Carburo...

CREATE TABLE pro_producto (
    id              SERIAL PRIMARY KEY,
    codigo          varchar(30) NOT NULL UNIQUE,
    codigo_barra     varchar(50),
    codigo_ubicacion varchar(20),             -- ubicación/cajón digitable (ej. ARO-GEN-01)
    nombre          varchar(300) NOT NULL,
    id_sub_categoria  INT REFERENCES pro_sub_categoria(id),
    id_unidad_medida  INT REFERENCES gen_lista_opciones(id), -- UNID, MT3, KG, MTS, PAR...
    marca           varchar(100),
    presentacion    varchar(150),
    -- Flags especiales
    es_gas           BOOLEAN DEFAULT FALSE,   -- true si es un gas (Oxigeno, Nitrogeno...)
    es_servicio      BOOLEAN DEFAULT FALSE,   -- true si es un servicio (Mantenimiento, Alquiler...)
    es_alquilable    BOOLEAN DEFAULT FALSE,   -- puede ser alquilado
    afecta_stock     BOOLEAN DEFAULT TRUE,    -- false para servicios puros
    precio          NUMERIC(12,4) DEFAULT 0,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Catálogo de imágenes del producto (archivo físico en storage vía gen_archivo)
CREATE TABLE pro_producto_imagen (
    id                      SERIAL PRIMARY KEY,
    id_producto             INT NOT NULL REFERENCES pro_producto(id),
    id_archivo              INT NOT NULL REFERENCES gen_archivo(id),
    orden                   INT NOT NULL DEFAULT 0,
    es_principal            BOOLEAN NOT NULL DEFAULT FALSE,
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW()
);

-- Catálogo unificado de precios (cilindro recargado, garantía, accesorios)
-- id_tipo_catalogo: RECARGADO | GARANTIA | ACCESORIO (gen_lista TipoCatalogoPrecio)
-- id_tipo_catalogo: RECARGADO (gas+cilindro vendido), GARANTIA (depósito préstamo),
--                VENTA_CILINDRO (cilindro vacío vendido), ACCESORIO
CREATE TABLE pro_catalogo_precio (
    id                      SERIAL PRIMARY KEY,
    id_tipo_catalogo          INT NOT NULL REFERENCES gen_lista_opciones(id),
    periodo                 varchar(20),
    nombre_item              varchar(200) NOT NULL,
    id_producto              INT REFERENCES pro_producto(id),    -- gas asociado
    id_tipo_balon             INT REFERENCES bal_tipo_balon(id),   -- tipo de cilindro (link directo)
    id_proveedor             INT REFERENCES cli_clientes(id),
    clasificacion           varchar(100),
    modelo                  varchar(100),
    capacidad               NUMERIC(10,4),
    id_unidad_medida          INT REFERENCES gen_lista_opciones(id),
    descripcion_presentacion varchar(300),
    costo_producto           NUMERIC(12,4) DEFAULT 0,
    costo_flete              NUMERIC(12,4) DEFAULT 0,
    porcentaje_margen        NUMERIC(6,2),
    precio_final             NUMERIC(12,4),    -- precio confirmado (app calcula margen, usuario ajusta)
    precio_garantia          NUMERIC(12,4),    -- depósito al prestar el cilindro
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);

-- Stock por producto y almacén
CREATE TABLE pro_stock (
    id              SERIAL PRIMARY KEY,
    id_almacen       INT NOT NULL REFERENCES gen_almacen(id),
    id_producto      INT NOT NULL REFERENCES pro_producto(id),
    stock           NUMERIC(12,4) NOT NULL DEFAULT 0,
    stock_minimo     NUMERIC(12,4) DEFAULT 0,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW(),
    UNIQUE(id_almacen, id_producto)
);

-- Kardex / movimientos de inventario
CREATE TABLE pro_movimientos (
    id                  SERIAL PRIMARY KEY,
    fecha               DATE NOT NULL,
    id_producto          INT NOT NULL REFERENCES pro_producto(id),
    id_almacen           INT NOT NULL REFERENCES gen_almacen(id),
    id_tipo_movimiento    INT REFERENCES gen_lista_opciones(id), -- INGRESO, SALIDA, TRASLADO...
    cantidad            NUMERIC(12,4) NOT NULL,
    stock_anterior       NUMERIC(12,4),
    stock_nuevo          NUMERIC(12,4),
    id_documento_ref      INT,                                              -- ID del documento origen (polimórfico)
    id_tipo_documento_ref  INT REFERENCES gen_lista_opciones(id),            -- (gen_lista: TipoDocumentoRef)
    glosa               varchar(255),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 5: BALONES / CILINDROS (CORE DEL NEGOCIO)
-- ============================================================

-- Catálogo de tipos de balón
-- Cada balón físico tendrá su propio registro con número de serie
CREATE TABLE bal_tipo_balon (
    id              SERIAL PRIMARY KEY,
    nombre          varchar(150) NOT NULL,  -- "Oxígeno Industrial 10m3", "Oxígeno Medicinal 1m3"...
    id_gas           INT REFERENCES pro_producto(id),  -- gas que contiene
    capacidad       NUMERIC(10,4),          -- en m3 o kg
    id_unidad_medida  INT REFERENCES gen_lista_opciones(id),
    peso            NUMERIC(10,4),          -- peso tara en kg
    vigencia_ph_anios INT NOT NULL DEFAULT 5, -- vigencia PH por normativa del tipo/gas (5 o 10 años)
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Registro individual de cada balón físico (libro de cilindros / trazabilidad total)
CREATE TABLE bal_balon (
    id                  SERIAL PRIMARY KEY,
    codigo_balon         varchar(50) NOT NULL UNIQUE,  -- identificador principal / número de serie
    numero_serie         varchar(50),                 -- número de serie del fabricante (si difiere del código)
    libro_cilindro       varchar(30),                 -- LIBRO 1, LIBRO 5, SIN LIBRO...
    pagina_libro         INT,                         -- PAG. 103, 0 si sin libro
    fecha_registro       DATE,                        -- FECHA de asignación / registro actual
    id_almacen           INT REFERENCES gen_almacen(id),
    id_cliente_ubicacion  INT REFERENCES cli_clientes(id),
    -- Propiedad del envase
    id_propietario       INT REFERENCES gen_lista_opciones(id),  -- EMPRESA / CLIENTE / PROPIA / PLANTA
    id_cliente_propietario INT REFERENCES cli_clientes(id),
    id_referencia        INT REFERENCES gen_lista_opciones(id),  -- ReferenciaCilindro
    -- Identificación del envase
    id_marca_cilindro     INT REFERENCES gen_lista_opciones(id), -- MarcaCilindro: JP, JD, YA, LD...
    id_organo_inspector   INT REFERENCES gen_lista_opciones(id), -- OrganoInspectorCilindro
    organo_inspector_no_aplica BOOLEAN NOT NULL DEFAULT FALSE,
    -- Gas / producto actual en el cilindro
    id_tipo_balon         INT REFERENCES bal_tipo_balon(id),
    id_producto_gas       INT REFERENCES pro_producto(id),
    -- Estado actual del balón
    id_estado_balon       INT REFERENCES gen_lista_opciones(id),
    -- Prueba hidrostática (snapshot vigente)
    fecha_ultima_prueba_hidrostatica   DATE,
    vigencia_prueba_hidrostatica_anios INT DEFAULT 5,
    fecha_proxima_prueba_hidrostatica  DATE,
    -- Datos técnicos adicionales
    fecha_fabricacion    DATE,
    anio_fabricacion     SMALLINT,                    -- año de fabricación (consulta rápida)
    numero_recepcion     varchar(30),
    presion_actual       NUMERIC(8,2),
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Historial de movimientos/estados del balón (trazabilidad completa)
CREATE TABLE bal_movimiento (
    id                  SERIAL PRIMARY KEY,
    id_balon             INT NOT NULL REFERENCES bal_balon(id),
    id_tipo_movimiento    INT REFERENCES gen_lista_opciones(id),
    -- Tipos: SALIDA_VENTA, SALIDA_PRESTAMO, SALIDA_ALQUILER, SALIDA_MANTENIMIENTO,
    --        ENTRADA_DEVOLUCION, ENTRADA_LLENADO, TRASLADO_LIMA, RETORNO_LIMA
    id_documento_ref      INT,                                              -- ID del documento asociado (polimórfico)
    id_tipo_documento_ref  INT REFERENCES gen_lista_opciones(id),            -- (gen_lista: TipoDocumentoRef)
    id_cliente           INT REFERENCES cli_clientes(id),
    id_almacen_origen     INT REFERENCES gen_almacen(id),
    id_almacen_destino    INT REFERENCES gen_almacen(id),
    fecha_movimiento     TIMESTAMP NOT NULL DEFAULT NOW(),
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Recarga de cilindro: CLIENTE (mostrador) o PLANTA_EXTERNA (envío a tercero)
CREATE TABLE bal_movimiento_recarga (
    id                      SERIAL PRIMARY KEY,
    fecha_salida_almacen      DATE NOT NULL,
    id_balon                 INT NOT NULL REFERENCES bal_balon(id),
    id_cliente               INT REFERENCES cli_clientes(id),           -- cliente que trae el balón (tipo CLIENTE)
    id_tipo_recarga          INT REFERENCES gen_lista_opciones(id),      -- (gen_lista: TipoRecarga) CLIENTE | PLANTA_EXTERNA
    id_producto              INT REFERENCES pro_producto(id),
    capacidad               NUMERIC(10,4),
    id_unidad_medida          INT REFERENCES gen_lista_opciones(id),
    -- Guías de remisión
    serie_guia_salida                 varchar(10),
    numero_guia_salida                varchar(15),
    serie_guia_ingreso                varchar(10),
    numero_guia_ingreso               varchar(15),
    -- Factura asociada
    serie_factura                    varchar(10),
    numero_factura                   varchar(15),
    id_comprobante                   INT REFERENCES ven_comprobante(id),
    fecha_llegada_almacen             DATE,
    lote                            varchar(50),
    fecha_vencimiento_lote            DATE,
    fecha_prueba_hidrostatica         DATE,           -- P.H. certificada en esta recarga (proveedor en id_proveedor)
    id_proveedor             INT REFERENCES cli_clientes(id),       -- planta de recarga / P.H.
    observacion             varchar(500),
    id_almacen               INT REFERENCES gen_almacen(id),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion           INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion       INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);

-- Préstamo de balones: cliente, empresa↔cliente, o planta proveedora
CREATE TABLE bal_prestamo (
    id                  SERIAL PRIMARY KEY,
    numero_prestamo      varchar(30) UNIQUE,
    id_tipo_prestamo      INT NOT NULL REFERENCES gen_lista_opciones(id),
    -- Tipos: ENVASE_EMPRESA_A_CLIENTE, CILINDRO_CLIENTE_A_EMPRESA, CILINDRO_A_PLANTA
    id_cliente           INT REFERENCES cli_clientes(id),
    id_proveedor         INT REFERENCES cli_clientes(id),
    id_almacen           INT REFERENCES gen_almacen(id),
    fecha_salida         DATE,
    fecha_retorno_pactada DATE,
    fecha_retorno_real    DATE,
    titulo              varchar(200),
    observacion         varchar(500),
    id_estado            INT REFERENCES gen_lista_opciones(id),
    id_comprobante_venta  INT REFERENCES ven_comprobante(id),       -- garantía cobrada al cliente
    id_comprobante_compra INT REFERENCES com_comprobante_compra(id), -- factura recibida del proveedor
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Detalle de cilindros en préstamo (cliente o planta) con guías GRE
CREATE TABLE bal_prestamo_detalle (
    id                  SERIAL PRIMARY KEY,
    id_prestamo          INT NOT NULL REFERENCES bal_prestamo(id),
    id_balon             INT REFERENCES bal_balon(id),
    id_producto          INT REFERENCES pro_producto(id),
    motivo_especifico    varchar(255),
    fecha_entregado      DATE,
    fecha_prestamo       DATE,
    dias_prestamo        INT DEFAULT 30,
    fecha_vencimiento    DATE,
    fecha_devolucion     DATE,
    serie_guia_entrega    varchar(10),
    numero_guia_entrega   varchar(15),
    serie_guia_devolucion varchar(10),
    numero_guia_devolucion varchar(15),
    id_estado            INT REFERENCES gen_lista_opciones(id),
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Alquiler de balones de la empresa al cliente
CREATE TABLE bal_alquiler (
    id                  SERIAL PRIMARY KEY,
    numero_alquiler      varchar(30) NOT NULL UNIQUE,
    id_cliente           INT NOT NULL REFERENCES cli_clientes(id),
    id_almacen           INT NOT NULL REFERENCES gen_almacen(id),
    fecha_inicio         DATE NOT NULL,
    fecha_fin_pactada     DATE,
    fecha_fin_real        DATE,
    tarifa_diaria        NUMERIC(10,4) DEFAULT 0,
    total_cobrado        NUMERIC(12,4) DEFAULT 0,
    -- Estado: ACTIVO, FINALIZADO, FACTURADO
    id_estado            INT REFERENCES gen_lista_opciones(id),
    observacion         varchar(500),
    id_comprobante_venta  INT REFERENCES ven_comprobante(id),       -- factura emitida al cliente
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Detalle de balones en alquiler
CREATE TABLE bal_alquiler_detalle (
    id              SERIAL PRIMARY KEY,
    id_alquiler      INT NOT NULL REFERENCES bal_alquiler(id),
    id_balon         INT NOT NULL REFERENCES bal_balon(id),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Mantenimiento de cilindros (recertificación, prueba hidrostática, reparación)
CREATE TABLE bal_mantenimiento (
    id                  SERIAL PRIMARY KEY,
    id_balon             INT NOT NULL REFERENCES bal_balon(id),
    id_tipo_mantenimiento INT REFERENCES gen_lista_opciones(id),
    -- Tipos: PRUEBA_HIDROSTATICA, RECERTIFICACION, REPARACION, PINTURA, VALVULA
    fecha_ingreso        DATE NOT NULL,
    fecha_salida         DATE,
    descripcion         varchar(500),
    costo               NUMERIC(10,4) DEFAULT 0,
    -- Si es mantenimiento externo (Lima u otro proveedor)
    es_externo           BOOLEAN DEFAULT FALSE,
    id_proveedor         INT REFERENCES cli_clientes(id),           -- taller externo (Lima u otro)
    -- Estado: PENDIENTE, EN_PROCESO, FINALIZADO
    id_estado            INT REFERENCES gen_lista_opciones(id),
    id_comprobante_venta  INT REFERENCES ven_comprobante(id),       -- si se cobra al cliente
    id_comprobante_compra INT REFERENCES com_comprobante_compra(id), -- si es externo (proveedor Lima)
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Historial de pruebas hidrostáticas por cilindro (renovaciones PH)
CREATE TABLE bal_balon_ph_historial (
    id                      SERIAL PRIMARY KEY,
    id_balon                 INT NOT NULL REFERENCES bal_balon(id),
    fecha_prueba             DATE NOT NULL,
    vigencia_anios           INT NOT NULL DEFAULT 5,
    fecha_proxima            DATE,
    id_organo_inspector      INT REFERENCES gen_lista_opciones(id),
    organo_inspector_no_aplica BOOLEAN NOT NULL DEFAULT FALSE,
    numero_certificado       varchar(50),
    id_mantenimiento         INT REFERENCES bal_mantenimiento(id),
    id_movimiento_recarga    INT REFERENCES bal_movimiento_recarga(id),
    es_vigente               BOOLEAN NOT NULL DEFAULT TRUE,
    observacion             varchar(500),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion           INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion       INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);

-- Baja controlada de cilindro (motivo obligatorio + autorización de administrador)
CREATE TABLE bal_baja_balon (
    id                      SERIAL PRIMARY KEY,
    id_balon                 INT NOT NULL REFERENCES bal_balon(id),
    id_motivo_baja           INT NOT NULL REFERENCES gen_lista_opciones(id), -- MotivoBajaBalon
    fecha_baja               DATE NOT NULL DEFAULT CURRENT_DATE,
    id_usuario_solicita      INT NOT NULL REFERENCES auth_usuarios(id),
    id_usuario_autoriza      INT REFERENCES auth_usuarios(id),
    fecha_autorizacion       TIMESTAMP,
    estado_aprobacion        VARCHAR(20) NOT NULL DEFAULT 'APROBADA', -- PENDIENTE | APROBADA | RECHAZADA
    motivo_detalle           varchar(500),  -- texto adicional (ej. cuando motivo = OTROS)
    id_cliente_comprador     INT REFERENCES cli_clientes(id),
    id_comprobante_venta     INT REFERENCES ven_comprobante(id),
    serie_comprobante        varchar(10),
    numero_comprobante       varchar(15),
    monto_venta              NUMERIC(12,4),
    id_movimiento            INT REFERENCES bal_movimiento(id),
    observacion             varchar(500),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion           INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion       INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 6: VENTAS / FACTURACIÓN
-- ============================================================

CREATE TABLE ven_comprobante (
    id                  SERIAL PRIMARY KEY,
    -- Identificación SUNAT
    id_tipo_comprobante   INT REFERENCES gen_lista_opciones(id),  -- FACTURA(01), BOLETA(03), NC(07), ND(08)
    serie               varchar(10) NOT NULL,
    numero              varchar(15) NOT NULL,
    id_estado_sunat       INT REFERENCES gen_lista_opciones(id),  -- (gen_lista: EstadoSunat)
    id_tipo_operacion_sunat INT REFERENCES gen_lista_opciones(id), -- (gen_lista: TipoOperacionSunat)
    -- Nota de crédito / débito: referencia al comprobante que corrige
    id_comprobante_origen INT REFERENCES ven_comprobante(id),   -- NULL si es FC/BL normal
    id_motivo_nota        INT REFERENCES gen_lista_opciones(id),  -- MotivoNotaCredito o MotivoNotaDebito según tipo
    -- Ciclo electrónico SUNAT
    ticket_sunat         varchar(100),  -- ticket async para consultar CDR
    hash_documento       varchar(100),  -- hash del XML firmado
    xml_firmado          TEXT,          -- XML enviado a SUNAT (firmado)
    cdr_respuesta        TEXT,          -- CDR de respuesta de SUNAT
    -- Datos del documento
    id_tipo_movimiento    INT REFERENCES gen_lista_opciones(id),  -- MOV. DIVERSOS, etc.
    id_tipo_venta         INT REFERENCES gen_lista_opciones(id),  -- VENTAS C/S GUIAS REMISION
    fecha               DATE NOT NULL,
    fecha_vencimiento    DATE,
    tipo_cambio          NUMERIC(10,4) DEFAULT 3.5,
    -- Partes
    id_cliente           INT NOT NULL REFERENCES cli_clientes(id),
    id_sucursal          INT REFERENCES gen_sucursal(id),
    id_almacen           INT REFERENCES gen_almacen(id),
    id_condicion_pago     INT REFERENCES gen_condicion_pago(id),
    id_moneda            INT REFERENCES gen_lista_opciones(id),  -- Nuevos Soles, USD
    id_medio_pago         INT REFERENCES gen_lista_opciones(id),  -- (gen_lista: MedioPago)
    -- Importes
    sub_total            NUMERIC(12,4) DEFAULT 0,
    descuento           NUMERIC(12,4) DEFAULT 0,
    valor_venta          NUMERIC(12,4) DEFAULT 0,
    igv                 NUMERIC(12,4) DEFAULT 0,
    total_importe        NUMERIC(12,4) DEFAULT 0,
    anticipos           NUMERIC(12,4) DEFAULT 0,
    exonerado           NUMERIC(12,4) DEFAULT 0,
    -- Glosa y observaciones
    glosa               varchar(500),
    observaciones       varchar(500),
    -- Contabilidad
    periodo_contable     varchar(10),
    operacion           varchar(100),
    -- Estado: PENDIENTE, PAGADO, ANULADO
    id_estado            INT REFERENCES gen_lista_opciones(id),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW(),
    UNIQUE(serie, numero)
);

-- Resumen diario de boletas (comunicación asíncrona a SUNAT)
CREATE TABLE ven_resumen_diario (
    id                      SERIAL PRIMARY KEY,
    fecha                   DATE NOT NULL,
    correlativo             VARCHAR(10) NOT NULL,
    identificador           VARCHAR(50),
    ticket_sunat            VARCHAR(100),
    id_estado_sunat         INT REFERENCES gen_lista_opciones(id),
    hash_documento          VARCHAR(100),
    xml_firmado             TEXT,
    cdr_respuesta           TEXT,
    moneda                  VARCHAR(3) DEFAULT 'PEN',
    cantidad_docs           INT NOT NULL DEFAULT 0,
    total_importe           NUMERIC(12,4) NOT NULL DEFAULT 0,
    total_igv               NUMERIC(12,4) NOT NULL DEFAULT 0,
    total_valor_venta       NUMERIC(12,4) NOT NULL DEFAULT 0,
    observacion             VARCHAR(500),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW(),
    UNIQUE (fecha, correlativo)
);

CREATE TABLE ven_resumen_diario_detalle (
    id                      SERIAL PRIMARY KEY,
    id_resumen              INT NOT NULL REFERENCES ven_resumen_diario(id),
    id_comprobante          INT NOT NULL REFERENCES ven_comprobante(id),
    item                    INT NOT NULL,
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW(),
    UNIQUE (id_resumen, id_comprobante)
);

-- Detalle de cada línea del comprobante
CREATE TABLE ven_comprobante_detalle (
    id                  SERIAL PRIMARY KEY,
    id_comprobante       INT NOT NULL REFERENCES ven_comprobante(id),
    item                INT NOT NULL,
    id_producto          INT NOT NULL REFERENCES pro_producto(id),
    descripcion         varchar(300),
    id_unidad_medida      INT REFERENCES gen_lista_opciones(id),
    cantidad            NUMERIC(12,4) NOT NULL,
    precio_unitario      NUMERIC(12,6) NOT NULL,
    descuento           NUMERIC(12,4) DEFAULT 0,
    valor_venta          NUMERIC(12,4),
    porcentaje_igv       NUMERIC(6,4) DEFAULT 18,
    id_afectacion_igv     INT REFERENCES gen_lista_opciones(id),  -- (gen_lista: AfectacionIgv) 10, 20, 30, 40
    impuesto            NUMERIC(12,4),
    importe             NUMERIC(12,4),
    -- Si el producto es un balón específico, referenciar
    id_balon             INT REFERENCES bal_balon(id),
    capacidad_cilindro   NUMERIC(10,4),
    id_estado_cilindro    INT REFERENCES gen_lista_opciones(id),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Relación comprobante → Guía de Remisión
 
-- Cuotas de pago para ventas a crédito
CREATE TABLE ven_cuotas (
    id              SERIAL PRIMARY KEY,
    id_comprobante   INT NOT NULL REFERENCES ven_comprobante(id),
    numero_cuota     INT NOT NULL,
    fecha_vencimiento DATE NOT NULL,
    monto           NUMERIC(12,4) NOT NULL,
    monto_pagado     NUMERIC(12,4) DEFAULT 0,
    -- Estado: PENDIENTE, PAGADO, VENCIDO
    id_estado        INT REFERENCES gen_lista_opciones(id),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Garantía de envase/cilindro cobrada al cliente
-- Una garantía puede cubrir uno o varios cilindros del mismo préstamo
CREATE TABLE ven_garantia (
    id                  SERIAL PRIMARY KEY,
    id_cliente           INT NOT NULL REFERENCES cli_clientes(id),
    id_prestamo          INT REFERENCES bal_prestamo(id),       -- préstamo que originó la garantía
    ubicacion           varchar(150),
    id_producto          INT REFERENCES pro_producto(id),
    cantidad_venta       NUMERIC(12,4),
    id_unidad_medida      INT REFERENCES gen_lista_opciones(id),
    fecha_registro       DATE NOT NULL,
    monto_cobrado        NUMERIC(12,4) NOT NULL DEFAULT 0,
    monto_devuelto       NUMERIC(12,4) NOT NULL DEFAULT 0,
    monto_saldo          NUMERIC(12,4) NOT NULL DEFAULT 0,
    id_estado            INT REFERENCES gen_lista_opciones(id),  -- ACTIVA, DEVUELTA, PARCIAL
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Movimientos de garantía: cobro inicial y devoluciones parciales/totales
-- COBRO  → id_comprobante apunta a la factura/boleta de cobro de garantía
-- DEVOLUCION → id_comprobante apunta a la Nota de Crédito emitida al devolver
CREATE TABLE ven_garantia_movimiento (
    id                  SERIAL PRIMARY KEY,
    id_garantia          INT NOT NULL REFERENCES ven_garantia(id),
    id_tipo_movimiento    INT NOT NULL REFERENCES gen_lista_opciones(id), -- COBRO, DEVOLUCION
    id_comprobante       INT REFERENCES ven_comprobante(id),            -- FC cobro o NC devolución
    fecha               DATE NOT NULL,
    monto               NUMERIC(12,4) NOT NULL,
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 7: GUÍAS DE REMISIÓN (GRE)
-- ============================================================

CREATE TABLE gre_guia_remision (
    id                      SERIAL PRIMARY KEY,
    -- Identificación SUNAT
    id_tipo_guia_remision      INT REFERENCES gen_lista_opciones(id),  -- (gen_lista: TipoGuiaRemision) 09, 31
    serie                   varchar(10) NOT NULL,
    numero                  varchar(15) NOT NULL,
    id_estado_sunat           INT REFERENCES gen_lista_opciones(id),  -- (gen_lista: EstadoSunat)
    -- Ciclo electrónico SUNAT
    ticket_sunat             varchar(100),
    hash_documento           varchar(100),
    xml_firmado              TEXT,
    cdr_respuesta            TEXT,
    fecha                   DATE NOT NULL,
    tipo_cambio              NUMERIC(10,4) DEFAULT 3.5,
    id_sucursal              INT NOT NULL REFERENCES gen_sucursal(id),
    id_almacen               INT NOT NULL REFERENCES gen_almacen(id),
    id_cliente               INT REFERENCES cli_clientes(id),
    -- Traslado
    fecha_traslado           DATE NOT NULL,
    id_motivo_traslado        INT REFERENCES gen_lista_opciones(id),   -- (gen_lista: MotivoTraslado)
    id_unidad_medida          INT REFERENCES gen_lista_opciones(id),
    peso_bruto               NUMERIC(10,4),
    numero_bultos            INT,
    -- Origen (la dirección se deriva de gen_sucursal; se puede sobreescribir)
    direccion_origen         varchar(255),
    id_distrito_origen        INT REFERENCES gen_distrito(id),  -- codigo_ubigeo requerido por SUNAT
    -- Destinatario
    id_destinatario          INT REFERENCES cli_clientes(id),
    direccion_llegada        varchar(255),
    id_distrito_llegada       INT REFERENCES gen_distrito(id),  -- codigo_ubigeo requerido por SUNAT
    -- Transporte (chofer y vehículo de la empresa o del cliente/proveedor)
    id_modalidad_traslado     INT REFERENCES gen_lista_opciones(id),  -- PRIVADO(02), PUBLICO(01)
    id_transportista         INT REFERENCES cli_clientes(id),       -- RUC del transportista (modalidad pública)
    id_chofer                INT REFERENCES gen_chofer(id),
    id_vehiculo              INT REFERENCES gen_vehiculo(id),
    -- Responsable interno
    id_responsable           INT REFERENCES auth_usuarios(id),
    observaciones           varchar(500),
    -- Contabilidad
    periodo_contable         varchar(10),
    operacion               varchar(100),
    -- Estado: PENDIENTE, ENVIADO, RECIBIDO, ANULADO
    id_estado                INT REFERENCES gen_lista_opciones(id),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion           TIMESTAMP DEFAULT NOW(),
    fecha_modificacion       TIMESTAMP DEFAULT NOW(),
    UNIQUE(serie, numero)
);

-- Detalle de la guía de remisión
CREATE TABLE gre_guia_remision_detalle (
    id              SERIAL PRIMARY KEY,
    id_guia_remision  INT NOT NULL REFERENCES gre_guia_remision(id),
    item            INT NOT NULL,
    id_producto      INT NOT NULL REFERENCES pro_producto(id),
    descripcion     varchar(300),
    id_unidad_medida  INT REFERENCES gen_lista_opciones(id),
    cantidad        NUMERIC(12,4) NOT NULL,
    -- Balón específico si aplica
    id_balon         INT REFERENCES bal_balon(id),
    glosa           varchar(255),
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Documentos de referencia de la guía (facturas, boletas, otras GRE asociadas)
CREATE TABLE gre_documentos_referencia (
    id                  SERIAL PRIMARY KEY,
    id_guia_remision      INT NOT NULL REFERENCES gre_guia_remision(id),
    id_tipo_comprobante   INT NOT NULL REFERENCES gen_lista_opciones(id),  -- (gen_lista: TipoComprobante) 01, 03, 09...
    serie               varchar(10),
    numero              varchar(15),
    fecha               DATE,
    estado          INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion   TIMESTAMP DEFAULT NOW(),
    fecha_modificacion TIMESTAMP DEFAULT NOW()
);

-- Control de rangos de numeración de guías asignados (ej. GUIAS JHON 8554-8600)
CREATE TABLE gre_rango_numeracion (
    id                  SERIAL PRIMARY KEY,
    responsable         varchar(100) NOT NULL,     -- JHON
    descripcion         varchar(150),              -- GUIAS JHON
    serie               varchar(10),
    numero_inicio        INT NOT NULL,              -- 8554
    numero_fin           INT NOT NULL,              -- 8600
    numero_actual        INT,                       -- último usado
    fecha_asignacion     DATE,
    observacion         varchar(255),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 8: FINANZAS — CUENTAS POR COBRAR / PAGAR Y COBRANZA
-- ============================================================

-- Cuentas por cobrar y por pagar unificadas
-- id_tipo_cuenta: COBRAR (cliente) | PAGAR (proveedor)
CREATE TABLE fin_cuenta (
    id                  SERIAL PRIMARY KEY,
    id_tipo_cuenta        INT NOT NULL REFERENCES gen_lista_opciones(id),
    id_tercero           INT NOT NULL REFERENCES cli_clientes(id),
    id_comprobante_venta  INT REFERENCES ven_comprobante(id),
    id_comprobante_compra INT REFERENCES com_comprobante_compra(id),
    id_cuota             INT REFERENCES ven_cuotas(id),
    fecha_emision        DATE NOT NULL,
    fecha_vencimiento    DATE,
    monto_pendiente      NUMERIC(12,4) NOT NULL,
    monto_abonado        NUMERIC(12,4) DEFAULT 0,
    monto_saldo          NUMERIC(12,4),
    id_estado            INT REFERENCES gen_lista_opciones(id),
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE fin_pago (
    id                  SERIAL PRIMARY KEY,
    id_cuenta            INT NOT NULL REFERENCES fin_cuenta(id),
    fecha_pago           DATE NOT NULL,
    monto               NUMERIC(12,4) NOT NULL,
    id_medio_pago         INT REFERENCES gen_lista_opciones(id),
    referencia          varchar(100),
    observacion         varchar(255),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion    INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 9: FINANZAS (PRÉSTAMOS BANCARIOS)
-- ============================================================

CREATE TABLE fin_prestamo_banco (
    id                  SERIAL PRIMARY KEY,
    id_banco             INT REFERENCES gen_lista_opciones(id),
    descripcion         varchar(255),
    monto_total          NUMERIC(14,4),
    numero_cuotas        INT,
    fecha_inicio         DATE,
    tasa_interes         NUMERIC(8,4),
    -- Estado: ACTIVO, CANCELADO
    id_estado            INT REFERENCES gen_lista_opciones(id),
    observacion         varchar(500),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE fin_prestamo_banco_cuota (
    id                  SERIAL PRIMARY KEY,
    id_prestamo_banco     INT NOT NULL REFERENCES fin_prestamo_banco(id),
    numero_cuota         INT NOT NULL,
    importe             NUMERIC(12,4) NOT NULL,
    fecha_vencimiento    DATE,
    fecha_pago           DATE,
    id_medio_pago         INT REFERENCES gen_lista_opciones(id),  -- TRANSFERENCIA, CHEQUE, DÉBITO AUTOMÁTICO
    numero_operacion     varchar(50),                            -- N° operación / N° cheque
    id_cuenta_bancaria    INT REFERENCES gen_cuenta_bancaria(id), -- cuenta empresa debitada
    -- Estado: PENDIENTE, PAGADO, VENCIDO
    id_estado            INT REFERENCES gen_lista_opciones(id),
    observacion         varchar(255),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW(),
    UNIQUE(id_prestamo_banco, numero_cuota)
);


-- ============================================================
-- GRUPO 10: COMPRAS, GASTOS Y CUENTAS POR PAGAR
-- ============================================================

-- Clasificación contable / operativa en 3 niveles (Grupo > Subgrupo > Sub subgrupo)
-- Ej: GASES INDUSTRIALES > GAS NOBLE > OXIGENO GAS INDUSTRIAL
--     OFICINA > GASTOS ADMINISTRATIVOS > MANO DE OBRA
--     CAMIÓN > GASTOS DE TRANSPORTE > COMBUSTIBLES
CREATE TABLE gen_clasificacion_gasto (
    id                  SERIAL PRIMARY KEY,
    grupo               varchar(100) NOT NULL,     -- OFICINA, CAMIÓN, GASES INDUSTRIALES, FLETE...
    subgrupo            varchar(100) NOT NULL,     -- GASTOS ADMINISTRATIVOS, GAS NOBLE...
    sub_subgrupo         varchar(100) NOT NULL,   -- MANO DE OBRA, OXIGENO GAS INDUSTRIAL...
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW(),
    UNIQUE(grupo, subgrupo, sub_subgrupo)
);

-- Comprobante de compra o gasto (factura proveedor, gasto sin proveedor, tributos SUNAT...)
CREATE TABLE com_comprobante_compra (
    id                  SERIAL PRIMARY KEY,
    id_tipo_comprobante   INT REFERENCES gen_lista_opciones(id),  -- FACTURA, BOLETA, S/D, RR.HH... (gen_lista: TipoComprobante)
    serie               varchar(10),
    numero              varchar(15),
    fecha               DATE NOT NULL,
    id_proveedor         INT REFERENCES cli_clientes(id),
    id_tipo_registro      INT REFERENCES gen_lista_opciones(id),  -- COMPRA, GASTO
    id_categoria_gasto    INT REFERENCES gen_lista_opciones(id),  -- Combustible, Tributos, Flete...
    id_sucursal          INT REFERENCES gen_sucursal(id),
    id_almacen           INT REFERENCES gen_almacen(id),
    id_moneda            INT REFERENCES gen_lista_opciones(id),
    id_condicion_pago     INT REFERENCES gen_condicion_pago(id),
    sub_total            NUMERIC(12,4) DEFAULT 0,
    igv                 NUMERIC(12,4) DEFAULT 0,
    total_importe        NUMERIC(12,4) DEFAULT 0,
    afecta_inventario    BOOLEAN DEFAULT FALSE,     -- true si ingresa stock (gases, cilindros...)
    declarar_sunat       BOOLEAN DEFAULT FALSE,     -- true = factura a declarar ante SUNAT (secc. IV y V)
    glosa               varchar(500),
    -- Estado: PENDIENTE, PAGADO, ANULADO
    id_estado            INT REFERENCES gen_lista_opciones(id),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Detalle de compra/gasto por línea (clasificación + pago por línea como en Excel de egresos)
CREATE TABLE com_comprobante_compra_detalle (
    id                  SERIAL PRIMARY KEY,
    id_comprobante       INT NOT NULL REFERENCES com_comprobante_compra(id),
    item                INT NOT NULL,
    id_clasificacion_gasto INT REFERENCES gen_clasificacion_gasto(id),
    id_producto          INT REFERENCES pro_producto(id),
    descripcion         varchar(300) NOT NULL,
    id_unidad_medida      INT REFERENCES gen_lista_opciones(id),
    cantidad            NUMERIC(12,4) NOT NULL,
    precio_unitario      NUMERIC(12,6),
    importe             NUMERIC(12,4) NOT NULL,
    -- Pago de la línea
    id_medio_pago         INT REFERENCES gen_lista_opciones(id),
    fecha_pago           DATE,
    numero_operacion     varchar(50),
    id_estado_pago        INT REFERENCES gen_lista_opciones(id),
    observacion         varchar(500),
    afecta_stock         BOOLEAN DEFAULT FALSE,
    id_pago              INT REFERENCES fin_pago(id),
    estado              INT NOT NULL DEFAULT 1,
    id_usuario_creacion       INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion   INT REFERENCES auth_usuarios(id),
    fecha_creacion       TIMESTAMP DEFAULT NOW(),
    fecha_modificacion   TIMESTAMP DEFAULT NOW()
);

-- Agenda de Actividades
CREATE TABLE age_actividad (
    id                      SERIAL PRIMARY KEY,
    titulo                  varchar(150) NOT NULL,
    descripcion             text,
    fecha_programada        DATE NOT NULL,
    hora_inicio_estimada    TIME,
    hora_fin_estimada       TIME,
    fecha_hora_cierre       TIMESTAMP,
    id_tipo_actividad       INT NOT NULL REFERENCES gen_lista_opciones(id),
    id_prioridad            INT NOT NULL REFERENCES gen_lista_opciones(id),
    id_cliente              INT REFERENCES cli_clientes(id),
    id_usuario_responsable  INT REFERENCES auth_usuarios(id),
    id_estado_actividad     INT NOT NULL REFERENCES gen_lista_opciones(id),
    observaciones           varchar(500),
    estado                  INT NOT NULL DEFAULT 1,
    id_usuario_creacion     INT REFERENCES auth_usuarios(id),
    id_usuario_modificacion INT REFERENCES auth_usuarios(id),
    fecha_creacion          TIMESTAMP DEFAULT NOW(),
    fecha_modificacion      TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES RECOMENDADOS PARA PERFORMANCE
-- ============================================================

-- Clientes
CREATE INDEX idx_cli_clientes_numDoc ON cli_clientes(numero_documento);
CREATE INDEX idx_cli_clientes_codigo ON cli_clientes(codigo_interno);
CREATE INDEX idx_cli_clientes_razon ON cli_clientes(razon_social);
CREATE INDEX idx_cli_contacto_cliente ON cli_contacto(id_cliente);
CREATE INDEX idx_gen_vehiculo_placa ON gen_vehiculo(placa);
CREATE INDEX idx_gen_vehiculo_cliente ON gen_vehiculo(id_cliente);
CREATE UNIQUE INDEX idx_gen_vehiculo_placa_empresa ON gen_vehiculo(placa) WHERE id_cliente IS NULL;
CREATE UNIQUE INDEX idx_gen_vehiculo_placa_cliente ON gen_vehiculo(id_cliente, placa) WHERE id_cliente IS NOT NULL;
CREATE INDEX idx_gen_chofer_documento ON gen_chofer(numero_documento);
CREATE INDEX idx_gen_chofer_cliente ON gen_chofer(id_cliente);
CREATE INDEX idx_gen_cuenta_cliente ON gen_cuenta_bancaria(id_cliente);

-- Balones
CREATE INDEX idx_bal_balon_codigo ON bal_balon(codigo_balon);
CREATE INDEX idx_bal_balon_numero_serie ON bal_balon(numero_serie);
CREATE INDEX idx_bal_balon_libro ON bal_balon(libro_cilindro, pagina_libro);
CREATE INDEX idx_bal_balon_cliente_ubic ON bal_balon(id_cliente_ubicacion);
CREATE INDEX idx_bal_balon_ph_vence ON bal_balon(fecha_proxima_prueba_hidrostatica);
CREATE INDEX idx_bal_balon_estado ON bal_balon(id_estado_balon);
CREATE INDEX idx_bal_balon_cliente ON bal_balon(id_cliente_propietario);
CREATE INDEX idx_bal_balon_marca ON bal_balon(id_marca_cilindro);
CREATE INDEX idx_bal_balon_anio_fabricacion ON bal_balon(anio_fabricacion);
CREATE INDEX idx_bal_balon_ph_historial_balon ON bal_balon_ph_historial(id_balon);
CREATE INDEX idx_bal_balon_ph_historial_vigente ON bal_balon_ph_historial(id_balon, es_vigente) WHERE es_vigente = TRUE;
CREATE INDEX idx_bal_baja_balon_balon ON bal_baja_balon(id_balon);
CREATE UNIQUE INDEX idx_bal_baja_balon_pendiente ON bal_baja_balon(id_balon) WHERE estado = 1 AND estado_aprobacion = 'PENDIENTE';
CREATE UNIQUE INDEX idx_bal_baja_balon_aprobada ON bal_baja_balon(id_balon) WHERE estado = 1 AND estado_aprobacion = 'APROBADA';
CREATE INDEX idx_bal_movimiento_balon ON bal_movimiento(id_balon);
CREATE INDEX idx_bal_movimiento_fecha ON bal_movimiento(fecha_movimiento);
CREATE INDEX idx_bal_movimiento_recarga_balon ON bal_movimiento_recarga(id_balon);
CREATE INDEX idx_bal_movimiento_recarga_fecha ON bal_movimiento_recarga(fecha_salida_almacen);
CREATE INDEX idx_bal_prestamo_cliente ON bal_prestamo(id_cliente);
CREATE INDEX idx_bal_prestamo_proveedor ON bal_prestamo(id_proveedor);
CREATE INDEX idx_bal_prestamo_tipo ON bal_prestamo(id_tipo_prestamo);
CREATE INDEX idx_bal_prestamo_detalle_balon ON bal_prestamo_detalle(id_balon);
CREATE INDEX idx_bal_prestamo_detalle_venc ON bal_prestamo_detalle(fecha_vencimiento);
CREATE INDEX idx_bal_prestamo_detalle_est ON bal_prestamo_detalle(id_estado);
CREATE INDEX idx_bal_alquiler_cliente ON bal_alquiler(id_cliente);

-- Ventas
CREATE INDEX idx_ven_comprobante_serie ON ven_comprobante(serie, numero);
CREATE INDEX idx_ven_comprobante_cliente ON ven_comprobante(id_cliente);
CREATE INDEX idx_ven_comprobante_fecha ON ven_comprobante(fecha);
CREATE INDEX idx_ven_detalle_comprobante ON ven_comprobante_detalle(id_comprobante);
CREATE INDEX idx_ven_detalle_estado_cil ON ven_comprobante_detalle(id_estado_cilindro);
CREATE INDEX idx_ven_resumen_diario_fecha ON ven_resumen_diario(fecha);
CREATE INDEX idx_ven_resumen_diario_ticket ON ven_resumen_diario(ticket_sunat);
CREATE INDEX idx_ven_resumen_diario_estado_sunat ON ven_resumen_diario(id_estado_sunat);
CREATE INDEX idx_ven_resumen_detalle_resumen ON ven_resumen_diario_detalle(id_resumen);
CREATE INDEX idx_ven_resumen_detalle_comprobante ON ven_resumen_diario_detalle(id_comprobante);
CREATE INDEX idx_ven_garantia_cliente ON ven_garantia(id_cliente);
CREATE INDEX idx_ven_garantia_fecha ON ven_garantia(fecha_registro);
CREATE INDEX idx_ven_garantia_mov ON ven_garantia_movimiento(id_garantia);

-- GRE
CREATE INDEX idx_gre_serie ON gre_guia_remision(serie, numero);
CREATE INDEX idx_gre_fecha ON gre_guia_remision(fecha);
CREATE INDEX idx_gre_cliente ON gre_guia_remision(id_cliente);
CREATE INDEX idx_gre_rango_responsable ON gre_rango_numeracion(responsable);

-- Stock y movimientos
CREATE INDEX idx_pro_stock_almacen ON pro_stock(id_almacen, id_producto);
CREATE INDEX idx_pro_movimientos_producto ON pro_movimientos(id_producto, fecha);
CREATE INDEX idx_pro_catalogo_precio ON pro_catalogo_precio(id_tipo_catalogo, periodo);
CREATE INDEX idx_pro_catalogo_nombre ON pro_catalogo_precio(nombre_item);

-- Vencimientos documentos
CREATE INDEX idx_gen_doc_vencimiento_fecha ON gen_documento_vencimiento(fecha_vencimiento);
CREATE INDEX idx_gen_doc_vencimiento_vehiculo ON gen_documento_vencimiento(id_vehiculo);

-- Cobranza / kardex
-- Finanzas unificadas
CREATE INDEX idx_fin_cuenta_tercero ON fin_cuenta(id_tercero);
CREATE INDEX idx_fin_cuenta_tipo ON fin_cuenta(id_tipo_cuenta);
CREATE INDEX idx_fin_cuenta_saldo ON fin_cuenta(id_tercero, monto_saldo);
CREATE INDEX idx_fin_pago_cuenta ON fin_pago(id_cuenta);
CREATE INDEX idx_fin_pago_fecha ON fin_pago(fecha_pago);

-- Compras y gastos
CREATE INDEX idx_com_compra_fecha ON com_comprobante_compra(fecha);
CREATE INDEX idx_com_compra_proveedor ON com_comprobante_compra(id_proveedor);
CREATE INDEX idx_com_detalle_comprobante ON com_comprobante_compra_detalle(id_comprobante);
CREATE INDEX idx_com_detalle_clasificacion ON com_comprobante_compra_detalle(id_clasificacion_gasto);
CREATE INDEX idx_com_detalle_fecha_pago ON com_comprobante_compra_detalle(fecha_pago);
CREATE INDEX idx_com_detalle_descripcion ON com_comprobante_compra_detalle(descripcion);
CREATE INDEX idx_gen_clasificacion_gasto ON gen_clasificacion_gasto(grupo, subgrupo);
CREATE INDEX idx_com_compra_declarar_sunat ON com_comprobante_compra(declarar_sunat, fecha);

-- Agenda de Actividades
CREATE INDEX idx_age_actividad_fecha ON age_actividad(fecha_programada);
CREATE INDEX idx_age_actividad_estado ON age_actividad(id_estado_actividad);
CREATE INDEX idx_age_actividad_chofer ON age_actividad(id_chofer_responsable) WHERE id_chofer_responsable IS NOT NULL;
CREATE INDEX idx_age_actividad_usuario ON age_actividad(id_usuario_responsable) WHERE id_usuario_responsable IS NOT NULL;
CREATE INDEX idx_age_actividad_cliente ON age_actividad(id_cliente) WHERE id_cliente IS NOT NULL;


-- ============================================================
-- DATOS INICIALES MÍNIMOS: LISTAS MAESTRAS
-- ============================================================

-- Lista base (gen_lista)
INSERT INTO gen_lista (nombre, descripcion) VALUES
('TipoPersona',       'Natural o Jurídica'),
('TipoCliente',       'Cliente, Paciente, Proveedor o Ambos'),
('TipoDocumento',     'RUC, DNI, CE, etc.'),
('TipoCuenta',        'Tipo de cuenta bancaria'),
('Banco',             'Bancos disponibles'),
('UnidadMedida',      'Unidades de medida de productos'),
('TipoMovInv',        'Tipos de movimiento de inventario'),
('TipoMovBalon',      'Tipos de movimiento de balón'),
('TipoRecarga',       'CLIENTE = mostrador; PLANTA_EXTERNA = envío a tercero'),
('EstadoBalon',       'Estados posibles de un balón'),
('TipoPrestamo',      'ENVASE_EMPRESA_A_CLIENTE, CILINDRO_CLIENTE_A_EMPRESA, CILINDRO_A_PLANTA'),
('TipoMantenimiento', 'Tipos de mantenimiento de cilindro'),
('ModalidadTraslado', '01=Transporte público, 02=Transporte privado'),
('MotivoTraslado',    '01=Venta, 02=Compra, 04=Entre establecimientos, 09=Exportación, 13=Otros'),
('MedioPago',         'Medios de pago'),
('Moneda',            'Monedas'),
('TipoComprobante',   'Tipos: 01=Factura, 03=Boleta, 07=NC, 08=ND, 09=GRE, NV=Nota de venta'),
('MotivoNotaCredito', '01=Anulación, 07=Descuento, 08=Devolución, 13=Ajuste de precio'),
('MotivoNotaDebito',  '01=Intereses por mora, 02=Aumento de valor, 03=Penalidades'),
('TipoOperacionSunat','0101=Venta interna, 0112=Sustento gastos, 0200=Exportación'),
('TipoDocumentoRef',  'Tipos de documento origen en movimientos: FACTURA, GRE, PRESTAMO, ALQUILER, RECARGA, COMPRA, DEVOLUCION'),
('EstadoSunat',       'PENDIENTE, ACEPTADO, RECHAZADO, BAJA, NO_APLICA'),
('TipoGuiaRemision',  '09=GRE Remitente, 31=GRE Transportista'),
('AfectacionIgv',     '10=Gravado, 20=Exonerado, 30=Inafecto, 40=Exportación'),
('AmbienteSunat',     'BETA, PRODUCCION'),
('EstadoDocumento',   'Estados de documentos'),
('TipoVehiculo',      'Tipos de vehículo de la empresa'),
('CategoriaVencimiento', 'Categoría de documentos con vencimiento'),
('EstadoGarantia',    'Estados de garantía: ACTIVA, DEVUELTA, PARCIAL'),
('TipoMovimientoGarantia', 'COBRO y DEVOLUCION de garantía'),
('TipoCatalogoPrecio', 'RECARGADO=gas+cilindro, GARANTIA=depósito préstamo, VENTA_CILINDRO=cilindro vacío, ACCESORIO'),
('TipoCuentaFinanciera', 'COBRAR (cliente) o PAGAR (proveedor)'),
('EstadoPrestamoDetalle', 'Estado por cilindro en préstamo: ACTIVO, PENDIENTE, DEVUELTO, VENCIDO'),
('TipoRegistroCompra','Compra a proveedor o gasto operativo'),
('CategoriaGasto',    'Combustible, tributos, flete, mantenimiento, oficina...'),
('EstadoCilindroVenta', 'POR RECOGER, DEVUELTO en venta con cilindro'),
('ReferenciaCilindro',  'ALMACEN, CLIENTE, Cliente Extraviada, Almacen Extraviada...'),
('EstadoPagoGasto',     'Cancelado, Pendiente, Anulado');

-- Opciones EstadoBalon (ajustar id_lista según ID real de 'EstadoBalon')
-- INSERT INTO gen_lista_opciones (id_lista, nombre) VALUES
-- (9, 'EN_ALMACEN'),
-- (9, 'POR_RECOGER'),      -- del Excel: cilindros pendientes de recoger
-- (9, 'PRESTADO_CLIENTE'),
-- (9, 'EN_RUTA_LIMA'),
-- (9, 'EN_MANTENIMIENTO'),
-- (9, 'ALQUILADO'),
-- (9, 'DEVUELTO'),
-- (9, 'ROBO'),
-- (9, 'DADO_DE_BAJA');

-- ============================================================
-- DATOS INICIALES: MAPEO DESDE EXCEL (estructura de referencia)
-- Ejecutar después de cargar gen_lista_opciones de TipoVehiculo, Banco, UnidadMedida
-- ============================================================

-- gen_empresa + gen_configuracion_sunat
-- INSERT INTO gen_empresa (ruc, razon_social, nombre_comercial) VALUES
-- ('10175332796', 'RUIZ DE LOS SANTOS HAYDEE', 'OXIGENO SARITA');
-- INSERT INTO gen_configuracion_sunat (id_empresa, usuario_sol, clave_sol) VALUES
-- (1, 'WILLOONT', 'Grupo2026GVR');

-- gen_configuracion_servicio
-- INSERT INTO gen_configuracion_servicio (codigo, nombre, email, usuario, contrasena) VALUES
-- ('CORREO', 'Correo corporativo', 'gvariasr@hotmail.com', 'gvariasr@hotmail.com', 'Rumymisky1214'),
-- ('WHEREX', 'Plataforma WHEREX', NULL, 'gvariasr@hotmail.com', 'S@rit@35');

-- gen_vehiculo — flota empresa (id_cliente NULL)
-- INSERT INTO gen_vehiculo (id_tipo_vehiculo, placa) VALUES
-- (..., '9773CM'),   -- MOTOTAXI
-- (..., 'M4F782'),   -- CAMION
-- (..., '02198M');   -- MOTO CARGUERA
-- -- MOTO LINEAL: placa pendiente en Excel

-- gen_chofer — choferes empresa (id_cliente NULL)
-- INSERT INTO gen_chofer (apellido_paterno, apellido_materno, nombres, brevete, id_tipo_documento, numero_documento) VALUES
-- ('VALDERA', 'ACOSTA', 'JUAN JOSE', 'C16740640', ..., '16740640'),
-- ('VARIAS', 'PANTA', 'LUIS ALBERTO', 'C17534821', ..., '17534821'),
-- ('VARIAS', 'RUIZ', 'GIANCARLO JAVIER', 'C43862326', ..., '43862326'),
-- ('SANTISTEBAN', 'SALZAR', 'JHON OCTAVIO', NULL, ..., '72684495');

-- gen_cuenta_bancaria — cuentas empresa (id_cliente NULL)
-- INSERT INTO gen_cuenta_bancaria (id_banco, titular, numero_cuenta, numero_cuenta_interbancaria) VALUES
-- (...,'RUIZ DE LOS SANTOS HAYDEE', '30515162800047', '00230511516280004713'),  -- BCP
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '001107960200180312', '01179600020018031207'),  -- BBVA
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '7123243857101', '00371201324385710171'),  -- INTERBANK
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '7208838719', '00940920720883871943');  -- SCOTIABANK
-- INSERT INTO gen_cuenta_bancaria (id_tipo_cuenta, titular, telefono_billetera) VALUES
-- (...,'RUIZ DE LOS SANTOS HAYDEE', '964069607'),  -- YAPE
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '964069607');  -- PLIN

-- gen_vehiculo / gen_chofer / gen_cuenta_bancaria — cliente (id_cliente = ...)
-- INSERT INTO gen_chofer (id_cliente, nombres, apellido_paterno, dni, brevete) VALUES (...);
-- INSERT INTO gen_vehiculo (id_cliente, placa, marca, certificado_inscripcion) VALUES (...);
-- INSERT INTO gen_cuenta_bancaria (id_cliente, id_banco, id_tipo_cuenta, numero_cuenta) VALUES (...);

-- pro_producto (gases)
-- Los gases van en pro_producto con es_gas=TRUE (090, 095, 040...)
-- Ejemplo: Oxígeno Industrial codigo 010, U.M. m3

-- gen_documento_vencimiento
-- INSERT INTO gen_documento_vencimiento (descripcion, fecha_vencimiento) VALUES
-- ('CAMION - SOAT', '2025-08-26'),
-- ('CAMION - INSPECCION VEHICULAR', '2025-01-24'),
-- ('MOTO CARGUERA - SOAT', '2025-05-08'),
-- ('MOTOTAXI - SOAT', '2025-01-22'),
-- ('MOTO LINEAL - SOAT', '2025-06-06'),
-- ('CERTIFICADO DE SALUBRIDAD', '2025-09-06'),
-- ('CERTIFICADOS DE SALUBRIDAD (04)', '2025-01-27'),
-- ('CERTIFICADO DE INSPECCION TECNICA - MUNICIPALIDAD', '2026-09-03'),
-- ('BPA', '2026-10-06'),
-- ('EXTINTOR', '2025-12-01');
-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
