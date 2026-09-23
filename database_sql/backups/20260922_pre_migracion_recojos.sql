-- Respaldo previo a las migraciones 20260911_recojos_solo_actividades y 20260911_alquiler_solo_regulador
-- Generado: 2026-09-22T20:54:11.154Z

-- Estructura de las tablas retiradas (no queda copia en database_sql/tablas/)

CREATE TABLE bal_recojo (
  id integer DEFAULT nextval('bal_recojo_id_seq'::regclass) NOT NULL,
  id_cliente integer NOT NULL,
  id_prestamo integer,
  fecha_programada date NOT NULL,
  hora_estimada time without time zone,
  fecha_visita date,
  id_usuario_responsable integer,
  id_estado integer,
  id_motivo_fallo integer,
  observacion varchar(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_alquiler integer,
  id_resultado_regulador integer,
  id_condicion_regulador integer,
  nueva_fecha_retorno_regulador date,
  observacion_regulador varchar(500),
  id_compra integer,
  id_doc_salida integer
);

CREATE TABLE bal_recojo_detalle (
  id integer DEFAULT nextval('bal_recojo_detalle_id_seq'::regclass) NOT NULL,
  id_recojo integer NOT NULL,
  id_prestamo_detalle integer,
  id_resultado integer,
  id_estado_contenido integer,
  nueva_fecha_retorno date,
  id_almacen_destino integer,
  observacion varchar(500),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  id_alquiler_detalle integer,
  cantidad_restante numeric(10,4),
  id_balon integer
);

CREATE TABLE bal_alquiler_detalle (
  id integer DEFAULT nextval('bal_alquiler_detalle_id_seq'::regclass) NOT NULL,
  id_alquiler integer NOT NULL,
  id_balon integer NOT NULL,
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now(),
  fecha_devolucion date
);

-- bal_recojo: 8 fila(s)
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (8, 17, 22, '2026-09-10T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-09T20:27:07.361Z', '2026-09-09T20:27:07.361Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (9, 14, 23, '2026-09-18T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-09T22:42:33.640Z', '2026-09-09T22:42:33.640Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (10, 17, 24, '2026-09-23T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 2, 2, '2026-09-09T23:58:38.561Z', '2026-09-09T23:58:38.561Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (11, 17, 25, '2026-09-23T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 2, 2, '2026-09-10T00:01:01.181Z', '2026-09-10T00:01:01.181Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (12, 17, 26, '2026-09-23T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 2, 2, '2026-09-10T00:03:31.050Z', '2026-09-10T00:03:31.050Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (13, 17, 27, '2026-09-30T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-16T15:50:49.268Z', '2026-09-16T15:50:49.268Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (14, 20, 28, '2026-10-06T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-22T15:25:04.206Z', '2026-09-22T15:25:04.206Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO bal_recojo (id, id_cliente, id_prestamo, fecha_programada, hora_estimada, fecha_visita, id_usuario_responsable, id_estado, id_motivo_fallo, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler, id_resultado_regulador, id_condicion_regulador, nueva_fecha_retorno_regulador, observacion_regulador, id_compra, id_doc_salida) VALUES (15, 20, 29, '2026-10-06T05:00:00.000Z', NULL, NULL, NULL, 284, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-22T16:51:06.209Z', '2026-09-22T16:51:06.209Z', NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- bal_recojo_detalle: 8 fila(s)
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (8, 8, 6, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-09T20:27:07.361Z', '2026-09-09T20:27:07.361Z', NULL, NULL, NULL);
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (9, 9, 7, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-09T22:42:33.640Z', '2026-09-09T22:42:33.640Z', NULL, NULL, NULL);
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (10, 10, 8, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 2, 2, '2026-09-09T23:58:38.561Z', '2026-09-09T23:58:38.561Z', NULL, NULL, NULL);
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (11, 11, 9, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 2, 2, '2026-09-10T00:01:01.181Z', '2026-09-10T00:01:01.181Z', NULL, NULL, NULL);
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (12, 12, 10, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 2, 2, '2026-09-10T00:03:31.050Z', '2026-09-10T00:03:31.050Z', NULL, NULL, NULL);
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (13, 13, 11, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-16T15:50:49.268Z', '2026-09-16T15:50:49.268Z', NULL, NULL, NULL);
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (14, 14, 12, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-22T15:25:04.206Z', '2026-09-22T15:25:04.206Z', NULL, NULL, NULL);
INSERT INTO bal_recojo_detalle (id, id_recojo, id_prestamo_detalle, id_resultado, id_estado_contenido, nueva_fecha_retorno, id_almacen_destino, observacion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion, id_alquiler_detalle, cantidad_restante, id_balon) VALUES (15, 15, 13, NULL, NULL, NULL, NULL, 'Recojo automático generado al vender el préstamo', 1, 3, 3, '2026-09-22T16:51:06.209Z', '2026-09-22T16:51:06.209Z', NULL, NULL, NULL);

-- bal_alquiler_detalle: 0 fila(s)

-- gen_lista: 3 fila(s)
INSERT INTO gen_lista (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (61, 'MotivoFalloRecojo', 'Motivo de fallo / no recogido en visita de recojo', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (62, 'ResultadoRecojoDetalle', 'Resultado por cilindro en una visita de recojo', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (63, 'EstadoRecojo', 'Estados de visita de recojo de cilindros en préstamo', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');

-- gen_lista_opciones: 14 fila(s)
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (280, 63, 'EN_RUTA', 'En ruta', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (281, 63, 'REPROGRAMADO', 'Reprogramado', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (282, 63, 'FALLIDO', 'Fallido', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (283, 63, 'EXITOSO', 'Exitoso', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (284, 63, 'PROGRAMADO', 'Programado', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (285, 63, 'CANCELADO', 'Cancelado', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (286, 62, 'RECOGIDO', 'Recogido', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (287, 62, 'NO_RECOGIDO', 'No recogido', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (288, 62, 'EXTENDIDO', 'Fecha extendida', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (289, 61, 'GAS_NO_USADO', 'Gas no usado', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (290, 61, 'CLIENTE_AUSENTE', 'Cliente ausente', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (291, 61, 'OTRO', 'Otro', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (292, 61, 'SIN_ACCESO', 'Sin acceso', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (293, 61, 'CILINDRO_NO_DISPONIBLE', 'No disponible', 1, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');

-- auth_permisos: 10 fila(s)
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (97, 'alquileres_detalle.ver', 'Ver detalle por cilindro en alquiler', TRUE, NULL, NULL, '2026-07-08T03:23:46.944Z', '2026-07-08T03:23:46.944Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (111, 'alquileres_detalle.eliminar', 'Eliminar detalle de alquiler', TRUE, NULL, NULL, '2026-07-08T03:23:46.944Z', '2026-07-08T03:23:46.944Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (118, 'alquileres_detalle.listar', 'Listar detalle de alquileres', TRUE, NULL, NULL, '2026-07-08T03:23:46.944Z', '2026-07-08T03:23:46.944Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (119, 'alquileres_detalle.crear', 'Vincular cilindros a alquiler (legado; preferir préstamo)', TRUE, NULL, NULL, '2026-07-08T03:23:46.944Z', '2026-07-08T03:23:46.944Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (131, 'alquileres_detalle.editar', 'Editar detalle de alquiler', TRUE, NULL, NULL, '2026-07-08T03:23:46.944Z', '2026-07-08T03:23:46.944Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (199, 'recojos_balon.editar', 'Editar / registrar resultado de recojo', TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (200, 'recojos_balon.ver', 'Ver detalle de visita de recojo', TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (201, 'recojos_balon.crear', 'Programar visitas de recojo', TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (202, 'recojos_balon.eliminar', 'Eliminar visitas de recojo', TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_permisos (id, nombre, descripcion, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (203, 'recojos_balon.listar', 'Listar visitas de recojo de cilindros', TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');

-- auth_roles_permisos: 25 fila(s)
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (108, 1, 97, TRUE, NULL, NULL, '2026-07-08T03:23:47.066Z', '2026-07-08T03:23:47.066Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (111, 1, 118, TRUE, NULL, NULL, '2026-07-08T03:23:47.066Z', '2026-07-08T03:23:47.066Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (115, 1, 111, TRUE, NULL, NULL, '2026-07-08T03:23:47.066Z', '2026-07-08T03:23:47.066Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (119, 1, 131, TRUE, NULL, NULL, '2026-07-08T03:23:47.066Z', '2026-07-08T03:23:47.066Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (127, 1, 119, TRUE, NULL, NULL, '2026-07-08T03:23:47.066Z', '2026-07-08T03:23:47.066Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (158, 2, 131, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (160, 2, 119, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (163, 2, 118, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (173, 2, 111, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (185, 2, 97, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (216, 4, 97, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (230, 4, 111, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (237, 4, 118, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (246, 4, 119, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (252, 4, 131, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (278, 3, 111, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (282, 3, 118, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (293, 3, 97, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (315, 3, 119, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (327, 3, 131, TRUE, NULL, NULL, '2026-07-14T22:14:34.202Z', '2026-07-14T22:14:34.202Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (393, 1, 203, TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (394, 1, 201, TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (395, 1, 200, TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (396, 1, 199, TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');
INSERT INTO auth_roles_permisos (id, id_rol, id_permiso, estado, id_usuario_creacion, id_usuario_modificacion, fecha_creacion, fecha_modificacion) VALUES (397, 1, 202, TRUE, NULL, NULL, '2026-08-07T15:33:03.649Z', '2026-08-07T15:33:03.649Z');

-- bal_mantenimiento_id_recojo: 0 fila(s)

-- age_actividad_item_id_alquiler_detalle: 0 fila(s)

