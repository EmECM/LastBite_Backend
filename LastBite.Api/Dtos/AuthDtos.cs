namespace LastBite.Api.Dtos;

// Entrada: class con set, que es lo que necesita el enlazador de modelos.
// Salida: record, porque son inmutables.

public sealed class RegistroRequest
{
    public string Nombres { get; set; } = "";
    public string Apellidos { get; set; } = "";
    public string Correo { get; set; } = "";
    public string Telefono { get; set; } = "";
    public string Contrasena { get; set; } = "";
}

public sealed class LoginRequest
{
    public string Correo { get; set; } = "";
    public string Contrasena { get; set; } = "";
}

public sealed record UsuarioResponse(
    long Id,
    string Nombres,
    string Apellidos,
    string Correo,
    string? Telefono,
    List<string> Roles,
    short NoShows,
    string Estado);

public sealed record LoginResponse(
    string Token,
    UsuarioResponse Usuario);
