# database_sql

Esquema de la base (Supabase / PostgreSQL) como fuente de verdad del repo.

## Estructura

```
database_sql/
  tablas/<modulo>/<tabla>.sql        DDL de pg_dump --schema-only (tabla, secuencias, índices, constraints, FKs, triggers)
  funciones/<modulo>/<nombre>.sql    todas las firmas de una función: descripción + DROP exacto + CREATE
  seeds/<modulo>/listas.sql          gen_lista / gen_lista_opciones del módulo
  seeds/<modulo>/permisos.sql        auth_permisos del módulo
  seeds/<modulo>/datos-base.sql      datos base (general, finanzas, clientes, auth)
  migraciones/sync-prod-desde-dev.sql  lo elegido de DEV que le falta a PROD
  migraciones/sync-dev-desde-prod.sql  lo elegido de PROD que le falta a DEV
  scripts/                           generadores, verificación y reconstrucción
  .cache/                            local, NO se versiona (ver abajo)
```

Módulo = prefijo del nombre del objeto (`scripts/lib/modulos.js`):

| Módulo | Prefijos | Módulo | Prefijos |
|---|---|---|---|
| general | `gen_` y desconocidos | finanzas | `fin_` |
| auth | `auth_` | personal | `tra_` |
| productos | `pro_` | actividades | `age_` |
| inventario | `inv_` | activos | `act_` |
| clientes | `cli_` | documentos-salida | `doc_`, `gre_` |
| balones | `bal_` | ventas | `ven_` |
| compras | `com_` | dashboard | `dash_` |

Orden de módulos al aplicar: general, auth, productos, inventario, clientes, balones, compras,
finanzas, personal, actividades, activos, documentos-salida, ventas, dashboard.

## Regla de versión (funciones)

`scripts/lib/version.js`, por nombre de función (conjunto de firmas, cuerpos sin comentarios ni espacios):

- Solo existe en una base → esa base.
- En DEV y PROD e iguales → `ambas`.
- Difieren y la regeneración anterior la dejó como `ambas` (línea base, ver abajo) → la base que
  cambió desde entonces: solo DEV → `dev`; solo PROD → `prod`; las dos → `pendiente`.
- Difieren sin línea base → si algún cuerpo del repo coincide con DEV → `dev`; si coincide con
  PROD → `prod`; si no coincide con ninguna → `pendiente` (se deja el texto del repo y se documenta
  en `.cache/reporte-funciones.md` con los diffs contra DEV y PROD).
- Las firmas de la otra base que no están en la elegida quedan como obsoletas (`DROP` en los sync).

**Línea base:** `regenerar-funciones.js` lee el `.cache/decisiones-funciones.json` anterior (si
existe) como el último cuerpo conocido de cada función. Así, si una función estaba en `ambas` y se
editó directamente en DEV, la siguiente regeneración la marca `dev` (no la revierte a PROD aunque
el repo coincida con PROD). La consola indica qué funciones se decidieron por la línea base. Si se
borra ese archivo se vuelve a la regla de coincidencia con el repo.

**Flujo para cambiar una función: 1) editar primero el archivo de `funciones/<modulo>/` en el repo,
2) aplicarlo en DEV, 3) refrescar `catalogo.js --env dev` y regenerar.** Editar solo en la base sin
tocar el repo funciona gracias a la línea base, pero si además PROD cambió desde la última
regeneración la función queda `pendiente`.

Tablas: DDL de la base donde existe; si existe en ambas y difiere, se escribe PROD y se anota en
`.cache/reporte-tablas.md`. Seeds: siempre desde PROD. Las tablas **no** usan línea base: un cambio
hecho solo en DEV a una tabla que existe en ambas bases se sobrescribe con el DDL de PROD al
regenerar (queda anotado en `reporte-tablas.md` como DEV ≠ PROD); publicar los cambios de tablas
con una migración/sync antes de regenerar o revisar ese reporte.

## Actualizar el repo desde las bases

Todo es de **solo lectura** sobre las bases (`scripts/lib/conexion.js`: sesión READ ONLY; la URL
nunca se imprime). URL: `DATABASE_URL_DEV` / `DATABASE_URL_PROD` en `.env`, o la línea
`DATABASE_URL=` (comentada o no) que contenga el ref del proyecto.

```sh
node database_sql/scripts/catalogo.js --env dev     # → .cache/catalogo-dev.json
node database_sql/scripts/catalogo.js --env prod    # → .cache/catalogo-prod.json
node database_sql/scripts/regenerar-funciones.js    # funciones/ + reporte-funciones.md + decisiones-funciones.json
node database_sql/scripts/regenerar-tablas.js       # tablas/ + reporte-tablas.md
node database_sql/scripts/regenerar-seeds.js        # seeds/ (desde PROD)
node database_sql/scripts/generar-sync.js           # migraciones/sync-*.sql
```

Los `regenerar-*` aceptan `--dry-run` (solo resumen, no escriben) y siempre necesitan **las dos**
cachés, porque la regla de versión compara DEV, PROD y repo.

Atajos: `sync-functions.js` / `sync-tables.js` hacen `catalogo.js --env <env>` + el `regenerar-*`
correspondiente:

```sh
node database_sql/scripts/sync-functions.js --env dev            # refresca DEV y regenera funciones/
node database_sql/scripts/sync-tables.js --env prod --dry-run     # refresca PROD, solo resumen
node database_sql/scripts/sync-functions.js --env ambos           # refresca DEV y PROD
node database_sql/scripts/sync-tables.js --sin-catalogo           # solo regenera desde las cachés
```

Revisar siempre `git diff` y los reportes de `.cache/` antes de commitear.

## Verificar cobertura

```sh
node database_sql/scripts/verify-functions-coverage.js --env dev    # y --env prod
node database_sql/scripts/verify-tables-coverage.js --env dev       # y --env prod
```

Listan lo que falta en el repo, lo que sobra respecto de esa base y archivos fuera de su módulo.
Salen con código 1 si falta algo. Que haya sobrantes es normal (objetos que solo están en la otra base).

## Levantar una base desde cero

`scripts/rebuild-schema-from-repo.js` usa `DATABASE_URL` (variable de entorno o línea activa de
`.env`). **Es destructivo**: comprobar a qué base apunta antes de ejecutarlo. Antes de actuar imprime
el host y el nombre de la base de destino (nunca la URL).

Guardas:

- `--functions` y `--full` se **niegan** (antes de conectar) si el host termina en `supabase.com` /
  `supabase.co` o la URL contiene el ref de DEV (`adhxtqjxklnujajdunin`) o PROD
  (`ebotjjfdgcuwrfoappsa`), salvo que se pase `--permitir-remoto`.
- `--full` exige `--wipe`, y `--full --wipe` exige `CONFIRM_REBUILD=<nombre exacto de la base de destino>`
  (también en `--dry-run`, que solo interpreta la URL y no se conecta).

```sh
# Ver el orden sin conectarse a ninguna base (la base local se llama, p. ej., sarita_local):
CONFIRM_REBUILD=sarita_local node database_sql/scripts/rebuild-schema-from-repo.js --full --wipe --dry-run

# Esquema desde 0 (DROP SCHEMA public CASCADE):
CONFIRM_REBUILD=sarita_local node database_sql/scripts/rebuild-schema-from-repo.js --full --wipe

# Reaplicar todas las funciones del repo (sin transacción):
node database_sql/scripts/rebuild-schema-from-repo.js --functions
```

`--functions` **solo es para una base reconstruida desde este repo**. No usarlo en DEV ni PROD vivos:
el repo mezcla versiones `dev` y `prod` (y `pendiente`), así que dejaría cada base con funciones de la
otra, y sin transacción un fallo a mitad deja la base a medias. Para publicar usar `migraciones/`.

Orden con `--full --wipe`:

1. Tablas, fase A: cada archivo de `tablas/` sin sus FKs ni triggers.
2. Tablas, fase B: todas las `ALTER TABLE … ADD CONSTRAINT … FOREIGN KEY` (los ciclos de FK no importan).
3. Funciones (`check_function_bodies = off`).
4. Triggers de las tablas.
5. Seeds: todos los `listas.sql` → todos los `permisos.sql` → `datos-base.sql` en el orden
   general, finanzas, clientes, (otros), **auth al final** (asigna permisos de todos los módulos).

## Publicar cambios en las bases

`migraciones/` solo contiene los dos scripts generados por `generar-sync.js` (una transacción cada
uno, idempotentes). Nadie los ejecuta automáticamente.

1. Revisar el script y **respaldar** la base de destino:
   - Supabase: Dashboard → Database → Backups (comprobar que hay un backup reciente o crear uno), o
   - `pg_dump` con PostgreSQL 18 (la versión del servidor; un `pg_dump` más viejo falla):
     ```powershell
     & "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe" --dbname "<url de la base>" -Fc -f respaldo-AAAAMMDD.dump
     ```
     (la URL sale de `.env`; no pegarla en documentos ni en el historial compartido).
2. Aplicar `sync-dev-desde-prod.sql` a **DEV** y/o `sync-prod-desde-dev.sql` a **PROD**.
3. Confirmar: `catalogo.js --env dev`, `catalogo.js --env prod`, `regenerar-funciones.js`,
   `regenerar-tablas.js` y `generar-sync.js`; las diferencias publicadas deben desaparecer.

**`sync-prod-desde-dev.sql` incluye las funciones de caja** (`fin_caja_*`: bitácora de sesión,
conversión VSD, etc.) que la API y el admin nuevos esperan. Publicarlo en PROD **junto con** el
despliegue de los cambios correspondientes de la API y del admin: ni antes (el código desplegado
llamaría firmas que ya no existen) ni mucho después (el código nuevo fallaría contra las funciones viejas).

Las funciones `pendiente` no se incluyen en ningún sync: resolverlas a mano según
`.cache/reporte-funciones.md`.

## Formato

```sh
npm run format:sql         # formatea funciones/, tablas/, seeds/ (solo si el resultado es equivalente)
npm run test:db-scripts    # pruebas de scripts/lib
```

## `.cache/` (nunca commitear)

Está en `.gitignore`. Contiene datos reales de las bases y los reportes:

- `catalogo-dev.json`, `catalogo-prod.json`: definiciones y filas de catálogo de cada base.
- `decisiones-funciones.json`, `reporte-funciones.md`, `reporte-tablas.md`.
- `repo-drift*/`: textos del repo que no coincidían con ninguna base al regenerar. Los `regenerar-*`
  solo reemplazan su carpeta cuando hay drift nuevo; si no, la dejan como está.
- `limpieza-2026-10-27/`: evidencia **congelada** de la limpieza del 2026-10-27 (repo-drift*,
  reportes y decisiones de ese momento). Ningún script la toca; no borrarla ni modificarla. Los
  archivos originales de `database_sql/` anteriores a la limpieza están en git, en el commit `c07be19`
  (`git show c07be19:database_sql/<ruta>`).

## Otros

- `scripts/vsd-local.js test <archivo.sql>` / `snapshot`: pruebas de `test/sql/` contra la copia
  local en Docker (`gvr-postgres-local`); nunca lee `.env`.
- `scripts/apply-migration.js`: aplica un archivo a la base de `DATABASE_URL` de `.env` (puede ser
  PRODUCCIÓN). Se conserva solo porque lo cita `test/sql/README-empresa-emisora.md`; no usarlo para publicar.
- Documentos históricos de despliegues: `docs/database/`.
