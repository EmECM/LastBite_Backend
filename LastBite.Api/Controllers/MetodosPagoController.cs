using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>Endpoint 5 del contrato · M3.</summary>
[ApiController]
[Route("api/metodos-pago")]
[Authorize]
public sealed class MetodosPagoController : ControllerBase
{
    private readonly IMetodoPagoService _servicio;

    public MetodosPagoController(IMetodoPagoService servicio) => _servicio = servicio;

    /// <summary>Métodos de pago activos, en el orden en que deben mostrarse.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<MetodoPagoResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<MetodoPagoResponse>>> Listar()
        => Ok(await _servicio.ListarActivosAsync());
}
