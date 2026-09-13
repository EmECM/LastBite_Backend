using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Dtos;

namespace LastBite.Api.Repositories;

public interface IZonaRepository
{
    Task<IReadOnlyList<ZonaResponse>> ActivasAsync();
}

/// <summary>
/// EJEMPLO DE REFERENCIA. Este repositorio es la rebanada completa que sirve de
/// molde para todos los demás. Fijate en cuatro cosas:
///
///   1. Todo el SQL vive acá. Ni el controlador ni el servicio tienen consultas.
///   2. La conexión se abre con ConexionFactory y se libera con "await using".
///   3. Las columnas vienen en snake_case y Dapper las mapea a PascalCase
///      gracias a MatchNamesWithUnderscores, que se activa en Program.cs.
///   4. Los métodos son asíncronos y terminan en Async.
/// </summary>
public sealed class ZonaRepository : IZonaRepository
{
    private readonly ConexionFactory _fabrica;

    public ZonaRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    public async Task<IReadOnlyList<ZonaResponse>> ActivasAsync()
    {
        // Solo zonas activas: hay dos zonas sembradas inactivas que no deben
        // aparecer. El conteo de bolsas sale de la vista de publicaciones
        // vigentes, que ya filtra por estado, cupo y ventana horaria.
        // SUM devuelve bigint: el ::int es necesario porque ZonaResponse
        // espera int y Dapper arma los records solo si los tipos coinciden.
        const string sql = """
            SELECT z.id                        AS id,
                   z.nombre                    AS nombre,
                   c.nombre                    AS ciudad,
                   z.hora_limite_retiro        AS hora_limite_retiro,
                   COALESCE(v.bolsas, 0)::int  AS bolsas_disponibles
              FROM geo.zona z
              INNER JOIN geo.ciudad c
                      ON c.id = z.ciudad_id
              LEFT JOIN (
                    SELECT zona_id, SUM(cantidad_disponible) AS bolsas
                      FROM oferta.vw_publicacion_vigente
                     GROUP BY zona_id
                   ) v ON v.zona_id = z.id
             WHERE z.es_activo
             ORDER BY z.nombre
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var filas = await conexion.QueryAsync<ZonaResponse>(sql);
        return filas.ToList();
    }
}
