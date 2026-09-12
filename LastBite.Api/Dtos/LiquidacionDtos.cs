namespace LastBite.Api.Dtos;

/// <summary>
/// Corte de pago al comercio. Solo entran reservas en estado RETIRADA:
/// lo reservado y no recogido no se le paga al comercio.
/// Estado: CALCULADA, PAGADA o ANULADA.
/// </summary>
// Sin constructor posicional: traen DateOnly y Dapper necesita el camino que
// consulta los TypeHandler (ver la nota en ZonaResponse, CatalogoDtos.cs).
public sealed record LiquidacionResponse
{
    public int Id { get; init; }
    public DateOnly Desde { get; init; }
    public DateOnly Hasta { get; init; }
    public int Reservas { get; init; }
    public decimal Ventas { get; init; }
    public decimal Comision { get; init; }
    public decimal Total { get; init; }
    public string Estado { get; init; } = "";
}

public sealed record DetalleLiquidacionResponse
{
    public string Codigo { get; init; } = "";
    public DateOnly Fecha { get; init; }
    public string Bolsa { get; init; } = "";
    public decimal Monto { get; init; }
}

public sealed record LiquidacionDetalleResponse(
    int Id,
    DateOnly Desde,
    DateOnly Hasta,
    decimal Ventas,
    decimal Comision,
    decimal Total,
    string Estado,
    List<DetalleLiquidacionResponse> Detalle);

public sealed class GenerarLiquidacionRequest
{
    public int ComercioId { get; set; }
    public DateOnly Desde { get; set; }
    public DateOnly Hasta { get; set; }
}

public sealed record LiquidacionCreadaResponse(int LiquidacionId);
