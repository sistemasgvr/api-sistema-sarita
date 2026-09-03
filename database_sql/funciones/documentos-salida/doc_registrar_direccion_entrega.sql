-- Registra o actualiza la dirección de entrega + coordenadas de un documento
-- de salida. Se puede llamar en cualquier momento del ciclo (BORRADOR o
-- GENERADA) — no mueve inventario ni cambia estado, solo guarda dónde
-- entregar. Si viene de una dirección guardada del cliente (p_id_direccion_cliente),
-- se copia el snapshot de esa fila; si es manual, se usan los parámetros tal cual.
--
-- ⚠️ Requiere las columnas agregadas por
-- database_sql/migraciones/20260904_doc_salida_direccion_entrega.sql
-- (aún sin aplicar — ver ese archivo).
DROP FUNCTION IF EXISTS doc_registrar_direccion_entrega(p_id integer, p_direccion_entrega character varying, p_referencia_entrega character varying, p_latitud numeric, p_longitud numeric, p_id_distrito_entrega integer, p_id_direccion_cliente integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION doc_registrar_direccion_entrega(
    p_id integer,
    p_direccion_entrega character varying DEFAULT NULL::character varying,
    p_referencia_entrega character varying DEFAULT NULL::character varying,
    p_latitud numeric DEFAULT NULL::numeric,
    p_longitud numeric DEFAULT NULL::numeric,
    p_id_distrito_entrega integer DEFAULT NULL::integer,
    p_id_direccion_cliente integer DEFAULT NULL::integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer
)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc RECORD;
    v_direccion VARCHAR;
    v_referencia VARCHAR;
    v_latitud NUMERIC;
    v_longitud NUMERIC;
    v_id_distrito INTEGER;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT d.*, ec.nombre AS estado_ciclo
    INTO v_doc
    FROM doc_salida d
    JOIN gen_lista_opciones ec ON ec.id = d.id_estado_ciclo
    WHERE d.id = p_id AND d.estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El documento de salida no existe o está anulado', 'registro', NULL);
    END IF;

    IF v_doc.estado_ciclo = 'ANULADA' THEN
        RETURN json_build_object('error', 'El documento está anulado', 'registro', NULL);
    END IF;

    IF p_id_direccion_cliente IS NOT NULL THEN
        SELECT cd.direccion, cd.referencia, cd.latitud, cd.longitud, cd.id_distrito
        INTO v_direccion, v_referencia, v_latitud, v_longitud, v_id_distrito
        FROM cli_direcciones cd
        WHERE cd.id = p_id_direccion_cliente AND cd.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La dirección del cliente indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    ELSE
        v_direccion := p_direccion_entrega;
        v_referencia := p_referencia_entrega;
        v_latitud := p_latitud;
        v_longitud := p_longitud;
        v_id_distrito := p_id_distrito_entrega;
    END IF;

    IF COALESCE(TRIM(v_direccion), '') = '' THEN
        RETURN json_build_object('error', 'La dirección de entrega es obligatoria', 'registro', NULL);
    END IF;

    UPDATE doc_salida
    SET direccion_entrega = v_direccion,
        referencia_entrega = v_referencia,
        latitud = v_latitud,
        longitud = v_longitud,
        id_distrito_entrega = v_id_distrito,
        id_direccion_cliente = p_id_direccion_cliente,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
