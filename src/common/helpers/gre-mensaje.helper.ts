/** Mensajes de GRE derivados de los formatos Error, ValidationResponse y CdrResponse del PSE. */
export interface GreDiagnostico {
  tipo: 'aceptacion' | 'rechazo' | 'acceso' | 'validacion' | 'pendiente';
  titulo: string;
  mensaje: string;
  accion: string;
  codigo: string | null;
  problemas: string[];
}

const obj = (v: unknown): Record<string, unknown> => v && typeof v === 'object' && !Array.isArray(v) ? v as Record<string, unknown> : {};
const texto = (v: unknown): string => typeof v === 'string' || typeof v === 'number' ? String(v).trim() : '';

const campos: [RegExp, string, string][] = [
  [/licencia|license|IdentityDocumentReference/i, 'Licencia del conductor', 'Revisa el número de licencia en Configuración → Choferes → Licencias y cópialo tal como corresponde a la licencia vigente.'],
  [/placa|plate/i, 'Placa del vehículo', 'Revisa la placa en Configuración → Vehículos y los datos de traslado de la guía.'],
  [/ubigeo|district/i, 'Ubigeo', 'Revisa el distrito y el ubigeo de los puntos de partida y llegada en los datos GRE.'],
  [/destinatario|destinatary/i, 'Destinatario', 'Revisa el tipo y número de documento y los datos del destinatario de la guía.'],
  [/chofer|conductor|driver/i, 'Conductor', 'Revisa el documento, los nombres y apellidos del chofer en Configuración → Choferes.'],
  [/transportista|carrier|transportist/i, 'Transportista', 'Revisa el RUC y los datos del transportista en los datos de traslado.'],
  [/peso|weight/i, 'Peso del traslado', 'Revisa el peso bruto y la unidad de medida en los datos GRE.'],
  [/fecha|date/i, 'Fecha de la guía', 'Revisa las fechas de emisión y de inicio del traslado en los datos GRE.'],
  [/serie|correlativo|correlativ/i, 'Numeración de la guía', 'Revisa la serie y el número de la guía antes de continuar.'],
  [/direccion|dirección|address/i, 'Dirección', 'Revisa las direcciones de partida y llegada en los datos GRE.'],
  [/item|producto|cantidad|quantity/i, 'Productos de la guía', 'Revisa los productos, cantidades y unidades de medida del documento de salida.'],
  [/certificado|certificate|firma|signature/i, 'Certificado digital', 'Revisa el certificado digital y su vigencia en la empresa del PSE.'],
];

/** Eliminar trazas, nodos XML, URLs y posibles secretos del texto de negocio. */
function limpiar(s: string): string {
  return s.split(/\s*:\s*error:|\s*\(nodo:|\s*errorCode\s|\s*Stack trace/i)[0]
    .replace(/https?:\/\/\S+/gi, '')
    .replace(/(?:client_secret|password|access_token|authorization)\s*[=:]\s*\S+/gi, '[dato protegido]')
    .replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim().slice(0, 350);
}

export function interpretarGre(response: unknown, estado = 'POR_CONFIRMAR'): GreDiagnostico {
  let root = obj(response);
  // Históricos guardados como JSON con {tipo, respuesta}, además del formato del envío.
  if (typeof response === 'string') {
    try { root = obj(JSON.parse(response)); } catch { root = { error: response }; }
  }
  if (root.respuesta) root = obj(root.respuesta);
  const result = root.sunatResponse ? obj(root.sunatResponse) : root;
  const cdr = obj(result.cdrResponse);
  const error = obj(result.error);
  const http = /\[(4\d\d|5\d\d)\]/.exec(texto(error.message))?.[1];
  const codigo = texto(cdr.code) || (http ? `HTTP ${http}` : texto(error.code)) || (['98', '99'].includes(texto(result.code)) ? texto(result.code) : '') || null;
  const raw = texto(error.message) || texto(cdr.description) || texto(result.error) || texto(result.message);
  const issues = Array.isArray(response) ? response : Array.isArray(result.errors) ? result.errors : [];
  const base = { codigo, problemas: [] as string[], tipo: 'rechazo' as GreDiagnostico['tipo'] };
  const accepted = estado === 'ACEPTADO';
  if (accepted) {
    const notas = Array.isArray(cdr.notes) ? cdr.notes.map(n => limpiar(texto(n))).filter(Boolean) : [];
    return { ...base, tipo: 'aceptacion', titulo: notas.length ? 'Guía aceptada con observaciones' : 'Guía aceptada por SUNAT', mensaje: 'La guía fue aceptada por SUNAT.', accion: notas.length ? 'Revisa las observaciones de SUNAT.' : 'Puedes consultar sus archivos oficiales.', problemas: notas };
  }
  const ambiguous = ['PENDIENTE', 'POR_CONFIRMAR', 'ENVIANDO'].includes(estado);
  const pendiente = 'Usa «Consultar estado SUNAT» para confirmar el resultado antes de volver a emitir.';
  // El HTTP describe el acceso, nunca es por sí mismo un rechazo fiscal del documento.
  if (/unauthorized_client|invalid_client/i.test(raw)) return { ...base, tipo: 'acceso', titulo: 'SUNAT no autoriza la aplicación GRE', mensaje: 'SUNAT no pudo autenticar la aplicación con las credenciales registradas.', accion: 'Revisa el Client ID, Client Secret y el permiso GRE de la aplicación en SUNAT; guarda y sincroniza la configuración GRE.' };
  if (/\[429\]|too many requests/i.test(raw)) return { ...base, tipo: 'pendiente', titulo: 'El servicio recibió demasiadas solicitudes', mensaje: 'El servicio limitó temporalmente las solicitudes.', accion: 'Espera unos minutos y consulta el estado de la guía antes de intentar otro envío.' };
  if (/invalid_grant|usuario.*clave.*incorrect|SOL.*inv[aá]lid/i.test(raw)) return { ...base, tipo: 'acceso', titulo: 'No se pudo autenticar el usuario SOL', mensaje: 'SUNAT no aceptó las credenciales del usuario SOL.', accion: 'Revisa el usuario SOL, su contraseña y sus permisos para GRE; luego sincroniza la configuración.' };
  if (/\[40[13]\]|unauthorized|forbidden|credenciales.*inv[aá]lidas/i.test(raw)) return { ...base, tipo: 'acceso', titulo: 'No se pudo acceder al servicio GRE', mensaje: 'El servicio rechazó el acceso con las credenciales o permisos actuales.', accion: 'Revisa las credenciales y permisos de SUNAT y del PSE en Configuración → SUNAT. Guarda y sincroniza la configuración GRE.' };
  if (/timeout|timed out|servidor interno|internal server|no se pudo confirmar|no se pudo comunicar|\[5\d\d\]/i.test(raw)) return { ...base, tipo: 'pendiente', titulo: 'Resultado del envío por confirmar', mensaje: 'El proveedor no confirmó el resultado de la operación. Esto no demuestra que SUNAT haya rechazado la guía.', accion: pendiente };
  if (issues.length) {
    const problemas = issues.map(item => {
      const i = obj(item); const field = texto(i.field);
      const campo = campos.find(([re]) => re.test(field));
      const message = texto(i.message);
      const razon = /required|blank|empty|not null/i.test(message) ? 'Completa este dato.' : /invalid|format|match|length/i.test(message) ? 'Revisa el formato de este dato.' : limpiar(message) || 'Revisa este dato.';
      return `${campo?.[1] ?? 'Dato de la guía'}: ${razon}${campo ? ` ${campo[2]}` : ''}`;
    });
    return { ...base, tipo: 'validacion', titulo: 'Revisa los datos de la guía', mensaje: 'El proveedor encontró datos incompletos o inválidos.', accion: 'Corrige los datos indicados antes de enviar la guía.', problemas: [...new Set(problemas)] };
  }
  if (ambiguous) return { ...base, tipo: 'pendiente', titulo: 'Resultado del envío por confirmar', mensaje: 'Aún no hay una aceptación o un rechazo definitivo de SUNAT.', accion: pendiente };
  const campo = campos.find(([re]) => re.test(raw));
  const valor = campo ? /valor:\s*["']([^"']{1,60})["']/i.exec(raw)?.[1] : undefined;
  const motivo = codigo === '2573'
    ? 'El número de licencia del conductor no cumple con el formato exigido por SUNAT.'
    : /Exception|Stack trace|Client error|Server error/i.test(raw) ? 'El servicio devolvió un error técnico. Consulta el detalle con soporte.'
    : limpiar(raw) || 'SUNAT rechazó la guía sin proporcionar un motivo legible.';
  const mensaje = motivo + (valor ? ` Valor enviado: ${limpiar(valor)}.` : '');
  return { ...base, titulo: campo ? `Revisa: ${campo[1].toLowerCase()}` : 'Guía rechazada por SUNAT', mensaje,
    accion: campo?.[2] ?? 'Revisa el motivo y corrige los datos de la guía. Si no puedes identificar el dato, consulta el detalle técnico con soporte.', problemas: [] };
}

export function mensajeGre(response: unknown, estado: string): string {
  const d = interpretarGre(response, estado);
  return [d.mensaje, ...d.problemas, d.accion, d.codigo && d.codigo !== '0' ? `(Código ${d.codigo})` : ''].filter(Boolean).join(' ');
}
