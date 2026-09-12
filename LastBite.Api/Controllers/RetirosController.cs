using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>
/// M4 · retiro y validación. Endpoints 10 y 11 del contrato.
///
/// Junta las dos rutas de M4 en un solo controlador, sin [Route] de clase,
/// para no competir con el SucursalesController que Back A todavía no crea
/// (api/sucursales/{id} para el detalle del local es de M1, no de acá).
/// </summary>
[ApiController]
[Authorize]
public sealed class RetirosController : ControllerBase
{
    private readonly IRetiroService _servicio;

    public RetirosController(IRetiroService servicio) => _servicio = servicio;

    /// <summary>Valida el código que dicta el cliente y marca la entrega.</summary>
    [HttpPost("api/retiros")]
    [ProducesResponseType(typeof(EntregaResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<EntregaResponse>> Retirar(EntregarRequest pedido)
        => Ok(await _servicio.RetirarAsync(User.ObtenerId(), pedido));

    /// <summary>Reservas del día en una sucursal. Solo para quien trabaja ahí.</summary>
    [HttpGet("api/sucursales/{id:int}/reservas")]
    [ProducesResponseType(typeof(IReadOnlyList<ReservaPanelResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ReservaPanelResponse>>> PorSucursal(
        int id, [FromQuery] DateOnly? fecha)
        => Ok(await _servicio.ListarPorSucursalAsync(User.ObtenerId(), id, fecha ?? DateOnly.FromDateTime(DateTime.Now)));
}
