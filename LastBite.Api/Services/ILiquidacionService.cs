using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface ILiquidacionService
{
    Task<LiquidacionCreadaResponse> GenerarAsync(long usuarioId, GenerarLiquidacionRequest pedido);
    Task<IReadOnlyList<LiquidacionResponse>> ListarAsync(int? comercioId);
    Task<LiquidacionDetalleResponse> DetalleAsync(int id);
}

public sealed class LiquidacionService : ILiquidacionService
{
    private readonly ILiquidacionRepository _repositorio;

    public LiquidacionService(ILiquidacionRepository repositorio) => _repositorio = repositorio;

    public Task<LiquidacionCreadaResponse> GenerarAsync(long usuarioId, GenerarLiquidacionRequest pedido)
        => _repositorio.GenerarAsync(usuarioId, pedido);

    public Task<IReadOnlyList<LiquidacionResponse>> ListarAsync(int? comercioId)
        => _repositorio.ListarAsync(comercioId);

    public async Task<LiquidacionDetalleResponse> DetalleAsync(int id)
        => await _repositorio.DetalleAsync(id)
            ?? throw new ReglaNegocioException("LIQUIDACION_INEXISTENTE", "No existe esa liquidación.");
}
