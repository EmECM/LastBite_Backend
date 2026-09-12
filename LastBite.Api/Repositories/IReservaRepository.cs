using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Dtos;

namespace LastBite.Api.Repositories;

public interface IReservaRepository
{
    Task<ReservaCreadaResponse> CrearAsync(long usuarioId, CrearReservaRequest pedido);
    Task<IReadOnlyList<ReservaResponse>> MisReservasAsync(long clienteId);
    Task<ReservaDetalleResponse?> DetalleAsync(long reservaId);
    Task<EstadoPagoRow?> ObtenerEstadoPagoAsync(long reservaId);
    Task<PagoResponse> ConfirmarPagoAsync(long reservaId, long usuarioId);
}

/// <summary>Lo mínimo para decidir si una reserva se puede pagar y quién es su dueño.</summary>
public sealed record EstadoPagoRow(long ClienteUsuarioId, string EstadoReserva, string? EstadoPago);

public sealed class ReservaRepository : IReservaRepository
{
    private readonly ConexionFactory _fabrica;

    public ReservaRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    /// <summary>
    /// Llama a sp_reserva_crear. Los tres NULL finales son p_mpu_id (no se usa
    /// en el MVP) y los dos parámetros OUT, que en PostgreSQL exigen un
    /// marcador de posición en el CALL aunque no se les pase valor.
    /// </summary>
    public async Task<ReservaCreadaResponse> CrearAsync(long usuarioId, CrearReservaRequest pedido)
    {
        await using var conexion = await _fabrica.AbrirAsync(usuarioId);

        var creada = await conexion.QuerySingleAsync<ReservaCreadaRow>(
            "CALL venta.sp_reserva_crear(@pub, @usr, @cant, @metodo, NULL, NULL, NULL)",
            new
            {
                pub = pedido.PublicacionId,
                usr = usuarioId,
                cant = pedido.Cantidad,
                metodo = pedido.MetodoPagoId
            });

        // El procedimiento no devuelve total ni estado; se leen aparte.
        var extra = await conexion.QuerySingleAsync<(decimal Total, string Estado)>(
            "SELECT total, estado::text FROM venta.reserva WHERE id = @id",
            new { id = creada.OReservaId });

        return new ReservaCreadaResponse(creada.OReservaId, creada.OCodigo, extra.Total, extra.Estado);
    }

    public async Task<IReadOnlyList<ReservaResponse>> MisReservasAsync(long clienteId)
    {
        const string sql = """
            SELECT reserva_id, codigo, estado_reserva, estado_pago, bolsa, sucursal,
                   nombre_comercial, cantidad, total, fecha, hora_inicio_retiro, hora_fin_retiro
              FROM venta.vw_reserva_detalle
             WHERE cliente_id = @clienteId
             ORDER BY fecha_reserva DESC
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var filas = await conexion.QueryAsync<ReservaResponse>(sql, new { clienteId });
        return filas.ToList();
    }

    public async Task<ReservaDetalleResponse?> DetalleAsync(long reservaId)
    {
        const string sql = """
            SELECT reserva_id, codigo, estado_reserva, estado_pago, bolsa, sucursal,
                   nombre_comercial, s.direccion, cantidad, precio_unitario, subtotal, isv, total,
                   metodo_pago, fecha, hora_inicio_retiro, hora_fin_retiro, retiro_date
              FROM venta.vw_reserva_detalle v
              JOIN comercio.sucursal s ON s.id = v.sucursal_id
             WHERE reserva_id = @reservaId
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        return await conexion.QuerySingleOrDefaultAsync<ReservaDetalleResponse>(sql, new { reservaId });
    }

    public async Task<EstadoPagoRow?> ObtenerEstadoPagoAsync(long reservaId)
    {
        const string sql = """
            SELECT r.cliente_usuario_id AS cliente_usuario_id,
                   r.estado::text       AS estado_reserva,
                   pg.estado::text      AS estado_pago
              FROM venta.reserva r
              LEFT JOIN venta.pago pg ON pg.reserva_id = r.id
             WHERE r.id = @reservaId
             ORDER BY pg.id DESC
             LIMIT 1
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        return await conexion.QuerySingleOrDefaultAsync<EstadoPagoRow>(sql, new { reservaId });
    }

    /// <summary>
    /// Simula la aprobación: captura el pago que quedó pendiente y confirma la
    /// reserva. No hay procedimiento para esto porque en la vida real sería la
    /// pasarela de pago la que dispara el cambio; acá se hace directo sobre
    /// venta, que es el esquema de Back B.
    /// </summary>
    public async Task<PagoResponse> ConfirmarPagoAsync(long reservaId, long usuarioId)
    {
        await using var conexion = await _fabrica.AbrirAsync(usuarioId);
        await using var transaccion = await conexion.BeginTransactionAsync();

        await conexion.ExecuteAsync(
            "UPDATE venta.pago SET estado = 'CAPTURADO' WHERE reserva_id = @reservaId AND estado = 'PENDIENTE'",
            new { reservaId }, transaccion);

        await conexion.ExecuteAsync(
            "UPDATE venta.reserva SET estado = 'CONFIRMADA' WHERE id = @reservaId",
            new { reservaId }, transaccion);

        await transaccion.CommitAsync();

        return new PagoResponse("CAPTURADO", "CONFIRMADA");
    }
}

internal sealed record ReservaCreadaRow(long OReservaId, string OCodigo);
