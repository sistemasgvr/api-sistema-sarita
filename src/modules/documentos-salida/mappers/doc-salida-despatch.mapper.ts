import { BadRequestException, Injectable } from '@nestjs/common';
import type { FacturacionApisperuPayload } from '../../../integrations/facturacion-apisperu/interfaces/facturacion-apisperu.interface';
import {
  esFlotaPropia,
  nombresChofer,
  normalizarPlaca,
  soloErrores,
  validarGre,
  type ContextoValidacionGre,
} from '../helpers/gre-validacion';
import type {
  DocumentoSalidaCompletoResult,
  DocumentoSalidaDetalleRegistro,
  DocumentoSalidaRegistro,
  EmpresaEmisora,
} from '../interfaces/documento-salida.interface';

@Injectable()
export class DocSalidaDespatchMapper {
  /**
   * Arma el payload de `despatch/send`. Corre la misma prevalidación que el
   * endpoint `validar-gre`: si hay errores, no se envía nada.
   */
  mapToDespatchPayload(
    doc: DocumentoSalidaCompletoResult,
    empresa: EmpresaEmisora,
    contexto: ContextoValidacionGre = {},
  ): FacturacionApisperuPayload {
    const cabecera = doc.registro;

    if (!cabecera) {
      throw new BadRequestException('Documento de salida inválido');
    }

    const errores = soloErrores(validarGre(cabecera, empresa, contexto));
    if (errores.length > 0) {
      throw new BadRequestException(errores.map((e) => e.mensaje).join('; '));
    }

    const detalles = cabecera.detalle ?? [];
    const tipoDoc = cabecera.codigo_tipo_guia as string;
    const flotaPropia = esFlotaPropia(cabecera);

    const envio: Record<string, unknown> = {
      codTraslado: cabecera.codigo_motivo_traslado,
      desTraslado: this.mapDesTraslado(
        cabecera.nombre_motivo_traslado,
        cabecera.codigo_motivo_traslado,
      ),
      fecTraslado: this.formatFecha(cabecera.fecha_traslado as string),
      pesoTotal: Number(cabecera.peso_bruto ?? 0),
      undPesoTotal: this.mapUnidadPeso(
        cabecera.codigo_unidad_medida,
        cabecera.nombre_unidad_medida,
      ),
      numBultos: Number(cabecera.numero_bultos ?? 1),
      llegada: {
        ubigueo: (cabecera.ubigeo_llegada as string).trim(),
        direccion: (cabecera.direccion_llegada as string).trim(),
      },
      partida: {
        ubigueo: (cabecera.ubigeo_origen as string).trim(),
        direccion: (cabecera.direccion_origen as string).trim(),
      },
    };

    // La modalidad (público/privado) es un dato de la guía remitente; en la
    // transportista (31) no existe: el emisor es quien transporta.
    if (tipoDoc === '09') {
      envio.modTraslado = flotaPropia ? '02' : '01';
    }

    if (flotaPropia) {
      // La placa impresa puede incluir guion; GRE recibe su identificador sin separadores.
      const placa = normalizarPlaca(cabecera.placa_vehiculo);
      const docChofer = (cabecera.documento_chofer ?? '').trim();
      const licencia = (cabecera.licencia_chofer ?? '').trim();
      const nombres = nombresChofer(cabecera);

      envio.vehiculo = { placa };
      envio.choferes = [
        {
          tipo: 'Principal',
          tipoDoc: this.mapTipoDocChofer(
            cabecera.codigo_tipo_doc_chofer,
            docChofer,
          ),
          nroDoc: docChofer,
          licencia,
          nombres: nombres.nombres,
          apellidos: nombres.apellidos,
        },
      ];
    } else {
      envio.transportista = {
        tipoDoc: '6',
        numDoc: (cabecera.documento_transportista as string).trim(),
        rznSocial: (cabecera.nombre_transportista as string).trim(),
      };
    }

    const payload: FacturacionApisperuPayload = {
      version: '2022',
      tipoDoc,
      serie: cabecera.serie ?? '',
      correlativo: this.parseCorrelativo(cabecera.numero_sunat as string),
      fechaEmision: this.formatFecha(cabecera.fecha_emision_gre as string),
      company: this.mapEmpresa(empresa),
      destinatario: this.resolverDestinatario(cabecera),
      envio,
      details: detalles.map((detalle) => this.mapDetalle(detalle)),
    };

    if (tipoDoc === '31') {
      const remitenteDoc = (cabecera.documento_cliente as string).trim();
      payload.remitente = {
        tipoDoc: this.mapTipoDocCliente(
          cabecera.nombre_tipo_doc_cliente,
          remitenteDoc,
        ),
        numDoc: remitenteDoc,
        rznSocial: (cabecera.nombre_cliente ?? 'REMITENTE').trim(),
      };
    }

    if (cabecera.observaciones?.trim()) {
      payload.observacion = cabecera.observaciones.trim();
    }

    const refs = cabecera.referencias ?? [];
    const mappedRefs = refs
      .filter((r) => r.serie && r.numero && r.codigo_tipo_comprobante)
      .map((r) => ({
        tipoDoc: r.codigo_tipo_comprobante as string,
        nroDoc: `${r.serie}-${this.parseCorrelativo(String(r.numero))}`,
      }));

    if (mappedRefs.length > 0) {
      payload.relDoc = mappedRefs[0];
      if (mappedRefs.length > 1) {
        payload.addDocs = mappedRefs
          .slice(1)
          .map((r) => ({ tipo: r.tipoDoc, nro: r.nroDoc }));
      }
    }

    return payload;
  }

  /**
   * `destinatario` del payload SUNAT (catálogo: tipoDoc / numDoc / rznSocial).
   *
   * En recarga y retorno de planta externa la carga va (o vuelve) del
   * proveedor: él ES el destinatario del documento y no hay tercero registrado
   * en `documento_destinatario`. Es el mismo criterio que imprime el PDF, y
   * mientras el mapper solo miraba el destinatario, esas guías se caían con
   * «el destinatario no tiene número de documento» sin que faltara ningún dato.
   *
   * En una GRE transportista (31) el cliente es el remitente, así que no puede
   * entrar además como destinatario.
   */
  private resolverDestinatario(cabecera: DocumentoSalidaRegistro) {
    // doc_obtener_salida no trae el tipo de documento del proveedor; sin él
    // mapTipoDocCliente lo deduce del largo (11 = RUC, 8 = DNI), que es lo que
    // ya hace de fallback para cliente y destinatario.
    const proveedor = {
      doc: (cabecera.documento_proveedor ?? '').trim(),
      nombre: (cabecera.nombre_proveedor ?? '').trim(),
      tipoDocumento: null as string | null,
    };
    const destinatario = {
      doc: (cabecera.documento_destinatario ?? '').trim(),
      nombre: (cabecera.nombre_destinatario ?? '').trim(),
      tipoDocumento: cabecera.nombre_tipo_doc_destinatario,
    };
    const cliente = {
      doc: (cabecera.documento_cliente ?? '').trim(),
      nombre: (cabecera.nombre_cliente ?? '').trim(),
      tipoDocumento: cabecera.nombre_tipo_doc_cliente,
    };

    const esPlantaExterna =
      cabecera.nombre_tipo_orden === 'RECARGA_PLANTA_EXTERNA';
    const orden = esPlantaExterna
      ? [proveedor, destinatario, cliente]
      : [destinatario, cliente, proveedor];
    const candidatos =
      cabecera.codigo_tipo_guia === '31'
        ? orden.filter((candidato) => candidato !== cliente)
        : orden;

    const elegido = candidatos.find((candidato) => candidato.doc);

    if (!elegido) {
      throw new BadRequestException(
        esPlantaExterna
          ? 'La planta externa no tiene número de documento. Registra el RUC del proveedor antes de emitir.'
          : 'El destinatario no tiene número de documento',
      );
    }

    return {
      tipoDoc: this.mapTipoDocCliente(elegido.tipoDocumento, elegido.doc),
      numDoc: elegido.doc,
      rznSocial: elegido.nombre || 'DESTINATARIO',
    };
  }

  private mapDetalle(detalle: DocumentoSalidaDetalleRegistro) {
    return {
      codigo:
        detalle.codigo_balon?.trim() ||
        detalle.codigo_producto ||
        (detalle.id_producto != null ? String(detalle.id_producto) : 'ZZ'),
      descripcion:
        detalle.glosa?.trim() ||
        detalle.descripcion?.trim() ||
        detalle.nombre_producto ||
        (detalle.id_producto != null
          ? `Producto ${detalle.id_producto}`
          : 'Ítem'),
      unidad: this.mapUnidadItem(
        detalle.codigo_unidad_medida,
        detalle.nombre_unidad_medida,
      ),
      cantidad: Number(detalle.cantidad ?? 0),
    };
  }

  /** Domicilio fiscal desde gen_empresa + ubigeo; ya validado (sin valores fijos). */
  private mapEmpresa(empresa: EmpresaEmisora) {
    const razonSocial =
      empresa.razon_social?.trim() || empresa.nombre_comercial?.trim() || '';
    return {
      ruc: empresa.ruc,
      razonSocial,
      nombreComercial: empresa.nombre_comercial?.trim() || razonSocial,
      address: {
        direccion: (empresa.direccion ?? '').trim(),
        provincia: (empresa.nombre_provincia ?? '').trim().toUpperCase(),
        departamento: (empresa.nombre_departamento ?? '').trim().toUpperCase(),
        distrito: (empresa.nombre_distrito ?? '').trim().toUpperCase(),
        ubigueo: (empresa.codigo_ubigeo ?? '').trim(),
      },
    };
  }

  private mapTipoDocCliente(tipoDocumento?: string | null, numDoc?: string) {
    const tipo = (tipoDocumento ?? '').toUpperCase();
    if (tipo.includes('RUC') || (numDoc?.length ?? 0) === 11) return '6';
    if (tipo.includes('DNI') || (numDoc?.length ?? 0) === 8) return '1';
    if (tipo.includes('CE')) return '4';
    if (tipo.includes('PAS')) return '7';
    return '6';
  }

  private mapTipoDocChofer(codigo?: string | null, numDoc?: string) {
    const c = (codigo ?? '').trim();
    if (['1', '4', '7'].includes(c)) return c;
    if ((numDoc?.length ?? 0) === 8) return '1';
    return '1';
  }

  private mapDesTraslado(nombre?: string | null, codigo?: string | null) {
    const label = (nombre ?? '').replace(/_/g, ' ').trim();
    if (label) return label;
    return (codigo ?? 'TRASLADO').trim() || 'TRASLADO';
  }

  /**
   * Códigos de unidad de SUNAT (catálogo 03). El catálogo interno usa códigos
   * propios ("MT3", "UNID", "LB") que SUNAT no reconoce, así que hay que
   * traducirlos: un metro cúbico es MTQ, no MT3.
   *
   * Se indexa por código y por etiqueta porque doc_obtener_salida devuelve los
   * dos campos cruzados respecto a su nombre (`codigo_unidad_medida` trae la
   * etiqueta y `nombre_unidad_medida` el código), y este mapper no puede
   * depender de cuál de los dos le llegue primero.
   */
  private static readonly UNIDADES_SUNAT: Record<string, string> = {
    UNID: 'NIU',
    UND: 'NIU',
    UNI: 'NIU',
    UNIDAD: 'NIU',
    NIU: 'NIU',
    BOT: 'NIU',
    BOTELLA: 'NIU',
    BOTELLAS: 'NIU',
    PAR: 'PR',
    PR: 'PR',
    KG: 'KGM',
    KGM: 'KGM',
    KILOGRAMO: 'KGM',
    LB: 'LBR',
    LBR: 'LBR',
    MT3: 'MTQ',
    MTQ: 'MTQ',
    'METRO CUBICO': 'MTQ',
    'METRO CÚBICO': 'MTQ',
    M3: 'MTQ',
    MTS: 'MTR',
    MTR: 'MTR',
    METRO: 'MTR',
    LTR: 'LTR',
    LITRO: 'LTR',
    GLN: 'GLL',
    GLL: 'GLL',
    GALON: 'GLL',
    GALÓN: 'GLL',
  };

  /** Resuelve el código SUNAT probando ambos campos del catálogo. */
  private resolverUnidadSunat(
    valores: (string | null | undefined)[],
    porDefecto: string,
  ): string {
    for (const valor of valores) {
      const raw = (valor ?? '').trim().toUpperCase();
      if (!raw) continue;
      const mapeado = DocSalidaDespatchMapper.UNIDADES_SUNAT[raw];
      if (mapeado) return mapeado;
    }
    return porDefecto;
  }

  private mapUnidadPeso(codigo?: string | null, nombre?: string | null) {
    return this.resolverUnidadSunat([nombre, codigo], 'KGM');
  }

  private mapUnidadItem(codigo?: string | null, nombre?: string | null) {
    return this.resolverUnidadSunat([nombre, codigo], 'NIU');
  }

  private parseCorrelativo(numero: string) {
    const limpio = numero.replace(/^0+/, '') || '0';
    const parsed = Number.parseInt(limpio, 10);
    if (Number.isNaN(parsed)) {
      throw new BadRequestException(`Número SUNAT inválido: ${numero}`);
    }
    return String(parsed);
  }

  private formatFecha(fecha: string) {
    const base = fecha.includes('T') ? fecha.slice(0, 10) : fecha.slice(0, 10);
    return `${base}T00:00:00-05:00`;
  }
}
