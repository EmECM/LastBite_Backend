namespace LastBite.Api.Common;

/// <summary>
/// Rechazo de aplicación con la misma forma que los errores P0001 de la base:
/// un código estable en mayúsculas más un mensaje. Se usa para las reglas que
/// no viven en un procedimiento (por ejemplo, "esta reserva no es tuya"),
/// para que ErroresMiddleware las traduzca con el mismo mapa de códigos.
/// </summary>
public sealed class ReglaNegocioException : Exception
{
    public string Codigo { get; }

    public ReglaNegocioException(string codigo, string mensaje) : base(mensaje)
        => Codigo = codigo;
}
