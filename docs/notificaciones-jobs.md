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

O un one-liner:

```bash
curl -sS -X POST "https://api.tudominio.com/notificaciones/jobs/alquileres-vencidos" -H "X-Notificaciones-Jobs-Token: $NOTIFICACIONES_JOBS_TOKEN" && \
curl -sS -X POST "https://api.tudominio.com/notificaciones/jobs/alquileres-por-vencer" -H "X-Notificaciones-Jobs-Token: $NOTIFICACIONES_JOBS_TOKEN" && \
curl -sS -X POST "https://api.tudominio.com/notificaciones/jobs/prestamos-vencidos" -H "X-Notificaciones-Jobs-Token: $NOTIFICACIONES_JOBS_TOKEN" && \
curl -sS -X POST "https://api.tudominio.com/notificaciones/jobs/prestamos-por-vencer" -H "X-Notificaciones-Jobs-Token: $NOTIFICACIONES_JOBS_TOKEN" && \
curl -sS -X POST "https://api.tudominio.com/notificaciones/jobs/stock-bajo" -H "X-Notificaciones-Jobs-Token: $NOTIFICACIONES_JOBS_TOKEN"
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

Los campos varían por job (`prestamos`, `items`, etc.).  
Si no hay casos, verás contadores en `0` (no es error).

---

## Notas

- Hay **dedupe diario** por clave (`ALQUILER_VENCIDO:{id}:{fecha}`, etc.): correr el job varias veces el mismo día no duplica la misma alerta.
- Si el API Nest ya tiene el cron interno activo **y** también programas cron externo, ambos pueden ejecutarse: el dedupe evita spam.
- Eventos en tiempo real (baja aprobada/rechazada, error SUNAT) **no** usan estos jobs: se disparan al momento de la acción.
- Swagger: `GET /api/docs` → tag **Notificaciones**.
