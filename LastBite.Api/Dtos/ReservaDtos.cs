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
// Sin constructor posicional: ver la nota en ZonaResponse (CatalogoDtos.cs).
// Trae DateOnly/TimeOnly, así que necesita el camino de Dapper que sí
// consulta los TypeHandler registrados en Program.cs.
public sealed record ReservaResponse
{
    public long ReservaId { get; init; }
    public string Codigo { get; init; } = "";
    public string EstadoReserva { get; init; } = "";
    public string? EstadoPago { get; init; }
    public string Bolsa { get; init; } = "";
    public string Sucursal { get; init; } = "";
    public string NombreComercial { get; init; } = "";
    public short Cantidad { get; init; }
    public decimal Total { get; init; }
    public DateOnly Fecha { get; init; }
    public TimeOnly HoraInicioRetiro { get; init; }
    public TimeOnly HoraFinRetiro { get; init; }
}

/// <summary>
/// Comprobante. Los importes NO se recalculan: salen de las columnas que se
/// copiaron dentro de la reserva el día de la compra.
/// </summary>
public sealed record ReservaDetalleResponse
{
    public long ReservaId { get; init; }
    public string Codigo { get; init; } = "";
    public string EstadoReserva { get; init; } = "";
    public string? EstadoPago { get; init; }
    public string Bolsa { get; init; } = "";
    public string Sucursal { get; init; } = "";
    public string NombreComercial { get; init; } = "";
    public string Direccion { get; init; } = "";
    public short Cantidad { get; init; }
    public decimal PrecioUnitario { get; init; }
    public decimal Subtotal { get; init; }
    public decimal Isv { get; init; }
    public decimal Total { get; init; }
    public string? MetodoPago { get; init; }
    public DateOnly Fecha { get; init; }
    public TimeOnly HoraInicioRetiro { get; init; }
    public TimeOnly HoraFinRetiro { get; init; }
    public DateTimeOffset? RetiroDate { get; init; }
}

/// <summary>Resultado del pago simulado.</summary>
public sealed record PagoResponse(
    string EstadoPago,
    string EstadoReserva);
