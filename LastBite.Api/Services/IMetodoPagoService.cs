using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface IMetodoPagoService
{
    Task<IReadOnlyList<MetodoPagoResponse>> ListarActivosAsync();
}

public sealed class MetodoPagoService : IMetodoPagoService
{
    private readonly IMetodoPagoRepository _repositorio;

    public MetodoPagoService(IMetodoPagoRepository repositorio) => _repositorio = repositorio;

    public Task<IReadOnlyList<MetodoPagoResponse>> ListarActivosAsync()
        => _repositorio.ActivosAsync();
}
