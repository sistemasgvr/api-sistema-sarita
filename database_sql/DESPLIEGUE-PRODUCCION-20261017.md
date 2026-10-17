# Migración aplicada a producción

Confirmada y verificada el 17/10/2026 a las 11:27 de Lima (16:27 UTC).
Solo se aplicaron cambios de base de datos autorizados; API e interfaz
quedan pendientes de publicación manual por el usuario.

Se aplicó el contenido de la migración final
`migraciones/20261017_cpe_edicion_segura_pre_emision.sql`, que ya contiene
íntegramente las funciones y estructura de la migración VSD anterior. Se usó
una única transacción con comprobaciones adicionales de integridad, bloqueo
temporal de escrituras en tablas públicas y límites de espera. El esquema
vigente se comparó previamente con el respaldo ensayado.

Cambios confirmados:

- Funciones de corrección, cambio de balón y validación antes de emisión,
  incluyendo sus protecciones de reversión, creación y eliminación.
- Tabla `ven_vsd_operacion`, su secuencia e índice, inicialmente vacía.
- Única fila técnica `CAMBIO_VSD` en el catálogo de referencias, expresamente
  autorizada por el usuario. No se ejecutaron seeds de roles ni permisos.

Dentro de la transacción, antes de COMMIT, se compararon los conteos y hashes
de las 137 tablas originales de todos los esquemas. Coincidieron, excluyendo
solamente la nueva fila técnica autorizada. También se verificó que ninguna
secuencia existente ajena al catálogo autorizado cambiara. La tabla de
historial quedó con cero filas.

Tras COMMIT se consultó producción en modo de solo lectura: las definiciones
de funciones y columnas coinciden exactamente con el ensayo local. Se
confirmaron la tabla nueva y la única configuración `CAMBIO_VSD` activa.
No se ejecutaron ventas, cambios físicos ni gastos de prueba en producción.

Respaldo actualizado, completado antes de la migración:
`../outputs/ventas-seguras/production-20261017162330.dump`.
Su ruta, tamaño y SHA-256 quedaron registrados en
`../outputs/despliegue-estructura/backup.json`.

Evidencia:

- `../outputs/despliegue-estructura/aplicar-estructura.sql`: SQL exacto ensayado y aplicado.
- `../outputs/despliegue-estructura/production-committed.json`: confirmación de COMMIT e integridad.
- `../outputs/despliegue-estructura/production-verified.json`: verificación posterior.
- `../outputs/despliegue-estructura/funciones-aplicadas.json`: definiciones nuevas o modificadas.

El código del API y la interfaz debe publicarse de forma coordinada para usar
los nuevos campos de motivo/versión y las nuevas opciones del formulario.
No se desplegó código ni se reiniciaron servicios de aplicación.
