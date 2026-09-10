using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>
/// EJEMPLO DE REFERENCIA · endpoint 4 del contrato.
///
/// Molde de todos los controladores:
///   - Recurso en plural, sufijo Controller.
///   - Ruta en minúsculas: api/zonas.
///   - [Authorize] a nivel de clase; [AllowAnonymous] solo donde haga falta.
///   - Sin lógica y sin SQL: valida la forma, llama al servicio y devuelve.
///   - Sin try/catch: de los errores de la base se encarga ErroresMiddleware.
/// </summary>
[ApiController]
[Route("api/zonas")]
[Authorize]
public sealed class ZonasController : ControllerBase
{
    private readonly IZonaService _servicio;

    public ZonasController(IZonaService servicio) => _servicio = servicio;

    /// <summary>Zonas activas con su hora límite y cuántas bolsas hay hoy.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<ZonaResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ZonaResponse>>> Listar()
        => Ok(await _servicio.ListarActivasAsync());
}
