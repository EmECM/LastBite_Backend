using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface IRetiroService
{
    Task<EntregaResponse> RetirarAsync(long empleadoId, EntregarRequest pedido);
    Task<IReadOnlyList<ReservaPanelResponse>> ListarPorSucursalAsync(long empleadoId, int sucursalId, DateOnly fecha);
}

public sealed class RetiroService : IRetiroService
{
    private readonly IRetiroRepository _repositorio;

    public RetiroService(IRetiroRepository repositorio) => _repositorio = repositorio;

    // sp_reserva_retirar ya valida la ventana y que el empleado sea de esa sucursal.
    public Task<EntregaResponse> RetirarAsync(long empleadoId, EntregarRequest pedido)
        => _repositorio.RetirarAsync(pedido.Codigo, empleadoId);

    public async Task<IReadOnlyList<ReservaPanelResponse>> ListarPorSucursalAsync(
        long empleadoId, int sucursalId, DateOnly fecha)
    {
        if (!await _repositorio.EmpleadoPerteneceAsync(empleadoId, sucursalId))
            throw new ReglaNegocioException("EMPLEADO_AJENO", "Esa persona no pertenece a esta sucursal.");

        return await _repositorio.PorSucursalAsync(sucursalId, fecha);
    }
}
