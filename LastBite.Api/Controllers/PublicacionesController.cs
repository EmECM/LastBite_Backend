using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>M2 · Oferta y búsqueda · endpoints 8 y 9 del contrato.</summary>
[ApiController]
[Route("api/publicaciones")]
[Authorize]
public sealed class PublicacionesController : ControllerBase
{
    private readonly IPublicacionService _servicio;

    public PublicacionesController(IPublicacionService servicio) => _servicio = servicio;

    /// <summary>Bolsas disponibles ahora mismo, opcionalmente filtradas por zona.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PublicacionResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PublicacionResponse>>> Listar([FromQuery] int? zonaId)
        => Ok(await _servicio.VigentesAsync(zonaId));

    /// <summary>Detalle de una publicación puntual.</summary>
    [HttpGet("{id:long}")]
    [ProducesResponseType(typeof(PublicacionDetalleResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<PublicacionDetalleResponse>> PorId(long id)
    {
        var publicacion = await _servicio.ObtenerAsync(id);

        return publicacion is null
            ? NotFound(new ErrorResponse("PUBLICACION_INEXISTENTE",
                "La publicación no existe o ya no está disponible."))
            : Ok(publicacion);
    }
}
