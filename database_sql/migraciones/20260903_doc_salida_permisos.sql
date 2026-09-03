-- Fase 2 — permisos del módulo unificado documentos_salida.*, y retiro de
-- guias_remision.* (el módulo NestJS guias-remision se eliminó: ver
-- database_sql/seeds/doc_permisos_banderas.sql). No se toca
-- movimientos_recarga.* — lo sigue usando el módulo separado de
-- movimientos por cilindro (movimientos-recarga), fuera de este alcance.

-- ===== database_sql/seeds/doc_permisos_banderas.sql =====
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

-- Retiro de guias_remision.* — el módulo NestJS ya no existe (llamaba a
-- funciones gre_* que se eliminaron con la unificación a doc_salida).
DELETE FROM auth_roles_permisos
WHERE id_permiso IN (SELECT id FROM auth_permisos WHERE nombre LIKE 'guias_remision.%');

DELETE FROM auth_permisos WHERE nombre LIKE 'guias_remision.%';
