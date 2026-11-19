-- Adjuntos de compra (factura del proveedor en PDF/imagen, guía).
--  * Antes no había dónde guardarlos: el cliente mandaba los PDF por WhatsApp (23/10 y 6/11).
--  * Tabla com_compra_adjunto (vínculo compra ↔ gen_archivo) y funciones listar/agregar/quitar.
--  * La API (compras.controller.ts) expone GET/POST /compras/:id/adjuntos y DELETE /compras/:id/adjuntos/:idAdjunto.
--  * El archivo se sube a storage en la carpeta compras/ (permiso compras.crear o compras.editar;
--    ya no hace falta configuracion_sunat.editar — ver storage-permisos.helper.ts).
-- Idempotente. Respaldar la base antes de publicar.
BEGIN;

CREATE TABLE IF NOT EXISTS public.com_compra_adjunto (
  id serial PRIMARY KEY,
  id_compra integer NOT NULL REFERENCES public.com_comprobante_compra (id),
  id_archivo integer NOT NULL REFERENCES public.gen_archivo (id),
  descripcion character varying(150),
  estado integer DEFAULT 1 NOT NULL,
  id_usuario_creacion integer,
  id_usuario_modificacion integer,
  fecha_creacion timestamp without time zone DEFAULT now(),
  fecha_modificacion timestamp without time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_com_compra_adjunto_compra
  ON public.com_compra_adjunto USING btree (id_compra)
  WHERE (estado = 1);

-- Adjuntos de compra: listar, agregar y quitar (ver tablas/compras/com_compra_adjunto.sql).
-- No exigen caja abierta: adjuntar un documento no mueve dinero ni stock.

-- Lista los adjuntos vigentes de una compra
DROP FUNCTION IF EXISTS public.com_listar_adjuntos_compra (p_id_compra integer);

CREATE OR REPLACE FUNCTION public.com_listar_adjuntos_compra (p_id_compra integer) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_registros JSON;
BEGIN
    SELECT COALESCE(json_agg(json_build_object(
        'id', ad.id,
        'id_compra', ad.id_compra,
        'id_archivo', ad.id_archivo,
        'descripcion', ad.descripcion,
        'nombre_original', ar.nombre_original,
        'ruta', ar.ruta,
        'mime_type', ar.mime_type,
        'tamanio_bytes', ar.tamanio_bytes,
        'fecha_creacion', ad.fecha_creacion,
        'usuario_creacion', u.nombre
    ) ORDER BY ad.fecha_creacion, ad.id), '[]'::JSON)
    INTO v_registros
    FROM com_compra_adjunto ad
    JOIN gen_archivo ar ON ar.id = ad.id_archivo
    LEFT JOIN auth_usuarios u ON u.id = ad.id_usuario_creacion
    WHERE ad.id_compra = p_id_compra
      AND ad.estado = 1;

    RETURN json_build_object('registros', v_registros);
END;
$function$;

-- Vincula un archivo ya subido (carpeta compras/) a una compra
DROP FUNCTION IF EXISTS public.com_agregar_adjunto_compra (p_id_compra integer, p_id_archivo integer, p_descripcion character varying, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.com_agregar_adjunto_compra (
  p_id_compra integer,
  p_id_archivo integer,
  p_descripcion character varying DEFAULT NULL::character varying,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
DECLARE
    v_ruta VARCHAR;
    v_id INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM com_comprobante_compra WHERE id = p_id_compra) THEN
        RETURN json_build_object('error', 'La compra no existe', 'registro', NULL);
    END IF;

    SELECT ruta INTO v_ruta FROM gen_archivo WHERE id = p_id_archivo AND estado = 1;
    IF v_ruta IS NULL THEN
        RETURN json_build_object('error', 'El archivo no existe o fue eliminado. Vuelve a subirlo.', 'registro', NULL);
    END IF;
    -- Solo archivos de la carpeta de compras: evita vincular, por ejemplo, el certificado SUNAT.
    IF v_ruta NOT LIKE 'compras/%' THEN
        RETURN json_build_object('error', 'El archivo no pertenece a la carpeta de compras', 'registro', NULL);
    END IF;

    IF EXISTS (
        SELECT 1 FROM com_compra_adjunto
        WHERE id_compra = p_id_compra AND id_archivo = p_id_archivo AND estado = 1
    ) THEN
        RETURN json_build_object('error', 'Ese archivo ya está adjunto a la compra', 'registro', NULL);
    END IF;

    INSERT INTO com_compra_adjunto (
        id_compra, id_archivo, descripcion, id_usuario_creacion, id_usuario_modificacion
    ) VALUES (
        p_id_compra, p_id_archivo, NULLIF(TRIM(p_descripcion), ''), p_id_usuario_auditoria, p_id_usuario_auditoria
    )
    RETURNING id INTO v_id;

    RETURN json_build_object(
        'error', NULL,
        'registro', (
            SELECT r FROM json_array_elements(
                (com_listar_adjuntos_compra(p_id_compra)->'registros')
            ) r
            WHERE (r->>'id')::INTEGER = v_id
        )
    );
END;
$function$;

-- Quita un adjunto (borrado lógico; el archivo queda en storage como respaldo)
DROP FUNCTION IF EXISTS public.com_eliminar_adjunto_compra (p_id_compra integer, p_id_adjunto integer, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION public.com_eliminar_adjunto_compra (
  p_id_compra integer,
  p_id_adjunto integer,
  p_id_usuario_auditoria integer DEFAULT NULL::integer
) RETURNS json LANGUAGE plpgsql AS $function$
BEGIN
    UPDATE com_compra_adjunto
    SET estado = 0,
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = now()
    WHERE id = p_id_adjunto
      AND id_compra = p_id_compra
      AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('error', 'El adjunto no existe o ya fue quitado', 'eliminado', FALSE);
    END IF;

    RETURN json_build_object('error', NULL, 'eliminado', TRUE);
END;
$function$;

COMMIT;
