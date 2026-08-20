DROP FUNCTION IF EXISTS public.cli_exportar_relacionados(integer[]);

CREATE OR REPLACE FUNCTION public.cli_exportar_relacionados(
    p_ids_cliente integer[]
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_resultado JSON;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT json_build_object(
        'direcciones', COALESCE((
            SELECT json_agg(row_to_json(t))
            FROM (
                SELECT
                    d.id,
                    d.id_cliente,
                    c.razon_social AS cliente_razon_social,
                    c.nombres AS cliente_nombres,
                    c.apellido_paterno AS cliente_apellido_paterno,
                    c.apellido_materno AS cliente_apellido_materno,
                    c.numero_documento AS cliente_numero_documento,
                    d.descripcion,
                    d.direccion,
                    d.id_pais,
                    pa.nombre AS nombre_pais,
                    d.id_departamento,
                    dep.nombre AS nombre_departamento,
                    d.id_provincia,
                    prov.nombre AS nombre_provincia,
                    d.id_distrito,
                    dist.nombre AS nombre_distrito,
                    d.referencia,
                    d.latitud,
                    d.longitud,
                    d.es_principal,
                    d.estado,
                    d.fecha_creacion,
                    d.fecha_modificacion
                FROM cli_direcciones d
                INNER JOIN cli_clientes c ON d.id_cliente = c.id
                LEFT JOIN gen_pais pa ON d.id_pais = pa.id
                LEFT JOIN gen_departamento dep ON d.id_departamento = dep.id
                LEFT JOIN gen_provincia prov ON d.id_provincia = prov.id
                LEFT JOIN gen_distrito dist ON d.id_distrito = dist.id
                WHERE d.id_cliente = ANY(p_ids_cliente)
                ORDER BY d.id_cliente, d.es_principal DESC, d.id DESC
            ) t
        ), '[]'::json),

        'vehiculos', COALESCE((
            SELECT json_agg(row_to_json(t))
            FROM (
                SELECT
                    v.id,
                    v.id_cliente,
                    c.razon_social AS cliente_razon_social,
                    c.nombres AS cliente_nombres,
                    c.apellido_paterno AS cliente_apellido_paterno,
                    c.apellido_materno AS cliente_apellido_materno,
                    c.numero_documento AS cliente_numero_documento,
                    v.id_tipo_vehiculo,
                    tv.nombre AS nombre_tipo_vehiculo,
                    v.placa,
                    v.placa2,
                    v.marca,
                    v.marca2,
                    v.modelo,
                    v.anio,
                    v.color,
                    v.certificado_inscripcion,
                    v.certificado2,
                    v.estado,
                    v.fecha_creacion,
                    v.fecha_modificacion
                FROM gen_vehiculo v
                LEFT JOIN cli_clientes c ON v.id_cliente = c.id
                LEFT JOIN gen_lista_opciones tv ON v.id_tipo_vehiculo = tv.id
                WHERE v.id_cliente = ANY(p_ids_cliente)
                ORDER BY v.id_cliente, v.placa ASC
            ) t
        ), '[]'::json),

        'choferes', COALESCE((
            SELECT json_agg(row_to_json(t))
            FROM (
                SELECT
                    ch.id,
                    ch.id_cliente,
                    c.razon_social AS cliente_razon_social,
                    c.nombres AS cliente_nombres,
                    c.apellido_paterno AS cliente_apellido_paterno,
                    c.apellido_materno AS cliente_apellido_materno,
                    c.numero_documento AS cliente_numero_documento,
                    ch.apellido_paterno,
                    ch.apellido_materno,
                    ch.nombres,
                    ch.id_tipo_documento,
                    td.nombre AS nombre_tipo_documento,
                    ch.numero_documento,
                    ch.telefono,
                    lic.codigo AS codigo_licencia,
                    lic.fecha_emision,
                    lic.fecha_vencimiento,
                    lic.id_tipo_licencia,
                    tl.nombre AS nombre_tipo_licencia,
                    lic.id_categoria_licencia,
                    cl.nombre AS nombre_categoria_licencia,
                    ch.estado,
                    ch.fecha_creacion,
                    ch.fecha_modificacion
                FROM gen_chofer ch
                LEFT JOIN cli_clientes c ON ch.id_cliente = c.id
                LEFT JOIN gen_lista_opciones td ON ch.id_tipo_documento = td.id
                LEFT JOIN LATERAL (
                    SELECT l.codigo, l.fecha_emision, l.fecha_vencimiento,
                           l.id_tipo_licencia, l.id_categoria_licencia
                    FROM gen_licencia l
                    WHERE l.id_chofer = ch.id
                    ORDER BY l.fecha_vencimiento DESC
                    LIMIT 1
                ) lic ON true
                LEFT JOIN gen_lista_opciones tl ON lic.id_tipo_licencia = tl.id
                LEFT JOIN gen_lista_opciones cl ON lic.id_categoria_licencia = cl.id
                WHERE ch.id_cliente = ANY(p_ids_cliente)
                ORDER BY ch.id_cliente, ch.nombres ASC
            ) t
        ), '[]'::json),

        'cuentas_bancarias', COALESCE((
            SELECT json_agg(row_to_json(t))
            FROM (
                SELECT
                    cb.id,
                    cb.id_cliente,
                    c.razon_social AS cliente_razon_social,
                    c.nombres AS cliente_nombres,
                    c.apellido_paterno AS cliente_apellido_paterno,
                    c.apellido_materno AS cliente_apellido_materno,
                    c.numero_documento AS cliente_numero_documento,
                    cb.id_banco,
                    b.nombre AS nombre_banco,
                    cb.id_tipo_cuenta,
                    tc.nombre AS nombre_tipo_cuenta,
                    cb.titular,
                    cb.numero_cuenta,
                    cb.numero_cuenta_interbancaria,
                    cb.telefono_billetera,
                    cb.es_principal,
                    cb.estado,
                    cb.fecha_creacion,
                    cb.fecha_modificacion
                FROM gen_cuenta_bancaria cb
                LEFT JOIN cli_clientes c ON cb.id_cliente = c.id
                LEFT JOIN gen_lista_opciones b ON cb.id_banco = b.id
                LEFT JOIN gen_lista_opciones tc ON cb.id_tipo_cuenta = tc.id
                WHERE cb.id_cliente = ANY(p_ids_cliente)
                ORDER BY cb.id_cliente, cb.es_principal DESC, cb.id ASC
            ) t
        ), '[]'::json)
    )
    INTO v_resultado;

    RETURN v_resultado;
END;
$function$;
