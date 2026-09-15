# Empresa emisora de las guías

## Despliegue

Aplicar `database_sql/migraciones/20260915_empresa_emisora_gre.sql` antes de publicar el backend y el frontend de este cambio. La migración añade `doc_salida.id_empresa` y actualiza las funciones de creación, consulta y conversión. Se ejecuta dentro de una transacción y no asigna empresas a documentos históricos.

Desde la carpeta del backend, con la conexión del entorno de destino configurada:

```sh
node database_sql/scripts/apply-migration.js database_sql/migraciones/20260915_empresa_emisora_gre.sql
```

Cada emisor debe tener su configuración SUNAT/PSE activa y sus credenciales completas. Las guías no completan secretos faltantes con los de otra empresa ni con variables globales. Si se utiliza el mismo proveedor para varias empresas, registrar explícitamente sus credenciales en cada configuración.

Una guía histórica con ticket o emisión previa y sin empresa vinculada requiere verificar y vincular su emisor real mediante una migración de datos revisada. No se debe asignar la empresa activa masivamente. Las órdenes antiguas sin guía pueden imprimir su PDF usando la empresa seleccionada explícitamente; las guías siempre exigen el emisor vinculado.

## Corrección de firmas y series

Si ya se aplicó la migración inicial, aplicar `database_sql/migraciones/20260915_fix_gre_firmas_y_series.sql`. Unifica las variantes de `doc_convertir_a_gre` cuyo parámetro 18 era `integer` o `json`, conservando empresa emisora, `gre_extra` y las reglas de transporte; instala también `doc_listar_series_gre`. No convierte documentos ni envía guías a SUNAT.

## Pruebas

En una base PostgreSQL temporal vacía, ejecutar en este orden:

1. `test/sql/empresa-emisora-schema.sql` (fixture mínimo; no usar en bases del sistema).
2. `database_sql/migraciones/20260915_empresa_emisora_gre.sql`.
3. `test/sql/empresa-emisora-gre.sql` (comprueba la vinculación, empresas inactivas y protección del emisor; revierte sus datos al terminar).

Pruebas de credenciales y selección en el PSE:

```sh
npm test -- --runInBand facturacion-credentials.service.spec.ts facturacion-apisperu.client.spec.ts
```

En el frontend, iniciar Vite en el puerto 5179 y ejecutar `node test/empresa-persistencia.cjs`. La prueba intercepta las llamadas de API y utiliza exclusivamente empresas y un usuario simulados.
