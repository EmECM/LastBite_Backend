namespace LastBite.Api.Dtos;

/// <summary>
/// Corte de pago al comercio. Solo entran reservas en estado RETIRADA:
/// lo reservado y no recogido no se le paga al comercio.
/// Estado: CALCULADA, PAGADA o ANULADA.
/// </summary>
public sealed record LiquidacionResponse(
    int Id,
    DateOnly Desde,
    DateOnly Hasta,
    int Reservas,
    decimal Ventas,
    decimal Comision,
    decimal Total,
    string Estado);

public sealed record DetalleLiquidacionResponse(
    string Codigo,
    DateOnly Fecha,
    string Bolsa,
    decimal Monto);

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
