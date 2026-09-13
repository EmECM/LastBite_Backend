namespace LastBite.Api.Common;

/// <summary>
/// Rechazo de una regla de aplicación: algo que la base de datos no valida pero
/// que el servicio sí debe negar. Por ejemplo, credenciales incorrectas o un
/// correo que ya está registrado.
///
/// Los servicios la lanzan y ErroresMiddleware la convierte en
/// { codigo, mensaje } con el estado HTTP indicado, igual que hace con los
/// errores de los procedimientos. Así los controladores siguen sin try/catch.
///
/// Ejemplo:
///     throw new ReglaAplicacionException(StatusCodes.Status409Conflict,
///         "CORREO_DUPLICADO", "Ya existe una cuenta con ese correo.");
/// </summary>
public sealed class ReglaAplicacionException : Exception
{
    /// <summary>Estado HTTP que se devuelve: 400, 401, 403, 404, 409...</summary>
    public int Estado { get; }

    /// <summary>Código estable en mayúsculas que usa el frontend.</summary>
    public string Codigo { get; }

    public ReglaAplicacionException(int estado, string codigo, string mensaje)
        : base(mensaje)
    {
        Estado = estado;
        Codigo = codigo;
    }
}
