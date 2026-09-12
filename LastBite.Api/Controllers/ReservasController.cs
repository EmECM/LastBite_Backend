using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>M3 · reserva y pago. Endpoints 6 a 9 del contrato.</summary>
[ApiController]
[Route("api/reservas")]
[Authorize]
public sealed class ReservasController : ControllerBase
{
    private readonly IReservaService _servicio;

    public ReservasController(IReservaService servicio) => _servicio = servicio;

    /// <summary>Crea la reserva. Bloquea cupo, valida y calcula montos en la base.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(ReservaCreadaResponse), StatusCodes.Status201Created)]
    public async Task<ActionResult<ReservaCreadaResponse>> Crear(CrearReservaRequest pedido)
    {
        var creada = await _servicio.CrearAsync(User.ObtenerId(), pedido);
        return CreatedAtAction(nameof(Detalle), new { id = creada.ReservaId }, creada);
    }

    /// <summary>Historial de reservas del cliente en sesión.</summary>
    [HttpGet("mias")]
    [ProducesResponseType(typeof(IReadOnlyList<ReservaResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ReservaResponse>>> Mias()
        => Ok(await _servicio.MisReservasAsync(User.ObtenerId()));

    /// <summary>Comprobante de una reserva propia.</summary>
    [HttpGet("{id:long}")]
    [ProducesResponseType(typeof(ReservaDetalleResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ReservaDetalleResponse>> Detalle(long id)
        => Ok(await _servicio.DetalleAsync(User.ObtenerId(), id));

    /// <summary>Pago simulado: siempre aprueba.</summary>
    [HttpPost("{id:long}/pago")]
    [ProducesResponseType(typeof(PagoResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<PagoResponse>> Pagar(long id)
        => Ok(await _servicio.ConfirmarPagoAsync(User.ObtenerId(), id));
}
