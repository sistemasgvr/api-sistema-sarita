-- Permisos del módulo Documentos de salida (Fase 2 — doc_salida unificado).
-- Reemplaza guias_remision.* y la parte de recarga-planta de movimientos_recarga.*
-- (que sigue existiendo para el módulo separado de movimientos por cilindro).

INSERT INTO auth_permisos (nombre, descripcion)
SELECT v.nombre, v.descripcion
FROM (
    VALUES
        ('documentos_salida.listar', 'Listar documentos de salida (órdenes, recargas planta, guías)'),
        ('documentos_salida.ver', 'Ver detalle de un documento de salida'),
        ('documentos_salida.crear', 'Crear documentos de salida y agregar/quitar líneas'),
        ('documentos_salida.editar', 'Generar, editar detalle y registrar retorno de un documento de salida'),
        ('documentos_salida.eliminar', 'Anular un documento de salida'),
        ('documentos_salida.emitir', 'Convertir a guía de remisión y emitir/consultar estado SUNAT')
) AS v(nombre, descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre
);

INSERT INTO auth_roles_permisos (id_rol, id_permiso)
SELECT r.id, p.id
FROM auth_roles r
CROSS JOIN auth_permisos p
WHERE r.nombre = 'Administrador'
  AND p.estado = TRUE
  AND p.nombre LIKE 'documentos_salida.%'
  AND NOT EXISTS (
      SELECT 1
      FROM auth_roles_permisos rp
      WHERE rp.id_rol = r.id AND rp.id_permiso = p.id
  );
