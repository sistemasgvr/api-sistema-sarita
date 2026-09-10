-- ⚠️ NO EJECUTAR sin revisión — aplicar a mano con apply-migration.js cuando el usuario lo confirme.
--
-- P0/P1 comprobantes:
-- 1) ven_obtener_siguiente_numero: advisory lock por serie
-- 2) ven_crear_comprobante: NC origen ACEPTADO, cap qty NC, correlativo sin confiar en cliente, IGV default 10
-- 3) ven_obtener_comprobante: dias_credito/numero_cuotas + cantidad_nc_previa/cantidad_disponible_nc
--
-- Las definiciones canónicas viven en database_sql/funciones/comprobantes/.
-- Este archivo documenta el despliegue: sincronizar esas funciones a la BD.

\echo 'Aplicar funciones actualizadas:'
\echo '  - ven_obtener_siguiente_numero.sql'
\echo '  - ven_crear_comprobante.sql'
\echo '  - ven_obtener_comprobante.sql'
\echo 'Usar el script de sync de funciones o ejecutar los CREATE OR REPLACE de esos archivos.'
