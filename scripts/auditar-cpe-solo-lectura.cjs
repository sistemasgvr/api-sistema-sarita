// Consulta únicamente: PostgreSQL READ ONLY y GET /invoice/status del proveedor.
// No inicia Nest ni ejecuta emisión, sincronización o actualización de estados.
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');
const axios = require('axios');
const env = require('dotenv').parse(fs.readFileSync(path.join(__dirname, '../.env')));

function resumen(payload) {
  const data = payload?.sunatResponse ?? payload ?? {};
  return {
    success: data.success,
    codigo: data.code ?? data.error?.code,
    mensaje: data.message ?? data.error?.message,
    cdr: data.cdrResponse ? {
      id: data.cdrResponse.id,
      codigo: data.cdrResponse.code,
      descripcion: data.cdrResponse.description,
      observaciones: data.cdrResponse.notes,
    } : null,
  };
}

async function main() {
  const db = new Client({
    connectionString: env.DATABASE_URL,
    connectionTimeoutMillis: 10000,
    options: '-c default_transaction_read_only=on -c statement_timeout=15000',
  });
  let docs;
  let config;
  try {
    await db.connect();
    await db.query('BEGIN READ ONLY');
    const configs = (await db.query(
      'SELECT api_token, api_base_url, ruc_emisor FROM gen_configuracion_sunat WHERE estado=1',
    )).rows;
    if (configs.length !== 1) throw new Error('Se requiere una única configuración activa');
    config = configs[0];
    if (config.api_base_url !== 'https://facturacion.apisperu.com/api/v1') {
      throw new Error('Proveedor inesperado; no se enviaron credenciales');
    }
    docs = (await db.query(`
      SELECT c.id,c.serie,c.numero,c.fecha::text,c.total_importe,
             s.nombre AS estado_sistema,t.nombre AS tipo,c.cdr_respuesta,c.xml_firmado
      FROM ven_comprobante c
      LEFT JOIN gen_lista_opciones s ON s.id=c.id_estado_sunat
      LEFT JOIN gen_lista_opciones t ON t.id=c.id_tipo_comprobante
      WHERE c.estado=1 AND t.nombre IN ('BOLETA','FACTURA')
      ORDER BY c.id
    `)).rows;
    await db.query('ROLLBACK');
  } finally {
    await db.end();
  }
  const informe = {
    consultadoEn: new Date().toISOString(),
    ruc: config.ruc_emisor,
    fuente: 'CDR almacenado y GET /invoice/status de APIs PERU',
    consultaIntegradaSunat: 'Este script no consulta la API integrada; consulta únicamente el estado por el proveedor',
    soloLectura: true,
    comprobantes: [],
  };
  for (const doc of docs) {
    let guardado;
    try { guardado = resumen(JSON.parse(doc.cdr_respuesta || '{}')); }
    catch { guardado = { error: 'CDR almacenado no es JSON' }; }
    const item = {
      id: doc.id, documento: `${doc.serie}-${Number(doc.numero)}`,
      numeroAlmacenado: doc.numero,
      idXml: doc.xml_firmado?.match(/<cbc:ID[^>]*>([^<]+)<\/cbc:ID>/)?.[1] ?? null,
      fecha: doc.fecha, importe: doc.total_importe,
      estadoSistema: doc.estado_sistema, respuestaGuardada: guardado,
    };
    try {
      const response = await axios.get(`${config.api_base_url}/invoice/status`, {
        params: {ruc:config.ruc_emisor,tipo:doc.tipo==='BOLETA'?'03':'01',serie:doc.serie,numero:String(Number(doc.numero))},
        headers: {Authorization:`Bearer ${config.api_token}`},
        timeout:30000, maxRedirects:0, validateStatus:()=>true,
      });
      item.consultaActual = {http:response.status,...resumen(response.data)};
    } catch (error) {
      item.consultaActual = {error:error.code || 'ERROR_CONSULTA'};
    }
    informe.comprobantes.push(item);
    console.log(JSON.stringify({documento:item.documento,guardado:guardado.cdr?.codigo,actual:item.consultaActual.cdr?.codigo ?? item.consultaActual.codigo ?? item.consultaActual.error}));
  }
  const salida = path.resolve(__dirname, '../../diagnosticos/auditoria-cpe-2026-10-12.json');
  fs.mkdirSync(path.dirname(salida), {recursive:true});
  fs.writeFileSync(salida, JSON.stringify(informe,null,2));
  console.log(`Informe: ${salida}`);
}
main().catch(error=>{console.error(error.code || error.message);process.exitCode=1;});
