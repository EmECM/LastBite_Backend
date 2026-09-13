using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface ISucursalService
{
    Task<SucursalDetalleResponse?> ObtenerAsync(int sucursalId);
    Task<IReadOnlyList<AsignacionResponse>> MisSucursalesAsync(long usuarioId);
}

/// <summary>
/// M1 · Comercios y sucursales. Solo lectura: detalle de la sucursal para la
/// app del cliente y locales asignados para el panel del comercio.
/// </summary>
public sealed class SucursalService : ISucursalService
{
    private readonly ISucursalRepository _repositorio;

    public SucursalService(ISucursalRepository repositorio) => _repositorio = repositorio;

    public async Task<SucursalDetalleResponse?> ObtenerAsync(int sucursalId)
    {
        // Null si no existe o si no está operable (comercio suspendido,
        // sucursal dada de baja, licencia vencida): la vista ya la filtra.
        var sucursal = await _repositorio.PorIdAsync(sucursalId);
        if (sucursal is null) return null;

        var horarios = await _repositorio.HorariosAsync(sucursalId);
        return sucursal with { Horarios = horarios };
    }

    public Task<IReadOnlyList<AsignacionResponse>> MisSucursalesAsync(long usuarioId)
        => _repositorio.PorEmpleadoAsync(usuarioId);
}
