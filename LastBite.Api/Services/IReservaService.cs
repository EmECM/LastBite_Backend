using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface IReservaService
{
    Task<ReservaCreadaResponse> CrearAsync(long usuarioId, CrearReservaRequest pedido);
    Task<IReadOnlyList<ReservaResponse>> MisReservasAsync(long clienteId);
    Task<ReservaDetalleResponse> DetalleAsync(long usuarioId, long reservaId);
    Task<PagoResponse> ConfirmarPagoAsync(long usuarioId, long reservaId);
}

public sealed class ReservaService : IReservaService
{
    private readonly IReservaRepository _repositorio;

    public ReservaService(IReservaRepository repositorio) => _repositorio = repositorio;

    public Task<ReservaCreadaResponse> CrearAsync(long usuarioId, CrearReservaRequest pedido)
        => _repositorio.CrearAsync(usuarioId, pedido);

    public Task<IReadOnlyList<ReservaResponse>> MisReservasAsync(long clienteId)
        => _repositorio.MisReservasAsync(clienteId);

    public async Task<ReservaDetalleResponse> DetalleAsync(long usuarioId, long reservaId)
    {
        var estado = await _repositorio.ObtenerEstadoPagoAsync(reservaId)
            ?? throw new ReglaNegocioException("RESERVA_INEXISTENTE", "No existe esa reserva.");

        if (estado.ClienteUsuarioId != usuarioId)
            throw new ReglaNegocioException("RESERVA_AJENA", "Esa reserva no te pertenece.");

        // Ya se comprobó que existe y que es del usuario; el detalle no puede venir nulo.
        return await _repositorio.DetalleAsync(reservaId) ?? throw new InvalidOperationException();
    }

    /// <summary>
    /// El pago se simula: siempre aprueba. Si la reserva ya está confirmada
    /// (los métodos digitales lo quedan desde que se crean) devuelve el estado
    /// actual sin volver a escribir; si sigue pendiente, la captura.
    /// </summary>
    public async Task<PagoResponse> ConfirmarPagoAsync(long usuarioId, long reservaId)
    {
        var estado = await _repositorio.ObtenerEstadoPagoAsync(reservaId)
            ?? throw new ReglaNegocioException("RESERVA_INEXISTENTE", "No existe esa reserva.");

        if (estado.ClienteUsuarioId != usuarioId)
            throw new ReglaNegocioException("RESERVA_AJENA", "Esa reserva no te pertenece.");

        return estado.EstadoReserva switch
        {
            "CONFIRMADA" => new PagoResponse(estado.EstadoPago ?? "CAPTURADO", estado.EstadoReserva),
            "PENDIENTE_PAGO" => await _repositorio.ConfirmarPagoAsync(reservaId, usuarioId),
            _ => throw new ReglaNegocioException(
                "RESERVA_NO_PAGABLE", $"La reserva está en estado {estado.EstadoReserva} y no admite pago.")
        };
    }
}
