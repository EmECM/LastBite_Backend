using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Dtos;

namespace LastBite.Api.Repositories;

public interface IRetiroRepository
{
    Task<EntregaResponse> RetirarAsync(string codigo, long empleadoId);
    Task<bool> EmpleadoPerteneceAsync(long empleadoId, int sucursalId);
    Task<IReadOnlyList<ReservaPanelResponse>> PorSucursalAsync(int sucursalId, DateOnly fecha);
}

public sealed class RetiroRepository : IRetiroRepository
{
    private readonly ConexionFactory _fabrica;

    public RetiroRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    /// <summary>
    /// Llama a sp_reserva_retirar. El único parámetro OUT también exige su
    /// marcador de posición NULL en el CALL.
    /// </summary>
    public async Task<EntregaResponse> RetirarAsync(string codigo, long empleadoId)
    {
        await using var conexion = await _fabrica.AbrirAsync(empleadoId);

        var entregada = await conexion.QuerySingleAsync<EntregaRow>(
            "CALL venta.sp_reserva_retirar(@codigo, @empleado, NULL)",
            new { codigo, empleado = empleadoId });

        const string sql = """
            SELECT r.id                             AS reserva_id,
                   r.estado::text                    AS estado,
                   u.nombres || ' ' || u.apellidos   AS cliente,
                   pb.nombre                         AS bolsa,
                   r.cantidad                        AS cantidad
              FROM venta.reserva r
              JOIN seguridad.usuario u        ON u.id  = r.cliente_usuario_id
              JOIN oferta.publicacion p       ON p.id  = r.publicacion_id
              JOIN oferta.plantilla_bolsa pb  ON pb.id = p.plantilla_bolsa_id
             WHERE r.id = @id
            """;

        return await conexion.QuerySingleAsync<EntregaResponse>(sql, new { id = entregada.OReservaId });
    }

    public async Task<bool> EmpleadoPerteneceAsync(long empleadoId, int sucursalId)
    {
        const string sql = """
            SELECT EXISTS(
                SELECT 1 FROM comercio.usuario_sucursal
                 WHERE usuario_id = @empleadoId AND sucursal_id = @sucursalId)
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        return await conexion.ExecuteScalarAsync<bool>(sql, new { empleadoId, sucursalId });
    }

    public async Task<IReadOnlyList<ReservaPanelResponse>> PorSucursalAsync(int sucursalId, DateOnly fecha)
    {
        const string sql = """
            SELECT r.id                             AS reserva_id,
                   r.codigo                          AS codigo,
                   u.nombres || ' ' || u.apellidos   AS cliente,
                   u.telefono                        AS cliente_telefono,
                   pb.nombre                         AS bolsa,
                   r.cantidad                        AS cantidad,
                   r.total                           AS total,
                   r.estado::text                     AS estado_reserva,
                   pg.estado::text                    AS estado_pago,
                   p.hora_inicio_retiro              AS hora_inicio_retiro,
                   p.hora_fin_retiro                 AS hora_fin_retiro,
                   r.retiro_date                     AS retiro_date,
                   e.nombres || ' ' || e.apellidos   AS entregado_por
              FROM venta.reserva r
              JOIN seguridad.usuario u        ON u.id  = r.cliente_usuario_id
              JOIN oferta.publicacion p       ON p.id  = r.publicacion_id
              JOIN oferta.plantilla_bolsa pb  ON pb.id = p.plantilla_bolsa_id
              LEFT JOIN seguridad.usuario e   ON e.id  = r.entrega_usuario_id
              LEFT JOIN LATERAL (
                    SELECT pa.estado FROM venta.pago pa
                     WHERE pa.reserva_id = r.id
                     ORDER BY (pa.estado = 'CAPTURADO') DESC, pa.id DESC
                     LIMIT 1
              ) pg ON true
             WHERE pb.sucursal_id = @sucursalId
               AND p.fecha = @fecha
             ORDER BY p.hora_inicio_retiro, r.id
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var filas = await conexion.QueryAsync<ReservaPanelResponse>(sql, new { sucursalId, fecha });
        return filas.ToList();
    }
}

internal sealed record EntregaRow(long OReservaId);
