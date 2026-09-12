namespace LastBite.Api.Dtos;

/// <summary>
/// El empleado teclea el código que muestra el cliente. No hay lector de QR.
/// </summary>
public sealed class EntregarRequest
{
    public string Codigo { get; set; } = "";
}

/// <summary>Lo que devuelve sp_reserva_retirar cuando la entrega es válida.</summary>
public sealed record EntregaResponse(
    long ReservaId,
    string Estado,
    string Cliente,
    string Bolsa,
    short Cantidad);

/// <summary>
/// Fila de la pantalla de reservas del día del panel. Solo aparecen las
/// reservas de la sucursal donde el empleado está asignado.
/// </summary>
public sealed record ReservaPanelResponse
{
    public long ReservaId { get; init; }
    public string Codigo { get; init; } = "";
    public string Cliente { get; init; } = "";
    public string? ClienteTelefono { get; init; }
    public string Bolsa { get; init; } = "";
    public short Cantidad { get; init; }
    public decimal Total { get; init; }
    public string EstadoReserva { get; init; } = "";
    public string? EstadoPago { get; init; }
    public TimeOnly HoraInicioRetiro { get; init; }
    public TimeOnly HoraFinRetiro { get; init; }
    public DateTimeOffset? RetiroDate { get; init; }
    public string? EntregadoPor { get; init; }
}

/// <summary>
/// Resultado de sp_publicacion_vencer: cuántas publicaciones se cerraron y
/// cuántas reservas quedaron marcadas como no retiradas.
/// </summary>
public sealed record CierreResponse(
    int Publicaciones,
    int Reservas);
