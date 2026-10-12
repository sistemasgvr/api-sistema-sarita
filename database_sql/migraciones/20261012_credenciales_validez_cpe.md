# Configuración independiente de GRE y validez CPE

Aplicar `20261012_credenciales_validez_cpe.sql` antes de desplegar la API y el frontend. La migración agrega dos columnas opcionales y actualiza las funciones de lectura. No reemplaza los campos de GRE ni modifica comprobantes.

En Configuración → SUNAT se mantienen los campos Client ID GRE / Client Secret GRE existentes. La nueva sección «Validez de comprobantes (API SUNAT)» permite ingresar el ID y la clave de la aplicación registrada en Consulta de Validez de Comprobantes de Pago de SUNAT SOL.

La API de configuración recibe `validezClientId` y `validezClientSecret`. Guarda estos campos en `validez_client_id` y `validez_client_secret`, por empresa y en la misma transacción que el resto de la configuración. Los campos vacíos u omitidos conservan los valores existentes. Las lecturas devuelven el ID y el indicador `tiene_validez_client_secret`; nunca devuelven la nueva clave. Las credenciales de validez no se envían a la sincronización GRE ni al proveedor de emisión.

Las credenciales de la captura se deben ingresar en el formulario después del despliegue. No se incluyen valores reales en la migración o en el código fuente. Esta implementación agrega su configuración y almacenamiento; no incorpora todavía la consulta integrada de validez de comprobantes ni confirma el acceso a SUNAT.

Validación local: cinco pruebas del modelo de guardado, compilación TypeScript de producción de la API y build Vite del frontend correctos. La comprobación global `vue-tsc -b` está bloqueada por errores de tipos en `src/shared/components/form/AppDropzone.vue`, fuera de este cambio.

Migración aplicada a producción el 12/10/2026 a las 10:20 (America/Lima), por autorización del usuario. Se verificaron las dos columnas y las lecturas de detalle/listado antes de confirmar la transacción. Los 68 comprobantes y todos los valores previos de configuración permanecieron intactos. El proveedor sigue siendo APIS PERU y su URL no cambió. Evidencia: `diagnosticos/migracion-validez-produccion-20261012.json` en la raíz del workspace. Las credenciales de validez siguen sin cargarse y la API/frontend locales aún no se han desplegado.
