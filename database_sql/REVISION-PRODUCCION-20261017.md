# Revisión final para publicación — 17/10/2026

Resultado: favorable para un despliegue coordinado de base de datos, API e
interfaz. No se ha ejecutado ningún cambio en producción.

## Ensayo independiente desde el respaldo original

Se creó `sarita_release_review_20261017` en `gvr-postgres-local` y se restauró
el respaldo completo original de las 09:49 de Lima. Se aplicaron los archivos
exactos, sin regenerarlos, en este orden:

1. `migraciones/20261017_vsd_correccion_cambio_seguro.sql`
2. `migraciones/20261017_cpe_edicion_segura_pre_emision.sql`

Ambos terminaron correctamente con `ON_ERROR_STOP`. Después de cada migración,
las 137 tablas originales de todos los esquemas conservaron sus conteos y
hashes. El único dato de catálogo añadido fue `CAMBIO_VSD`; la nueva tabla de
historial comenzó vacía. Las 143 comprobaciones SQL pasaron en esta restauración
nueva. Reaplicar la migración final tampoco alteró datos ni duplicó el catálogo.

El SHA-256 del respaldo coincide con el registrado al crearlo. Se revisó su
inventario de privilegios: no contiene ACL especiales de las funciones de
ventas reemplazadas ni privilegios por defecto del esquema public.

Evidencia en `../outputs/revision-produccion/resultado.json`, `integridad.json`
y `sql-tests.log`. Reproductor: `test/migraciones-release-local.js`, fijado a
esa base Docker. No lee `.env` ni conexiones de producción.

Las verificaciones previas de API, concurrencia, interfaz y permisos siguen
documentadas en `README-vsd-seguro.md` y `README-permisos-local.md`.

## Publicación

1. Obtener un respaldo nuevo inmediatamente antes del despliegue y confirmar
   que no hubo cambios de esquema posteriores al respaldo ensayado.
2. Suspender temporalmente escrituras y emisión de comprobantes; esperar a que
   finalicen las solicitudes en curso. La firma de edición y sus validaciones
   cambian, por lo que la actualización exige coordinar las tres capas.
3. Aplicar ambos SQL en el orden indicado, deteniéndose ante cualquier error.
   Cada archivo delimita su propia transacción. No ejecutar seeds generales,
   sincronizaciones completas ni scripts que sobrescriban roles o datos.
4. Publicar el API y la interfaz de esta implementación. La corrección de
   gastos y los botones de permisos son cambios de interfaz: no necesitan
   modificar roles ni ejecutar una migración adicional.
5. Comprobar inicio de sesión, permisos de `cruiz`, consulta de cajas, registro
   de gastos y edición de un documento permitido. Confirmar que un documento
   emitido continúa bloqueado. Reanudar las operaciones tras estas comprobaciones.

Ante un fallo de despliegue, mantener suspendidas las escrituras y resolverlo
antes de habilitar usuarios. Si ya se registraron cambios físicos mediante el
flujo nuevo, conservar el historial y evitar volver a una versión anterior que
desconozca esos movimientos. No restaurar un respaldo antiguo sobre operaciones
nuevas como mecanismo automático de reversión.

## Alcance confirmado

Se permiten correcciones y reemplazos equivalentes dentro de las validaciones
documentadas. Cambios por otro producto/capacidad, diferencias de precio y
reembolsos permanecen bloqueados en este flujo. Las anulaciones o conversiones
de documentos con cambios físicos requieren conciliación comercial.

`cruiz` puede registrar gastos, pero no tiene permisos de abrir/cerrar caja en
el respaldo examinado. Una caja cerrada, de fecha anterior o no abierta sigue
bloqueando el registro. No se ampliaron sus permisos.

La revisión acredita el comportamiento y la migración sobre el respaldo
examinado; no incluye una emisión real a SUNAT ni una revisión visual completa
de todas las pantallas. La comprobación final del esquema y respaldo vigentes
corresponde al momento de ejecutar el despliegue.
