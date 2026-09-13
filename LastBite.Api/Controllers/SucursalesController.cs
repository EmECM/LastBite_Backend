using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>
/// M1 · Comercios y sucursales · endpoints 6 y 7 del contrato.
///
/// Los endpoints de M2 y M4 que cuelgan de una sucursal
/// (/api/sucursales/{id}/publicaciones, /api/sucursales/{id}/reservas)
/// se agregan en sus propios controladores o acá, según los vaya haciendo
/// cada dueño.
/// </summary>
[ApiController]
[Route("api/sucursales")]
[Authorize]
public sealed class SucursalesController : ControllerBase
{
    private readonly ISucursalService _servicio;

    public SucursalesController(ISucursalService servicio) => _servicio = servicio;

    /// <summary>Detalle de la sucursal con su zona, hora límite y horarios.</summary>
    [HttpGet("{id:int}")]
    [ProducesResponseType(typeof(SucursalDetalleResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<SucursalDetalleResponse>> PorId(int id)
    {
        var sucursal = await _servicio.ObtenerAsync(id);

        return sucursal is null
            ? NotFound(new ErrorResponse("SUCURSAL_INEXISTENTE",
                "La sucursal no existe o no está activa."))
            : Ok(sucursal);
    }

    /// <summary>
    /// Locales donde está asignado el empleado en sesión. Un cliente recibe
    /// una lista vacía.
    /// La ruta empieza con "/" para no heredar el prefijo api/sucursales.
    /// </summary>
    [HttpGet("/api/mis-sucursales")]
    [ProducesResponseType(typeof(IReadOnlyList<AsignacionResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<AsignacionResponse>>> Mias()
        => Ok(await _servicio.MisSucursalesAsync(User.ObtenerId()));
}
