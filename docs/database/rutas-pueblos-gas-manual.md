# Vigente desde el 31/10/2026: solo historial

Ruta pueblos conserva salida, retorno, lecturas manuales, consumo y cuadre.
Ninguna etapa modifica stock, genera movimientos ni cambia el estado o ubicación
de cilindros. Las facturas y boletas mantienen su propio efecto en inventario.
La lógica anterior se conserva comentada, incluyendo los auxiliares exclusivos
de rutas, que ahora no tienen efecto aunque se llamen directamente.

Aplicar `database_sql/migraciones/20261031_rutas_pueblos_solo_historial.sql`
después de las migraciones del 30/10. Conserva firmas y permisos. No reaplicar
las migraciones anteriores por separado, porque reactivarían inventario.

La ruta #1 conserva EN_RUTA, sus 14 cilindros, 20 productos y lecturas. La corrección
`database_sql/correcciones/20261031_ruta_1_solo_historial.sql` compensa sus 48
movimientos sin borrarlos: +38 m³ de argón, +53 m³ de oxígeno industrial,
el débito exacto de cada producto adicional y la ubicación/estado anterior de los
cilindros. Las compensaciones no representan un retorno físico. El ajuste rechaza
movimientos posteriores y no vuelve a sumar stock en un reintento completo.

Pruebas y aplicación:

- `node test/rutas-pueblos-historial-local.cjs`: ciclo con stock cero, cancelación,
  reintentos y respeto de ubicaciones cambiadas por ventas; Docker y ROLLBACK.
- `node scripts/rutas-pueblos-historial.cjs --prepare`: captura y respaldo lógico
  de todas las tablas, datos y definiciones del esquema de la aplicación (`public`).
- `node scripts/rutas-pueblos-historial.cjs --test-local`: ensayo con la captura real
  en un esquema aislado; verifica los 22 saldos, 14 cilindros y reintento.
- `node scripts/rutas-pueblos-historial.cjs --apply`: migración y restitución atómicas,
  con respaldo y verificaciones antes de COMMIT.

Para reactivar, revisar conjuntamente llamadas, auxiliares, validaciones, interfaz,
pruebas y ventas. Distinguir las rutas históricas de las futuras rutas con inventario
y evitar devolver stock que nunca se descontó. No basta descomentar una llamada
ni cambiar `control_gas_manual`, que indica el formato de las lecturas.

---

El resto documenta el comportamiento anterior como referencia para reactivación.
Las pruebas manuales antiguas verifican ese contrato anterior.

# Rutas a pueblos: libras y m³ manuales (comportamiento anterior)

Cada cilindro nuevo requiere `lbSalida` y `m3Salida`. En el retorno se registran
`lbRetorno` y `m3Retorno`. Las libras son una lectura de control y no se convierten
en volumen. El producto gas debe estar activo, afectar stock y usar m³
(`MT3`, `M3` o `M³`). El detalle conserva el producto gas elegido al crear la ruta.

## Inventario y ciclo

- Crear la ruta deja el estado ABIERTA y no descuenta gas.
- Al crear y al iniciar se valida la capacidad nominal del tipo de cada cilindro.
  Si está en otra unidad, se necesita su equivalencia configurada con el producto
  gas en m³; las libras y los m³ manuales ingresados no se convierten entre sí.
- Se suman por producto los m³ de todos los cilindros y las cantidades de los
  productos adicionales. Ese total no puede superar el stock del almacén.
  Al iniciar se relee y bloquea el saldo vigente, porque crear una ruta no reserva stock.
  Los rechazos muestran el cilindro y su capacidad o el producto, almacén,
  cantidad disponible y cantidad total solicitada.
- Iniciar descuenta los m³ manuales de cada cilindro. Si falla una salida o no
  alcanza el stock, se revierte la operación completa.
- Retornar suma exclusivamente los m³ manuales que regresan. Se permiten
  retornos parciales de cilindros y cero si se vendió todo su contenido.
- Los m³ y las libras de retorno no pueden superar sus respectivas salidas.
- El consumo es `m3Salida - m3Retorno`, conservado con cuatro decimales.
- Cerrar compara ese consumo con las ventas reportadas. No genera otro débito.
  El usuario confirmó que las ventas se reportan al cerrar, sin emitirlas en POS.
- Cada movimiento de gas tiene ruta, detalle de cilindro, producto, almacén y
  usuario de auditoría. Dos cilindros del mismo gas generan dos movimientos.
  Repetir un retorno idéntico no duplica stock; cambiar un retorno ya guardado
  se rechaza. Los movimientos con documento no se anulan desde el kardex genérico.
- Una ruta manual iniciada no se cancela ni cambia de almacén. Se deben registrar
  sus retornos reales y cerrarla. No se eliminan rutas manuales que ya movieron gas.

Los productos adicionales mantienen su ciclo de cantidades enviadas y retornadas.
En las rutas manuales también deben tener retorno registrado antes del cierre
(usar cero cuando no regresaron).

## Compatibilidad y publicación

Aplicar `database_sql/migraciones/20261030_rutas_pueblos_gas_manual.sql` junto con
la API y el admin de este cambio. La migración agrega campos, dos tipos de
movimiento y actualiza las funciones de rutas. No modifica stock al ejecutarse.

Las rutas anteriores quedan con `control_gas_manual=false`: conservan sus cálculos
anteriores y sus retornos no generan ingresos adicionales de gas. No se convierten
a manual ni se infieren m³ históricos, porque esas salidas no descontaron gas.
Las rutas nuevas creadas por la función quedan con control manual.

No revertir a las funciones anteriores después de registrar rutas manuales sin
revisar sus movimientos: el código anterior no conoce estos débitos e ingresos.

## Pruebas

- `node test/rutas-pueblos-manual-local.cjs`: solo PostgreSQL en Docker local.
  Ejecuta la migración dos veces y usa la función real de movimiento de productos;
  simula el movimiento del envase. Toda la prueba termina en ROLLBACK.
- Casos con stock inicial de 100 m³: salida/retorno 8/2 → 94;
  6/0 → 94; 10/2.7 → 92.7. También verifica reintentos, duplicados, fallos después
  del movimiento de gas, stock insuficiente, cierre y protección de cancelación.
- API: `npx jest --runInBand rutas-pueblos.model.spec.ts`.
- Admin: `node test/ruta-pueblo-manual.cjs`, con Vite en el puerto 5188 y API
  simulada; comprueba ambos formularios y el cierre de 7.3 m³.
