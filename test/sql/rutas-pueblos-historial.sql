-- Fixture aislado: probar el ciclo completo con inventario sin existencias.
DO $$
DECLARE rid integer; rid2 integer; n integer; foto jsonb; stocks jsonb; r json;
BEGIN
    UPDATE pro_stock SET stock=0;
    SELECT jsonb_agg(to_jsonb(b) ORDER BY id) INTO foto FROM bal_balon b;
    SELECT jsonb_agg(to_jsonb(s) ORDER BY id) INTO stocks FROM pro_stock s;
    SELECT count(*) INTO n FROM inv_movimiento;
    r:=public.bal_crear_ruta_pueblo(p_id_almacen=>1,
        p_detalles=>'[{"idBalon":101,"lbSalida":1300,"m3Salida":10}]',
        p_detalles_productos=>'[{"idProducto":1,"cantidad":4}]');
    PERFORM ok(r->>'error' IS NULL, 'Crear historial con stock cero');
    rid:=(r->'registro'->>'id')::integer;
    PERFORM public.bal_iniciar_ruta_pueblo(rid);
    PERFORM ok((SELECT e.nombre='EN_RUTA' FROM bal_ruta_pueblo r JOIN gen_lista_opciones e ON e.id=r.id_estado WHERE r.id=rid), 'Iniciar cambia el estado de la ruta');
    PERFORM public.bal_movimiento_gas_ruta((SELECT id FROM bal_ruta_pueblo_detalle WHERE id_ruta_pueblo=rid),FALSE);
    PERFORM public.bal_validar_stock_salida_ruta(rid,TRUE);
    -- Simular la venta: el retorno histórico no debe sobrescribir su ubicación.
    UPDATE bal_balon SET id_almacen=NULL,id_cliente_ubicacion=123,id_estado_balon=4 WHERE id=101;
    SELECT jsonb_agg(to_jsonb(b) ORDER BY id) INTO foto FROM bal_balon b;
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,
        '[{"idBalon":101,"lbRetorno":300,"m3Retorno":2.7}]',NULL,
        '[{"idProducto":1,"cantidadRetorno":2}]');
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,
        '[{"idBalon":101,"lbRetorno":300,"m3Retorno":2.7}]',NULL,
        '[{"idProducto":1,"cantidadRetorno":2}]');
    PERFORM ok((SELECT m3_calculado=7.3 FROM bal_ruta_pueblo WHERE id=rid), 'Conserva consumo histórico exacto');
    PERFORM public.bal_cerrar_ruta_pueblo(rid,7.3);
    PERFORM ok((SELECT descuadre_m3=0 FROM bal_ruta_pueblo WHERE id=rid), 'Cierre conserva cuadre');
    PERFORM ok((SELECT jsonb_agg(to_jsonb(b) ORDER BY id)=foto FROM bal_balon b), 'Retorno y cierre respetan el estado y ubicación de una venta');
    PERFORM ok((SELECT jsonb_agg(to_jsonb(s) ORDER BY id)=stocks FROM pro_stock s), 'Ciclo completo no modifica stock ni auditoría del stock');
    PERFORM ok((SELECT count(*)=n FROM inv_movimiento), 'Ciclo y auxiliares no generan movimientos');
    rid2:=crear_manual(102,900,6);
    PERFORM public.bal_iniciar_ruta_pueblo(rid2);
    PERFORM public.bal_actualizar_ruta_pueblo(rid2,p_estado_nombre=>'CANCELADA');
    PERFORM ok((SELECT e.nombre='CANCELADA' FROM bal_ruta_pueblo r JOIN gen_lista_opciones e ON e.id=r.id_estado WHERE r.id=rid2), 'Permite cancelar historial iniciado');
    PERFORM ok((SELECT jsonb_agg(to_jsonb(b) ORDER BY id)=foto FROM bal_balon b), 'Cancelación no modifica cilindros');
    PERFORM ok((public.bal_eliminar_ruta_pueblo(rid2)->>'eliminado')::boolean, 'Elimina lógicamente historial cancelado');
    rid2:=crear_manual(103,900,6);
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid2,'[{"idBalon":103,"lbRetorno":0,"m3Retorno":0}]');
    PERFORM public.bal_cerrar_ruta_pueblo(rid2,6);
    PERFORM ok((SELECT jsonb_agg(to_jsonb(s) ORDER BY id)=stocks FROM pro_stock s) AND (SELECT count(*)=n FROM inv_movimiento), 'Retorno desde ABIERTA tampoco mueve stock');
END $$;
