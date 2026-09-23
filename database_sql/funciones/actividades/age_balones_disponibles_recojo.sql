-- Balones físicamente entregados, todavía prestados y sin recojo activo.
CREATE OR REPLACE FUNCTION age_balones_disponibles_recojo(p_id_prestamo integer)
RETURNS TABLE (id_detalle integer, id_balon integer, id_producto integer, codigo_balon varchar)
LANGUAGE sql STABLE AS $function$
    SELECT pd.id, pd.id_balon, COALESCE(pd.id_producto, b.id_producto_gas), b.codigo_balon
    FROM bal_prestamo_detalle pd
    JOIN bal_prestamo p ON p.id = pd.id_prestamo
    JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
    JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
    WHERE pd.id_prestamo = p_id_prestamo AND p.estado = 1
      AND p.fecha_retorno_real IS NULL
      AND NOT EXISTS (SELECT 1 FROM gen_lista_opciones ep WHERE ep.id = p.id_estado AND UPPER(TRIM(ep.nombre)) <> 'ACTIVO')
      AND pd.estado = 1 AND pd.rol = 'ENTREGADO' AND pd.fecha_devolucion IS NULL
      -- Dos estados significan "lo tiene el cliente": PRESTADO_CLIENTE lo pone
      -- bal_prestamo_aplicar_salida_cilindro al despachar el préstamo, y
      -- EN_PODER_CLIENTE lo pone la entrega confirmada (age_culminar_entrega o
      -- mostrador). Exigir solo el segundo dejaba sin recojo posible a todo
      -- préstamo que no pasó por un reparto.
      AND UPPER(TRIM(eb.nombre)) IN ('EN_PODER_CLIENTE', 'PRESTADO_CLIENTE')
      AND b.id_cliente_ubicacion = p.id_cliente
      AND NOT EXISTS (
          SELECT 1 FROM age_actividad act
          JOIN gen_lista_opciones ta ON ta.id = act.id_tipo_actividad
          JOIN gen_lista_opciones ea ON ea.id = act.id_estado_actividad
          WHERE act.estado = 1 AND UPPER(TRIM(ta.nombre)) = 'RECOJO'
            AND UPPER(TRIM(ea.nombre)) NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
            AND (EXISTS (SELECT 1 FROM age_actividad_item ai WHERE ai.id_actividad = act.id AND ai.estado = 1 AND ai.id_balon = pd.id_balon)
              OR (act.id_prestamo = pd.id_prestamo AND NOT EXISTS (SELECT 1 FROM age_actividad_item ai WHERE ai.id_actividad = act.id AND ai.estado = 1)))
      );
$function$;
