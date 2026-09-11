-- Registra o actualiza la dirección de entrega + coordenadas de un documento
-- de salida. Se puede llamar en cualquier momento del ciclo (BORRADOR o
-- GENERADA) — no mueve inventario ni cambia estado, solo guarda dónde
-- entregar. Si viene de una dirección guardada del cliente (p_id_direccion_cliente),
-- se copia el snapshot de esa fila; si es manual, se usan los parámetros tal cual.
--
-- Dirección manual + p_guardar_en_cliente (default TRUE): la dirección se
-- registra también en cli_direcciones del destinatario del documento
-- (id_destinatario → id_cliente → id_proveedor; los proveedores también son
-- filas de cli_clientes) y el doc queda enlazado a esa fila. Así una dirección
-- marcada desde la orden de salida aparece en la ficha del cliente/proveedor
-- y en el mapa (cli_listar_clientes_mapa). Si el cliente ya tiene una
-- dirección activa con el mismo texto se reutiliza (y se completan sus
-- coordenadas/referencia/distrito con lo nuevo) en vez de duplicarla. Solo se
-- marca como principal cuando el cliente aún no tiene una.
--
-- ⚠️ Requiere las columnas agregadas por
-- database_sql/migraciones/20260904_doc_salida_direccion_entrega.sql.
DROP FUNCTION IF EXISTS doc_registrar_direccion_entrega(p_id integer, p_direccion_entrega character varying, p_referencia_entrega character varying, p_latitud numeric, p_longitud numeric, p_id_distrito_entrega integer, p_id_direccion_cliente integer, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS doc_registrar_direccion_entrega(p_id integer, p_direccion_entrega character varying, p_referencia_entrega character varying, p_latitud numeric, p_longitud numeric, p_id_distrito_entrega integer, p_id_direccion_cliente integer, p_id_usuario_auditoria integer, p_guardar_en_cliente boolean);

CREATE OR REPLACE FUNCTION doc_registrar_direccion_entrega(
    p_id integer,
    p_direccion_entrega character varying DEFAULT NULL::character varying,
    p_referencia_entrega character varying DEFAULT NULL::character varying,
    p_latitud numeric DEFAULT NULL::numeric,
    p_longitud numeric DEFAULT NULL::numeric,
    p_id_distrito_entrega integer DEFAULT NULL::integer,
    p_id_direccion_cliente integer DEFAULT NULL::integer,
    p_id_usuario_auditoria integer DEFAULT NULL::integer,
    p_guardar_en_cliente boolean DEFAULT TRUE
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
    v_id_direccion_cliente INTEGER;
    v_id_cliente INTEGER;
    v_id_provincia INTEGER;
    v_id_departamento INTEGER;
    v_id_pais INTEGER;
    v_tiene_principal BOOLEAN;
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

    v_id_direccion_cliente := p_id_direccion_cliente;

    IF p_id_direccion_cliente IS NOT NULL THEN
        SELECT cd.direccion, cd.referencia, cd.latitud, cd.longitud, cd.id_distrito
        INTO v_direccion, v_referencia, v_latitud, v_longitud, v_id_distrito
        FROM cli_direcciones cd
        WHERE cd.id = p_id_direccion_cliente AND cd.estado = 1;

        IF NOT FOUND THEN
            RETURN json_build_object('error', 'La dirección del cliente indicada no existe o está inactiva', 'registro', NULL);
        END IF;
    ELSE
        v_direccion := NULLIF(TRIM(p_direccion_entrega), '');
        v_referencia := NULLIF(TRIM(p_referencia_entrega), '');
        v_latitud := p_latitud;
        v_longitud := p_longitud;
        v_id_distrito := p_id_distrito_entrega;
    END IF;

    IF v_direccion IS NULL THEN
        RETURN json_build_object('error', 'La dirección de entrega es obligatoria', 'registro', NULL);
    END IF;

    -- Dirección manual: asociarla al cliente/proveedor destinatario del documento.
    v_id_cliente := COALESCE(v_doc.id_destinatario, v_doc.id_cliente, v_doc.id_proveedor);

    IF p_id_direccion_cliente IS NULL AND COALESCE(p_guardar_en_cliente, TRUE) AND v_id_cliente IS NOT NULL THEN
        -- Reutilizar una dirección activa con el mismo texto en vez de duplicarla.
        SELECT cd.id
        INTO v_id_direccion_cliente
        FROM cli_direcciones cd
        WHERE cd.id_cliente = v_id_cliente
          AND cd.estado = 1
          AND LOWER(TRIM(cd.direccion)) = LOWER(v_direccion)
        ORDER BY cd.es_principal DESC, cd.id DESC
        LIMIT 1;

        IF v_id_direccion_cliente IS NOT NULL THEN
            UPDATE cli_direcciones
            SET latitud = COALESCE(v_latitud, latitud),
                longitud = COALESCE(v_longitud, longitud),
                referencia = COALESCE(v_referencia, referencia),
                id_distrito = COALESCE(v_id_distrito, id_distrito),
                id_usuario_modificacion = p_id_usuario_auditoria,
                fecha_modificacion = NOW()
            WHERE id = v_id_direccion_cliente;
        ELSE
            IF v_id_distrito IS NOT NULL THEN
                SELECT d.id_provincia, pr.id_departamento, dp.id_pais
                INTO v_id_provincia, v_id_departamento, v_id_pais
                FROM gen_distrito d
                JOIN gen_provincia pr ON pr.id = d.id_provincia
                JOIN gen_departamento dp ON dp.id = pr.id_departamento
                WHERE d.id = v_id_distrito;
            END IF;

            SELECT EXISTS (
                SELECT 1 FROM cli_direcciones cd
                WHERE cd.id_cliente = v_id_cliente AND cd.estado = 1 AND cd.es_principal = TRUE
            ) INTO v_tiene_principal;

            INSERT INTO cli_direcciones (
                id_cliente,
                descripcion,
                direccion,
                id_pais,
                id_departamento,
                id_provincia,
                id_distrito,
                referencia,
                latitud,
                longitud,
                es_principal,
                id_usuario_creacion,
                id_usuario_modificacion
            )
            VALUES (
                v_id_cliente,
                'Entrega ' || COALESCE(v_doc.serie || '-', '') || v_doc.numero,
                v_direccion,
                v_id_pais,
                v_id_departamento,
                v_id_provincia,
                v_id_distrito,
                v_referencia,
                v_latitud,
                v_longitud,
                NOT v_tiene_principal,
                p_id_usuario_auditoria,
                p_id_usuario_auditoria
            )
            RETURNING id INTO v_id_direccion_cliente;
        END IF;
    END IF;

    UPDATE doc_salida
    SET direccion_entrega = v_direccion,
        referencia_entrega = v_referencia,
        latitud = v_latitud,
        longitud = v_longitud,
        id_distrito_entrega = v_id_distrito,
        id_direccion_cliente = v_id_direccion_cliente,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id;

    RETURN doc_obtener_salida(p_id);
END;
$function$;
