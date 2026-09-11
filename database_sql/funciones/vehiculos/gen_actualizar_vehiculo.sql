-- Synced from DEV via database_sql/scripts/sync-functions-from-dev.js
-- Function: gen_actualizar_vehiculo
-- Overloads: 1
-- Updated: 2026-09-11 — p_clear_id_cliente permite flota propia (id_cliente NULL)
DROP FUNCTION IF EXISTS gen_actualizar_vehiculo(p_id integer, p_id_cliente integer, p_id_tipo_vehiculo integer, p_placa character varying, p_placa2 character varying, p_marca character varying, p_marca2 character varying, p_modelo character varying, p_anio integer, p_color character varying, p_certificado_inscripcion character varying, p_certificado2 character varying, p_id_usuario_auditoria integer);
DROP FUNCTION IF EXISTS gen_actualizar_vehiculo(p_id integer, p_id_cliente integer, p_id_tipo_vehiculo integer, p_placa character varying, p_placa2 character varying, p_marca character varying, p_marca2 character varying, p_modelo character varying, p_anio integer, p_color character varying, p_certificado_inscripcion character varying, p_certificado2 character varying, p_clear_id_cliente boolean, p_id_usuario_auditoria integer);

CREATE OR REPLACE FUNCTION gen_actualizar_vehiculo(p_id integer, p_id_cliente integer DEFAULT NULL::integer, p_id_tipo_vehiculo integer DEFAULT NULL::integer, p_placa character varying DEFAULT NULL::character varying, p_placa2 character varying DEFAULT NULL::character varying, p_marca character varying DEFAULT NULL::character varying, p_marca2 character varying DEFAULT NULL::character varying, p_modelo character varying DEFAULT NULL::character varying, p_anio integer DEFAULT NULL::integer, p_color character varying DEFAULT NULL::character varying, p_certificado_inscripcion character varying DEFAULT NULL::character varying, p_certificado2 character varying DEFAULT NULL::character varying, p_clear_id_cliente boolean DEFAULT false, p_id_usuario_auditoria integer DEFAULT NULL::integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
BEGIN
    SET TIME ZONE 'America/Lima';

    IF p_placa IS NOT NULL AND EXISTS (
        SELECT 1 FROM gen_vehiculo
        WHERE placa = p_placa AND estado = 1 AND id <> p_id
    ) THEN
        RETURN json_build_object('registro', NULL, 'error', 'Ya existe un vehículo activo con esa placa');
    END IF;

    UPDATE gen_vehiculo
    SET
        -- Flota propia: el FE envía idCliente null + p_clear_id_cliente; sin el flag,
        -- COALESCE(null, id_cliente) dejaría el dueño anterior.
        id_cliente = CASE
            WHEN COALESCE(p_clear_id_cliente, FALSE) THEN NULL
            ELSE COALESCE(p_id_cliente, id_cliente)
        END,
        id_tipo_vehiculo = COALESCE(p_id_tipo_vehiculo, id_tipo_vehiculo),
        placa = COALESCE(p_placa, placa),
        placa2 = COALESCE(p_placa2, placa2),
        marca = COALESCE(p_marca, marca),
        marca2 = COALESCE(p_marca2, marca2),
        modelo = COALESCE(p_modelo, modelo),
        anio = COALESCE(p_anio, anio),
        color = COALESCE(p_color, color),
        certificado_inscripcion = COALESCE(p_certificado_inscripcion, certificado_inscripcion),
        certificado2 = COALESCE(p_certificado2, certificado2),
        id_usuario_modificacion = p_id_usuario_auditoria,
        fecha_modificacion = NOW()
    WHERE id = p_id AND estado = 1;

    IF NOT FOUND THEN
        RETURN json_build_object('registro', NULL);
    END IF;

    RETURN gen_obtener_vehiculo(p_id);
END;
$function$;
