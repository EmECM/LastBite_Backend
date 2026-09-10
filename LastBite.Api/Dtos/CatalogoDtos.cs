namespace LastBite.Api.Dtos;

/// <summary>
/// Zona de la ciudad. HoraLimiteRetiro puede venir nula: las zonas céntricas
/// como el Barrio Los Andes no tienen restricción horaria.
/// </summary>
public sealed record ZonaResponse(
    int Id,
    string Nombre,
    string Ciudad,
    TimeOnly? HoraLimiteRetiro,
    int BolsasDisponibles);

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
