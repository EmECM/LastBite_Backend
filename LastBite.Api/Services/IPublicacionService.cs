using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface IPublicacionService
{
    Task<IReadOnlyList<PublicacionResponse>> VigentesAsync(int? zonaId);
    Task<PublicacionDetalleResponse?> ObtenerAsync(long publicacionId);
}

/// <summary>M2 · Oferta y búsqueda. Lectura pública de lo disponible hoy.</summary>
public sealed class PublicacionService : IPublicacionService
{
    private readonly IPublicacionRepository _repositorio;

    public PublicacionService(IPublicacionRepository repositorio) => _repositorio = repositorio;

    public Task<IReadOnlyList<PublicacionResponse>> VigentesAsync(int? zonaId)
        => _repositorio.VigentesAsync(zonaId);

    public Task<PublicacionDetalleResponse?> ObtenerAsync(long publicacionId)
        => _repositorio.PorIdAsync(publicacionId);
}
