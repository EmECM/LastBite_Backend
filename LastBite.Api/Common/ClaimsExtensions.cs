using System.Security.Claims;

namespace LastBite.Api.Common;

/// <summary>
/// Atajos para leer el usuario que viene dentro del token.
/// Se usan en los controladores: User.ObtenerId()
/// </summary>
public static class ClaimsExtensions
{
    /// <summary>Id del usuario en sesión. Lanza si no hay token válido.</summary>
    public static long ObtenerId(this ClaimsPrincipal user)
    {
        var valor = user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new UnauthorizedAccessException("El token no trae el id del usuario.");

        return long.Parse(valor);
    }

    public static string ObtenerCorreo(this ClaimsPrincipal user)
        => user.FindFirstValue(ClaimTypes.Email) ?? "";

    public static bool EsCliente(this ClaimsPrincipal user) => user.IsInRole("CLIENTE");
    public static bool EsComercio(this ClaimsPrincipal user) => user.IsInRole("COMERCIO");
    public static bool EsAdmin(this ClaimsPrincipal user) => user.IsInRole("ADMIN");
}
