-- Function: doc_actualizar_salida
-- Observaciones de la orden después de creada.
--
-- doc_crear_salida las recibe, pero no había forma de corregirlas: una nota que
-- se escribe mal al crear ("envío urgente", "revisar presión de balones")
-- quedaba fija hasta anular el documento. El detalle sí se puede seguir
-- editando en BORRADOR, así que la nota que lo acompaña también debería.
--
-- Se puede editar mientras el documento no esté anulado ni emitido a SUNAT,
-- misma regla que doc_actualizar_traslado: después de la emisión el contenido
-- es inmutable.
--
-- NULL = no cambiar. Para vaciar las observaciones se envía cadena vacía.
DROP FUNCTION IF EXISTS doc_actualizar_salida(p_id integer, p_observaciones character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_actualizar_salida(p_id integer, p_observaciones character varying DEFAULT NULL::character varying, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_estado VARCHAR;
    v_emitido BOOLEAN;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT ec.nombre, COALESCE(d.emitido_sunat, FALSE)
    INTO v_estado, v_emitido
    FROM doc_salida d
    LEFT JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF v_estado = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF v_emitido THEN
        RETURN json_build_object(
            'error', 'El documento ya fue emitido a SUNAT: su contenido no se puede cambiar',
            'registro', NULL
        );
    END IF;

    UPDATE doc_salida
    SET observaciones = CASE
                            WHEN p_observaciones IS NULL THEN observaciones
                            WHEN TRIM(p_observaciones) = '' THEN NULL
                            ELSE p_observaciones
                        END,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
