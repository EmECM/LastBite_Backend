namespace LastBite.Api.Dtos;

/// <summary>
/// Sale de core.mv_venta_diaria, una vista materializada. No se actualiza sola:
/// hay que refrescarla antes de la demo con
/// REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_venta_diaria;
/// </summary>
public sealed record VentaDiariaResponse(
    DateOnly Fecha,
    int ZonaId,
    string Zona,
    string Rubro,
    int Reservas,
    decimal TotalVendido,
    decimal Comision,
    int NoShows);

/// <summary>
/// Sale de core.mv_ranking_sucursal. Promedio puede venir nulo si la sucursal
/// todavía no tiene calificaciones.
/// </summary>
public sealed record RankingResponse(
    int SucursalId,
    string Sucursal,
    string NombreComercial,
    int Calificaciones,
    decimal? Promedio,
    int Retiradas,
    int NoRetiradas);

/// <summary>
/// Sale de core.mv_impacto_usuario. Está fuera del MVP, pero la vista ya existe
/// y el DTO queda listo por si se toma como valor agregado.
/// </summary>
public sealed record ImpactoResponse(
    long UsuarioId,
    int BolsasRescatadas,
    decimal KgRescatados,
    decimal KgCo2Evitados,
    decimal AhorroTotal);
