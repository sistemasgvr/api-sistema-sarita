/**
 * Regenera database_sql/seeds/<modulo>/{listas,permisos,datos-base}.sql desde la caché de PROD
 * (database_sql/.cache/catalogo-prod.json → seeds). No se conecta a ninguna base.
 *
 * - listas.sql: gen_lista y gen_lista_opciones con su id de PROD (el FE fija ids en ListaIds y
 *   TipoClienteIds) + ON CONFLICT (id) y NOT EXISTS por nombre; id_lista de la opción resuelto por
 *   nombre de lista; al final setval de ambas secuencias.
 * - permisos.sql: auth_permisos por nombre (sin índice único → WHERE NOT EXISTS).
 * - datos-base.sql: auth (roles y rol-permiso por nombre), finanzas (fin_medio_pago_config,
 *   ON CONFLICT DO UPDATE), general (gen_condicion_pago, ON CONFLICT (codigo)), clientes
 *   (Clientes Varios, ON CONFLICT (codigo_interno)).
 * Orden de aplicación: todos los listas.sql, luego todos los permisos.sql, luego los datos-base.sql
 * (auth/datos-base.sql asigna permisos de todos los módulos).
 *
 * Si seeds/ aún tiene el formato antiguo (archivos .sql sueltos), antes de borrarlo compara su
 * contenido con PROD, lista lo que PROD no tiene y copia esos archivos a .cache/repo-drift-seeds/.
 *
 * Uso: node database_sql/scripts/regenerar-seeds.js [--dry-run] [--drift-desde <dir con seeds antiguos>]
 */
const fs = require('fs')
const path = require('path')
const { formatearSql } = require('./lib/formato')

const DB = path.join(__dirname, '..')
const SEEDS = path.join(DB, 'seeds')
const CACHE = path.join(DB, '.cache')
const DRIFT = path.join(CACHE, 'repo-drift-seeds')
const DRY = process.argv.includes('--dry-run')

/** Seeds antiguos de demo/prueba/fix que no se regeneran. */
const EXCLUIDOS = [
  'cli_clientes_demo_genericos.sql',
  'inv_balones_stock_demo.sql',
  'gen_test_data_cuentas_vencimientos.sql',
  'gen_lista_nombre_fixes.sql',
]

/** Lista → módulo: archivo seed que la definía; si no, objetos que la usan; ambiguo → general. */
const LISTA_MODULO = {
  general: [
    'TipoPersona', 'TipoCliente', 'TipoDocumento', 'UnidadMedida', 'AmbienteSunat', 'TipoLicencia',
    'CategoriaLicencia', 'TipoVehiculo', 'EstadoVencimiento', 'CategoriaVencimiento', 'TipoNotificacion',
    'EstadoGarantia', 'EstadoProductoRecogido', 'TipoValvula', 'SentidoAjuste', 'TipoItemMantenimiento',
    'MotivoBajaCliente', 'EstadoAprobacion', 'TipoSolicitud',
  ],
  productos: ['TipoMovInv', 'TipoCatalogoPrecio', 'TipoDocumentoRef'],
  balones: [
    'ReferenciaCilindro', 'EstadoCilindroVenta', 'EstadoMantenimiento', 'EstadoAlquiler', 'EstadoPrestamo',
    'PropietarioBalon', 'EstadoBalon', 'TipoMantenimiento', 'TipoMovBalon', 'TipoPrestamo',
    'EstadoPrestamoDetalle', 'MotivoBajaBalon', 'MarcaCilindro', 'OrganoInspectorCilindro', 'TipoRecarga',
    'EstadoContenidoBalon', 'EstadoRecargaPlanta', 'EstadoRutaPueblo', 'EstadoAlquilerPeriodo',
    'CondicionRegulador',
  ],
  ventas: [
    'TipoComprobante', 'MotivoNotaCredito', 'MotivoNotaDebito', 'TipoOperacionSunat', 'EstadoSunat',
    'EstadoDocumento', 'TipoVenta', 'AfectacionIgv', 'EstadoCuota', 'TipoMovimientoGarantia', 'Moneda',
    'RegimenPercepcion', 'TasaPercepcion',
  ],
  compras: ['RegimenRetencion', 'TasaRetencion', 'TipoRegistroCompra', 'CategoriaGasto'],
  finanzas: ['EstadoCaja', 'MedioPago', 'TipoCuentaFinanciera', 'TipoCuenta', 'Bancos'],
  'documentos-salida': [
    'TipoGuiaRemision', 'ModalidadTraslado', 'MotivoTraslado', 'EstadoGuiaRemision', 'TipoOrdenSalida',
    'EstadoCicloSalida',
  ],
  inventario: ['TipoMovInvUnificado', 'NaturalezaMovInv'],
  personal: ['AREAS_TRABAJADOR', 'CARGOS_TRABAJADOR'],
  activos: ['ACTIVOS_TIPO'],
  actividades: ['TipoActividad', 'EstadoActividad', 'PrioridadActividad', 'EstadoVerificacionItem', 'TipoOrigenActividad'],
}

/** Recurso del permiso (texto antes del ".") → módulo, según el archivo seed que lo definía. */
const PERMISO_MODULO = {
  auth: ['usuarios', 'sesiones', 'permisos', 'usuarios_roles', 'roles_permisos', 'roles', 'auth', 'notificaciones'],
  general: [
    'empresas', 'configuracion', 'almacenes', 'sucursales', 'configuracion_sunat', 'configuracion_servicios',
    'condiciones_pago', 'actividades', 'documentos_vencimiento', 'choferes', 'licencias', 'vehiculos',
    'cuentas_bancarias', 'catalogos',
  ],
  clientes: ['clientes', 'bajas_cliente', 'contactos', 'direcciones'],
  productos: ['productos', 'categorias', 'sub_categorias', 'catalogo_precios', 'stock', 'movimientos'],
  balones: [
    'tipos_balon', 'prestamos_balon', 'mantenimientos_balon', 'prestamos_detalle', 'alquileres_balon', 'balones',
    'movimientos_recarga', 'movimientos_balon', 'bajas_balon', 'rutas_pueblos', 'lotes_protocolo',
  ],
  ventas: ['comprobantes', 'ventas', 'guias_remision', 'percepciones'],
  compras: ['compras', 'retenciones'],
  dashboard: ['dashboard'],
  finanzas: ['finanzas', 'caja'],
  'documentos-salida': ['documentos_salida'],
  personal: ['trabajador'],
  activos: ['activo'],
  inventario: ['inventario_movimientos'],
}

function invertir(mapa) {
  const m = new Map()
  for (const [modulo, claves] of Object.entries(mapa)) for (const k of claves) m.set(k, modulo)
  return m
}
const LISTA_A_MODULO = invertir(LISTA_MODULO)
const RECURSO_A_MODULO = invertir(PERMISO_MODULO)

// ---------------------------------------------------------------- SQL helpers
function lit(v) {
  if (v === null || v === undefined) return 'NULL'
  if (typeof v === 'boolean') return v ? 'TRUE' : 'FALSE'
  if (typeof v === 'number') return String(v)
  return `'${String(v).replace(/'/g, "''")}'`
}
const tupla = (vals) => `(${vals.map(lit).join(', ')})`
const valores = (filas) => filas.map(tupla).join(',\n')
const porId = (a, b) => a.id - b.id

/** Primera aparición por clave (filas ordenadas por id). */
function unicos(filas, clave) {
  const vistos = new Set()
  return filas.filter((f) => {
    const k = clave(f)
    if (vistos.has(k)) return false
    vistos.add(k)
    return true
  })
}

// ---------------------------------------------------------------- generadores
function sqlListas(listas, opciones) {
  const out = []
  out.push(`INSERT INTO gen_lista (id, nombre, descripcion, estado)
SELECT v.id, v.nombre, v.descripcion, v.estado
FROM (VALUES
${valores(listas.map((l) => [l.id, l.nombre, l.descripcion, l.estado]))}
) AS v (id, nombre, descripcion, estado)
WHERE NOT EXISTS (SELECT 1 FROM gen_lista l WHERE l.nombre = v.nombre)
ON CONFLICT (id) DO NOTHING;`)
  if (opciones.length) {
    out.push(`INSERT INTO gen_lista_opciones (id, id_lista, nombre, descripcion, estado)
SELECT v.id, l.id, v.nombre, v.descripcion, v.estado
FROM (VALUES
${valores(opciones.map((o) => [o.id, o.lista, o.nombre, o.descripcion, o.estado]))}
) AS v (id, lista, nombre, descripcion, estado)
JOIN gen_lista l ON l.nombre = v.lista
WHERE NOT EXISTS (SELECT 1 FROM gen_lista_opciones o WHERE o.id_lista = l.id AND o.nombre = v.nombre)
ON CONFLICT (id) DO NOTHING;`)
  }
  out.push(`SELECT setval(pg_get_serial_sequence('gen_lista', 'id'), (SELECT COALESCE(MAX(id), 0) + 1 FROM gen_lista), FALSE);`)
  if (opciones.length) {
    out.push(`SELECT setval(pg_get_serial_sequence('gen_lista_opciones', 'id'), (SELECT COALESCE(MAX(id), 0) + 1 FROM gen_lista_opciones), FALSE);`)
  }
  return out
}

function sqlPermisos(permisos) {
  return [`INSERT INTO auth_permisos (nombre, descripcion, estado)
SELECT v.nombre, v.descripcion, v.estado
FROM (VALUES
${valores(permisos.map((p) => [p.nombre, p.descripcion, p.estado]))}
) AS v (nombre, descripcion, estado)
WHERE NOT EXISTS (SELECT 1 FROM auth_permisos p WHERE p.nombre = v.nombre);`]
}

function sqlAuthDatosBase(roles, pares) {
  return [
    `INSERT INTO auth_roles (nombre, descripcion, estado)
SELECT v.nombre, v.descripcion, v.estado
FROM (VALUES
${valores(roles.map((r) => [r.nombre, r.descripcion, r.estado]))}
) AS v (nombre, descripcion, estado)
WHERE NOT EXISTS (SELECT 1 FROM auth_roles r WHERE r.nombre = v.nombre);`,
    `INSERT INTO auth_roles_permisos (id_rol, id_permiso, estado)
SELECT r.id, p.id, v.estado
FROM (VALUES
${valores(pares.map((x) => [x.rol, x.permiso, x.estado]))}
) AS v (rol, permiso, estado)
JOIN LATERAL (SELECT id FROM auth_roles WHERE nombre = v.rol ORDER BY id LIMIT 1) r ON TRUE
JOIN LATERAL (SELECT id FROM auth_permisos WHERE nombre = v.permiso ORDER BY id LIMIT 1) p ON TRUE
WHERE NOT EXISTS (SELECT 1 FROM auth_roles_permisos rp WHERE rp.id_rol = r.id AND rp.id_permiso = p.id);`,
  ]
}

function sqlMedioPago(config) {
  return [`INSERT INTO fin_medio_pago_config (id_medio_pago, es_efectivo, afecta_caja, requiere_cuenta_bancaria, requiere_numero_operacion, es_credito, orden, estado)
SELECT o.id, v.es_efectivo, v.afecta_caja, v.requiere_cuenta_bancaria, v.requiere_numero_operacion, v.es_credito, v.orden, v.estado
FROM (VALUES
${valores(config.map((c) => [c.medio, c.es_efectivo, c.afecta_caja, c.requiere_cuenta_bancaria, c.requiere_numero_operacion, c.es_credito, c.orden, c.estado]))}
) AS v (medio, es_efectivo, afecta_caja, requiere_cuenta_bancaria, requiere_numero_operacion, es_credito, orden, estado)
JOIN gen_lista l ON l.nombre = 'MedioPago'
JOIN gen_lista_opciones o ON o.id_lista = l.id AND o.nombre = v.medio
ON CONFLICT (id_medio_pago) DO UPDATE SET
es_efectivo = EXCLUDED.es_efectivo,
afecta_caja = EXCLUDED.afecta_caja,
requiere_cuenta_bancaria = EXCLUDED.requiere_cuenta_bancaria,
requiere_numero_operacion = EXCLUDED.requiere_numero_operacion,
es_credito = EXCLUDED.es_credito,
orden = EXCLUDED.orden,
estado = EXCLUDED.estado,
fecha_modificacion = NOW();`]
}

function sqlCondiciones(conds) {
  return [`INSERT INTO gen_condicion_pago (codigo, nombre, dias_credito, numero_cuotas, dia_mes_pago, estado)
VALUES
${valores(conds.map((c) => [c.codigo, c.nombre, c.dias_credito, c.numero_cuotas, c.dia_mes_pago, c.estado]))}
ON CONFLICT (codigo) DO NOTHING;`]
}

const COLS_CLIENTE = [
  'codigo_interno', 'razon_social', 'nombres', 'apellido_paterno', 'apellido_materno', 'numero_documento',
  'direccion', 'referencia', 'telefono', 'email', 'es_agente_percepcion', 'es_buen_contribuyente',
  'es_agente_retenedor', 'afecto_rus', 'situacion_sunat', 'estado_contribuyente_sunat', 'observacion', 'estado',
]
const OPCIONES_CLIENTE = { id_tipo_cliente: 'TipoCliente', id_tipo_persona: 'TipoPersona', id_tipo_documento: 'TipoDocumento' }

function sqlClientesVarios(cli, opcionPorId) {
  const sub = (col) => {
    const o = opcionPorId.get(cli[col])
    if (!o) return 'NULL'
    return `(SELECT o.id FROM gen_lista_opciones o JOIN gen_lista l ON l.id = o.id_lista WHERE l.nombre = ${lit(o.lista)} AND o.nombre = ${lit(o.nombre)} ORDER BY o.id LIMIT 1)`
  }
  const cols = [...COLS_CLIENTE, ...Object.keys(OPCIONES_CLIENTE)]
  const vals = [...COLS_CLIENTE.map((c) => lit(cli[c])), ...Object.keys(OPCIONES_CLIENTE).map(sub)]
  return [`INSERT INTO cli_clientes (${cols.join(', ')})
VALUES (${vals.join(', ')})
ON CONFLICT (codigo_interno) DO NOTHING;`]
}

// ---------------------------------------------------------------- drift del formato antiguo
function stmts(t) {
  return t.replace(/--[^\n]*/g, '').split(/;\s*\n/)
}
const sinComillas = (x) => x.replace(/''/g, "'")

const literales = (s) => [...s.matchAll(/'((?:[^']|'')*)'/g)].map((m) => sinComillas(m[1]))
const likeARegex = (p) => new RegExp(`^${p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/%/g, '.*').replace(/_/g, '.')}$`)

/**
 * Permisos que un INSERT INTO auth_roles_permisos antiguo asigna a cada rol, evaluados contra los
 * nombres de PROD. Roles: r.nombre = '…' | IN (…). Permisos: unión de p.nombre = / IN / LIKE,
 * menos NOT IN / NOT LIKE / <>; sin condición positiva sobre p.nombre → todos los permisos.
 * Aproximación: trata las condiciones positivas como OR y las negativas como AND NOT.
 */
function asignacionesRol(st, permisosProd) {
  const P = '(?<![a-z_])p\\.nombre'
  const roles = new Set()
  for (const m of st.matchAll(/(?<![a-z_])r\.nombre\s*=\s*'([^']+)'/g)) roles.add(m[1])
  for (const m of st.matchAll(/(?<![a-z_])r\.nombre\s+IN\s*\(([^)]*)\)/g)) literales(m[1]).forEach((r) => roles.add(r))
  const pos = []
  const neg = []
  for (const m of st.matchAll(new RegExp(`${P}\\s+(NOT\\s+)?IN\\s*\\(([^)]*)\\)`, 'g'))) {
    const set = new Set(literales(m[2]))
    ;(m[1] ? neg : pos).push((n) => set.has(n))
  }
  for (const m of st.matchAll(new RegExp(`${P}\\s+(NOT\\s+)?I?LIKE\\s+'([^']+)'`, 'g'))) {
    const re = likeARegex(m[2])
    ;(m[1] ? neg : pos).push((n) => re.test(n))
  }
  for (const m of st.matchAll(new RegExp(`${P}\\s*(=|<>|!=)\\s*'([^']+)'`, 'g'))) {
    const v = m[2]
    ;(m[1] === '=' ? pos : neg).push((n) => n === v)
  }
  const esperados = [...permisosProd].filter((n) => (!pos.length || pos.some((f) => f(n))) && !neg.some((f) => f(n)))
  return [...roles].map((r) => [r, new Set(esperados)])
}

function driftAntiguo(seeds, dir) {
  const archivos = fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile() && e.name.endsWith('.sql'))
    .map((e) => [e.name, fs.readFileSync(path.join(dir, e.name), 'utf8')])
  if (!archivos.length) return null
  const listaId = new Map(seeds.gen_lista.map((l) => [l.nombre, l.id]))
  const opcionesProd = new Set()
  for (const o of seeds.gen_lista_opciones) {
    opcionesProd.add(`${o.id_lista}|${o.nombre}`)
    if (o.descripcion) opcionesProd.add(`${o.id_lista}|${o.descripcion}`) // algunas opciones se buscan por código en descripcion
  }
  const permisosProd = new Set(seeds.auth_permisos.map((p) => p.nombre))
  const tablasProd = new Set(Object.keys(seeds))
  const rolPorId = new Map(seeds.auth_roles.map((r) => [r.id, r.nombre]))
  const permPorId = new Map(seeds.auth_permisos.map((p) => [p.id, p.nombre]))
  const permisosDeRol = new Map()
  for (const x of seeds.auth_roles_permisos) {
    const r = rolPorId.get(x.id_rol)
    if (!permisosDeRol.has(r)) permisosDeRol.set(r, new Set())
    permisosDeRol.get(r).add(permPorId.get(x.id_permiso))
  }
  const items = []
  for (const [f, t] of archivos) {
    if (EXCLUIDOS.includes(f)) {
      items.push([f, 'seed de demo/prueba/fix: no se regenera'])
      continue
    }
    for (const st of stmts(t)) {
      const ins = st.match(/INSERT INTO\s+([a-z_]+)/)
      const upd = st.match(/^\s*UPDATE\s+([a-z_]+)/m)
      if (/\bDO\s+\$/.test(st)) {
        const tabla = (st.match(/INSERT INTO\s+([a-z_]+)/) || [])[1]
        items.push([f, `bloque DO con escritura en ${tabla || '?'} (fuera de los seeds de PROD)`])
        continue
      }
      if (upd) items.push([f, `UPDATE ${upd[1]} (normalización/fix; no se regenera)`])
      if (!ins) continue
      const tabla = ins[1]
      if (!tablasProd.has(tabla)) {
        items.push([f, `INSERT en ${tabla} (tabla fuera de los seeds de PROD)`])
        continue
      }
      const vs = st.split(/VALUES/)[1]
      if (tabla === 'gen_lista_opciones' && vs) {
        const ln = [...new Set([...st.matchAll(/l\.nombre\s*=\s*'([^']+)'/g)].map((m) => m[1]))]
        if (ln.length !== 1) continue
        const cuerpo = vs.split(/\)\s*AS\s+v/)[0]
        for (const m of cuerpo.matchAll(/\(\s*'((?:[^']|'')*)'/g)) {
          const n = sinComillas(m[1])
          if (!opcionesProd.has(`${listaId.get(ln[0])}|${n}`)) items.push([f, `opción ${ln[0]}.${n} no existe en PROD`])
        }
      } else if (tabla === 'gen_lista' && vs) {
        for (const m of vs.split(/\)\s*AS\s+v/)[0].matchAll(/\(\s*'((?:[^']|'')*)'/g)) {
          if (!listaId.has(sinComillas(m[1]))) items.push([f, `lista ${m[1]} no existe en PROD`])
        }
      } else if (tabla === 'auth_permisos' && vs) {
        for (const m of vs.matchAll(/\(\s*'([a-z_]+\.[a-z_]+)'/g)) {
          if (!permisosProd.has(m[1])) items.push([f, `permiso ${m[1]} no existe en PROD`])
        }
      } else if (tabla === 'auth_roles_permisos') {
        for (const [rol, esperados] of asignacionesRol(st, permisosProd)) {
          const faltan = [...esperados].filter((n) => !(permisosDeRol.get(rol) || new Set()).has(n))
          if (faltan.length) {
            items.push([f, `asigna al rol ${rol} ${faltan.length} permiso(s) que en PROD no tiene: ${faltan.join(', ')}`])
          }
        }
      }
    }
  }
  return { archivos, items }
}

// ---------------------------------------------------------------- main
function escribir(rel, descripcion, sentencias) {
  const crudo = `-- ${descripcion}\n${sentencias.join('\n\n')}\n`
  const fmt = formatearSql(crudo)
  if (!fmt.ok) throw new Error(`${rel}: ${fmt.error}`)
  const destino = path.join(SEEDS, rel)
  if (!DRY) {
    fs.mkdirSync(path.dirname(destino), { recursive: true })
    fs.writeFileSync(destino, fmt.texto)
  }
  return rel
}

function main() {
  const { seeds } = JSON.parse(fs.readFileSync(path.join(CACHE, 'catalogo-prod.json'), 'utf8'))
  for (const t of ['gen_lista', 'gen_lista_opciones', 'auth_permisos', 'auth_roles', 'auth_roles_permisos', 'fin_medio_pago_config', 'gen_condicion_pago', 'cli_clientes']) {
    if (!Array.isArray(seeds[t])) throw new Error(`catalogo-prod.json sin seeds.${t}`)
  }

  const sinModulo = seeds.gen_lista.filter((l) => !LISTA_A_MODULO.has(l.nombre)).map((l) => l.nombre)
  const recursosSinModulo = [...new Set(seeds.auth_permisos.map((p) => p.nombre.split('.')[0]))].filter((r) => !RECURSO_A_MODULO.has(r))
  if (sinModulo.length) console.warn(`Listas sin módulo asignado (→ general): ${sinModulo.join(', ')}`)
  if (recursosSinModulo.length) console.warn(`Recursos de permiso sin módulo (→ general): ${recursosSinModulo.join(', ')}`)

  // Drift del formato antiguo (antes de borrar). --drift-desde <dir>: analiza una copia de los seeds antiguos.
  const i = process.argv.indexOf('--drift-desde')
  const origen = i > 0 ? path.resolve(process.argv[i + 1]) : SEEDS
  const drift = driftAntiguo(seeds, origen)
  if (drift) {
    console.log(`Seeds antiguos: ${drift.archivos.length}; contenido no representado en PROD: ${drift.items.length}`)
    for (const [f, d] of drift.items) console.log(`  ${f}: ${d}`)
    // repo-drift-seeds/ solo se reemplaza si hay drift nuevo; si no, se conserva la evidencia anterior
    // (la de la limpieza está congelada en .cache/limpieza-2026-10-27/).
    if (!DRY && drift.items.length) {
      fs.rmSync(DRIFT, { recursive: true, force: true })
      fs.mkdirSync(DRIFT, { recursive: true })
      for (const f of new Set(drift.items.map((x) => x[0]))) fs.copyFileSync(path.join(origen, f), path.join(DRIFT, f))
    }
  }
  if (!DRY) fs.rmSync(SEEDS, { recursive: true, force: true })

  const listaPorId = new Map(seeds.gen_lista.map((l) => [l.id, l]))
  const opcionPorId = new Map(
    seeds.gen_lista_opciones.map((o) => [o.id, { lista: listaPorId.get(o.id_lista).nombre, nombre: o.nombre }]),
  )
  const modListas = (n) => LISTA_A_MODULO.get(n) || 'general'
  const modPermiso = (n) => RECURSO_A_MODULO.get(n.split('.')[0]) || 'general'

  const resumen = []
  const anotar = (rel, tabla, n) => resumen.push(`${rel}\t${tabla}\t${n}`)

  // listas.sql por módulo
  const listas = [...seeds.gen_lista].sort(porId)
  const opciones = [...seeds.gen_lista_opciones].sort(porId)
  for (const modulo of [...new Set(listas.map((l) => modListas(l.nombre)))].sort()) {
    const ls = listas.filter((l) => modListas(l.nombre) === modulo)
    const ids = new Set(ls.map((l) => l.id))
    const os = unicos(
      opciones.filter((o) => ids.has(o.id_lista)).map((o) => ({ ...o, lista: listaPorId.get(o.id_lista).nombre })),
      (o) => `${o.id_lista}|${o.nombre}`,
    )
    const rel = escribir(`${modulo}/listas.sql`, `Listas y opciones del módulo ${modulo}`, sqlListas(ls, os))
    anotar(rel, 'gen_lista', ls.length)
    anotar(rel, 'gen_lista_opciones', os.length)
  }

  // permisos.sql por módulo
  const permisos = unicos([...seeds.auth_permisos].sort(porId), (p) => p.nombre)
  for (const modulo of [...new Set(permisos.map((p) => modPermiso(p.nombre)))].sort()) {
    const ps = permisos.filter((p) => modPermiso(p.nombre) === modulo)
    const rel = escribir(`${modulo}/permisos.sql`, `Permisos del módulo ${modulo}`, sqlPermisos(ps))
    anotar(rel, 'auth_permisos', ps.length)
  }

  // auth/datos-base.sql
  const roles = unicos([...seeds.auth_roles].sort(porId), (r) => r.nombre)
  const rolPorId = new Map(seeds.auth_roles.map((r) => [r.id, r.nombre]))
  const permPorId = new Map(seeds.auth_permisos.map((p) => [p.id, p.nombre]))
  const pares = unicos(
    [...seeds.auth_roles_permisos].sort(porId).map((x) => ({ rol: rolPorId.get(x.id_rol), permiso: permPorId.get(x.id_permiso), estado: x.estado })),
    (x) => `${x.rol}|${x.permiso}`,
  )
  let rel = escribir('auth/datos-base.sql', 'Roles y asignación rol-permiso (aplicar después de todos los permisos.sql)', sqlAuthDatosBase(roles, pares))
  anotar(rel, 'auth_roles', roles.length)
  anotar(rel, 'auth_roles_permisos', pares.length)

  // finanzas/datos-base.sql
  const config = [...seeds.fin_medio_pago_config]
    .sort((a, b) => a.orden - b.orden)
    .map((c) => ({ ...c, medio: opcionPorId.get(c.id_medio_pago).nombre }))
  rel = escribir('finanzas/datos-base.sql', 'Comportamiento de cada medio de pago en caja y cobros', sqlMedioPago(config))
  anotar(rel, 'fin_medio_pago_config', config.length)

  // general/datos-base.sql
  const conds = [...seeds.gen_condicion_pago].sort(porId)
  rel = escribir('general/datos-base.sql', 'Condiciones de pago estándar', sqlCondiciones(conds))
  anotar(rel, 'gen_condicion_pago', conds.length)

  // clientes/datos-base.sql (solo Clientes Varios)
  const cvarios = seeds.cli_clientes.filter((c) => c.codigo_interno === 'CVARIOS')
  if (cvarios.length !== 1) throw new Error(`se esperaba 1 cliente CVARIOS, hay ${cvarios.length}`)
  rel = escribir('clientes/datos-base.sql', 'Cliente genérico de mostrador (Clientes Varios, codigo_interno CVARIOS)', sqlClientesVarios(cvarios[0], opcionPorId))
  anotar(rel, 'cli_clientes', 1)

  console.log(`${DRY ? '[dry-run] ' : ''}Archivos generados: ${new Set(resumen.map((r) => r.split('\t')[0])).size}`)
  for (const r of resumen) console.log(`  ${r}`)
}

main()
