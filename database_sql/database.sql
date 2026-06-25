-- ============================================================
--  BASE DE DATOS - OXÍGENO SARITA
--  Versión 6.0 | Junio 2026
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
--  2. GENERALES   → Catálogos (gen_Lista/gen_ListaOpciones), sucursales, almacenes,
--                   vehículos, choferes, cuentas bancarias, documentos con vencimiento,
--                   configuración SUNAT y servicios externos
--  3. CLIENTES    → Clientes y proveedores (misma tabla cli_Clientes), contactos,
--                   direcciones de entrega y condiciones de pago
--  4. PRODUCTOS   → Categorías, subcategorías, productos (gases, accesorios, servicios),
--                   catálogo de precios con costo/flete/margen, stock por almacén y kardex
--  5. BALONES     → Maestro de balones/cilindros (bal_Balon) con trazabilidad completa:
--                   movimientos físicos, recargas en planta, préstamos, alquiler,
--                   mantenimiento y garantías cobradas/devueltas
--  6. VENTAS      → Comprobantes de venta con ciclo FE-SUNAT completo (xmlFirmado,
--                   cdrRespuesta, NC/ND), detalle por línea con afectación IGV,
--                   cuotas de crédito y relación con GRE
--  7. GRE         → Guías de Remisión Electrónica (remitente 09 / transportista 31)
--                   con UBIGEO, motivo de traslado y ciclo XML/CDR SUNAT
--  8. FINANZAS    → Cuentas por cobrar y pagar (fin_Cuenta + fin_Pago),
--                   préstamos bancarios y cuotas (fin_PrestamoBanco)
--  9. COMPRAS     → Comprobantes de compra/gasto con clasificación contable de 3 niveles,
--                   afectación de inventario y declaración SUNAT
--
--  FLUJOS DEL NEGOCIO
--  ------------------
--  A. VENTA DE GAS (cliente trae su propio balón)
--       ven_Comprobante + ven_ComprobanteDetalle + pro_Movimientos (salida gas)
--
--  B. VENTA DE GAS + BALÓN EN PRÉSTAMO
--       bal_Prestamo (garantía cobrada → idComprobanteVenta) +
--       bal_PrestamoDetalle (cilindros entregados con GRE) +
--       ven_Comprobante (factura gas) + gre_GuiaRemision (salida)
--       Al devolver: fecha devolución en bal_PrestamoDetalle + GRE retorno
--
--  C. VENTA DE GAS + VENTA DE BALÓN (cliente compra el cilindro)
--       ven_Comprobante con 2 líneas en ven_ComprobanteDetalle:
--         línea 1 → gas (esGas=TRUE), línea 2 → balón (idBalon → bal_Balon)
--       bal_Balon.idClienteUbicacion actualizado al cliente comprador
--
--  D. ALQUILER DE BALÓN
--       bal_Alquiler (tarifa diaria) + bal_AlquilerDetalle (cilindros) +
--       gre_GuiaRemision (entrega/retiro) +
--       ven_Comprobante periódico (idComprobanteVenta en bal_Alquiler)
--
--  E. MANTENIMIENTO / REVISIÓN DE BALÓN
--       bal_Mantenimiento + ven_Comprobante (servicio cobrado al cliente)
--       o com_ComprobanteCompra (servicio contratado a tercero)
--
--  F. RECARGA EN PLANTA (balones propios enviados al proveedor)
--       bal_MovimientoRecarga (lote + P.H. de la recarga) +
--       gre_GuiaRemision salida + gre_GuiaRemision retorno +
--       com_ComprobanteCompra (factura de la planta)
--
--  G. CORRECCIÓN / ANULACIÓN DE COMPROBANTE (NC / ND)
--       ven_Comprobante tipo 07/08 con idComprobanteOrigen apuntando al original
--       y idMotivoNota (01=Anulación, 07=Descuento, 08=Devolución, 13=Ajuste)
--
--  H. FACTURACIÓN ELECTRÓNICA SUNAT
--       ven_Comprobante y gre_GuiaRemision almacenan:
--         xmlFirmado, cdrRespuesta, hashDocumento, ticketSunat, idEstadoSunat
--       gen_ConfiguracionSunat guarda credenciales SOL y certificado digital
--       idAfectacionIgv por línea vía gen_Lista (10 Gravado, 20 Exonerado, 30 Inafecto, 40 Exportación)
--       Ubigeo en gen_Distrito.codigoUbigeo para origen/destino de GREs
--
--  DECISIONES DE DISEÑO
--  --------------------
--  - Sin tablas snapshot ni columnas calculadas: todo se deriva con JOINs y vistas
--  - Clientes y proveedores en una sola tabla (cli_Clientes); rol determinado por contexto
--  - Balón identificado por código único; lote solo en la recarga, no en el balón
--  - NC/ND como registros en ven_Comprobante (no tabla separada)
--  - gen_Chofer y gen_Vehiculo usados tanto para flota propia (idCliente NULL)
--    como para transportistas externos (idCliente → cli_Clientes)
-- ============================================================


-- ============================================================
-- GRUPO 1: AUTENTICACIÓN Y USUARIOS
-- ============================================================

CREATE TABLE auth_Usuarios (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL,
    correo          VARCHAR(150) NOT NULL UNIQUE,
    contrasena      VARCHAR(255) NOT NULL,
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_Roles (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     VARCHAR(255),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_Permisos (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     VARCHAR(255),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_UsuariosRoles (
    id              SERIAL PRIMARY KEY,
    idUsuario       INT NOT NULL REFERENCES auth_Usuarios(id),
    idRol           INT NOT NULL REFERENCES auth_Roles(id),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_RolesPermisos (
    id              SERIAL PRIMARY KEY,
    idRol           INT NOT NULL REFERENCES auth_Roles(id),
    idPermiso       INT NOT NULL REFERENCES auth_Permisos(id),
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE auth_Sesiones (
    id              SERIAL PRIMARY KEY,
    idUsuario       INT NOT NULL REFERENCES auth_Usuarios(id),
    token           VARCHAR(512) NOT NULL,
    ip              VARCHAR(45),
    userAgent       VARCHAR(512),
    fechaInicio     TIMESTAMP DEFAULT NOW(),
    fechaFin        TIMESTAMP,
    estado          BOOLEAN NOT NULL DEFAULT TRUE,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 2: GENERALES / CATÁLOGOS BASE
-- ============================================================

CREATE TABLE gen_Pais (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_Departamento (
    id              SERIAL PRIMARY KEY,
    idPais          INT NOT NULL REFERENCES gen_Pais(id),
    nombre          VARCHAR(100) NOT NULL,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_Provincia (
    id              SERIAL PRIMARY KEY,
    idDepartamento  INT NOT NULL REFERENCES gen_Departamento(id),
    nombre          VARCHAR(100) NOT NULL,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_Distrito (
    id              SERIAL PRIMARY KEY,
    idProvincia     INT NOT NULL REFERENCES gen_Provincia(id),
    nombre          VARCHAR(100) NOT NULL,
    codigoUbigeo    VARCHAR(6),   -- SUNAT UBIGEO 6 dígitos (ej. 140101 = Chiclayo)
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Lista maestra de opciones (equivalente a tablas de tipo/estado)
-- Ejemplos de uso: TipoDocumento, TipoPersona, TipoCuenta, TipoMovimiento, etc.
CREATE TABLE gen_Lista (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     VARCHAR(255),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

CREATE TABLE gen_ListaOpciones (
    id              SERIAL PRIMARY KEY,
    idLista         INT NOT NULL REFERENCES gen_Lista(id),
    nombre          VARCHAR(150) NOT NULL,
    descripcion     VARCHAR(255),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Sucursales de la empresa
CREATE TABLE gen_Sucursal (
    id              SERIAL PRIMARY KEY,
    codigo          VARCHAR(20) NOT NULL UNIQUE,
    nombre          VARCHAR(150) NOT NULL,
    direccion       VARCHAR(255),
    idDepartamento  INT REFERENCES gen_Departamento(id),
    idProvincia     INT REFERENCES gen_Provincia(id),
    idDistrito      INT REFERENCES gen_Distrito(id),
    telefono        VARCHAR(30),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Almacenes vinculados a sucursal
CREATE TABLE gen_Almacen (
    id              SERIAL PRIMARY KEY,
    idSucursal      INT NOT NULL REFERENCES gen_Sucursal(id),
    nombre          VARCHAR(150) NOT NULL,
    ubicacion       VARCHAR(255),
    descripcion     VARCHAR(255),
    idDepartamento  INT REFERENCES gen_Departamento(id),
    idProvincia     INT REFERENCES gen_Provincia(id),
    idDistrito      INT REFERENCES gen_Distrito(id),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Condiciones de pago (CONTADO, CREDITO 10 DIAS, etc.)
CREATE TABLE gen_CondicionPago (
    id              SERIAL PRIMARY KEY,
    codigo          VARCHAR(10) NOT NULL UNIQUE,
    nombre          VARCHAR(100) NOT NULL,
    diasCredito     INT NOT NULL DEFAULT 0,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Datos fiscales de la empresa (RUC, razón social)
CREATE TABLE gen_Empresa (
    id                  SERIAL PRIMARY KEY,
    ruc                 VARCHAR(11) NOT NULL UNIQUE,
    razonSocial         VARCHAR(255),
    nombreComercial     VARCHAR(150) DEFAULT 'OXIGENO SARITA',
    direccion           VARCHAR(255),
    telefono            VARCHAR(30),
    email               VARCHAR(150),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Credenciales SUNAT / facturación electrónica (SOL)
CREATE TABLE gen_ConfiguracionSunat (
    id                  SERIAL PRIMARY KEY,
    idEmpresa           INT NOT NULL REFERENCES gen_Empresa(id),
    usuarioSol          VARCHAR(50) NOT NULL,
    claveSol            VARCHAR(255) NOT NULL,   -- cifrar en aplicación
    certificadoDigital  VARCHAR(255),             -- ruta o referencia al .pfx
    claveCertificado    VARCHAR(255),             -- cifrar en aplicación
    idAmbiente          INT REFERENCES gen_ListaOpciones(id),  -- (gen_Lista: AmbienteSunat) BETA, PRODUCCION
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Credenciales de servicios externos (correo, WHEREX, etc.)
CREATE TABLE gen_ConfiguracionServicio (
    id                  SERIAL PRIMARY KEY,
    codigo              VARCHAR(50) NOT NULL UNIQUE,  -- CORREO, WHEREX...
    nombre              VARCHAR(100) NOT NULL,
    usuario             VARCHAR(150),
    contrasena          VARCHAR(255),                 -- cifrar en aplicación
    email               VARCHAR(150),
    url                 VARCHAR(255),
    observacion         VARCHAR(255),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 3: CLIENTES Y PROVEEDORES
-- ============================================================

CREATE TABLE cli_Clientes (
    id                  SERIAL PRIMARY KEY,
    codigoInterno       VARCHAR(20) UNIQUE,        -- 141, 127, 0000002 (cuando no hay RUC/DNI)
    razonSocial         VARCHAR(300),              -- nombre completo: LATERCER S.A.C., BANCES DE LA CRUZ...
    idTipoCliente       INT REFERENCES gen_ListaOpciones(id),  -- Cliente, Paciente, Proveedor...
    idTipoPersona       INT REFERENCES gen_ListaOpciones(id),  -- Natural / Jurídica
    nombres             VARCHAR(200),
    apellidoPaterno     VARCHAR(100),
    apellidoMaterno     VARCHAR(100),
    idTipoDocumento     INT REFERENCES gen_ListaOpciones(id),  -- RUC / DNI
    numeroDocumento     VARCHAR(20) UNIQUE,        -- RUC/DNI; puede ser NULL si solo hay codigoInterno
    direccion           VARCHAR(255),
    referencia          VARCHAR(255),                -- referencia de ubicación
    telefono            VARCHAR(30),
    email               VARCHAR(150),
    idDepartamento      INT REFERENCES gen_Departamento(id),
    idProvincia         INT REFERENCES gen_Provincia(id),
    idDistrito          INT REFERENCES gen_Distrito(id),
    idPais              INT REFERENCES gen_Pais(id),
    -- Flags tributarios
    esAgentePercepcion  BOOLEAN DEFAULT FALSE,
    esBuenContribuyente BOOLEAN DEFAULT FALSE,
    esAgenteRetenedor   BOOLEAN DEFAULT FALSE,
    afectoRUS           BOOLEAN DEFAULT FALSE,
    -- SUNAT (texto devuelto por consulta RUC; no es estado del comprobante electrónico)
    situacionSunat      VARCHAR(50),   -- HABIDO, NO HABIDO
    estadoContribuyenteSunat VARCHAR(50),  -- ACTIVO, BAJA, SUSPENSION TEMPORAL
    observacion         VARCHAR(500),
    -- Control
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Contactos del cliente (múltiples por cliente)
CREATE TABLE cli_Contacto (
    id              SERIAL PRIMARY KEY,
    idCliente       INT NOT NULL REFERENCES cli_Clientes(id),
    nombre          VARCHAR(150),
    apellidoPaterno VARCHAR(100),
    apellidoMaterno VARCHAR(100),
    direccion       VARCHAR(255),
    email           VARCHAR(150),
    telefono1       VARCHAR(20),
    telefono2       VARCHAR(20),
    telefono3       VARCHAR(20),
    esPrincipal     BOOLEAN DEFAULT FALSE,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Direcciones de entrega del cliente (para guías de remisión)
CREATE TABLE cli_Direcciones (
    id              SERIAL PRIMARY KEY,
    idCliente       INT NOT NULL REFERENCES cli_Clientes(id),
    descripcion     VARCHAR(150),
    direccion       VARCHAR(255) NOT NULL,
    idDepartamento  INT REFERENCES gen_Departamento(id),
    idProvincia     INT REFERENCES gen_Provincia(id),
    idDistrito      INT REFERENCES gen_Distrito(id),
    referencia      VARCHAR(255),
    esPrincipal     BOOLEAN DEFAULT FALSE,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Vehículos de la empresa y de clientes/proveedores (GRE, flota propia)
-- idCliente NULL = vehículo de la empresa | idCliente NOT NULL = del cliente/proveedor
CREATE TABLE gen_Vehiculo (
    id                      SERIAL PRIMARY KEY,
    idCliente               INT REFERENCES cli_Clientes(id),
    idTipoVehiculo          INT REFERENCES gen_ListaOpciones(id),  -- MOTOTAXI, CAMION, MOTO CARGUERA...
    placa                   VARCHAR(20) NOT NULL,
    placa2                  VARCHAR(20),                             -- remolque / segundo vehículo
    marca                   VARCHAR(100),
    marca2                  VARCHAR(100),
    modelo                  VARCHAR(100),
    anio                    INT,
    color                   VARCHAR(50),
    certificadoInscripcion  VARCHAR(50),
    certificado2            VARCHAR(50),
    estado                  INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion           TIMESTAMP DEFAULT NOW(),
    fechaModificacion       TIMESTAMP DEFAULT NOW()
);

-- Choferes de la empresa y de clientes/proveedores
-- idCliente NULL = chofer de la empresa | idCliente NOT NULL = del cliente/proveedor
CREATE TABLE gen_Chofer (
    id                  SERIAL PRIMARY KEY,
    idCliente           INT REFERENCES cli_Clientes(id),
    apellidoPaterno     VARCHAR(100),
    apellidoMaterno     VARCHAR(100),
    nombres             VARCHAR(150) NOT NULL,
    idTipoDocumento     INT REFERENCES gen_ListaOpciones(id),  -- SUNAT: 1=DNI, 4=CE, 7=Pasaporte
    numeroDocumento     VARCHAR(20),   -- DNI, CE, Pasaporte según idTipoDocumento
    brevete             VARCHAR(30),
    telefono            VARCHAR(20),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Cuentas bancarias y billeteras de la empresa y de clientes/proveedores
-- idCliente NULL = cuenta de la empresa | idCliente NOT NULL = del cliente/proveedor
CREATE TABLE gen_CuentaBancaria (
    id                          SERIAL PRIMARY KEY,
    idCliente                   INT REFERENCES cli_Clientes(id),
    idBanco                     INT REFERENCES gen_ListaOpciones(id),
    idTipoCuenta                INT REFERENCES gen_ListaOpciones(id),  -- AHORROS, CCI, YAPE, PLIN...
    titular                     VARCHAR(200),
    numeroCuenta                VARCHAR(30),
    numeroCuentaInterbancaria   VARCHAR(30),
    telefonoBilletera           VARCHAR(20),          -- YAPE / PLIN
    esPrincipal                 BOOLEAN DEFAULT FALSE,
    estado                      INT NOT NULL DEFAULT 1,
    idUsuarioCreacion           INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion       INT REFERENCES auth_Usuarios(id),
    fechaCreacion               TIMESTAMP DEFAULT NOW(),
    fechaModificacion           TIMESTAMP DEFAULT NOW()
);

-- Vencimientos de documentos: SOAT, inspección vehicular, BPA, extintor, salubridad...
CREATE TABLE gen_DocumentoVencimiento (
    id                  SERIAL PRIMARY KEY,
    idCategoria         INT REFERENCES gen_ListaOpciones(id),  -- VEHICULO, CERTIFICADO, SEGURIDAD...
    descripcion         VARCHAR(255) NOT NULL,
    idVehiculo          INT REFERENCES gen_Vehiculo(id),
    fechaVencimiento    DATE NOT NULL,
    fechaRenovacion     DATE,
    numeroDocumento     VARCHAR(50),
    observacion         VARCHAR(255),
    -- Estado: VIGENTE, POR_VENCER, VENCIDO
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 4: PRODUCTOS E INVENTARIO
-- ============================================================

CREATE TABLE pro_Categoria (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    descripcion     VARCHAR(255),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);
-- Datos iniciales: Gases, Accesorios, Gastos Operativos, Gastos de otros Servicios

CREATE TABLE pro_SubCategoria (
    id              SERIAL PRIMARY KEY,
    idCategoria     INT NOT NULL REFERENCES pro_Categoria(id),
    nombre          VARCHAR(100) NOT NULL,
    descripcion     VARCHAR(255),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);
-- Datos iniciales: Oxigeno, Nitrogeno, Argon, Acetileno, Soldadura, Reguladores,
--                 Valvulas, Manometros, Mantenimiento, Carburo...

CREATE TABLE pro_Producto (
    id              SERIAL PRIMARY KEY,
    codigo          VARCHAR(30) NOT NULL UNIQUE,
    codigoBarra     VARCHAR(50),
    nombre          VARCHAR(300) NOT NULL,
    idSubCategoria  INT REFERENCES pro_SubCategoria(id),
    idUnidadMedida  INT REFERENCES gen_ListaOpciones(id), -- UNID, MT3, KG, MTS, PAR...
    marca           VARCHAR(100),
    presentacion    VARCHAR(150),
    -- Flags especiales
    esGas           BOOLEAN DEFAULT FALSE,   -- true si es un gas (Oxigeno, Nitrogeno...)
    esServicio      BOOLEAN DEFAULT FALSE,   -- true si es un servicio (Mantenimiento, Alquiler...)
    esAlquilable    BOOLEAN DEFAULT FALSE,   -- puede ser alquilado
    afectaStock     BOOLEAN DEFAULT TRUE,    -- false para servicios puros
    precio          NUMERIC(12,4) DEFAULT 0,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Catálogo unificado de precios (cilindro recargado, garantía, accesorios)
-- idTipoCatalogo: RECARGADO | GARANTIA | ACCESORIO (gen_Lista TipoCatalogoPrecio)
-- idTipoCatalogo: RECARGADO (gas+cilindro vendido), GARANTIA (depósito préstamo),
--                VENTA_CILINDRO (cilindro vacío vendido), ACCESORIO
CREATE TABLE pro_CatalogoPrecio (
    id                      SERIAL PRIMARY KEY,
    idTipoCatalogo          INT NOT NULL REFERENCES gen_ListaOpciones(id),
    periodo                 VARCHAR(20),
    nombreItem              VARCHAR(200) NOT NULL,
    idProducto              INT REFERENCES pro_Producto(id),    -- gas asociado
    idTipoBalon             INT REFERENCES bal_TipoBalon(id),   -- tipo de cilindro (link directo)
    idProveedor             INT REFERENCES cli_Clientes(id),
    clasificacion           VARCHAR(100),
    modelo                  VARCHAR(100),
    capacidad               NUMERIC(10,4),
    idUnidadMedida          INT REFERENCES gen_ListaOpciones(id),
    descripcionPresentacion VARCHAR(300),
    costoProducto           NUMERIC(12,4) DEFAULT 0,
    costoFlete              NUMERIC(12,4) DEFAULT 0,
    porcentajeMargen        NUMERIC(6,2),
    precioFinal             NUMERIC(12,4),    -- precio confirmado (app calcula margen, usuario ajusta)
    precioGarantia          NUMERIC(12,4),    -- depósito al prestar el cilindro
    estado                  INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion           TIMESTAMP DEFAULT NOW(),
    fechaModificacion       TIMESTAMP DEFAULT NOW()
);

-- Stock por producto y almacén
CREATE TABLE pro_Stock (
    id              SERIAL PRIMARY KEY,
    idAlmacen       INT NOT NULL REFERENCES gen_Almacen(id),
    idProducto      INT NOT NULL REFERENCES pro_Producto(id),
    stock           NUMERIC(12,4) NOT NULL DEFAULT 0,
    stockMinimo     NUMERIC(12,4) DEFAULT 0,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW(),
    UNIQUE(idAlmacen, idProducto)
);

-- Kardex / movimientos de inventario
CREATE TABLE pro_Movimientos (
    id                  SERIAL PRIMARY KEY,
    fecha               DATE NOT NULL,
    idProducto          INT NOT NULL REFERENCES pro_Producto(id),
    idAlmacen           INT NOT NULL REFERENCES gen_Almacen(id),
    idTipoMovimiento    INT REFERENCES gen_ListaOpciones(id), -- INGRESO, SALIDA, TRASLADO...
    cantidad            NUMERIC(12,4) NOT NULL,
    stockAnterior       NUMERIC(12,4),
    stockNuevo          NUMERIC(12,4),
    idDocumentoRef      INT,                                              -- ID del documento origen (polimórfico)
    idTipoDocumentoRef  INT REFERENCES gen_ListaOpciones(id),            -- (gen_Lista: TipoDocumentoRef)
    glosa               VARCHAR(255),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 5: BALONES / CILINDROS (CORE DEL NEGOCIO)
-- ============================================================

-- Catálogo de tipos de balón
-- Cada balón físico tendrá su propio registro con número de serie
CREATE TABLE bal_TipoBalon (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(150) NOT NULL,  -- "Oxígeno Industrial 10m3", "Oxígeno Medicinal 1m3"...
    idGas           INT REFERENCES pro_Producto(id),  -- gas que contiene
    capacidad       NUMERIC(10,4),          -- en m3 o kg
    idUnidadMedida  INT REFERENCES gen_ListaOpciones(id),
    peso            NUMERIC(10,4),          -- peso tara en kg
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Registro individual de cada balón físico (libro de cilindros / trazabilidad total)
CREATE TABLE bal_Balon (
    id                  SERIAL PRIMARY KEY,
    codigoBalon         VARCHAR(50) NOT NULL UNIQUE,  -- 20K650076, 21Y405093, 4706374...
    libroCilindro       VARCHAR(30),                 -- LIBRO 1, LIBRO 5, SIN LIBRO...
    paginaLibro         INT,                         -- PAG. 103, 0 si sin libro
    fechaRegistro       DATE,                        -- FECHA de asignación / registro actual
    idAlmacen           INT REFERENCES gen_Almacen(id),
    idClienteUbicacion  INT REFERENCES cli_Clientes(id),
    -- Propiedad del envase
    idPropietario       INT REFERENCES gen_ListaOpciones(id),  -- EMPRESA / CLIENTE / PROPIA
    idClientePropietario INT REFERENCES cli_Clientes(id),
    idReferencia        INT REFERENCES gen_ListaOpciones(id),  -- ReferenciaCilindro
    -- Gas / producto actual en el cilindro
    idTipoBalon         INT REFERENCES bal_TipoBalon(id),
    idProductoGas       INT REFERENCES pro_Producto(id),
    -- Estado actual del balón
    idEstadoBalon       INT REFERENCES gen_ListaOpciones(id),
    -- Prueba hidrostática
    fechaUltimaPruebaHidrostatica   DATE,
    vigenciaPruebaHidrostaticaAnios INT DEFAULT 5,
    fechaProximaPruebaHidrostatica  DATE,
    -- Datos técnicos adicionales
    fechaFabricacion    DATE,
    numeroRecepcion     VARCHAR(30),
    presionActual       NUMERIC(8,2),
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Historial de movimientos/estados del balón (trazabilidad completa)
CREATE TABLE bal_Movimiento (
    id                  SERIAL PRIMARY KEY,
    idBalon             INT NOT NULL REFERENCES bal_Balon(id),
    idTipoMovimiento    INT REFERENCES gen_ListaOpciones(id),
    -- Tipos: SALIDA_VENTA, SALIDA_PRESTAMO, SALIDA_ALQUILER, SALIDA_MANTENIMIENTO,
    --        ENTRADA_DEVOLUCION, ENTRADA_LLENADO, TRASLADO_LIMA, RETORNO_LIMA
    idDocumentoRef      INT,                                              -- ID del documento asociado (polimórfico)
    idTipoDocumentoRef  INT REFERENCES gen_ListaOpciones(id),            -- (gen_Lista: TipoDocumentoRef)
    idCliente           INT REFERENCES cli_Clientes(id),
    idAlmacenOrigen     INT REFERENCES gen_Almacen(id),
    idAlmacenDestino    INT REFERENCES gen_Almacen(id),
    fechaMovimiento     TIMESTAMP NOT NULL DEFAULT NOW(),
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Salida / ingreso de almacén por recarga de cilindro (GRE salida + GRE ingreso + factura)
CREATE TABLE bal_MovimientoRecarga (
    id                      SERIAL PRIMARY KEY,
    fechaSalidaAlmacen      DATE NOT NULL,
    idBalon                 INT NOT NULL REFERENCES bal_Balon(id),
    idProducto              INT REFERENCES pro_Producto(id),
    capacidad               NUMERIC(10,4),
    idUnidadMedida          INT REFERENCES gen_ListaOpciones(id),
    -- Guías de remisión
    serieGuiaSalida                 VARCHAR(10),
    numeroGuiaSalida                VARCHAR(15),
    serieGuiaIngreso                VARCHAR(10),
    numeroGuiaIngreso               VARCHAR(15),
    -- Factura asociada
    serieFactura                    VARCHAR(10),
    numeroFactura                   VARCHAR(15),
    idComprobante                   INT REFERENCES ven_Comprobante(id),
    fechaLlegadaAlmacen             DATE,
    lote                            VARCHAR(50),
    fechaVencimientoLote            DATE,
    fechaPruebaHidrostatica         DATE,           -- P.H. certificada en esta recarga (proveedor en idProveedor)
    idProveedor             INT REFERENCES cli_Clientes(id),       -- planta de recarga / P.H.
    observacion             VARCHAR(500),
    idAlmacen               INT REFERENCES gen_Almacen(id),
    estado                  INT NOT NULL DEFAULT 1,
    idUsuarioCreacion           INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion       INT REFERENCES auth_Usuarios(id),
    fechaCreacion           TIMESTAMP DEFAULT NOW(),
    fechaModificacion       TIMESTAMP DEFAULT NOW()
);

-- Préstamo de balones: cliente, empresa↔cliente, o planta proveedora
CREATE TABLE bal_Prestamo (
    id                  SERIAL PRIMARY KEY,
    numeroPrestamo      VARCHAR(30) UNIQUE,
    idTipoPrestamo      INT NOT NULL REFERENCES gen_ListaOpciones(id),
    -- Tipos: ENVASE_EMPRESA_A_CLIENTE, CILINDRO_CLIENTE_A_EMPRESA, CILINDRO_A_PLANTA
    idCliente           INT REFERENCES cli_Clientes(id),
    idProveedor         INT REFERENCES cli_Clientes(id),
    idAlmacen           INT REFERENCES gen_Almacen(id),
    fechaSalida         DATE,
    fechaRetornoPactada DATE,
    fechaRetornoReal    DATE,
    titulo              VARCHAR(200),
    observacion         VARCHAR(500),
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    idComprobanteVenta  INT REFERENCES ven_Comprobante(id),       -- garantía cobrada al cliente
    idComprobanteCompra INT REFERENCES com_ComprobanteCompra(id), -- factura recibida del proveedor
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Detalle de cilindros en préstamo (cliente o planta) con guías GRE
CREATE TABLE bal_PrestamoDetalle (
    id                  SERIAL PRIMARY KEY,
    idPrestamo          INT NOT NULL REFERENCES bal_Prestamo(id),
    idBalon             INT REFERENCES bal_Balon(id),
    idProducto          INT REFERENCES pro_Producto(id),
    motivoEspecifico    VARCHAR(255),
    fechaEntregado      DATE,
    fechaPrestamo       DATE,
    diasPrestamo        INT DEFAULT 30,
    fechaVencimiento    DATE,
    fechaDevolucion     DATE,
    serieGuiaEntrega    VARCHAR(10),
    numeroGuiaEntrega   VARCHAR(15),
    serieGuiaDevolucion VARCHAR(10),
    numeroGuiaDevolucion VARCHAR(15),
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Alquiler de balones de la empresa al cliente
CREATE TABLE bal_Alquiler (
    id                  SERIAL PRIMARY KEY,
    numeroAlquiler      VARCHAR(30) NOT NULL UNIQUE,
    idCliente           INT NOT NULL REFERENCES cli_Clientes(id),
    idAlmacen           INT NOT NULL REFERENCES gen_Almacen(id),
    fechaInicio         DATE NOT NULL,
    fechaFinPactada     DATE,
    fechaFinReal        DATE,
    tarifaDiaria        NUMERIC(10,4) DEFAULT 0,
    totalCobrado        NUMERIC(12,4) DEFAULT 0,
    -- Estado: ACTIVO, FINALIZADO, FACTURADO
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    observacion         VARCHAR(500),
    idComprobanteVenta  INT REFERENCES ven_Comprobante(id),       -- factura emitida al cliente
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Detalle de balones en alquiler
CREATE TABLE bal_AlquilerDetalle (
    id              SERIAL PRIMARY KEY,
    idAlquiler      INT NOT NULL REFERENCES bal_Alquiler(id),
    idBalon         INT NOT NULL REFERENCES bal_Balon(id),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Mantenimiento de cilindros (recertificación, prueba hidrostática, reparación)
CREATE TABLE bal_Mantenimiento (
    id                  SERIAL PRIMARY KEY,
    idBalon             INT NOT NULL REFERENCES bal_Balon(id),
    idTipoMantenimiento INT REFERENCES gen_ListaOpciones(id),
    -- Tipos: PRUEBA_HIDROSTATICA, RECERTIFICACION, REPARACION, PINTURA, VALVULA
    fechaIngreso        DATE NOT NULL,
    fechaSalida         DATE,
    descripcion         VARCHAR(500),
    costo               NUMERIC(10,4) DEFAULT 0,
    -- Si es mantenimiento externo (Lima u otro proveedor)
    esExterno           BOOLEAN DEFAULT FALSE,
    idProveedor         INT REFERENCES cli_Clientes(id),           -- taller externo (Lima u otro)
    -- Estado: PENDIENTE, EN_PROCESO, FINALIZADO
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    idComprobanteVenta  INT REFERENCES ven_Comprobante(id),       -- si se cobra al cliente
    idComprobanteCompra INT REFERENCES com_ComprobanteCompra(id), -- si es externo (proveedor Lima)
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 6: VENTAS / FACTURACIÓN
-- ============================================================

CREATE TABLE ven_Comprobante (
    id                  SERIAL PRIMARY KEY,
    -- Identificación SUNAT
    idTipoComprobante   INT REFERENCES gen_ListaOpciones(id),  -- FACTURA(01), BOLETA(03), NC(07), ND(08)
    serie               VARCHAR(10) NOT NULL,
    numero              VARCHAR(15) NOT NULL,
    idEstadoSunat       INT REFERENCES gen_ListaOpciones(id),  -- (gen_Lista: EstadoSunat)
    idTipoOperacionSunat INT REFERENCES gen_ListaOpciones(id), -- (gen_Lista: TipoOperacionSunat)
    -- Nota de crédito / débito: referencia al comprobante que corrige
    idComprobanteOrigen INT REFERENCES ven_Comprobante(id),   -- NULL si es FC/BL normal
    idMotivoNota        INT REFERENCES gen_ListaOpciones(id),  -- MotivoNotaCredito o MotivoNotaDebito según tipo
    -- Ciclo electrónico SUNAT
    ticketSunat         VARCHAR(100),  -- ticket async para consultar CDR
    hashDocumento       VARCHAR(100),  -- hash del XML firmado
    xmlFirmado          TEXT,          -- XML enviado a SUNAT (firmado)
    cdrRespuesta        TEXT,          -- CDR de respuesta de SUNAT
    -- Datos del documento
    idTipoMovimiento    INT REFERENCES gen_ListaOpciones(id),  -- MOV. DIVERSOS, etc.
    idTipoVenta         INT REFERENCES gen_ListaOpciones(id),  -- VENTAS C/S GUIAS REMISION
    fecha               DATE NOT NULL,
    fechaVencimiento    DATE,
    tipoCambio          NUMERIC(10,4) DEFAULT 3.5,
    -- Partes
    idCliente           INT NOT NULL REFERENCES cli_Clientes(id),
    idSucursal          INT REFERENCES gen_Sucursal(id),
    idAlmacen           INT REFERENCES gen_Almacen(id),
    idCondicionPago     INT REFERENCES gen_CondicionPago(id),
    idMoneda            INT REFERENCES gen_ListaOpciones(id),  -- Nuevos Soles, USD
    idMedioPago         INT REFERENCES gen_ListaOpciones(id),  -- (gen_Lista: MedioPago)
    -- Importes
    subTotal            NUMERIC(12,4) DEFAULT 0,
    descuento           NUMERIC(12,4) DEFAULT 0,
    valorVenta          NUMERIC(12,4) DEFAULT 0,
    igv                 NUMERIC(12,4) DEFAULT 0,
    totalImporte        NUMERIC(12,4) DEFAULT 0,
    anticipos           NUMERIC(12,4) DEFAULT 0,
    exonerado           NUMERIC(12,4) DEFAULT 0,
    -- Glosa y observaciones
    glosa               VARCHAR(500),
    observaciones       VARCHAR(500),
    -- Contabilidad
    periodoContable     VARCHAR(10),
    operacion           VARCHAR(100),
    -- Estado: PENDIENTE, PAGADO, ANULADO
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW(),
    UNIQUE(serie, numero)
);

-- Detalle de cada línea del comprobante
CREATE TABLE ven_ComprobanteDetalle (
    id                  SERIAL PRIMARY KEY,
    idComprobante       INT NOT NULL REFERENCES ven_Comprobante(id),
    item                INT NOT NULL,
    idProducto          INT NOT NULL REFERENCES pro_Producto(id),
    descripcion         VARCHAR(300),
    idUnidadMedida      INT REFERENCES gen_ListaOpciones(id),
    cantidad            NUMERIC(12,4) NOT NULL,
    precioUnitario      NUMERIC(12,6) NOT NULL,
    descuento           NUMERIC(12,4) DEFAULT 0,
    valorVenta          NUMERIC(12,4),
    porcentajeIgv       NUMERIC(6,4) DEFAULT 18,
    idAfectacionIgv     INT REFERENCES gen_ListaOpciones(id),  -- (gen_Lista: AfectacionIgv) 10, 20, 30, 40
    impuesto            NUMERIC(12,4),
    importe             NUMERIC(12,4),
    -- Si el producto es un balón específico, referenciar
    idBalon             INT REFERENCES bal_Balon(id),
    capacidadCilindro   NUMERIC(10,4),
    idEstadoCilindro    INT REFERENCES gen_ListaOpciones(id),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Relación comprobante → Guía de Remisión
 
-- Cuotas de pago para ventas a crédito
CREATE TABLE ven_Cuotas (
    id              SERIAL PRIMARY KEY,
    idComprobante   INT NOT NULL REFERENCES ven_Comprobante(id),
    numeroCuota     INT NOT NULL,
    fechaVencimiento DATE NOT NULL,
    monto           NUMERIC(12,4) NOT NULL,
    montoPagado     NUMERIC(12,4) DEFAULT 0,
    -- Estado: PENDIENTE, PAGADO, VENCIDO
    idEstado        INT REFERENCES gen_ListaOpciones(id),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Garantía de envase/cilindro cobrada al cliente
-- Una garantía puede cubrir uno o varios cilindros del mismo préstamo
CREATE TABLE ven_Garantia (
    id                  SERIAL PRIMARY KEY,
    idCliente           INT NOT NULL REFERENCES cli_Clientes(id),
    idPrestamo          INT REFERENCES bal_Prestamo(id),       -- préstamo que originó la garantía
    ubicacion           VARCHAR(150),
    idProducto          INT REFERENCES pro_Producto(id),
    cantidadVenta       NUMERIC(12,4),
    idUnidadMedida      INT REFERENCES gen_ListaOpciones(id),
    fechaRegistro       DATE NOT NULL,
    montoCobrado        NUMERIC(12,4) NOT NULL DEFAULT 0,
    montoDevuelto       NUMERIC(12,4) NOT NULL DEFAULT 0,
    montoSaldo          NUMERIC(12,4) NOT NULL DEFAULT 0,
    idEstado            INT REFERENCES gen_ListaOpciones(id),  -- ACTIVA, DEVUELTA, PARCIAL
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Movimientos de garantía: cobro inicial y devoluciones parciales/totales
-- COBRO  → idComprobante apunta a la factura/boleta de cobro de garantía
-- DEVOLUCION → idComprobante apunta a la Nota de Crédito emitida al devolver
CREATE TABLE ven_GarantiaMovimiento (
    id                  SERIAL PRIMARY KEY,
    idGarantia          INT NOT NULL REFERENCES ven_Garantia(id),
    idTipoMovimiento    INT NOT NULL REFERENCES gen_ListaOpciones(id), -- COBRO, DEVOLUCION
    idComprobante       INT REFERENCES ven_Comprobante(id),            -- FC cobro o NC devolución
    fecha               DATE NOT NULL,
    monto               NUMERIC(12,4) NOT NULL,
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 7: GUÍAS DE REMISIÓN (GRE)
-- ============================================================

CREATE TABLE gre_GuiaRemision (
    id                      SERIAL PRIMARY KEY,
    -- Identificación SUNAT
    idTipoGuiaRemision      INT REFERENCES gen_ListaOpciones(id),  -- (gen_Lista: TipoGuiaRemision) 09, 31
    serie                   VARCHAR(10) NOT NULL,
    numero                  VARCHAR(15) NOT NULL,
    idEstadoSunat           INT REFERENCES gen_ListaOpciones(id),  -- (gen_Lista: EstadoSunat)
    -- Ciclo electrónico SUNAT
    ticketSunat             VARCHAR(100),
    hashDocumento           VARCHAR(100),
    xmlFirmado              TEXT,
    cdrRespuesta            TEXT,
    fecha                   DATE NOT NULL,
    tipoCambio              NUMERIC(10,4) DEFAULT 3.5,
    idSucursal              INT NOT NULL REFERENCES gen_Sucursal(id),
    idAlmacen               INT NOT NULL REFERENCES gen_Almacen(id),
    idCliente               INT REFERENCES cli_Clientes(id),
    -- Traslado
    fechaTraslado           DATE NOT NULL,
    idMotivoTraslado        INT REFERENCES gen_ListaOpciones(id),   -- (gen_Lista: MotivoTraslado)
    idUnidadMedida          INT REFERENCES gen_ListaOpciones(id),
    pesoBruto               NUMERIC(10,4),
    numeroBultos            INT,
    -- Origen (la dirección se deriva de gen_Sucursal; se puede sobreescribir)
    direccionOrigen         VARCHAR(255),
    idDistritoOrigen        INT REFERENCES gen_Distrito(id),  -- codigoUbigeo requerido por SUNAT
    -- Destinatario
    idDestinatario          INT REFERENCES cli_Clientes(id),
    direccionLlegada        VARCHAR(255),
    idDistritoLlegada       INT REFERENCES gen_Distrito(id),  -- codigoUbigeo requerido por SUNAT
    -- Transporte (chofer y vehículo de la empresa o del cliente/proveedor)
    idModalidadTraslado     INT REFERENCES gen_ListaOpciones(id),  -- PRIVADO(02), PUBLICO(01)
    idTransportista         INT REFERENCES cli_Clientes(id),       -- RUC del transportista (modalidad pública)
    idChofer                INT REFERENCES gen_Chofer(id),
    idVehiculo              INT REFERENCES gen_Vehiculo(id),
    -- Responsable interno
    idResponsable           INT REFERENCES auth_Usuarios(id),
    observaciones           VARCHAR(500),
    -- Contabilidad
    periodoContable         VARCHAR(10),
    operacion               VARCHAR(100),
    -- Estado: PENDIENTE, ENVIADO, RECIBIDO, ANULADO
    idEstado                INT REFERENCES gen_ListaOpciones(id),
    estado                  INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion           TIMESTAMP DEFAULT NOW(),
    fechaModificacion       TIMESTAMP DEFAULT NOW(),
    UNIQUE(serie, numero)
);

-- Detalle de la guía de remisión
CREATE TABLE gre_GuiaRemisionDetalle (
    id              SERIAL PRIMARY KEY,
    idGuiaRemision  INT NOT NULL REFERENCES gre_GuiaRemision(id),
    item            INT NOT NULL,
    idProducto      INT NOT NULL REFERENCES pro_Producto(id),
    descripcion     VARCHAR(300),
    idUnidadMedida  INT REFERENCES gen_ListaOpciones(id),
    cantidad        NUMERIC(12,4) NOT NULL,
    -- Balón específico si aplica
    idBalon         INT REFERENCES bal_Balon(id),
    glosa           VARCHAR(255),
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Documentos de referencia de la guía (facturas, boletas, otras GRE asociadas)
CREATE TABLE gre_DocumentosReferencia (
    id                  SERIAL PRIMARY KEY,
    idGuiaRemision      INT NOT NULL REFERENCES gre_GuiaRemision(id),
    idTipoComprobante   INT NOT NULL REFERENCES gen_ListaOpciones(id),  -- (gen_Lista: TipoComprobante) 01, 03, 09...
    serie               VARCHAR(10),
    numero              VARCHAR(15),
    fecha               DATE,
    estado          INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion   TIMESTAMP DEFAULT NOW(),
    fechaModificacion TIMESTAMP DEFAULT NOW()
);

-- Control de rangos de numeración de guías asignados (ej. GUIAS JHON 8554-8600)
CREATE TABLE gre_RangoNumeracion (
    id                  SERIAL PRIMARY KEY,
    responsable         VARCHAR(100) NOT NULL,     -- JHON
    descripcion         VARCHAR(150),              -- GUIAS JHON
    serie               VARCHAR(10),
    numeroInicio        INT NOT NULL,              -- 8554
    numeroFin           INT NOT NULL,              -- 8600
    numeroActual        INT,                       -- último usado
    fechaAsignacion     DATE,
    observacion         VARCHAR(255),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 8: FINANZAS — CUENTAS POR COBRAR / PAGAR Y COBRANZA
-- ============================================================

-- Cuentas por cobrar y por pagar unificadas
-- idTipoCuenta: COBRAR (cliente) | PAGAR (proveedor)
CREATE TABLE fin_Cuenta (
    id                  SERIAL PRIMARY KEY,
    idTipoCuenta        INT NOT NULL REFERENCES gen_ListaOpciones(id),
    idTercero           INT NOT NULL REFERENCES cli_Clientes(id),
    idComprobanteVenta  INT REFERENCES ven_Comprobante(id),
    idComprobanteCompra INT REFERENCES com_ComprobanteCompra(id),
    idCuota             INT REFERENCES ven_Cuotas(id),
    fechaEmision        DATE NOT NULL,
    fechaVencimiento    DATE,
    montoPendiente      NUMERIC(12,4) NOT NULL,
    montoAbonado        NUMERIC(12,4) DEFAULT 0,
    montoSaldo          NUMERIC(12,4),
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE fin_Pago (
    id                  SERIAL PRIMARY KEY,
    idCuenta            INT NOT NULL REFERENCES fin_Cuenta(id),
    fechaPago           DATE NOT NULL,
    monto               NUMERIC(12,4) NOT NULL,
    idMedioPago         INT REFERENCES gen_ListaOpciones(id),
    referencia          VARCHAR(100),
    observacion         VARCHAR(255),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion    INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- GRUPO 9: FINANZAS (PRÉSTAMOS BANCARIOS)
-- ============================================================

CREATE TABLE fin_PrestamoBanco (
    id                  SERIAL PRIMARY KEY,
    idBanco             INT REFERENCES gen_ListaOpciones(id),
    descripcion         VARCHAR(255),
    montoTotal          NUMERIC(14,4),
    numeroCuotas        INT,
    fechaInicio         DATE,
    tasaInteres         NUMERIC(8,4),
    -- Estado: ACTIVO, CANCELADO
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    observacion         VARCHAR(500),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

CREATE TABLE fin_PrestamoBancoCuota (
    id                  SERIAL PRIMARY KEY,
    idPrestamoBanco     INT NOT NULL REFERENCES fin_PrestamoBanco(id),
    numeroCuota         INT NOT NULL,
    importe             NUMERIC(12,4) NOT NULL,
    fechaVencimiento    DATE,
    fechaPago           DATE,
    idMedioPago         INT REFERENCES gen_ListaOpciones(id),  -- TRANSFERENCIA, CHEQUE, DÉBITO AUTOMÁTICO
    numeroOperacion     VARCHAR(50),                            -- N° operación / N° cheque
    idCuentaBancaria    INT REFERENCES gen_CuentaBancaria(id), -- cuenta empresa debitada
    -- Estado: PENDIENTE, PAGADO, VENCIDO
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    observacion         VARCHAR(255),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW(),
    UNIQUE(idPrestamoBanco, numeroCuota)
);


-- ============================================================
-- GRUPO 10: COMPRAS, GASTOS Y CUENTAS POR PAGAR
-- ============================================================

-- Clasificación contable / operativa en 3 niveles (Grupo > Subgrupo > Sub subgrupo)
-- Ej: GASES INDUSTRIALES > GAS NOBLE > OXIGENO GAS INDUSTRIAL
--     OFICINA > GASTOS ADMINISTRATIVOS > MANO DE OBRA
--     CAMIÓN > GASTOS DE TRANSPORTE > COMBUSTIBLES
CREATE TABLE gen_ClasificacionGasto (
    id                  SERIAL PRIMARY KEY,
    grupo               VARCHAR(100) NOT NULL,     -- OFICINA, CAMIÓN, GASES INDUSTRIALES, FLETE...
    subgrupo            VARCHAR(100) NOT NULL,     -- GASTOS ADMINISTRATIVOS, GAS NOBLE...
    subSubgrupo         VARCHAR(100) NOT NULL,   -- MANO DE OBRA, OXIGENO GAS INDUSTRIAL...
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW(),
    UNIQUE(grupo, subgrupo, subSubgrupo)
);

-- Comprobante de compra o gasto (factura proveedor, gasto sin proveedor, tributos SUNAT...)
CREATE TABLE com_ComprobanteCompra (
    id                  SERIAL PRIMARY KEY,
    idTipoComprobante   INT REFERENCES gen_ListaOpciones(id),  -- FACTURA, BOLETA, S/D, RR.HH... (gen_Lista: TipoComprobante)
    serie               VARCHAR(10),
    numero              VARCHAR(15),
    fecha               DATE NOT NULL,
    idProveedor         INT REFERENCES cli_Clientes(id),
    idTipoRegistro      INT REFERENCES gen_ListaOpciones(id),  -- COMPRA, GASTO
    idCategoriaGasto    INT REFERENCES gen_ListaOpciones(id),  -- Combustible, Tributos, Flete...
    idSucursal          INT REFERENCES gen_Sucursal(id),
    idAlmacen           INT REFERENCES gen_Almacen(id),
    idMoneda            INT REFERENCES gen_ListaOpciones(id),
    idCondicionPago     INT REFERENCES gen_CondicionPago(id),
    subTotal            NUMERIC(12,4) DEFAULT 0,
    igv                 NUMERIC(12,4) DEFAULT 0,
    totalImporte        NUMERIC(12,4) DEFAULT 0,
    afectaInventario    BOOLEAN DEFAULT FALSE,     -- true si ingresa stock (gases, cilindros...)
    declararSunat       BOOLEAN DEFAULT FALSE,     -- true = factura a declarar ante SUNAT (secc. IV y V)
    glosa               VARCHAR(500),
    -- Estado: PENDIENTE, PAGADO, ANULADO
    idEstado            INT REFERENCES gen_ListaOpciones(id),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);

-- Detalle de compra/gasto por línea (clasificación + pago por línea como en Excel de egresos)
CREATE TABLE com_ComprobanteCompraDetalle (
    id                  SERIAL PRIMARY KEY,
    idComprobante       INT NOT NULL REFERENCES com_ComprobanteCompra(id),
    item                INT NOT NULL,
    idClasificacionGasto INT REFERENCES gen_ClasificacionGasto(id),
    idProducto          INT REFERENCES pro_Producto(id),
    descripcion         VARCHAR(300) NOT NULL,
    idUnidadMedida      INT REFERENCES gen_ListaOpciones(id),
    cantidad            NUMERIC(12,4) NOT NULL,
    precioUnitario      NUMERIC(12,6),
    importe             NUMERIC(12,4) NOT NULL,
    -- Pago de la línea
    idMedioPago         INT REFERENCES gen_ListaOpciones(id),
    fechaPago           DATE,
    numeroOperacion     VARCHAR(50),
    idEstadoPago        INT REFERENCES gen_ListaOpciones(id),
    observacion         VARCHAR(500),
    afectaStock         BOOLEAN DEFAULT FALSE,
    idPago              INT REFERENCES fin_Pago(id),
    estado              INT NOT NULL DEFAULT 1,
    idUsuarioCreacion       INT REFERENCES auth_Usuarios(id),
    idUsuarioModificacion   INT REFERENCES auth_Usuarios(id),
    fechaCreacion       TIMESTAMP DEFAULT NOW(),
    fechaModificacion   TIMESTAMP DEFAULT NOW()
);


-- ============================================================
-- ÍNDICES RECOMENDADOS PARA PERFORMANCE
-- ============================================================

-- Clientes
CREATE INDEX idx_cli_clientes_numDoc ON cli_Clientes(numeroDocumento);
CREATE INDEX idx_cli_clientes_codigo ON cli_Clientes(codigoInterno);
CREATE INDEX idx_cli_clientes_razon ON cli_Clientes(razonSocial);
CREATE INDEX idx_cli_contacto_cliente ON cli_Contacto(idCliente);
CREATE INDEX idx_gen_vehiculo_placa ON gen_Vehiculo(placa);
CREATE INDEX idx_gen_vehiculo_cliente ON gen_Vehiculo(idCliente);
CREATE UNIQUE INDEX idx_gen_vehiculo_placa_empresa ON gen_Vehiculo(placa) WHERE idCliente IS NULL;
CREATE UNIQUE INDEX idx_gen_vehiculo_placa_cliente ON gen_Vehiculo(idCliente, placa) WHERE idCliente IS NOT NULL;
CREATE INDEX idx_gen_chofer_documento ON gen_Chofer(numeroDocumento);
CREATE INDEX idx_gen_chofer_cliente ON gen_Chofer(idCliente);
CREATE INDEX idx_gen_cuenta_cliente ON gen_CuentaBancaria(idCliente);

-- Balones
CREATE INDEX idx_bal_balon_codigo ON bal_Balon(codigoBalon);
CREATE INDEX idx_bal_balon_libro ON bal_Balon(libroCilindro, paginaLibro);
CREATE INDEX idx_bal_balon_cliente_ubic ON bal_Balon(idClienteUbicacion);
CREATE INDEX idx_bal_balon_ph_vence ON bal_Balon(fechaProximaPruebaHidrostatica);
CREATE INDEX idx_bal_balon_estado ON bal_Balon(idEstadoBalon);
CREATE INDEX idx_bal_balon_cliente ON bal_Balon(idClientePropietario);
CREATE INDEX idx_bal_movimiento_balon ON bal_Movimiento(idBalon);
CREATE INDEX idx_bal_movimiento_fecha ON bal_Movimiento(fechaMovimiento);
CREATE INDEX idx_bal_movimiento_recarga_balon ON bal_MovimientoRecarga(idBalon);
CREATE INDEX idx_bal_movimiento_recarga_fecha ON bal_MovimientoRecarga(fechaSalidaAlmacen);
CREATE INDEX idx_bal_prestamo_cliente ON bal_Prestamo(idCliente);
CREATE INDEX idx_bal_prestamo_proveedor ON bal_Prestamo(idProveedor);
CREATE INDEX idx_bal_prestamo_tipo ON bal_Prestamo(idTipoPrestamo);
CREATE INDEX idx_bal_prestamo_detalle_balon ON bal_PrestamoDetalle(idBalon);
CREATE INDEX idx_bal_prestamo_detalle_venc ON bal_PrestamoDetalle(fechaVencimiento);
CREATE INDEX idx_bal_prestamo_detalle_est ON bal_PrestamoDetalle(idEstado);
CREATE INDEX idx_bal_alquiler_cliente ON bal_Alquiler(idCliente);

-- Ventas
CREATE INDEX idx_ven_comprobante_serie ON ven_Comprobante(serie, numero);
CREATE INDEX idx_ven_comprobante_cliente ON ven_Comprobante(idCliente);
CREATE INDEX idx_ven_comprobante_fecha ON ven_Comprobante(fecha);
CREATE INDEX idx_ven_detalle_comprobante ON ven_ComprobanteDetalle(idComprobante);
CREATE INDEX idx_ven_detalle_estado_cil ON ven_ComprobanteDetalle(idEstadoCilindro);
CREATE INDEX idx_ven_garantia_cliente ON ven_Garantia(idCliente);
CREATE INDEX idx_ven_garantia_fecha ON ven_Garantia(fechaRegistro);
CREATE INDEX idx_ven_garantia_mov ON ven_GarantiaMovimiento(idGarantia);

-- GRE
CREATE INDEX idx_gre_serie ON gre_GuiaRemision(serie, numero);
CREATE INDEX idx_gre_fecha ON gre_GuiaRemision(fecha);
CREATE INDEX idx_gre_cliente ON gre_GuiaRemision(idCliente);
CREATE INDEX idx_gre_rango_responsable ON gre_RangoNumeracion(responsable);

-- Stock y movimientos
CREATE INDEX idx_pro_stock_almacen ON pro_Stock(idAlmacen, idProducto);
CREATE INDEX idx_pro_movimientos_producto ON pro_Movimientos(idProducto, fecha);
CREATE INDEX idx_pro_catalogo_precio ON pro_CatalogoPrecio(idTipoCatalogo, periodo);
CREATE INDEX idx_pro_catalogo_nombre ON pro_CatalogoPrecio(nombreItem);

-- Vencimientos documentos
CREATE INDEX idx_gen_doc_vencimiento_fecha ON gen_DocumentoVencimiento(fechaVencimiento);
CREATE INDEX idx_gen_doc_vencimiento_vehiculo ON gen_DocumentoVencimiento(idVehiculo);

-- Cobranza / kardex
-- Finanzas unificadas
CREATE INDEX idx_fin_cuenta_tercero ON fin_Cuenta(idTercero);
CREATE INDEX idx_fin_cuenta_tipo ON fin_Cuenta(idTipoCuenta);
CREATE INDEX idx_fin_cuenta_saldo ON fin_Cuenta(idTercero, montoSaldo);
CREATE INDEX idx_fin_pago_cuenta ON fin_Pago(idCuenta);
CREATE INDEX idx_fin_pago_fecha ON fin_Pago(fechaPago);

-- Compras y gastos
CREATE INDEX idx_com_compra_fecha ON com_ComprobanteCompra(fecha);
CREATE INDEX idx_com_compra_proveedor ON com_ComprobanteCompra(idProveedor);
CREATE INDEX idx_com_detalle_comprobante ON com_ComprobanteCompraDetalle(idComprobante);
CREATE INDEX idx_com_detalle_clasificacion ON com_ComprobanteCompraDetalle(idClasificacionGasto);
CREATE INDEX idx_com_detalle_fecha_pago ON com_ComprobanteCompraDetalle(fechaPago);
CREATE INDEX idx_com_detalle_descripcion ON com_ComprobanteCompraDetalle(descripcion);
CREATE INDEX idx_gen_clasificacion_gasto ON gen_ClasificacionGasto(grupo, subgrupo);
CREATE INDEX idx_com_compra_declarar_sunat ON com_ComprobanteCompra(declararSunat, fecha);


-- ============================================================
-- DATOS INICIALES MÍNIMOS: LISTAS MAESTRAS
-- ============================================================

-- Lista base (gen_Lista)
INSERT INTO gen_Lista (nombre, descripcion) VALUES
('TipoPersona',       'Natural o Jurídica'),
('TipoCliente',       'Cliente, Paciente, Proveedor o Ambos'),
('TipoDocumento',     'RUC, DNI, CE, etc.'),
('TipoCuenta',        'Tipo de cuenta bancaria'),
('Banco',             'Bancos disponibles'),
('UnidadMedida',      'Unidades de medida de productos'),
('TipoMovInv',        'Tipos de movimiento de inventario'),
('TipoMovBalon',      'Tipos de movimiento de balón'),
('EstadoBalon',       'Estados posibles de un balón'),
('TipoPrestamo',      'ENVASE_EMPRESA_A_CLIENTE, CILINDRO_CLIENTE_A_EMPRESA, CILINDRO_A_PLANTA'),
('TipoMantenimiento', 'Tipos de mantenimiento de cilindro'),
('ModalidadTraslado', '01=Transporte público, 02=Transporte privado'),
('MotivoTraslado',    '01=Venta, 02=Compra, 04=Entre establecimientos, 09=Exportación, 13=Otros'),
('MedioPago',         'Medios de pago'),
('Moneda',            'Monedas'),
('TipoComprobante',   'Tipos comprobante SUNAT: 01=Factura, 03=Boleta, 07=NC, 08=ND, 09=GRE'),
('MotivoNotaCredito', '01=Anulación, 07=Descuento, 08=Devolución, 13=Ajuste de precio'),
('MotivoNotaDebito',  '01=Intereses por mora, 02=Aumento de valor, 03=Penalidades'),
('TipoOperacionSunat','0101=Venta interna, 0112=Sustento gastos, 0200=Exportación'),
('TipoDocumentoRef',  'Tipos de documento origen en movimientos: FACTURA, GRE, PRESTAMO, ALQUILER, RECARGA, COMPRA, DEVOLUCION'),
('EstadoSunat',       'PENDIENTE, ACEPTADO, RECHAZADO, BAJA'),
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

-- Opciones EstadoBalon (ajustar idLista según ID real de 'EstadoBalon')
-- INSERT INTO gen_ListaOpciones (idLista, nombre) VALUES
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
-- Ejecutar después de cargar gen_ListaOpciones de TipoVehiculo, Banco, UnidadMedida
-- ============================================================

-- gen_Empresa + gen_ConfiguracionSunat
-- INSERT INTO gen_Empresa (ruc, razonSocial, nombreComercial) VALUES
-- ('10175332796', 'RUIZ DE LOS SANTOS HAYDEE', 'OXIGENO SARITA');
-- INSERT INTO gen_ConfiguracionSunat (idEmpresa, usuarioSol, claveSol) VALUES
-- (1, 'WILLOONT', 'Grupo2026GVR');

-- gen_ConfiguracionServicio
-- INSERT INTO gen_ConfiguracionServicio (codigo, nombre, email, usuario, contrasena) VALUES
-- ('CORREO', 'Correo corporativo', 'gvariasr@hotmail.com', 'gvariasr@hotmail.com', 'Rumymisky1214'),
-- ('WHEREX', 'Plataforma WHEREX', NULL, 'gvariasr@hotmail.com', 'S@rit@35');

-- gen_Vehiculo — flota empresa (idCliente NULL)
-- INSERT INTO gen_Vehiculo (idTipoVehiculo, placa) VALUES
-- (..., '9773CM'),   -- MOTOTAXI
-- (..., 'M4F782'),   -- CAMION
-- (..., '02198M');   -- MOTO CARGUERA
-- -- MOTO LINEAL: placa pendiente en Excel

-- gen_Chofer — choferes empresa (idCliente NULL)
-- INSERT INTO gen_Chofer (apellidoPaterno, apellidoMaterno, nombres, brevete, idTipoDocumento, numeroDocumento) VALUES
-- ('VALDERA', 'ACOSTA', 'JUAN JOSE', 'C16740640', ..., '16740640'),
-- ('VARIAS', 'PANTA', 'LUIS ALBERTO', 'C17534821', ..., '17534821'),
-- ('VARIAS', 'RUIZ', 'GIANCARLO JAVIER', 'C43862326', ..., '43862326'),
-- ('SANTISTEBAN', 'SALZAR', 'JHON OCTAVIO', NULL, ..., '72684495');

-- gen_CuentaBancaria — cuentas empresa (idCliente NULL)
-- INSERT INTO gen_CuentaBancaria (idBanco, titular, numeroCuenta, numeroCuentaInterbancaria) VALUES
-- (...,'RUIZ DE LOS SANTOS HAYDEE', '30515162800047', '00230511516280004713'),  -- BCP
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '001107960200180312', '01179600020018031207'),  -- BBVA
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '7123243857101', '00371201324385710171'),  -- INTERBANK
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '7208838719', '00940920720883871943');  -- SCOTIABANK
-- INSERT INTO gen_CuentaBancaria (idTipoCuenta, titular, telefonoBilletera) VALUES
-- (...,'RUIZ DE LOS SANTOS HAYDEE', '964069607'),  -- YAPE
-- (...,'VARIAS RUIZ GIANCARLO JAVIER', '964069607');  -- PLIN

-- gen_Vehiculo / gen_Chofer / gen_CuentaBancaria — cliente (idCliente = ...)
-- INSERT INTO gen_Chofer (idCliente, nombres, apellidoPaterno, dni, brevete) VALUES (...);
-- INSERT INTO gen_Vehiculo (idCliente, placa, marca, certificadoInscripcion) VALUES (...);
-- INSERT INTO gen_CuentaBancaria (idCliente, idBanco, idTipoCuenta, numeroCuenta) VALUES (...);

-- pro_Producto (gases)
-- Los gases van en pro_Producto con esGas=TRUE (090, 095, 040...)
-- Ejemplo: Oxígeno Industrial codigo 010, U.M. m3

-- gen_DocumentoVencimiento
-- INSERT INTO gen_DocumentoVencimiento (descripcion, fechaVencimiento) VALUES
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
