using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Dtos;

namespace LastBite.Api.Repositories;

public interface IMetodoPagoRepository
{
    Task<IReadOnlyList<MetodoPagoResponse>> ActivosAsync();
}

public sealed class MetodoPagoRepository : IMetodoPagoRepository
{
    private readonly ConexionFactory _fabrica;

    public MetodoPagoRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    public async Task<IReadOnlyList<MetodoPagoResponse>> ActivosAsync()
    {
        const string sql = """
            SELECT id                             AS id,
                   codigo                          AS codigo,
                   nombre                          AS nombre,
                   requiere_confirmacion_en_sitio  AS requiere_confirmacion_en_sitio,
                   orden_presentacion               AS orden_presentacion
              FROM venta.metodo_pago
             WHERE es_activo
             ORDER BY orden_presentacion, nombre
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var filas = await conexion.QueryAsync<MetodoPagoResponse>(sql);
        return filas.ToList();
    }
}
