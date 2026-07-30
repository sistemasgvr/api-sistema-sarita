# Jobs de notificaciones (manual / hosting)

Los jobs de detección también corren **dentro del API** con cron Nest (`08:00 America/Lima`).  
Si en tu hosting el proceso se reinicia, duerme, o quieres control externo (Coolify / cron del servidor), usa estos endpoints HTTP.

## Requisitos

| Ítem | Valor |
|---|---|
| Método | `POST` |
| Auth | Token de entorno `NOTIFICACIONES_JOBS_TOKEN` (no caduca) |
| Header | `X-Notificaciones-Jobs-Token: <token>` **o** `Authorization: Bearer <token>` |
| Base URL | URL pública del API, ej. `https://api.tudominio.com` |

Configura la variable en el `.env` del API (y en Coolify / hosting):

```env
NOTIFICACIONES_JOBS_TOKEN=un_secreto_largo_y_aleatorio
```

Genera un valor fuerte, por ejemplo:

```bash
openssl rand -hex 32
```

> No uses el JWT de un usuario: ese token **expira**. Este token de jobs es estático y pensado solo para cron/hosting.

---

## Endpoints

| Job | Endpoint | Qué hace |
|---|---|---|
| Alquileres vencidos | `POST /notificaciones/jobs/alquileres-vencidos` | Alquileres ACTIVOS ya vencidos |
| Alquileres por vencer | `POST /notificaciones/jobs/alquileres-por-vencer` | Vencen en 3–7 días |
| Préstamos vencidos | `POST /notificaciones/jobs/prestamos-vencidos` | Detalles de préstamo vencidos |
| Préstamos por vencer | `POST /notificaciones/jobs/prestamos-por-vencer` | Vencen en 3–7 días |
| Stock bajo / cero | `POST /notificaciones/jobs/stock-bajo` | Productos con `afecta_stock` bajo mínimo o en 0 |
| Documentos por vencer | `POST /notificaciones/jobs/documentos-por-vencer` | SOAT/inspección/etc. en 3–7 días |
| Documentos vencidos | `POST /notificaciones/jobs/documentos-vencidos` | Documentos ya vencidos |
| Licencias por vencer | `POST /notificaciones/jobs/licencias-por-vencer` | Licencias de chofer en 3–7 días |
| Licencias vencidas | `POST /notificaciones/jobs/licencias-vencidas` | Licencias ya vencidas |
| Comprobantes pendientes SUNAT | `POST /notificaciones/jobs/comprobantes-pendientes-sunat` | Ticket en `PENDIENTE` ≥1 día |
| Guías pendientes SUNAT | `POST /notificaciones/jobs/guias-pendientes-sunat` | GRE con ticket en `PENDIENTE` ≥1 día |

### Ejemplo (uno)

```bash
export API_URL="https://api.tudominio.com"
export NOTIFICACIONES_JOBS_TOKEN="tu_token_del_env"

curl -s -X POST "$API_URL/notificaciones/jobs/alquileres-vencidos" \
  -H "X-Notificaciones-Jobs-Token: $NOTIFICACIONES_JOBS_TOKEN" \
  -H "Content-Type: application/json"
```

Equivalente con Bearer:

```bash
curl -s -X POST "$API_URL/notificaciones/jobs/alquileres-vencidos" \
  -H "Authorization: Bearer $NOTIFICACIONES_JOBS_TOKEN" \
  -H "Content-Type: application/json"
```

### Ejemplo (todos en secuencia)

```bash
#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-https://api.tudominio.com}"
NOTIFICACIONES_JOBS_TOKEN="${NOTIFICACIONES_JOBS_TOKEN:?Falta NOTIFICACIONES_JOBS_TOKEN}"

jobs=(
  alquileres-vencidos
  alquileres-por-vencer
  prestamos-vencidos
  prestamos-por-vencer
  stock-bajo
  documentos-por-vencer
  documentos-vencidos
  licencias-por-vencer
  licencias-vencidas
  comprobantes-pendientes-sunat
  guias-pendientes-sunat
)

for job in "${jobs[@]}"; do
  echo "==> $job"
  curl -sS -X POST "$API_URL/notificaciones/jobs/$job" \
    -H "X-Notificaciones-Jobs-Token: $NOTIFICACIONES_JOBS_TOKEN" \
    -H "Content-Type: application/json"
  echo
done
```

---

## Notificaciones en tiempo real (no usan jobs)

Se disparan **en el momento de la acción** (emitir, aprobar, solicitar, etc.).  
No hay endpoint HTTP ni cron: no configures Coolify para estas.

| Código | Cuándo | Destinatarios | `tipo_referencia` |
|---|---|---|---|
| `BAJA_CILINDRO_SOLICITADA` | Se solicita baja de cilindro | Admins con `bajas_balon.aprobar` | `BALON` |
| `BAJA_CILINDRO_APROBADA` | Se aprueba la baja | Usuario solicitante | `BALON` |
| `BAJA_CILINDRO_RECHAZADA` | Se rechaza la baja | Usuario solicitante | `BALON` |
| `BAJA_CLIENTE_SOLICITADA` | Se solicita baja de cliente | Admins con `bajas_cliente.aprobar` | `CLIENTE` |
| `BAJA_CLIENTE_APROBADA` | Se aprueba la baja | Usuario solicitante | `CLIENTE` |
| `BAJA_CLIENTE_RECHAZADA` | Se rechaza la baja | Usuario solicitante | `CLIENTE` |
| `REACTIVACION_CLIENTE_SOLICITADA` | Se solicita reactivación | Admins con `bajas_cliente.aprobar` | `CLIENTE` |
| `REACTIVACION_CLIENTE_APROBADA` | Se aprueba la reactivación | Usuario solicitante | `CLIENTE` |
| `REACTIVACION_CLIENTE_RECHAZADA` | Se rechaza la reactivación | Usuario solicitante | `CLIENTE` |
| `COMPROBANTE_SUNAT_RECHAZADO` | SUNAT rechaza CPE (emisión o consulta CDR) | Usuarios con `comprobantes.emitir` (fallback: quien emitió) | `COMPROBANTE` |
| `COMPROBANTE_ERROR_EMISION` | Falla de red/API al emitir CPE | Usuarios con `comprobantes.emitir` (fallback: quien emitió) | `COMPROBANTE` |
| `GUIA_SUNAT_RECHAZADA` | SUNAT rechaza GRE (emisión o consulta estado) | Usuarios con `guias_remision.emitir` (fallback: quien emitió) | `GUIA_REMISION` |
| `GUIA_ERROR_EMISION` | Falla de red/API al emitir GRE | Usuarios con `guias_remision.emitir` (fallback: quien emitió) | `GUIA_REMISION` |
| `SISTEMA` / `USUARIO` | Creación manual vía `POST /notificaciones` | Según body (usuario, roles, permiso) | variable |

### Deep-link en el admin (al hacer clic)

| `tipo_referencia` | Destino en frontend |
|---|---|
| `ALQUILER` | Listado alquileres + modal del alquiler |
| `PRESTAMO` | Listado préstamos + modal del préstamo |
| `BALON` | Aprobaciones de baja (o detalle del cilindro si ya fue resuelta) |
| `CLIENTE` | Aprobaciones de baja/reactivación (o edición del cliente si ya fue resuelta) |
| `COMPROBANTE` | Listado comprobantes + modal |
| `GUIA_REMISION` | Listado guías + modal |
| `STOCK` | Listado stock + modal |
| `DOCUMENTO_VENCIMIENTO` | Vehículos (vehículo asociado o búsqueda por placa) |
| `LICENCIA` | Choferes (chofer asociado) |

---

## Cron sugerido en hosting

Zona horaria: **America/Lima**.

| Frecuencia | Expresión cron | Uso |
|---|---|---|
| Diario 08:00 | `0 8 * * *` | Recomendado (alineado al job Nest) |
| 2 veces/día | `0 8,18 * * *` | Si quieres refresco extra por la tarde |

### Coolify / Scheduled Task

1. Crea un **Scheduled Job** / cron en el proyecto.
2. Define `API_URL` y `NOTIFICACIONES_JOBS_TOKEN` como variables de entorno del job (mismo valor que el API).
3. Comando (ejemplo con script):

```bash
API_URL="https://api.tudominio.com" /bin/bash /ruta/script-notificaciones-jobs.sh
```

### crontab Linux

```cron
0 8 * * * NOTIFICACIONES_JOBS_TOKEN=... API_URL=https://api.tudominio.com /opt/sarita/scripts/notificaciones-jobs.sh >> /var/log/sarita-notificaciones.log 2>&1
```

---

## Respuesta típica

```json
{
  "success": true,
  "message": "Operación exitosa",
  "data": {
    "alquileres": 2,
    "destinatarios": 4,
    "notificaciones": 8
  }
}
```

Los campos varían por job (`prestamos`, `items`, `documentos`, `licencias`, etc.).  
Si no hay casos, verás contadores en `0` (no es error).

---

## Catálogo completo por origen

### Por job / cron (esta guía)

`ALQUILER_VENCIDO`, `ALQUILER_POR_VENCER`, `PRESTAMO_VENCIDO`, `PRESTAMO_POR_VENCER`, `STOCK_BAJO`, `STOCK_CERO`, `DOCUMENTO_POR_VENCER`, `DOCUMENTO_VENCIDO`, `LICENCIA_POR_VENCER`, `LICENCIA_VENCIDA`, `COMPROBANTE_SUNAT_PENDIENTE`, `GUIA_SUNAT_PENDIENTE`.

### Por evento (sección anterior)

`BAJA_CILINDRO_*`, `BAJA_CLIENTE_*`, `REACTIVACION_CLIENTE_*`, `COMPROBANTE_SUNAT_RECHAZADO`, `COMPROBANTE_ERROR_EMISION`, `GUIA_SUNAT_RECHAZADA`, `GUIA_ERROR_EMISION`, `SISTEMA`, `USUARIO`.

---

## Notas

- Hay **dedupe diario** por clave (`ALQUILER_VENCIDO:{id}:{fecha}`, etc.): correr el job varias veces el mismo día no duplica la misma alerta.
- Si el API Nest ya tiene el cron interno activo **y** también programas cron externo, ambos pueden ejecutarse: el dedupe evita spam.
- Las de tiempo real **no** se invocan por HTTP de jobs; solo ocurren al ejecutar la acción en el sistema.
- “Pendiente SUNAT” = estado `PENDIENTE` con `ticket_sunat` y antigüedad ≥1 día (no existe estado `OBSERVADO` en el catálogo).
- Swagger: `GET /api/docs` → tag **Notificaciones**.
