using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace LastBite.Api.Common;

/// <summary>
/// Genera el JWT que devuelve el login.
///
/// El token lleva tres cosas: el id del usuario, su correo y un claim de rol por
/// cada rol que tenga (CLIENTE, COMERCIO o ADMIN). El frontend usa los roles
/// para decidir qué superficie abrir.
/// </summary>
public sealed class TokenService
{
    private readonly string _clave;
    private readonly string _issuer;
    private readonly string _audience;
    private readonly int _horas;

    public TokenService(IConfiguration configuracion)
    {
        _clave = configuracion["Jwt:Clave"]
            ?? throw new InvalidOperationException("Falta Jwt:Clave en la configuración.");
        _issuer = configuracion["Jwt:Issuer"] ?? "LastBite";
        _audience = configuracion["Jwt:Audience"] ?? "LastBiteApp";
        _horas = int.TryParse(configuracion["Jwt:HorasVigencia"], out var h) ? h : 12;
    }

    public string Generar(long usuarioId, string correo, IEnumerable<string> roles)
    {
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, usuarioId.ToString()),
            new(ClaimTypes.Email, correo),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        claims.AddRange(roles.Select(r => new Claim(ClaimTypes.Role, r)));

        var credenciales = new SigningCredentials(
            new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_clave)),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _issuer,
            audience: _audience,
            claims: claims,
            expires: DateTime.UtcNow.AddHours(_horas),
            signingCredentials: credenciales);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
