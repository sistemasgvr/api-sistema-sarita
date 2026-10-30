-- Amplía el fixture aislado de rutas-pueblos-retorno.sql. Nunca usar en DEV/PROD.
CREATE SEQUENCE test_id START 1000;
ALTER TABLE gen_lista_opciones ALTER COLUMN id SET DEFAULT nextval('test_id');
ALTER TABLE gen_lista_opciones ADD COLUMN descripcion text;
INSERT INTO gen_lista VALUES (10, 'TipoMovInvUnificado'), (11, 'TipoDocumentoRef');
INSERT INTO gen_lista_opciones(nombre,id_lista) VALUES ('RUTA_PUEBLO',11), ('CANCELADA',2);
UPDATE gen_lista_opciones SET id_lista=2 WHERE nombre IN ('ABIERTA','EN_RUTA');
ALTER TABLE pro_producto ADD PRIMARY KEY(id);
ALTER TABLE pro_producto ADD COLUMN es_gas boolean DEFAULT true,
    ADD COLUMN afecta_stock boolean DEFAULT true, ADD COLUMN id_unidad_medida integer DEFAULT 1;
UPDATE pro_producto SET nombre='OXIGENO',codigo='GAS-OX';
ALTER TABLE gen_almacen ADD COLUMN estado integer DEFAULT 1;
INSERT INTO gen_almacen VALUES (1,'Principal',1);
CREATE TABLE gen_empresa (id integer, estado integer, tolerancia_m3_ruta_pueblo numeric);
ALTER TABLE bal_ruta_pueblo ALTER COLUMN id SET DEFAULT nextval('test_id');
ALTER TABLE bal_ruta_pueblo ADD COLUMN id_usuario_creacion integer;
ALTER TABLE bal_ruta_pueblo_detalle ALTER COLUMN id SET DEFAULT nextval('test_id');
ALTER TABLE bal_ruta_pueblo_detalle ADD COLUMN id_usuario_creacion integer;
ALTER TABLE bal_ruta_pueblo_detalle_producto ADD COLUMN id_usuario_creacion integer,
    ADD COLUMN id_usuario_modificacion integer, ADD COLUMN fecha_modificacion timestamp;
ALTER TABLE bal_ruta_pueblo_detalle_producto ALTER COLUMN estado SET DEFAULT 1;
ALTER TABLE bal_ruta_pueblo_detalle_producto ALTER COLUMN id SET DEFAULT nextval('test_id');
CREATE TABLE pro_stock (id serial PRIMARY KEY, id_producto integer, id_almacen integer,
    stock numeric(12,4), stock_minimo numeric DEFAULT 0, estado integer DEFAULT 1,
    id_usuario_creacion integer, id_usuario_modificacion integer, fecha_modificacion timestamp);
CREATE TABLE inv_movimiento (id serial PRIMARY KEY, fecha timestamp, id_tipo_movimiento integer,
    naturaleza text, id_producto integer, id_balon integer, cantidad numeric,
    id_unidad_medida integer, id_almacen_origen integer, id_almacen_destino integer,
    id_cliente integer, id_documento_origen integer, id_tipo_documento_origen integer,
    id_documento_detalle integer, id_movimiento_padre integer, stock_anterior numeric,
    stock_nuevo numeric, glosa text, estado integer DEFAULT 1,
    id_usuario_creacion integer, id_usuario_modificacion integer);
CREATE FUNCTION test_ruta_retorno.inv_obtener_movimiento(integer) RETURNS json LANGUAGE sql AS $$
    SELECT json_build_object('error',NULL,'registro',row_to_json(m)) FROM inv_movimiento m WHERE id=$1
$$;
INSERT INTO pro_stock(id_producto,id_almacen,stock) VALUES(1,1,100);
INSERT INTO bal_tipo_balon VALUES(4,'Sin capacidad en libras',1,10,NULL,1,1);
INSERT INTO bal_balon(id,codigo_balon,id_tipo_balon,id_almacen,id_estado_balon) VALUES
    (101,'MANUAL-A',4,1,5),(102,'MANUAL-B',4,1,5),(103,'MANUAL-C',4,1,5);
CREATE FUNCTION test_ruta_retorno.crear_manual(cid integer, libras numeric, m3 numeric) RETURNS integer LANGUAGE plpgsql AS $$
DECLARE r json; BEGIN
    r:=public.bal_crear_ruta_pueblo(p_id_almacen=>1,
        p_detalles=>json_build_array(json_build_object('idBalon',cid,'lbSalida',libras,'m3Salida',m3)));
    IF r->>'error' IS NOT NULL THEN RAISE EXCEPTION '%',r->>'error'; END IF;
    RETURN (r->'registro'->>'id')::integer;
END $$;
