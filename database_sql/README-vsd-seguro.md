La implementación separa la corrección de datos, la corrección de un balón reservado y el cambio físico después de la entrega. Se aplica a ventas sin documento y también a facturas y boletas antes de emitir a SUNAT. Las migraciones son `migraciones/20261017_vsd_correccion_cambio_seguro.sql` y `migraciones/20261017_cpe_edicion_segura_pre_emision.sql`. Están aplicadas exclusivamente a la copia local `sarita_vsd_20261017`, en `gvr-postgres-local` (PostgreSQL 17, puerto 5434). El archivo `.env` original no se modifica.

El respaldo completo se obtuvo con `pg_dump` en modo de solo lectura y se restauró con éxito, incluidos los esquemas de Supabase. El archivo de respaldo y los resultados están en `../outputs/ventas-seguras`, desde la raíz del API. No se versionan los datos de producción.

Para repetir las pruebas, desde la raíz del API:

```powershell
node database_sql/scripts/vsd-local.js apply
node database_sql/scripts/vsd-local.js apply-cpe
node database_sql/scripts/vsd-local.js test test/sql/vsd-correccion-cambio-seguro.sql
npm run build
node test/vsd-http-local.js
node test/vsd-concurrency-local.js
```

Estos ejecutores fijan el nombre de la base y el contenedor locales. No leen la conexión de producción del `.env`. Las pruebas SQL y HTTP ejecutan sus mutaciones dentro de transacciones con rollback. La prueba de concurrencia realiza una actualización sin cambio de valores para renovar la versión interna de una fila y comprobar el bloqueo entre sesiones. Las secuencias pueden avanzar durante las pruebas, como sucede normalmente con un rollback de PostgreSQL.

Las pruebas HTTP instancian el controlador, validación, lógica, modelo y SQL reales, con un usuario de prueba interno. No arrancan AppModule, tareas programadas ni integraciones externas. Verifican el contrato de los endpoints y que el usuario de auditoría se toma del contexto autenticado; no sustituyen una prueba del inicio de sesión ni una revisión visual de la interfaz.

La corrección de datos exige motivo y versión vigente. Los detalles vinculados conservan sus identificadores, balón, unidad, capacidad y referencias; no se eliminan y recrean. Cambiar cantidades de productos sin dependencias ajusta únicamente la diferencia de stock. Con balones, recargas, préstamos u órdenes vinculadas, se bloquean los cambios físicos desde esa corrección. Las garantías y cuentas con pagos tienen restricciones adicionales. Cada corrección conserva un snapshot anterior y posterior.

La factura o boleta debe seguir pendiente y sin evidencia de envío. Un rechazo definitivo registrado permite corregir antes de reemitir. Se bloquean aceptaciones, bajas, aceptación verificada, envíos en curso o por confirmar y boletas incluidas en un resumen diario pendiente/aceptado. La fecha prevista de emisión, por sí sola, no cuenta como un envío: una regularización puede asignarla antes de emitir. Ambas rutas de mutación toman la misma llave de bloqueo que la emisión para impedir una carrera entre corregir y enviar. La interfaz usa la misma condición que valida la base de datos.

Cuando se sustituye físicamente un balón de una factura o boleta todavía no emitida, el detalle conserva su id y pasa a señalar el balón que se entregará e imprimirá. La selección anterior queda en el snapshot del historial. Después de emitir, se impiden nuevas correcciones. Las bajas automáticas, notas de crédito y reversiones antiguas quedan bloqueadas si hubo un cambio físico, hasta conciliar la devolución comercial; el bloqueo de baja ocurre antes de solicitarla a SUNAT.

La corrección de reserva requiere un balón en PENDIENTE_ENVIO y ningún despacho vigente. Libera el anterior, reserva otro compatible, actualiza el detalle que leerá el despacho y deja el stock de gas intacto. El snapshot conserva la selección anterior.

El cambio físico requiere que el balón esté en poder del cliente de la venta y que el reemplazo esté disponible en el almacén indicado. Se valida gas, tipo, propiedad, producto activo, PH, préstamos, bajas, mantenimiento, actividades y documentos derivados. Se ingresa únicamente el gas utilizable medido que realmente regresa y se descuenta el gas del reemplazo. Un retorno para mantenimiento no repone gas. El préstamo mantiene su contrato, registra el balón devuelto y añade el nuevo; la garantía y el recojo pendiente se vinculan al reemplazo. Una solicitud UUID evita duplicados por reintentos.

Todos los movimientos y sus snapshots se guardan en una única transacción. Un fallo posterior a una devolución o ingreso de gas aborta la operación completa. Los bloqueos de venta, balones y stock y la versión interna de la venta protegen las operaciones concurrentes.

El alcance implementado conserva producto, tipo/capacidad y propietario en un reemplazo físico. No tramita un cambio comercial por otro producto o capacidad, diferencias de precio ni reembolsos. Esos casos requieren una devolución comercial y una nueva venta y se rechazan en este flujo. También se bloquea eliminar o generar un documento derivado de una venta con un cambio físico, porque los flujos antiguos de anulación/conversión no contemplan esa devolución y podrían restaurar inventario incorrectamente. Las ventas ya convertidas se gestionan desde su documento vigente.

Validación ampliada sobre el respaldo del 17 de octubre de 2026: 143 comprobaciones SQL (incluidas las verificaciones de rollback), 21 comprobaciones HTTP y tres pruebas de concurrencia/bloqueo entre sesiones. Además, pasaron 42 tests del API y 28 del módulo de ventas del frontend, y compilaron ambos proyectos. Los conteos y hashes de las 11 tablas de negocio verificadas coincidieron antes y después de las pruebas. La copia conserva 133 ventas, 202 detalles, 676 balones, 69 filas de stock y 387 movimientos de inventario. La base completa restaurada contiene 137 tablas antes de añadir la tabla nueva de historial.
