using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Dtos;

namespace LastBite.Api.Repositories;

public interface ILiquidacionRepository
{
    Task<LiquidacionCreadaResponse> GenerarAsync(long usuarioId, GenerarLiquidacionRequest pedido);
    Task<IReadOnlyList<LiquidacionResponse>> ListarAsync(int? comercioId);
    Task<LiquidacionDetalleResponse?> DetalleAsync(int id);
}

public sealed class LiquidacionRepository : ILiquidacionRepository
{
    private readonly ConexionFactory _fabrica;

    public LiquidacionRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    /// <summary>El único parámetro OUT exige su marcador de posición NULL en el CALL.</summary>
    public async Task<LiquidacionCreadaResponse> GenerarAsync(long usuarioId, GenerarLiquidacionRequest pedido)
    {
        await using var conexion = await _fabrica.AbrirAsync(usuarioId);

        var creada = await conexion.QuerySingleAsync<LiquidacionCreadaRow>(
            "CALL finanza.sp_liquidacion_generar(@comercioId, @desde, @hasta, NULL)",
            new { comercioId = pedido.ComercioId, desde = pedido.Desde, hasta = pedido.Hasta });

        return new LiquidacionCreadaResponse(creada.OLiquidacionId);
    }

    public async Task<IReadOnlyList<LiquidacionResponse>> ListarAsync(int? comercioId)
    {
        const string sql = """
            SELECT id                    AS id,
                   periodo_inicio        AS desde,
                   periodo_fin           AS hasta,
                   cantidad_reservas     AS reservas,
                   total_ventas          AS ventas,
                   total_comision        AS comision,
                   monto_neto            AS total,
                   estado::text          AS estado
              FROM finanza.liquidacion
             WHERE @comercioId IS NULL OR comercio_id = @comercioId
             ORDER BY periodo_inicio DESC
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var filas = await conexion.QueryAsync<LiquidacionResponse>(sql, new { comercioId });
        return filas.ToList();
    }

    public async Task<LiquidacionDetalleResponse?> DetalleAsync(int id)
    {
        await using var conexion = await _fabrica.AbrirAsync();

        const string sqlCabecera = """
            SELECT id                    AS id,
                   periodo_inicio        AS desde,
                   periodo_fin           AS hasta,
                   total_ventas          AS ventas,
                   total_comision        AS comision,
                   monto_neto            AS total,
                   estado::text          AS estado
              FROM finanza.liquidacion
             WHERE id = @id
            """;

        var cabecera = await conexion.QuerySingleOrDefaultAsync<LiquidacionCabeceraRow>(sqlCabecera, new { id });
        if (cabecera is null) return null;

        const string sqlDetalle = """
            SELECT r.codigo             AS codigo,
                   p.fecha              AS fecha,
                   pb.nombre            AS bolsa,
                   dl.monto_comercio    AS monto
              FROM finanza.detalle_liquidacion dl
              JOIN venta.reserva r            ON r.id  = dl.reserva_id
              JOIN oferta.publicacion p       ON p.id  = r.publicacion_id
              JOIN oferta.plantilla_bolsa pb  ON pb.id = p.plantilla_bolsa_id
             WHERE dl.liquidacion_id = @id
             ORDER BY p.fecha, r.codigo
            """;

        var detalle = await conexion.QueryAsync<DetalleLiquidacionResponse>(sqlDetalle, new { id });

        return new LiquidacionDetalleResponse(
            cabecera.Id, cabecera.Desde, cabecera.Hasta, cabecera.Ventas,
            cabecera.Comision, cabecera.Total, cabecera.Estado, detalle.ToList());
    }
}

internal sealed record LiquidacionCreadaRow(int OLiquidacionId);

// Sin constructor posicional: trae DateOnly (ver la nota en ZonaResponse, CatalogoDtos.cs).
internal sealed record LiquidacionCabeceraRow
{
    public int Id { get; init; }
    public DateOnly Desde { get; init; }
    public DateOnly Hasta { get; init; }
    public decimal Ventas { get; init; }
    public decimal Comision { get; init; }
    public decimal Total { get; init; }
    public string Estado { get; init; } = "";
}
