import { interpretarGre, mensajeGre } from './gre-mensaje.helper';

describe('Mensajes GRE para usuarios', () => {
  const licencia = { code: '99', error: { code: '2573', message: 'Numero de licencia del conductor - El dato ingresado no cumple con el formato establecido. : error: Tipo de conductor Principal: errorCode 2573 (nodo: "cac:IdentityDocumentReference/cbc:ID" valor: "C-95824269")' } };
  it('explica el rechazo real, el dato enviado y dónde corregirlo, sin nodos XML', () => {
    const d = interpretarGre(licencia, 'RECHAZADO');
    expect(d.codigo).toBe('2573');
    expect(d.mensaje).toContain('C-95824269');
    expect(d.accion).toContain('Choferes → Licencias');
    expect(d.mensaje).not.toContain('cac:');
  });
  it('interpreta CDR anidado y el histórico JSON', () => {
    const d = interpretarGre(JSON.stringify({ tipo: 'despatch_status', respuesta: { cdrResponse: { code: '2573', description: licencia.error.message } } }), 'RECHAZADO');
    expect(d.codigo).toBe('2573');
    expect(d.mensaje).toContain('licencia');
  });
  it.each(['unauthorized_client', '[401] Unauthorized', '[403] Forbidden'])('interpreta acceso %s sin afirmar rechazo fiscal', message => {
    const d = interpretarGre({ sunatResponse: { error: { code: 'API', message } } }, 'RECHAZADO');
    expect(d.accion).toMatch(/credenciales|Client ID/);
    expect(d.titulo).not.toContain('Guía rechazada');
  });
  it('distingue credenciales SOL de la aplicación', () => {
    expect(interpretarGre({ error: { message: 'invalid_grant' } }).titulo).toContain('usuario SOL');
  });
  it.each(['timeout', 'Error al comunicarse con el servidor interno', 'No se pudo confirmar la respuesta del proveedor'])('no propone reemitir un resultado ambiguo: %s', error => {
    const d = interpretarGre({ error });
    expect(d.accion).toContain('Consultar estado');
    expect(d.mensaje).toContain('no demuestra');
  });
  it('traduce todos los errores de validación del Swagger y elimina duplicados', () => {
    const d = interpretarGre([{ field: 'envio.choferes[0].licencia', message: 'This value is required' }, { field: 'envio.pesoBruto', message: 'Invalid format' }, { field: 'envio.pesoBruto', message: 'Invalid format' }], 'RECHAZADO');
    expect(d.problemas).toHaveLength(2);
    expect(d.problemas[0]).toContain('Licencia del conductor: Completa');
    expect(d.problemas[1]).toContain('Peso del traslado');
  });
  it('conserva la explicación de un código desconocido sin inventar su significado', () => {
    const d = interpretarGre({ cdrResponse: { code: '2999', description: 'Dato especial incorrecto (nodo: "xml")' } }, 'RECHAZADO');
    expect(d.mensaje).toBe('Dato especial incorrecto');
    expect(d.accion).toContain('soporte');
    expect(mensajeGre({ error: { code: '2999', message: 'Dato especial incorrecto' } }, 'RECHAZADO')).toContain('2999');
  });
  it('success y ticket no se confunden con aceptación', () => {
    expect(interpretarGre({ sunatResponse: { success: true, ticket: 'abc' } }, 'PENDIENTE').titulo).toContain('por confirmar');
  });
  it('muestra observaciones de una guía aceptada', () => {
    const d = interpretarGre({ cdrResponse: { code: '0', notes: ['Revisa el domicilio'] } }, 'ACEPTADO');
    expect(d.titulo).toContain('con observaciones');
    expect(d.problemas).toEqual(['Revisa el domicilio']);
  });
  it('protege valores sensibles en el mensaje de fallback', () => {
    expect(interpretarGre({ error: { message: 'Error client_secret=secreto https://host/clave' } }, 'RECHAZADO').mensaje).not.toMatch(/secreto|https/);
  });
});
