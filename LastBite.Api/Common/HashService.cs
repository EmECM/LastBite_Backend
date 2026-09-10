namespace LastBite.Api.Common;

/// <summary>
/// Hash y verificación de contraseñas con BCrypt.
///
/// El factor de costo 11 es el mismo que usa el archivo S003 de la base, así que
/// las contraseñas sembradas se verifican sin configuración adicional.
/// La contraseña de todos los usuarios de prueba es: LastBite2026
/// </summary>
public sealed class HashService
{
    private const int FactorCosto = 11;

    public string Hash(string contrasena)
        => BCrypt.Net.BCrypt.HashPassword(contrasena, FactorCosto);

    /// <summary>
    /// Devuelve true solo si la contraseña corresponde al hash.
    /// Si el hash está corrupto o vacío devuelve false en vez de reventar:
    /// un usuario con datos malos no debe tumbar el login de todos.
    /// </summary>
    public bool Verificar(string contrasena, string hash)
    {
        if (string.IsNullOrWhiteSpace(hash)) return false;

        try
        {
            return BCrypt.Net.BCrypt.Verify(contrasena, hash);
        }
        catch (BCrypt.Net.SaltParseException)
        {
            return false;
        }
    }
}
