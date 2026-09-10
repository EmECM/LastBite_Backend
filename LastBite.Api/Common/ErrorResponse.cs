namespace LastBite.Api.Common;

/// <summary>
/// Forma única de todos los errores de la API.
///
/// El campo Codigo es estable y es el que la aplicación usa para decidir qué
/// texto mostrarle al usuario. El Mensaje es técnico y no debe mostrarse tal cual.
///
/// Ejemplo:  { "codigo": "SIN_CUPO", "mensaje": "SIN_CUPO: quedan 0 bolsas" }
/// </summary>
public sealed record ErrorResponse(string Codigo, string Mensaje);
