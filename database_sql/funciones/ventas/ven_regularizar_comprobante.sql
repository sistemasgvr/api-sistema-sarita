-- Regulariza serie y número de una factura o boleta tras verificar su validez en SUNAT
DROP FUNCTION IF EXISTS public.ven_regularizar_comprobante (
  p_id integer,
  p_serie character varying,
  p_fecha_emision date,
  p_verificacion jsonb,
  p_cdr_esperado text,
  p_numero_esperado character varying,
  p_id_usuario_auditoria integer
);

CREATE OR REPLACE FUNCTION public.ven_regularizar_comprobante (
  p_id integer,
  p_serie character varying,
  p_fecha_emision date,
  p_verificacion jsonb,
  p_cdr_esperado text,
  p_numero_esperado character varying,
  p_id_usuario_auditoria integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_doc RECORD;
    v_destino VARCHAR;
    v_id_tipo_destino INTEGER;
    v_serie VARCHAR;
    v_numero VARCHAR;
    v_label_anterior VARCHAR;
    v_label_nuevo VARCHAR;
    v_ref_anterior VARCHAR;
    v_ref_nuevo VARCHAR;
    v_id_ref_anterior INTEGER;
    v_id_ref_nuevo INTEGER;
    v_id_pendiente INTEGER;
    v_tiene_envio BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    IF NOT pg_try_advisory_xact_lock(872016, p_id) THEN
        RETURN json_build_object('error', 'Hay una emisión a SUNAT en curso para este comprobante; espera a que termine.', 'registro', NULL);
    END IF;

    SELECT c.*, tc.descripcion AS codigo_tipo, es.nombre AS estado_sunat,
           COALESCE(tv.nombre, 'VENTA') AS nombre_tipo_venta,
           cli.numero_documento AS documento_cliente
    INTO v_doc
    FROM ven_comprobante c
    JOIN gen_lista_opciones tc ON tc.id = c.id_tipo_comprobante
    LEFT JOIN gen_lista_opciones es ON es.id = c.id_estado_sunat
    LEFT JOIN gen_lista_opciones tv ON tv.id = c.id_tipo_venta
    LEFT JOIN cli_clientes cli ON cli.id = c.id_cliente
    WHERE c.id = p_id AND c.estado = 1
    FOR UPDATE OF c;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    IF p_verificacion->>'consultadoEn' IS NULL OR abs(extract(epoch from (now() - (p_verificacion->>'consultadoEn')::timestamptz))) > 300 THEN
        RETURN json_build_object('error','La consulta de validez venció. Repite la verificación antes de regularizar.','registro',NULL);
    END IF;
    v_destino := v_doc.codigo_tipo;

    IF v_doc.codigo_tipo NOT IN ('01', '03') THEN
        RETURN json_build_object('error', 'Solo se puede convertir una boleta o una factura', 'registro', NULL);
    END IF;
    IF v_destino NOT IN ('01', '03') THEN
        RETURN json_build_object('error', 'El tipo destino debe ser 01 (factura) o 03 (boleta)', 'registro', NULL);
    END IF;

    IF p_verificacion->>'codigo' IS DISTINCT FROM '0'
       OR p_verificacion->'consulta'->>'numeroSerie' IS DISTINCT FROM v_doc.serie
       OR (p_verificacion->'consulta'->>'numero')::bigint IS DISTINCT FROM v_doc.numero::bigint
       OR (p_verificacion->'consulta'->>'monto')::numeric IS DISTINCT FROM v_doc.total_importe
       OR p_verificacion->'consulta'->>'fechaEmision' IS DISTINCT FROM to_char(COALESCE(v_doc.fecha_emision_cpe,v_doc.fecha), 'DD/MM/YYYY')
       OR v_doc.cdr_respuesta IS DISTINCT FROM p_cdr_esperado
    THEN
        RETURN json_build_object('error','La verificación de validez no corresponde a la versión actual del comprobante.','registro',NULL);
    END IF;
    IF p_fecha_emision IS DISTINCT FROM (now() AT TIME ZONE 'America/Lima')::date THEN
        RETURN json_build_object('error','El reemplazo debe usar la fecha actual de emisión. La fecha original de la venta se conserva.','registro',NULL);
    END IF;
    IF upper(trim(p_serie)) NOT IN ('F002','B002') OR upper(trim(p_serie)) = v_doc.serie THEN
        RETURN json_build_object('error','Esta regularización utiliza una serie nueva F002 o B002.','registro',NULL);
    END IF;

    IF v_doc.estado_sunat = 'BAJA' THEN
        RETURN json_build_object(
            'error', 'El comprobante ya está ' || v_doc.estado_sunat || ' en SUNAT: no se puede regularizar. Emite una nota de crédito y un comprobante nuevo.',
            'registro', NULL
        );
    END IF;

    v_tiene_envio := NULLIF(TRIM(COALESCE(v_doc.ticket_sunat, '')), '') IS NOT NULL
        OR v_doc.hash_documento IS NOT NULL
        OR v_doc.xml_firmado IS NOT NULL
        OR v_doc.cdr_respuesta IS NOT NULL;

    IF EXISTS (
        SELECT 1
        FROM ven_resumen_diario_detalle rd
        JOIN ven_resumen_diario r ON r.id = rd.id_resumen AND r.estado = 1
        LEFT JOIN gen_lista_opciones er ON er.id = r.id_estado_sunat
        WHERE rd.id_comprobante = p_id AND rd.estado = 1
          AND COALESCE(er.nombre, '') <> 'RECHAZADO'
    ) THEN
        RETURN json_build_object('error', 'La boleta está incluida en un resumen diario enviado a SUNAT: no se puede regularizar.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_comprobante WHERE id_comprobante_origen = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El comprobante tiene notas u otros documentos derivados: no se puede regularizar.', 'registro', NULL);
    END IF;

    IF EXISTS (SELECT 1 FROM ven_percepcion_detalle WHERE id_comprobante = p_id AND estado = 1) THEN
        RETURN json_build_object('error', 'El comprobante figura en un comprobante de percepción: no se puede regularizar.', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1
        FROM doc_salida d
        WHERE d.estado = 1
          AND (d.id_venta = p_id OR EXISTS (
                SELECT 1 FROM doc_salida_referencia r
                WHERE r.id_doc_salida = d.id AND r.id_comprobante = p_id AND r.estado = 1))
          AND (d.emitido_sunat
               OR NULLIF(TRIM(COALESCE(d.ticket_sunat, '')), '') IS NOT NULL
               OR EXISTS (SELECT 1 FROM doc_gre_intento i WHERE i.id_doc_salida = d.id AND i.estado <> 'RECHAZADO'))
    ) THEN
        RETURN json_build_object(
            'error', 'La guía de remisión de esta venta ya se envió a SUNAT citando su número actual: no se puede regularizar.',
            'registro', NULL
        );
    END IF;

    IF v_destino = '01' AND COALESCE(TRIM(v_doc.documento_cliente), '') !~ '^[0-9]{11}$' THEN
        RETURN json_build_object('error', 'La factura requiere un cliente con RUC (11 dígitos). Cambia el cliente antes de convertir.', 'registro', NULL);
    END IF;

    v_serie := UPPER(TRIM(COALESCE(p_serie, '')));
    IF v_serie = '' THEN
        v_serie := CASE WHEN v_destino = '01' THEN 'F' ELSE 'B' END
            || CASE WHEN UPPER(TRIM(v_doc.serie)) ~ '^[FB][0-9]{3}$' THEN substr(UPPER(TRIM(v_doc.serie)), 2) ELSE '001' END;
    END IF;

    IF char_length(v_serie) <> 4 THEN
        RETURN json_build_object('error', 'La serie electrónica debe tener 4 caracteres (ej. F001, B001)', 'registro', NULL);
    END IF;
    IF v_destino = '01' AND left(v_serie, 1) <> 'F' THEN
        RETURN json_build_object('error', 'La factura debe usar serie que inicie con F (ej. F001)', 'registro', NULL);
    END IF;
    IF v_destino = '03' AND left(v_serie, 1) <> 'B' THEN
        RETURN json_build_object('error', 'La boleta debe usar serie que inicie con B (ej. B001)', 'registro', NULL);
    END IF;

    SELECT lo.id INTO v_id_tipo_destino
    FROM gen_lista_opciones lo
    JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'TipoComprobante' AND lo.descripcion = v_destino AND lo.estado = 1
    LIMIT 1;

    IF v_id_tipo_destino IS NULL THEN
        RETURN json_build_object('error', format('Tipo de comprobante %s no configurado', v_destino), 'registro', NULL);
    END IF;

    v_numero := ven_obtener_siguiente_numero(v_id_tipo_destino, v_serie)->>'numero';
    IF v_numero IS NULL OR TRIM(v_numero) = '' THEN
        RETURN json_build_object('error', 'No se pudo asignar el correlativo de la serie ' || v_serie, 'registro', NULL);
    END IF;

    v_label_anterior := v_doc.serie || '-' || v_doc.numero;
    v_label_nuevo := v_serie || '-' || v_numero;

    IF v_numero::bigint IS DISTINCT FROM p_numero_esperado::bigint THEN
        RETURN json_build_object('error','El correlativo cambió durante la verificación. Vuelve a regularizar para comprobar el nuevo número.','registro',NULL);
    END IF;
    INSERT INTO ven_comprobante_historial_cpe
      (id_comprobante, serie, numero, datos_originales, verificacion_sunat, serie_nueva, numero_nuevo, fecha_emision_nueva, id_usuario_creacion)
    VALUES (p_id, v_doc.serie, v_doc.numero, to_jsonb(v_doc), p_verificacion, v_serie, v_numero, p_fecha_emision, p_id_usuario_auditoria);

    v_ref_anterior := ven_resolver_tipo_documento_ref(v_doc.codigo_tipo, v_doc.nombre_tipo_venta);
    v_ref_nuevo := ven_resolver_tipo_documento_ref(v_destino, v_doc.nombre_tipo_venta);

    IF v_ref_anterior <> v_ref_nuevo THEN
        SELECT lo.id INTO v_id_ref_anterior
        FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = v_ref_anterior AND lo.estado = 1
        LIMIT 1;
        SELECT lo.id INTO v_id_ref_nuevo
        FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
        WHERE l.nombre = 'TipoDocumentoRef' AND lo.nombre = v_ref_nuevo AND lo.estado = 1
        LIMIT 1;

        IF v_id_ref_anterior IS NULL OR v_id_ref_nuevo IS NULL THEN
            RAISE EXCEPTION 'Tipo de documento de inventario % o % no configurado', v_ref_anterior, v_ref_nuevo;
        END IF;

        UPDATE inv_movimiento
        SET id_tipo_documento_origen = v_id_ref_nuevo,
            id_usuario_modificacion = p_id_usuario_auditoria,
            fecha_modificacion = NOW()
        WHERE id_documento_origen = p_id
          AND id_tipo_documento_origen = v_id_ref_anterior;
    END IF;

    UPDATE doc_salida_referencia
    SET id_tipo_comprobante = v_id_tipo_destino,
        serie = v_serie,
        numero = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND estado = 1;

    UPDATE doc_salida
    SET observaciones = replace(observaciones, v_label_anterior, v_label_nuevo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_venta = p_id AND estado = 1
      AND observaciones LIKE '%' || v_label_anterior || '%';

    UPDATE fin_cuenta
    SET numero_comprobante = CASE WHEN numero_comprobante IS NULL THEN NULL ELSE v_label_nuevo END,
        descripcion = replace(descripcion, v_label_anterior, v_label_nuevo),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_venta = p_id;

    UPDATE bal_baja_balon
    SET serie_comprobante = v_serie,
        numero_comprobante = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante_venta = p_id;

    UPDATE bal_movimiento_recarga
    SET serie_factura = v_serie,
        numero_factura = v_numero,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id_comprobante = p_id AND serie_factura IS NOT NULL;

    SELECT lo.id INTO v_id_pendiente
    FROM gen_lista_opciones lo JOIN gen_lista l ON l.id = lo.id_lista
    WHERE l.nombre = 'EstadoSunat' AND lo.nombre = 'PENDIENTE' AND lo.estado = 1
    LIMIT 1;

    UPDATE ven_comprobante
    SET id_tipo_comprobante = v_id_tipo_destino,
        serie = v_serie,
        numero = v_numero,
        fecha_emision_cpe = p_fecha_emision,
        id_estado_sunat = COALESCE(v_id_pendiente, id_estado_sunat),
        ticket_sunat = NULL,
        hash_documento = NULL,
        xml_firmado = NULL,
        cdr_respuesta = NULL,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN json_build_object(
        'registro', json_build_object(
            'id', p_id,
            'codigo_tipo_comprobante', v_destino,
            'serie', v_serie,
            'numero', v_numero,
            'serie_anterior', v_doc.serie,
            'numero_anterior', v_doc.numero
        )
    );
END;
$function$;
