namespace LastBite.Api.Dtos;

/// <summary>
/// Cantidad va de 1 a 3: es el tope por cliente y publicación (regla RN-09).
/// Si el cliente tiene 3 o más faltas no puede elegir efectivo; eso lo rechaza
/// el procedimiento con EFECTIVO_BLOQUEADO.
/// </summary>
public sealed class CrearReservaRequest
{
    public long PublicacionId { get; set; }
    public short Cantidad { get; set; }
    public short MetodoPagoId { get; set; }
}

/// <summary>
/// Lo que devuelve sp_reserva_crear. El código lo genera la base, no la API.
/// </summary>
public sealed record ReservaCreadaResponse(
    long ReservaId,
    string Codigo,
    decimal Total,
    string Estado);

/// <summary>
/// Fila del historial del cliente. Sale de venta.vw_reserva_detalle.
/// EstadoReserva: PENDIENTE_PAGO, CONFIRMADA, RETIRADA, NO_RETIRADA,
/// CANCELADA o REEMBOLSADA.
/// </summary>
public sealed record ReservaResponse(
    long ReservaId,
    string Codigo,
    string EstadoReserva,
    string? EstadoPago,
    string Bolsa,
    string Sucursal,
    string NombreComercial,
    short Cantidad,
    decimal Total,
    DateOnly Fecha,
    TimeOnly HoraInicioRetiro,
    TimeOnly HoraFinRetiro);

/// <summary>
/// Comprobante. Los importes NO se recalculan: salen de las columnas que se
/// copiaron dentro de la reserva el día de la compra.
/// </summary>
public sealed record ReservaDetalleResponse(
    long ReservaId,
    string Codigo,
    string EstadoReserva,
    string? EstadoPago,
    string Bolsa,
    string Sucursal,
    string NombreComercial,
    string Direccion,
    short Cantidad,
    decimal PrecioUnitario,
    decimal Subtotal,
    decimal Isv,
    decimal Total,
    string? MetodoPago,
    DateOnly Fecha,
    TimeOnly HoraInicioRetiro,
    TimeOnly HoraFinRetiro,
    DateTimeOffset? RetiroDate);

/// <summary>Resultado del pago simulado.</summary>
public sealed record PagoResponse(
    string EstadoPago,
    string EstadoReserva);
