-- ============================================================
-- Migración: el selector de origen de recojo lista todos los activos
-- Fecha: 2026-09-22
--
-- Problema: age_listar_vencidos_recojo ocultaba todo préstamo/alquiler que
-- ya tuviera una actividad RECOJO vigente y todo préstamo sin balones
-- "disponibles" (age_balones_disponibles_recojo excluye los reservados por un
-- recojo abierto). Al correr age_generar_recojos_por_vencer —que creó un
-- recojo PENDIENTE por cada préstamo activo— el selector "Origen del recojo"
-- del formulario de actividades quedó vacío, aunque hay 6 préstamos activos.
--
-- Decisión: listar TODOS los préstamos/alquileres ACTIVOS (estado ACTIVO y sin
-- devolución real), con un campo nuevo recojo_abierto (id de la actividad
-- RECOJO vigente, o NULL). El front lo muestra como badge para que no se
-- duplique: age_crear_recojo_origen sigue siendo idempotente por origen
-- vigente y responde "creada: false" con la actividad existente.
--
-- Qué cambia
--  1) Se eliminan los filtros NOT EXISTS (vigentes), EXISTS (balones
--     disponibles) y "regulador pendiente" del WHERE: el listado es por
--     estado activo y la validación de "algo que recoger" queda en la
--     creación (age_crear_recojo_origen ya responde con error claro).
--  2) Nuevo campo recojo_abierto en cada fila.
--  3) cilindros_pendientes ahora cuenta los cilindros entregados con el
--     cliente sin ignorar el recojo abierto (antes mostraba 0 en pantalla).
--  4) Orden con NULLS LAST para los orígenes sin fecha pactada.
-- ============================================================

DROP FUNCTION IF EXISTS age_listar_vencidos_recojo(character varying, integer, integer);
DROP FUNCTION IF EXISTS age_listar_vencidos_recojo(character varying, integer, integer, boolean);

CREATE OR REPLACE FUNCTION age_listar_vencidos_recojo(
    p_busqueda character varying DEFAULT ''::character varying,
    p_limite integer DEFAULT 30,
    p_offset integer DEFAULT 0,
    p_incluir_no_vencidos boolean DEFAULT FALSE
)
RETURNS json
LANGUAGE plpgsql
AS $function$
DECLARE
    v_busqueda VARCHAR := LOWER(TRIM(COALESCE(p_busqueda, '')));
    v_rows JSON;
    v_total BIGINT;
BEGIN
    SET TIME ZONE 'America/Lima';

    WITH vigentes AS (
        SELECT a.id, a.id_prestamo, a.id_alquiler
        FROM age_actividad a
        JOIN gen_lista_opciones ta ON ta.id = a.id_tipo_actividad
        JOIN gen_lista_opciones ea ON ea.id = a.id_estado_actividad
        WHERE a.estado = 1
          AND ta.nombre = 'RECOJO'
          AND COALESCE(UPPER(TRIM(ea.nombre)), '') NOT IN ('CANCELADA', 'CANCELADO', 'REALIZADA')
    ),
    base AS (
        SELECT
            'PRESTAMO'::VARCHAR AS origen,
            p.id AS id_origen,
            p.numero_prestamo AS numero,
            p.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ) AS nombre_cliente,
            p.fecha_retorno_pactada AS fecha_pactada,
            (CURRENT_DATE - p.fecha_retorno_pactada)::INTEGER AS dias_vencido,
            (
                SELECT COUNT(*)::INTEGER
                FROM bal_prestamo_detalle pd
                JOIN bal_balon b ON b.id = pd.id_balon AND b.estado = 1
                JOIN gen_lista_opciones eb ON eb.id = b.id_estado_balon
                WHERE pd.id_prestamo = p.id
                  AND pd.estado = 1 AND pd.rol = 'ENTREGADO'
                  AND pd.fecha_devolucion IS NULL
                  AND UPPER(TRIM(eb.nombre)) IN ('EN_PODER_CLIENTE', 'PRESTADO_CLIENTE')
                  AND b.id_cliente_ubicacion = p.id_cliente
            ) AS cilindros_pendientes,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_prestamo = p.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ) AS garantias_activas,
            FALSE AS regulador_pendiente,
            (SELECT v.id FROM vigentes v WHERE v.id_prestamo = p.id ORDER BY v.id DESC LIMIT 1) AS recojo_abierto,
            COALESCE((SELECT json_agg(row_to_json(x)) FROM age_balones_disponibles_recojo(p.id) x), '[]'::JSON) AS balones_disponibles
        FROM bal_prestamo p
        LEFT JOIN cli_clientes c ON c.id = p.id_cliente
        LEFT JOIN gen_lista_opciones ep ON ep.id = p.id_estado
        WHERE p.estado = 1
          AND p.fecha_retorno_real IS NULL
          AND (p_incluir_no_vencidos OR p.fecha_retorno_pactada < CURRENT_DATE)
          AND COALESCE(ep.nombre, 'ACTIVO') = 'ACTIVO'

        UNION ALL

        SELECT
            'ALQUILER'::VARCHAR,
            a.id,
            a.numero_alquiler,
            a.id_cliente,
            COALESCE(
                NULLIF(TRIM(c.razon_social), ''),
                NULLIF(TRIM(CONCAT_WS(' ', c.nombres, c.apellido_paterno, c.apellido_materno)), ''),
                c.numero_documento
            ),
            a.fecha_fin_pactada,
            (CURRENT_DATE - a.fecha_fin_pactada)::INTEGER,
            0::INTEGER,
            (
                SELECT COUNT(*)::INTEGER
                FROM ven_garantia g
                JOIN gen_lista_opciones eg ON eg.id = g.id_estado
                WHERE g.id_alquiler = a.id
                  AND g.estado = 1
                  AND eg.nombre = 'ACTIVA'
            ),
            (
                COALESCE(a.id_producto_regulador, a.id_producto_stock) IS NOT NULL
                AND a.fecha_devolucion_regulador IS NULL
            ),
            (SELECT v.id FROM vigentes v WHERE v.id_alquiler = a.id ORDER BY v.id DESC LIMIT 1),
            '[]'::JSON
        FROM bal_alquiler a
        LEFT JOIN cli_clientes c ON c.id = a.id_cliente
        LEFT JOIN gen_lista_opciones ea ON ea.id = a.id_estado
        WHERE a.estado = 1
          AND a.fecha_fin_real IS NULL
          AND (p_incluir_no_vencidos OR a.fecha_fin_pactada < CURRENT_DATE)
          AND COALESCE(ea.nombre, 'ACTIVO') = 'ACTIVO'
    ),
    filtrado AS (
        SELECT *
        FROM base
        WHERE v_busqueda = ''
           OR LOWER(COALESCE(numero, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(COALESCE(nombre_cliente, '')) LIKE '%' || v_busqueda || '%'
           OR LOWER(origen) LIKE '%' || v_busqueda || '%'
    )
    SELECT
        (SELECT COUNT(*) FROM filtrado),
        (
            SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.dias_vencido DESC NULLS LAST, t.numero), '[]'::JSON)
            FROM (
                SELECT *
                FROM filtrado
                ORDER BY dias_vencido DESC NULLS LAST, numero
                LIMIT GREATEST(COALESCE(p_limite, 30), 1)
                OFFSET GREATEST(COALESCE(p_offset, 0), 0)
            ) t
        )
    INTO v_total, v_rows;

    RETURN json_build_object('registros', v_rows, 'total', v_total);
END;
$function$;
