namespace LastBite.Api.Dtos;

/// <summary>
/// Zona de la ciudad. HoraLimiteRetiro puede venir nula: las zonas céntricas
/// como el Barrio Los Andes no tienen restricción horaria.
/// </summary>
// Sin constructor posicional a propósito: Dapper materializa los DTOs con
// DateOnly/TimeOnly asignando propiedad por propiedad (para poder usar los
// TypeHandler de Common/DapperTypeHandlers.cs); con constructor posicional
// intenta encontrar un constructor que reciba exactamente lo que Npgsql
// entrega (TimeSpan, no TimeOnly) y revienta.
public sealed record ZonaResponse
{
    public int Id { get; init; }
    public string Nombre { get; init; } = "";
    public string Ciudad { get; init; } = "";
    public TimeOnly? HoraLimiteRetiro { get; init; }
    public int BolsasDisponibles { get; init; }
}

/// <summary>
/// Categoría de alimento. HorasMaxVentana es el límite sanitario: la comida
/// preparada solo admite 1 hora de ventana de retiro.
/// </summary>
public sealed record CategoriaAlimentoResponse(
    short Id,
    string Nombre,
    bool EsPerecible,
    short HorasMaxVentana);

/// <summary>
/// Método de pago. RequiereConfirmacionEnSitio va en true para el efectivo:
/// el cobro se cierra en el mostrador, no en la app.
/// </summary>
public sealed record MetodoPagoResponse(
    short Id,
    string Codigo,
    string Nombre,
    bool RequiereConfirmacionEnSitio,
    short OrdenPresentacion);
