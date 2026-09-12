using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>M6 · liquidación, solo lectura salvo por el corte mismo. Endpoints 12 y 13.</summary>
[ApiController]
[Route("api/liquidaciones")]
[Authorize]
public sealed class LiquidacionesController : ControllerBase
{
    private readonly ILiquidacionService _servicio;

    public LiquidacionesController(ILiquidacionService servicio) => _servicio = servicio;

    /// <summary>Liquidaciones existentes, opcionalmente filtradas por comercio.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<LiquidacionResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<LiquidacionResponse>>> Listar([FromQuery] int? comercioId)
        => Ok(await _servicio.ListarAsync(comercioId));

    /// <summary>Corte con el detalle de cada reserva que entró en él.</summary>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(LiquidacionDetalleResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<LiquidacionDetalleResponse>> Detalle(int id)
        => Ok(await _servicio.DetalleAsync(id));

    /// <summary>Genera el corte del período. Agrupa lo ya retirado, RN-14.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(LiquidacionCreadaResponse), StatusCodes.Status201Created)]
    public async Task<ActionResult<LiquidacionCreadaResponse>> Generar(GenerarLiquidacionRequest pedido)
    {
        var creada = await _servicio.GenerarAsync(User.ObtenerId(), pedido);
        return CreatedAtAction(nameof(Detalle), new { id = creada.LiquidacionId }, creada);
    }
}
