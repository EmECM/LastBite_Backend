using System.Text.RegularExpressions;
using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>
/// M0 · Identidad y acceso · endpoints 1, 2 y 3 del contrato.
///
/// Registro y login son los únicos endpoints de la API que no piden token.
/// </summary>
[ApiController]
[Route("api/auth")]
[Authorize]
public sealed class AuthController : ControllerBase
{
    // Mismo patrón que el dominio core.dm_correo de la base.
    private const string PatronCorreo = @"^[^@\s]+@[^@\s]+\.[a-zA-Z]{2,}$";

    private readonly IAuthService _servicio;

    public AuthController(IAuthService servicio) => _servicio = servicio;

    /// <summary>Crea una cuenta de cliente. Se le asigna el rol CLIENTE.</summary>
    [HttpPost("registro")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(UsuarioResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status409Conflict)]
    public async Task<ActionResult<UsuarioResponse>> Registrar(RegistroRequest peticion)
    {
        // Validación de forma. Que el correo no esté repetido lo revisa el servicio.
        if (peticion.Nombres.Trim().Length > 60 || peticion.Apellidos.Trim().Length > 60)
            return BadRequest(new ErrorResponse("DATO_INVALIDO",
                "Nombres y apellidos admiten hasta 60 caracteres."));

        var correo = peticion.Correo.Trim();
        if (correo.Length > 120 || !Regex.IsMatch(correo, PatronCorreo))
            return BadRequest(new ErrorResponse("CORREO_INVALIDO",
                "El correo no tiene un formato válido."));

        if (peticion.Contrasena.Length < 8)
            return BadRequest(new ErrorResponse("CONTRASENA_INVALIDA",
                "La contraseña debe tener al menos 8 caracteres."));

        var usuario = await _servicio.RegistrarAsync(peticion);
        return Created("/api/auth/yo", usuario);
    }

    /// <summary>Devuelve el token y el perfil con sus roles.</summary>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<LoginResponse>> Login(LoginRequest peticion)
        => Ok(await _servicio.LoginAsync(peticion));

    /// <summary>Perfil del usuario en sesión. La app lo usa para validar el token guardado.</summary>
    [HttpGet("yo")]
    [ProducesResponseType(typeof(UsuarioResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<UsuarioResponse>> Yo()
        => Ok(await _servicio.ObtenerActualAsync(User.ObtenerId()));
}
