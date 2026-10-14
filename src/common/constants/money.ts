/** Opciones estándar para validar montos monetarios (2 decimales). */
export const MONEY_NUMBER_OPTIONS = { maxDecimalPlaces: 2 } as const;

/**
 * Decimales admitidos para el precio unitario.
 *
 * El precio unitario no es un monto de caja: se persiste en
 * `numeric(12,6)` y se deriva del importe total de la línea
 * (`importe / cantidad`), por lo que necesita más resolución que los
 * 2 decimales de un monto. El importe de la línea se sigue guardando en
 * `numeric(12,4)`.
 */
export const PRECIO_UNITARIO_NUMBER_OPTIONS = { maxDecimalPlaces: 6 } as const;
