using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface IZonaService
{
    Task<IReadOnlyList<ZonaResponse>> ListarActivasAsync();
}

/// <summary>
/// EJEMPLO DE REFERENCIA.
///
/// Este servicio no hace casi nada porque la consulta es directa, y está bien
/// que así sea: la capa existe para que el controlador nunca hable con el
/// repositorio, y para tener dónde poner las reglas de aplicación cuando
/// aparezcan.
///
/// Dónde va cada tipo de validación:
///   - De forma (que la cantidad sea 1 a 3)      -> en el controlador
///   - De aplicación (que nadie vea lo ajeno)     -> acá, en el servicio
///   - De negocio (que no se reserve sin cupo)    -> YA ESTÁ en la base
/// </summary>
public sealed class ZonaService : IZonaService
{
    private readonly IZonaRepository _repositorio;

    public ZonaService(IZonaRepository repositorio) => _repositorio = repositorio;

    public Task<IReadOnlyList<ZonaResponse>> ListarActivasAsync()
        => _repositorio.ActivasAsync();
}
