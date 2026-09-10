namespace LastBite.Api.Dtos;

/// <summary>
/// Tarjeta del listado del cliente. Sale de oferta.vw_publicacion_vigente, que
/// ya filtra por estado publicado, con cupo y dentro de la ventana de retiro.
/// DescuentoPct viene calculado por la vista: no se recalcula en la app.
/// </summary>
public sealed record PublicacionResponse(
    long PublicacionId,
    string Bolsa,
    string TipoAlimento,
    decimal PrecioVenta,
    decimal ValorEstimado,
    int DescuentoPct,
    short CantidadDisponible,
    DateOnly Fecha,
    TimeOnly HoraInicioRetiro,
    TimeOnly HoraFinRetiro,
    int SucursalId,
    string Sucursal,
    string NombreComercial,
    string Rubro,
    int ZonaId,
    string Zona);

public sealed record PublicacionDetalleResponse(
    long PublicacionId,
    string Bolsa,
    string? Descripcion,
    string TipoAlimento,
    bool EsPerecible,
    string? Alergenos,
    decimal PesoEstimadoKg,
    decimal PrecioVenta,
    decimal ValorEstimado,
    int DescuentoPct,
    short CantidadDisponible,
    DateOnly Fecha,
    TimeOnly HoraInicioRetiro,
    TimeOnly HoraFinRetiro,
    int SucursalId,
    string Sucursal,
    string NombreComercial,
    string Direccion,
    int ZonaId,
    string Zona,
    TimeOnly? HoraLimiteRetiro);

/// <summary>
/// Vista del panel del comercio. Estado: PROGRAMADA, PUBLICADA, AGOTADA,
/// VENCIDA o CANCELADA.
/// </summary>
public sealed record PublicacionPanelResponse(
    long Id,
    string Bolsa,
    DateOnly Fecha,
    TimeOnly HoraInicioRetiro,
    TimeOnly HoraFinRetiro,
    decimal PrecioVenta,
    short CantidadTotal,
    short CantidadDisponible,
    short Reservadas,
    string Estado);

/// <summary>
/// La ventana de retiro debe caber en el horario de la sucursal y no exceder
/// las horas máximas de la categoría. Ambas cosas las valida un trigger.
/// </summary>
public sealed class CrearPublicacionRequest
{
    public int PlantillaBolsaId { get; set; }
    public DateOnly Fecha { get; set; }
    public TimeOnly HoraInicioRetiro { get; set; }
    public TimeOnly HoraFinRetiro { get; set; }
    public short CantidadTotal { get; set; }
    public decimal PrecioVenta { get; set; }
}

public sealed record PublicacionCreadaResponse(long Id, string Estado);

// --------------------------------------------------------------------------
// Plantillas de bolsa: el producto reutilizable del que cuelgan las
// publicaciones diarias.
// --------------------------------------------------------------------------

public sealed record PlantillaResponse(
    int Id,
    string Nombre,
    string? Descripcion,
    short CategoriaAlimentoId,
    string TipoAlimento,
    decimal PrecioBase,
    decimal ValorEstimado,
    decimal PesoEstimadoKg,
    bool RequiereRefrigeracion,
    string? Alergenos,
    bool EsActivo);

/// <summary>
/// ValorEstimado debe ser mayor que PrecioBase: si no hay ahorro, no hay
/// producto. Lo rechaza un trigger de la base.
/// </summary>
public sealed class CrearPlantillaRequest
{
    public string Nombre { get; set; } = "";
    public short CategoriaAlimentoId { get; set; }
    public string? Descripcion { get; set; }
    public decimal PrecioBase { get; set; }
    public decimal ValorEstimado { get; set; }
    public decimal PesoEstimadoKg { get; set; }
    public bool RequiereRefrigeracion { get; set; }
    public string? Alergenos { get; set; }
}
