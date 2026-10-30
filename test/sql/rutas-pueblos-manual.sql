-- Inventario de PRODUCTO usa inv_registrar_movimiento real; el envase está simulado.
DO $$
DECLARE rid integer; n integer;
BEGIN
    BEGIN
        PERFORM crear_manual(101,1200,11);
        RAISE EXCEPTION 'FAIL: capacidad excedida';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%MANUAL-A%11%capacidad máxima%10%', 'Mensaje identifica cilindro, cantidad solicitada y capacidad máxima');
    END;
    UPDATE bal_tipo_balon SET capacidad=NULL WHERE id=4;
    BEGIN
        PERFORM crear_manual(101,1200,8);
        RAISE EXCEPTION 'FAIL: capacidad sin configurar';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%configura la capacidad nominal%', 'Rechaza tipo sin capacidad con mensaje accionable');
    END;
    UPDATE bal_tipo_balon SET capacidad=10 WHERE id=4;
    UPDATE bal_tipo_balon SET id_unidad_medida=2 WHERE id=4;
    BEGIN
        PERFORM crear_manual(101,1200,6);
        RAISE EXCEPTION 'FAIL: capacidad en kg excedida';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%capacidad máxima%5%', 'Valida en m³ la capacidad de un tipo configurado en kg');
    END;
    UPDATE pro_producto SET factor_kg_m3=NULL WHERE id=1;
    BEGIN
        PERFORM crear_manual(101,1200,1);
        RAISE EXCEPTION 'FAIL: equivalencia no configurada';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%Revisa la equivalencia del producto gas%', 'No inventa una capacidad si falta la equivalencia de la unidad del tipo');
    END;
    UPDATE pro_producto SET factor_kg_m3=0.5 WHERE id=1;
    UPDATE bal_tipo_balon SET id_unidad_medida=1 WHERE id=4;
    UPDATE pro_stock SET stock=10 WHERE id_producto=1;
    SELECT count(*) INTO n FROM bal_ruta_pueblo;
    BEGIN
        PERFORM public.bal_crear_ruta_pueblo(p_id_almacen=>1,p_detalles=>'[{"idBalon":101,"lbSalida":900,"m3Salida":8},{"idBalon":102,"lbSalida":1200,"m3Salida":6}]');
        RAISE EXCEPTION 'FAIL: suma supera stock';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%Stock insuficiente%OXIGENO%Principal%disponible 10%solicitado 14%', 'Suma cilindros del mismo gas y explica stock disponible y total solicitado');
    END;
    PERFORM ok((SELECT count(*)=n FROM bal_ruta_pueblo) AND (SELECT stock=10 FROM pro_stock WHERE id_producto=1), 'Crear una ruta inválida no guarda cabecera ni altera stock');
    BEGIN
        PERFORM public.bal_crear_ruta_pueblo(p_id_almacen=>1,
            p_detalles=>'[{"idBalon":101,"lbSalida":900,"m3Salida":8}]',
            p_detalles_productos=>'[{"idProducto":1,"cantidad":4}]');
        RAISE EXCEPTION 'FAIL: gas extra supera stock';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%Stock insuficiente%solicitado 12%', 'Suma también los productos adicionales del mismo gas');
    END;
    rid:=crear_manual(101,1200,10);
    PERFORM ok(rid IS NOT NULL, 'Permite exactamente la capacidad y el stock disponibles');
    PERFORM public.bal_actualizar_ruta_pueblo(rid,p_estado_nombre=>'CANCELADA');
    UPDATE pro_stock SET stock=100 WHERE id_producto=1;
    rid:=crear_manual(101,1200,8);
    UPDATE bal_tipo_balon SET capacidad=6 WHERE id=4;
    BEGIN
        PERFORM public.bal_iniciar_ruta_pueblo(rid);
        RAISE EXCEPTION 'FAIL: tipo cambió';
    EXCEPTION WHEN raise_exception THEN
        PERFORM ok(SQLERRM LIKE '%capacidad máxima%6%', 'Revalida capacidad si el tipo cambió después de crear la ruta');
    END;
    PERFORM ok((SELECT stock=100 FROM pro_stock WHERE id_producto=1), 'Cambio de capacidad no permite una salida inválida');
    UPDATE bal_tipo_balon SET capacidad=10 WHERE id=4;
    PERFORM public.bal_actualizar_ruta_pueblo(rid,p_estado_nombre=>'CANCELADA');
END $$;

DO $$
DECLARE rid integer; rid2 integer; n integer; r json;
BEGIN
    rid:=crear_manual(101,1200,8);
    PERFORM ok((SELECT stock=100 FROM pro_stock WHERE id_producto=1), 'Crear ruta ABIERTA no descuenta gas');
    PERFORM public.bal_iniciar_ruta_pueblo(rid);
    PERFORM ok((SELECT stock=92 FROM pro_stock WHERE id_producto=1), 'Ejemplo 1: salida de 8 m³ descuenta stock');
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":101,"lbRetorno":300,"m3Retorno":2}]');
    PERFORM ok((SELECT stock=94 FROM pro_stock WHERE id_producto=1), 'Ejemplo 1: retorno de 2 m³ reingresa stock');
    SELECT count(*) INTO n FROM inv_movimiento;
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":101,"lbRetorno":300,"m3Retorno":2}]');
    PERFORM ok((SELECT count(*)=n FROM inv_movimiento), 'Repetir retorno no duplica ingreso');
    BEGIN
        PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":101,"lbRetorno":300,"m3Retorno":3}]');
        RAISE EXCEPTION 'FAIL: retorno modificado';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%ya fue registrado%', 'Retorno guardado no se modifica silenciosamente'); END;
    PERFORM public.bal_cerrar_ruta_pueblo(rid,6);
    PERFORM ok((SELECT stock=94 FROM pro_stock WHERE id_producto=1), 'Cerrar reporta consumo sin descontar otra vez');
    PERFORM ok((public.bal_eliminar_ruta_pueblo(rid)->>'eliminado')::boolean=FALSE, 'No se borra la ruta cerrada con movimientos');

    UPDATE pro_stock SET stock=100 WHERE id_producto=1;
    rid:=crear_manual(102,900,6);
    -- Retorno desde ABIERTA inicia la salida primero en la misma transacción.
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":102,"lbRetorno":0,"m3Retorno":0}]');
    PERFORM ok((SELECT stock=94 FROM pro_stock WHERE id_producto=1), 'Ejemplo 2: venta total, retorno cero no suma gas');
    PERFORM ok((SELECT count(*)=1 FROM inv_movimiento WHERE id_documento_origen=rid), 'Cero retorno no crea un movimiento de gas vacío');
    PERFORM public.bal_cerrar_ruta_pueblo(rid,6);

    UPDATE pro_stock SET stock=100 WHERE id_producto=1;
    rid:=crear_manual(103,1300,10);
    PERFORM public.bal_iniciar_ruta_pueblo(rid);
    BEGIN
        PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":103,"lbRetorno":350,"m3Retorno":11}]');
        RAISE EXCEPTION 'FAIL: retorno supera salida';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%no pueden superar%', 'Rechaza m³ de retorno mayores a salida'); END;
    BEGIN
        PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":103,"lbRetorno":350}]');
        RAISE EXCEPTION 'FAIL: retorno sin m3';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%ingresa los m³%', 'Rechaza retorno sin m³ manuales'); END;
    BEGIN
        PERFORM public.bal_actualizar_ruta_pueblo(rid,p_estado_nombre=>'CANCELADA');
        RAISE EXCEPTION 'FAIL: cancelación iniciada';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%no se puede cancelar%', 'No repone gas vendido al cancelar una ruta iniciada'); END;
    BEGIN
        PERFORM public.bal_actualizar_ruta_pueblo(rid,p_id_almacen=>2);
        RAISE EXCEPTION 'FAIL: cambiar almacén';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%cambiar el almacén%', 'Almacén de una ruta iniciada queda fijo'); END;
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":103,"lbRetorno":350,"m3Retorno":2.7}]');
    PERFORM public.bal_cerrar_ruta_pueblo(rid,7.3);
    PERFORM ok((SELECT stock=92.7 FROM pro_stock WHERE id_producto=1), 'Ejemplo 3: stock 92.7, sin truncamiento');
    PERFORM ok((SELECT m3_calculado=7.3 AND descuadre_m3=0 FROM bal_ruta_pueblo WHERE id=rid), 'Consumo manual conserva 7.3 m³ al cerrar');
    PERFORM ok((public.bal_obtener_ruta_pueblo(rid)->'registro'->>'ajuste_truncamiento_m3')::numeric=0, 'Ruta manual no genera ajuste por truncamiento');

    UPDATE pro_stock SET stock=100 WHERE id_producto=1;
    rid:=crear_manual(101,1200,8);
    -- El stock puede reducirse por otra operación entre crear e iniciar.
    UPDATE pro_stock SET stock=5 WHERE id_producto=1;
    SELECT count(*) INTO n FROM inv_movimiento;
    BEGIN
        PERFORM public.bal_iniciar_ruta_pueblo(rid);
        RAISE EXCEPTION 'FAIL: stock insuficiente';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%Stock insuficiente%', 'Rechaza salida sin stock suficiente'); END;
    PERFORM ok((SELECT stock=5 FROM pro_stock WHERE id_producto=1) AND (SELECT count(*)=n FROM inv_movimiento), 'Salida fallida revierte stock y movimientos');
    PERFORM ok((SELECT id_estado=6 FROM bal_ruta_pueblo WHERE id=rid), 'Salida fallida deja la ruta ABIERTA');
    PERFORM public.bal_actualizar_ruta_pueblo(rid,p_estado_nombre=>'CANCELADA');
    PERFORM ok((SELECT stock=5 FROM pro_stock WHERE id_producto=1), 'Cancelar ABIERTA no modifica stock');

    UPDATE pro_stock SET stock=100 WHERE id_producto=1;
    rid:=crear_manual(103,1300,10);
    PERFORM set_config('test_ruta.mov_falla','si',TRUE);
    SELECT count(*) INTO n FROM inv_movimiento;
    BEGIN
        PERFORM public.bal_iniciar_ruta_pueblo(rid);
        RAISE EXCEPTION 'FAIL: error envase salida';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%Movimiento bloqueado%', 'Propaga error de envase después de descontar gas'); END;
    PERFORM ok((SELECT stock=100 FROM pro_stock WHERE id_producto=1) AND (SELECT count(*)=n FROM inv_movimiento), 'Error del envase revierte la salida de gas');
    PERFORM set_config('test_ruta.mov_falla','no',TRUE);
    PERFORM public.bal_iniciar_ruta_pueblo(rid);
    PERFORM set_config('test_ruta.mov_falla','si',TRUE);
    SELECT count(*) INTO n FROM inv_movimiento;
    BEGIN
        PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":103,"lbRetorno":350,"m3Retorno":2.7}]');
        RAISE EXCEPTION 'FAIL: error envase retorno';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%Movimiento bloqueado%', 'Propaga error de envase después de reingresar gas'); END;
    PERFORM ok((SELECT stock=90 FROM pro_stock WHERE id_producto=1) AND (SELECT count(*)=n FROM inv_movimiento), 'Error del envase revierte el ingreso de gas');
    PERFORM ok((SELECT lb_retorno IS NULL AND m3_retorno IS NULL FROM bal_ruta_pueblo_detalle WHERE id_ruta_pueblo=rid), 'Retorno fallido deja ambas lecturas pendientes');
    PERFORM set_config('test_ruta.mov_falla','no',TRUE);
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":103,"lbRetorno":350,"m3Retorno":2.7}]');
    PERFORM public.bal_cerrar_ruta_pueblo(rid,7.3);

    UPDATE pro_stock SET stock=100 WHERE id_producto=1;
    r:=public.bal_crear_ruta_pueblo(p_id_almacen=>1,p_detalles=>'[{"idBalon":101,"lbSalida":900,"m3Salida":8},{"idBalon":102,"lbSalida":1200,"m3Salida":6}]');
    rid:=(r->'registro'->>'id')::integer;
    PERFORM ok(rid IS NOT NULL, 'Crear dos cilindros del mismo gas');
    PERFORM public.bal_iniciar_ruta_pueblo(rid);
    PERFORM ok((SELECT stock=86 FROM pro_stock WHERE id_producto=1), 'Dos cilindros del mismo gas descuentan ambos detalles');
    PERFORM ok((SELECT count(*)=2 FROM inv_movimiento WHERE id_documento_origen=rid), 'Kardex distingue cada cilindro por detalle');
    SELECT count(*) INTO n FROM inv_movimiento;
    BEGIN
        PERFORM public.bal_iniciar_ruta_pueblo(rid);
    EXCEPTION WHEN raise_exception THEN NULL; END;
    PERFORM ok((SELECT count(*)=n FROM inv_movimiento), 'Reintentar inicio no duplica salidas');
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":101,"lbRetorno":100,"m3Retorno":0.1234}]');
    PERFORM ok((SELECT stock=86.1234 FROM pro_stock WHERE id_producto=1), 'Retorno parcial conserva cuatro decimales');
    BEGIN
        PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":102,"lbRetorno":100,"m3Retorno":2},{"idBalon":102,"lbRetorno":100,"m3Retorno":2}]');
        RAISE EXCEPTION 'FAIL: duplicado';
    EXCEPTION WHEN raise_exception THEN PERFORM ok(SQLERRM LIKE '%repetido%', 'Rechaza cilindros duplicados en el mismo retorno'); END;
    PERFORM ok((SELECT stock=86.1234 FROM pro_stock WHERE id_producto=1), 'Error en lote revierte todos sus movimientos');
    PERFORM public.bal_registrar_retorno_ruta_pueblo(rid,'[{"idBalon":102,"lbRetorno":100,"m3Retorno":2}]');
    PERFORM ok((SELECT stock=88.1234 FROM pro_stock WHERE id_producto=1), 'Segundo retorno parcial se suma una sola vez');
    PERFORM ok((SELECT count(*)=2 FROM gen_lista_opciones WHERE nombre IN ('SALIDA_RUTA_PUEBLO','ENTRADA_RETORNO_RUTA_PUEBLO')), 'Migración repetida no duplica tipos de movimiento');
END $$;
