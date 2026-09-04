-- Function: fin_listar_medios_pago
-- Fase 3: además del catálogo, devuelve la configuración de cada medio
-- (fin_medio_pago_config) y las cuentas de empresa asociadas, para que el
-- frontend sepa cuándo exigir cuenta bancaria y qué cuentas ofrecer sin
-- necesidad de una segunda llamada.
--
-- `configurado: false` marca los medios que existen en el catálogo pero no
-- tienen fila en fin_medio_pago_config: usarlos lanzará excepción en
-- fin_medio_pago_flag, así que la UI debe poder señalarlos.

DROP FUNCTION IF EXISTS fin_listar_medios_pago();

CREATE OR REPLACE FUNCTION fin_listar_medios_pago()
 RETURNS json
 LANGUAGE sql
 STABLE
AS $function$
    SELECT COALESCE(
        json_agg(
            json_build_object(
                'id', glo.id,
                'nombre', glo.nombre,
                'configurado', (c.id_medio_pago IS NOT NULL),
                'esEfectivo', COALESCE(c.es_efectivo, FALSE),
                'afectaCaja', COALESCE(c.afecta_caja, FALSE),
                'requiereCuentaBancaria', COALESCE(c.requiere_cuenta_bancaria, FALSE),
                'requiereNumeroOperacion', COALESCE(c.requiere_numero_operacion, FALSE),
                'esCredito', COALESCE(c.es_credito, FALSE),
                'cuentas', COALESCE((
                    SELECT json_agg(
                        json_build_object(
                            'id', cb.id,
                            'alias', cb.alias,
                            'titular', cb.titular,
                            'numeroCuenta', cb.numero_cuenta,
                            'telefonoBilletera', cb.telefono_billetera,
                            'banco', b.nombre,
                            'esPredeterminada', cm.es_predeterminada
                        )
                        ORDER BY cm.es_predeterminada DESC, cb.es_principal DESC, cb.id
                    )
                    FROM gen_cuenta_medio_pago cm
                    JOIN gen_cuenta_bancaria cb
                      ON cb.id = cm.id_cuenta_bancaria
                     AND cb.estado = 1
                     AND cb.ambito = 'EMPRESA'
                    LEFT JOIN gen_lista_opciones b ON b.id = cb.id_banco
                    WHERE cm.id_medio_pago = glo.id AND cm.estado = 1
                ), '[]'::json)
            )
            ORDER BY COALESCE(c.orden, 999), glo.id
        ),
        '[]'::json
    )
    FROM gen_lista_opciones glo
    JOIN gen_lista gl ON gl.id = glo.id_lista
    LEFT JOIN fin_medio_pago_config c ON c.id_medio_pago = glo.id AND c.estado = 1
    WHERE gl.nombre = 'MedioPago' AND glo.estado = 1;
$function$;
