# Revisión de permisos y gastos — 17/10/2026

Revisión sobre la copia completa `sarita_vsd_20261017` del contenedor
`gvr-postgres-local`. No se usó `.env`, no se inició AppModule y no se modificó
producción. No requiere migración ni ampliar permisos de usuarios.

## Hallazgos y corrección

- `cruiz` (id 3) está activa y tiene `caja.ver` y `caja.registrar_gasto`.
  El API acepta registrar gastos con esos permisos cuando hay caja abierta.
- El formulario de Gastos y Compras → Gastos de caja no enviaba sucursal ni
  sesión. Buscaba una caja general (`id_sucursal IS NULL`), aunque la caja
  abierta perteneciera a una sucursal. Se reprodujo el rechazo HTTP 400.
- El formulario ahora consulta las cajas abiertas de la fecha con `caja.ver`,
  permite seleccionar la caja y envía su sesión y sucursal. Selecciona
  automáticamente solo si hay una opción. Con varias, requiere elección.
  Bloquea el envío durante carga, ante error, sin caja o con selección obsoleta.
  En edición y en Caja del día conserva el contexto existente.
- Se agregó `catalogos.editar` al catálogo de permisos de la interfaz y se
  alinearon los botones de crear opciones de catálogo con el permiso del API
  en gastos, compras, productos, tipos de balón, cilindros, inventario,
  vencimientos, trabajadores y activos. Registrar una operación no concede
  permiso para modificar sus catálogos.

El rol Administrador de esta copia no tiene `caja.abrir` ni `caja.cerrar`.
Eso es configuración de permisos, no una excepción del guard. No se le otorgó
`auth.todo` ni permisos adicionales. Una persona autorizada debe abrir la caja
del día y cerrar la anterior cuando corresponda. La última caja de la copia,
del 16/10, estaba abierta; ese bloqueo de negocio se mantiene.

## Pruebas reproducibles

Desde `api-sistema-sarita`, con el backend compilado:

```powershell
node test/permisos-local.js
```

El script fija contenedor y base locales; no lee credenciales de producción.
Usa Nest, controller, DTO, lógica, modelo, JwtAuthGuard, JwtStrategy,
PermisosGuard y funciones PostgreSQL reales. Genera un JWT exclusivo de prueba
y sesiones temporales dentro de transacciones con ROLLBACK. Usa una secuencia
temporal para gastos y no avanza las secuencias existentes.

Resultados:

- 288 banderas del backend: 864 comprobaciones del guard (sin permiso,
  permiso explícito y `auth.todo`). Las 283 operativas existen y están activas
  en la copia; las cinco de `ejemplos.*` pertenecen al módulo de ejemplo, sin
  interfaz ni registro en AppModule.
- Referencias a banderas reconocidas en 57 archivos de controllers.
  Los catálogos frontend/backend coinciden en sus permisos compartidos;
  `configuracion.ver` agrupa navegación y licencias no tiene módulo de UI.
- 16 comprobaciones HTTP: registro con permisos efectivos de `cruiz`, consulta
  de cajas, reproducción del fallo original, monto/cuenta inválidos, falta de
  autenticación, JWT inválido, permisos/roles/asignaciones inactivos, revocación
  de sesión, usuario inactivo, discordancia JWT/sesión y caja cerrada/anterior.
- 99 tablas públicas con idénticos conteos y hashes antes/después, incluyendo
  stock, balones, documentos, finanzas, roles y usuarios. Las 92 secuencias
  públicas también permanecen iguales.

Desde `admin-sistema-sarita`:

```powershell
npm run test:unit -- src/modules/caja/composables/useSesionGasto.spec.ts src/shared/constants/permissions.spec.ts
npm run build
```

288 pruebas frontend: matriz de permisos, separación entre registrar gastos,
editar catálogos y abrir/cerrar caja, selección de sucursal y estados de carga,
error, caja cerrada, fecha anterior y cambio de fecha. Build verificado.

Evidencia local en `../outputs/permisos/resultado.json`, `integridad.json` y
`frontend-build.log`. La matriz verifica el mecanismo común de autorización;
no equivale a recorrer manualmente todas las pantallas ni todas las posibles
reglas de negocio. El fallo reproducido queda corregido en código local y
pendiente de publicación.
