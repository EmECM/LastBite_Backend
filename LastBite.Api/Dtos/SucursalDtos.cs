namespace LastBite.Api.Dtos;

/// <summary>Sale de comercio.vw_sucursal_activa.</summary>
public sealed record SucursalResponse(
    int SucursalId,
    string Sucursal,
    string NombreComercial,
    string Rubro,
    string Direccion,
    decimal Latitud,
    decimal Longitud,
    int ZonaId,
    string Zona,
    string Ciudad,
    TimeOnly? HoraLimiteRetiro);

/// <summary>DiaSemana: 0 es domingo.</summary>
public sealed record HorarioResponse(
    short DiaSemana,
    TimeOnly HoraApertura,
    TimeOnly HoraCierre);

public sealed record SucursalDetalleResponse(
    int SucursalId,
    string Sucursal,
    string NombreComercial,
    string Rubro,
    string Direccion,
    string? Telefono,
    int ZonaId,
    string Zona,
    TimeOnly? HoraLimiteRetiro,
    List<HorarioResponse> Horarios);

/// <summary>
/// Sucursal donde un empleado está asignado. Sale de comercio.usuario_sucursal.
/// Cargo es PROPIETARIO, ENCARGADO o CAJERO.
/// </summary>
public sealed record AsignacionResponse(
    int SucursalId,
    string Sucursal,
    string Cargo);
