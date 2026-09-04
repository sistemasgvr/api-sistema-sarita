-- Function: fin_notificar_caja_admins
-- Fase 3 (apunte 1.a.iii): al abrir y al cerrar caja se avisa a los usuarios
-- con rol ADMIN. Vive aparte para que fin_abrir_caja_sesion y
-- fin_cerrar_caja_sesion compartan el mismo texto y la misma clave de dedupe.
--
-- Nunca aborta la operación: si la notificación falla, la caja igual queda
-- abierta o cerrada. Avisar es un efecto secundario, no parte del arqueo.

DROP FUNCTION IF EXISTS fin_notificar_caja_admins(p_id_sesion integer, p_evento character varying, p_id_usuario integer);

CREATE OR REPLACE FUNCTION fin_notificar_caja_admins(
    p_id_sesion integer,
    p_evento character varying,
    p_id_usuario integer DEFAULT NULL::integer
)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_sesion RECORD;
    v_codigo VARCHAR;
    v_titulo VARCHAR;
    v_mensaje TEXT;
    v_actor VARCHAR;
    v_id_admin INT;
    v_dedupe VARCHAR;
BEGIN
    SET TIME ZONE 'America/Lima';

    SELECT s.id, s.fecha, s.monto_inicial, s.monto_efectivo_contado, s.diferencia,
           s.fecha_apertura, s.fecha_cierre, suc.nombre AS sucursal
    INTO v_sesion
    FROM fin_caja_sesion s
    LEFT JOIN gen_sucursal suc ON suc.id = s.id_sucursal
    WHERE s.id = p_id_sesion;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT nombre INTO v_actor FROM auth_usuarios WHERE id = p_id_usuario;

    IF UPPER(p_evento) = 'APERTURA' THEN
        v_codigo := 'CAJA_APERTURA';
        v_titulo := format('Caja abierta — %s', to_char(v_sesion.fecha, 'DD/MM/YYYY'));
        v_mensaje := format(
            '%s abrió la caja%s con un monto inicial de S/ %s.',
            COALESCE(v_actor, 'Un usuario'),
            CASE WHEN v_sesion.sucursal IS NOT NULL THEN ' de ' || v_sesion.sucursal ELSE '' END,
            gen_formato_cantidad(COALESCE(v_sesion.monto_inicial, 0))
        );
        -- La marca de tiempo del evento va en la clave: reabrir la caja sí es un
        -- aviso nuevo, pero repetir la misma llamada no duplica la notificación.
        v_dedupe := format('%s:%s:%s', v_codigo, v_sesion.id,
                           to_char(v_sesion.fecha_apertura, 'YYYYMMDDHH24MISS'));
    ELSE
        v_codigo := 'CAJA_CIERRE';
        v_titulo := format('Caja cerrada — %s', to_char(v_sesion.fecha, 'DD/MM/YYYY'));
        v_mensaje := format(
            '%s cerró la caja%s. Efectivo contado S/ %s, diferencia S/ %s.',
            COALESCE(v_actor, 'Un usuario'),
            CASE WHEN v_sesion.sucursal IS NOT NULL THEN ' de ' || v_sesion.sucursal ELSE '' END,
            gen_formato_cantidad(COALESCE(v_sesion.monto_efectivo_contado, 0)),
            gen_formato_cantidad(COALESCE(v_sesion.diferencia, 0))
        );
        v_dedupe := format('%s:%s:%s', v_codigo, v_sesion.id,
                           to_char(v_sesion.fecha_cierre, 'YYYYMMDDHH24MISS'));
    END IF;

    -- El bloque envuelve también la consulta de destinatarios: abrir o cerrar la
    -- caja no puede fallar porque el aviso no salga.
    BEGIN
        FOR v_id_admin IN
            SELECT (e #>> '{}')::INTEGER
            FROM json_array_elements(
                (auth_listar_ids_usuarios_admin_con_permiso('caja.ver')) -> 'ids'
            ) e
        LOOP
            -- El usuario que hizo la operación ya lo sabe.
            CONTINUE WHEN v_id_admin = p_id_usuario;

            PERFORM gen_crear_notificacion(
                v_id_admin,
                v_codigo,
                v_titulo,
                v_mensaje,
                json_build_object('idSesion', v_sesion.id, 'fecha', v_sesion.fecha),
                v_sesion.id,
                'fin_caja_sesion',
                v_dedupe,
                p_id_usuario
            );
        END LOOP;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'No se pudo notificar % de la sesión %: %', v_codigo, p_id_sesion, SQLERRM;
    END;
END;
$function$;
