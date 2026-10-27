-- Roles y asignación rol-permiso (aplicar después de todos los permisos.sql)
INSERT INTO
  auth_roles (nombre, descripcion, estado)
SELECT
  v.nombre,
  v.descripcion,
  v.estado
FROM
  (
    VALUES
      ('Gerencia', 'Acceso total al sistema', TRUE),
      (
        'Vendedor',
        'Mostrador y ventas: clientes, comprobantes y operaciones POS',
        TRUE
      ),
      (
        'Supervisor',
        'Supervisión operativa: mismo alcance que operario con más consulta',
        TRUE
      ),
      (
        'Operario',
        'Taller y almacén: cilindros, recargas, mantenimientos e inventario',
        TRUE
      ),
      (
        'Chofer',
        'Entregas: clientes, préstamos y movimientos de cilindros',
        TRUE
      ),
      ('Administrador', 'Administración de local', TRUE)
  ) AS v (nombre, descripcion, estado)
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      auth_roles r
    WHERE
      r.nombre = v.nombre
  );

INSERT INTO
  auth_roles_permisos (id_rol, id_permiso, estado)
SELECT
  r.id,
  p.id,
  v.estado
FROM
  (
    VALUES
      ('Gerencia', 'auth.todo', TRUE),
      ('Gerencia', 'almacenes.editar', TRUE),
      ('Gerencia', 'almacenes.listar', TRUE),
      ('Gerencia', 'almacenes.crear', TRUE),
      ('Gerencia', 'almacenes.eliminar', TRUE),
      ('Gerencia', 'almacenes.ver', TRUE),
      ('Administrador', 'usuarios.listar', TRUE),
      ('Administrador', 'empresas.listar', TRUE),
      ('Administrador', 'almacenes.listar', TRUE),
      (
        'Administrador',
        'configuracion_sunat.editar',
        TRUE
      ),
      (
        'Administrador',
        'configuracion_sunat.listar',
        TRUE
      ),
      (
        'Administrador',
        'configuracion_servicios.eliminar',
        TRUE
      ),
      ('Administrador', 'sucursales.listar', TRUE),
      (
        'Administrador',
        'configuracion_servicios.crear',
        TRUE
      ),
      ('Administrador', 'empresas.ver', TRUE),
      (
        'Administrador',
        'configuracion_servicios.ver',
        TRUE
      ),
      (
        'Administrador',
        'configuracion_servicios.listar',
        TRUE
      ),
      ('Administrador', 'configuracion_sunat.ver', TRUE),
      (
        'Administrador',
        'configuracion_servicios.editar',
        TRUE
      ),
      ('Administrador', 'condiciones_pago.listar', TRUE),
      ('Administrador', 'almacenes.ver', TRUE),
      ('Administrador', 'condiciones_pago.ver', TRUE),
      ('Administrador', 'clientes.ver', TRUE),
      ('Administrador', 'clientes.editar', TRUE),
      ('Administrador', 'clientes.listar', TRUE),
      ('Administrador', 'clientes.crear', TRUE),
      ('Administrador', 'categorias.listar', TRUE),
      ('Administrador', 'categorias.ver', TRUE),
      ('Administrador', 'categorias.crear', TRUE),
      ('Administrador', 'categorias.editar', TRUE),
      ('Administrador', 'categorias.eliminar', TRUE),
      ('Administrador', 'sub_categorias.listar', TRUE),
      ('Administrador', 'sub_categorias.ver', TRUE),
      ('Administrador', 'sub_categorias.crear', TRUE),
      ('Administrador', 'sub_categorias.editar', TRUE),
      ('Administrador', 'sub_categorias.eliminar', TRUE),
      ('Administrador', 'catalogo_precios.listar', TRUE),
      ('Administrador', 'catalogo_precios.ver', TRUE),
      ('Administrador', 'catalogo_precios.crear', TRUE),
      ('Administrador', 'catalogo_precios.editar', TRUE),
      (
        'Administrador',
        'catalogo_precios.eliminar',
        TRUE
      ),
      ('Administrador', 'stock.listar', TRUE),
      ('Administrador', 'stock.ver', TRUE),
      ('Administrador', 'movimientos.listar', TRUE),
      ('Administrador', 'movimientos.ver', TRUE),
      ('Administrador', 'movimientos.editar', TRUE),
      ('Administrador', 'tipos_balon.listar', TRUE),
      (
        'Administrador',
        'mantenimientos_balon.listar',
        TRUE
      ),
      (
        'Administrador',
        'mantenimientos_balon.editar',
        TRUE
      ),
      ('Administrador', 'alquileres_balon.ver', TRUE),
      ('Administrador', 'alquileres_balon.editar', TRUE),
      ('Administrador', 'balones.ver', TRUE),
      ('Administrador', 'alquileres_balon.listar', TRUE),
      ('Administrador', 'movimientos_balon.editar', TRUE),
      ('Administrador', 'movimientos_balon.crear', TRUE),
      ('Administrador', 'balones.crear', TRUE),
      (
        'Administrador',
        'mantenimientos_balon.crear',
        TRUE
      ),
      ('Administrador', 'movimientos_balon.ver', TRUE),
      ('Administrador', 'mantenimientos_balon.ver', TRUE),
      ('Administrador', 'balones.listar', TRUE),
      ('Administrador', 'balones.eliminar', TRUE),
      (
        'Administrador',
        'movimientos_balon.eliminar',
        TRUE
      ),
      ('Administrador', 'alquileres_balon.crear', TRUE),
      ('Administrador', 'tipos_balon.crear', TRUE),
      ('Administrador', 'tipos_balon.eliminar', TRUE),
      ('Administrador', 'tipos_balon.ver', TRUE),
      (
        'Administrador',
        'alquileres_balon.eliminar',
        TRUE
      ),
      ('Administrador', 'movimientos_balon.listar', TRUE),
      (
        'Administrador',
        'mantenimientos_balon.eliminar',
        TRUE
      ),
      ('Administrador', 'balones.editar', TRUE),
      ('Administrador', 'tipos_balon.editar', TRUE),
      ('Administrador', 'comprobantes.ver', TRUE),
      ('Administrador', 'ventas.ver', TRUE),
      ('Administrador', 'comprobantes.listar', TRUE),
      ('Administrador', 'comprobantes.crear', TRUE),
      (
        'Administrador',
        'comprobantes.consultar_cdr',
        TRUE
      ),
      ('Administrador', 'comprobantes.emitir', TRUE),
      ('Administrador', 'comprobantes.eliminar', TRUE),
      ('Administrador', 'comprobantes.editar', TRUE),
      ('Administrador', 'guias_remision.listar', TRUE),
      ('Administrador', 'guias_remision.crear', TRUE),
      ('Administrador', 'guias_remision.editar', TRUE),
      ('Administrador', 'guias_remision.emitir', TRUE),
      ('Administrador', 'guias_remision.ver', TRUE),
      ('Administrador', 'guias_remision.eliminar', TRUE),
      ('Administrador', 'compras.listar', TRUE),
      ('Administrador', 'compras.ver', TRUE),
      ('Administrador', 'compras.crear', TRUE),
      ('Administrador', 'compras.editar', TRUE),
      ('Administrador', 'compras.eliminar', TRUE),
      ('Administrador', 'dashboard.ver_clientes', TRUE),
      ('Administrador', 'dashboard.ver_balones', TRUE),
      ('Administrador', 'finanzas.cxc.ver', TRUE),
      ('Administrador', 'finanzas.cxp.ver', TRUE),
      (
        'Administrador',
        'finanzas.cxc.registrar_pago',
        TRUE
      ),
      (
        'Administrador',
        'finanzas.cxp.registrar_pago',
        TRUE
      ),
      ('Administrador', 'finanzas.cxp.crear', TRUE),
      ('Administrador', 'finanzas.cxc.crear', TRUE),
      ('Administrador', 'bajas_cliente.solicitar', TRUE),
      ('Administrador', 'bajas_cliente.ver', TRUE),
      ('Administrador', 'bajas_cliente.eliminar', TRUE),
      ('Administrador', 'bajas_balon.ver', TRUE),
      ('Administrador', 'bajas_balon.solicitar', TRUE),
      ('Administrador', 'bajas_balon.listar', TRUE),
      ('Administrador', 'sub_categorias.restaurar', TRUE),
      ('Administrador', 'categorias.restaurar', TRUE),
      ('Administrador', 'finanzas.cxc.eliminar', TRUE),
      ('Administrador', 'finanzas.cxp.editar', TRUE),
      ('Administrador', 'finanzas.cxp.eliminar', TRUE),
      ('Administrador', 'finanzas.cxc.editar', TRUE),
      ('Administrador', 'finanzas.exportar', TRUE),
      ('Administrador', 'finanzas.garantias.crear', TRUE),
      (
        'Administrador',
        'finanzas.forzar_duplicado',
        TRUE
      ),
      ('Administrador', 'finanzas.garantias.ver', TRUE),
      (
        'Administrador',
        'finanzas.garantias.eliminar',
        TRUE
      ),
      (
        'Administrador',
        'finanzas.garantias.editar',
        TRUE
      ),
      (
        'Administrador',
        'finanzas.garantias.reembolsar',
        TRUE
      ),
      ('Administrador', 'caja.ver', TRUE),
      ('Administrador', 'caja.registrar_gasto', TRUE),
      ('Administrador', 'caja.registrar_deposito', TRUE),
      ('Administrador', 'caja.observacion', TRUE),
      ('Administrador', 'caja.libro_diario', TRUE),
      ('Administrador', 'lotes_protocolo.listar', TRUE),
      ('Administrador', 'lotes_protocolo.ver', TRUE),
      ('Administrador', 'lotes_protocolo.crear', TRUE),
      ('Administrador', 'lotes_protocolo.eliminar', TRUE),
      ('Administrador', 'lotes_protocolo.editar', TRUE),
      ('Administrador', 'actividades.ranking', TRUE),
      ('Administrador', 'actividades.verificar', TRUE),
      ('Administrador', 'stock.crear', TRUE),
      ('Administrador', 'stock.editar', TRUE),
      ('Administrador', 'productos.ver', TRUE),
      ('Administrador', 'productos.listar', TRUE),
      ('Administrador', 'productos.crear', TRUE),
      ('Administrador', 'productos.editar', TRUE),
      ('Administrador', 'productos.eliminar', TRUE),
      ('Administrador', 'stock.eliminar', TRUE),
      ('Administrador', 'productos.restaurar', TRUE),
      ('Administrador', 'stock.restaurar', TRUE),
      ('Administrador', 'rutas_pueblos.listar', TRUE),
      ('Administrador', 'rutas_pueblos.ver', TRUE),
      ('Administrador', 'rutas_pueblos.editar', TRUE),
      ('Administrador', 'rutas_pueblos.crear', TRUE),
      ('Administrador', 'rutas_pueblos.eliminar', TRUE),
      ('Administrador', 'condiciones_pago.editar', TRUE),
      ('Administrador', 'condiciones_pago.crear', TRUE),
      ('Administrador', 'prestamos_balon.ver', TRUE),
      (
        'Administrador',
        'prestamos_detalle.eliminar',
        TRUE
      ),
      ('Administrador', 'prestamos_balon.eliminar', TRUE),
      ('Administrador', 'prestamos_detalle.listar', TRUE),
      ('Administrador', 'prestamos_detalle.crear', TRUE),
      ('Administrador', 'prestamos_detalle.editar', TRUE),
      ('Administrador', 'prestamos_balon.crear', TRUE),
      ('Administrador', 'prestamos_balon.listar', TRUE),
      (
        'Administrador',
        'movimientos_recarga.editar',
        TRUE
      ),
      (
        'Administrador',
        'movimientos_recarga.listar',
        TRUE
      ),
      ('Administrador', 'prestamos_detalle.ver', TRUE),
      ('Administrador', 'prestamos_balon.editar', TRUE),
      ('Administrador', 'movimientos_recarga.ver', TRUE),
      ('Administrador', 'percepciones.crear', TRUE),
      ('Administrador', 'percepciones.listar', TRUE),
      ('Administrador', 'retenciones.crear', TRUE),
      ('Administrador', 'percepciones.eliminar', TRUE),
      ('Administrador', 'retenciones.editar', TRUE),
      ('Administrador', 'retenciones.emitir', TRUE),
      ('Administrador', 'percepciones.ver', TRUE),
      ('Administrador', 'percepciones.editar', TRUE),
      ('Administrador', 'retenciones.ver', TRUE),
      ('Administrador', 'retenciones.listar', TRUE),
      ('Administrador', 'retenciones.eliminar', TRUE),
      ('Administrador', 'percepciones.emitir', TRUE),
      ('Administrador', 'almacenes.editar', TRUE),
      ('Administrador', 'almacenes.crear', TRUE),
      ('Administrador', 'almacenes.eliminar', TRUE),
      ('Administrador', 'clientes.restaurar', TRUE),
      ('Administrador', 'movimientos.crear', TRUE),
      ('Administrador', 'movimientos.eliminar', TRUE),
      (
        'Administrador',
        'movimientos_recarga.crear',
        TRUE
      ),
      ('Administrador', 'documentos_salida.crear', TRUE),
      ('Administrador', 'documentos_salida.ver', TRUE),
      ('Gerencia', 'documentos_salida.listar', TRUE),
      ('Administrador', 'documentos_salida.editar', TRUE),
      ('Gerencia', 'documentos_salida.emitir', TRUE),
      ('Gerencia', 'documentos_salida.eliminar', TRUE),
      ('Administrador', 'documentos_salida.listar', TRUE),
      ('Gerencia', 'documentos_salida.crear', TRUE),
      ('Gerencia', 'documentos_salida.ver', TRUE),
      (
        'Administrador',
        'documentos_salida.eliminar',
        TRUE
      ),
      ('Gerencia', 'documentos_salida.editar', TRUE),
      ('Administrador', 'documentos_salida.emitir', TRUE),
      ('Administrador', 'empresas.editar', TRUE),
      ('Administrador', 'empresas.eliminar', TRUE),
      ('Administrador', 'empresas.crear', TRUE),
      ('Administrador', 'choferes.listar', TRUE),
      ('Administrador', 'choferes.crear', TRUE),
      ('Administrador', 'choferes.eliminar', TRUE),
      ('Administrador', 'vehiculos.crear', TRUE),
      ('Administrador', 'vehiculos.ver', TRUE),
      ('Administrador', 'vehiculos.editar', TRUE),
      ('Administrador', 'vehiculos.listar', TRUE),
      ('Administrador', 'choferes.ver', TRUE),
      ('Administrador', 'choferes.editar', TRUE),
      ('Administrador', 'vehiculos.eliminar', TRUE),
      ('Administrador', 'licencias.crear', TRUE),
      ('Administrador', 'licencias.listar', TRUE),
      ('Administrador', 'actividades.crear', TRUE),
      ('Administrador', 'contactos.crear', TRUE),
      ('Administrador', 'trabajador.ver', TRUE),
      ('Administrador', 'actividades.ver', TRUE),
      ('Administrador', 'direcciones.listar', TRUE),
      ('Administrador', 'actividades.listar', TRUE),
      (
        'Administrador',
        'documentos_vencimiento.ver',
        TRUE
      ),
      ('Administrador', 'contactos.ver', TRUE),
      ('Administrador', 'direcciones.editar', TRUE),
      ('Administrador', 'trabajador.listar', TRUE),
      ('Administrador', 'direcciones.ver', TRUE),
      (
        'Administrador',
        'documentos_vencimiento.editar',
        TRUE
      ),
      ('Administrador', 'actividades.eliminar', TRUE),
      ('Administrador', 'dashboard.ver_ventas', TRUE),
      ('Administrador', 'contactos.editar', TRUE),
      ('Administrador', 'activo.editar', TRUE),
      ('Administrador', 'contactos.eliminar', TRUE),
      ('Administrador', 'licencias.eliminar', TRUE),
      ('Administrador', 'licencias.editar', TRUE),
      ('Administrador', 'contactos.listar', TRUE),
      ('Administrador', 'actividades.editar', TRUE),
      ('Administrador', 'trabajador.editar', TRUE),
      ('Administrador', 'activo.listar', TRUE),
      (
        'Administrador',
        'inventario_movimientos.ver',
        TRUE
      ),
      ('Administrador', 'dashboard.ver_garantias', TRUE),
      ('Administrador', 'licencias.ver', TRUE),
      ('Administrador', 'trabajador.crear', TRUE),
      (
        'Administrador',
        'inventario_movimientos.listar',
        TRUE
      ),
      ('Administrador', 'activo.crear', TRUE),
      (
        'Administrador',
        'documentos_vencimiento.eliminar',
        TRUE
      ),
      ('Administrador', 'activo.eliminar', TRUE),
      ('Administrador', 'direcciones.eliminar', TRUE),
      ('Administrador', 'direcciones.crear', TRUE),
      (
        'Administrador',
        'documentos_vencimiento.listar',
        TRUE
      ),
      ('Administrador', 'dashboard.ver_productos', TRUE),
      ('Administrador', 'activo.ver', TRUE),
      (
        'Administrador',
        'documentos_vencimiento.crear',
        TRUE
      ),
      ('Administrador', 'trabajador.eliminar', TRUE),
      (
        'Administrador',
        'inventario_movimientos.crear',
        TRUE
      ),
      ('Administrador', 'catalogos.editar', TRUE)
  ) AS v (rol, permiso, estado)
  JOIN LATERAL (
    SELECT
      id
    FROM
      auth_roles
    WHERE
      nombre = v.rol
    ORDER BY
      id
    LIMIT
      1
  ) r ON TRUE
  JOIN LATERAL (
    SELECT
      id
    FROM
      auth_permisos
    WHERE
      nombre = v.permiso
    ORDER BY
      id
    LIMIT
      1
  ) p ON TRUE
WHERE
  NOT EXISTS (
    SELECT
      1
    FROM
      auth_roles_permisos rp
    WHERE
      rp.id_rol = r.id
      AND rp.id_permiso = p.id
  );
