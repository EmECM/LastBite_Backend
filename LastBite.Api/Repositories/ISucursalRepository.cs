using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Dtos;

namespace LastBite.Api.Repositories;

public interface ISucursalRepository
{
    Task<SucursalDetalleResponse?> PorIdAsync(int sucursalId);
    Task<List<HorarioResponse>> HorariosAsync(int sucursalId);
    Task<IReadOnlyList<AsignacionResponse>> PorEmpleadoAsync(long usuarioId);
}

/// <summary>
/// M1 · Comercios y sucursales. Solo lectura.
///
/// Ojo con los records: Dapper los arma por constructor, así que el SELECT
/// debe traer las columnas en el MISMO orden y con el MISMO tipo que los
/// parámetros del record (int con int, smallint con short...).
/// </summary>
public sealed class SucursalRepository : ISucursalRepository
{
    private readonly ConexionFactory _fabrica;

    public SucursalRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    public async Task<SucursalDetalleResponse?> PorIdAsync(int sucursalId)
    {
        // La vista ya filtra sucursal activa, comercio ACTIVO, zona activa y
        // licencia vigente. Solo se une a sucursal para traer el teléfono,
        // que la vista no expone.
        const string sql = """
            SELECT v.sucursal_id,
                   v.sucursal,
                   v.nombre_comercial,
                   v.rubro,
                   v.direccion,
                   s.telefono,
                   v.zona_id,
                   v.zona,
                   v.hora_limite_retiro
              FROM comercio.vw_sucursal_activa v
              INNER JOIN comercio.sucursal s
                      ON s.id = v.sucursal_id
             WHERE v.sucursal_id = @sucursal_id
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var fila = await conexion.QuerySingleOrDefaultAsync<SucursalFila>(
            sql, new { sucursal_id = sucursalId });

        if (fila is null) return null;

        // Los horarios se piden aparte (HorariosAsync) y el servicio los agrega.
        return new SucursalDetalleResponse(
            fila.SucursalId, fila.Sucursal, fila.NombreComercial, fila.Rubro,
            fila.Direccion, fila.Telefono, fila.ZonaId, fila.Zona,
            fila.HoraLimiteRetiro, new List<HorarioResponse>());
    }

    public async Task<List<HorarioResponse>> HorariosAsync(int sucursalId)
    {
        // dia_semana va de 1 (lunes) a 7 (domingo), según ck_horario_dia.
        const string sql = """
            SELECT dia_semana,
                   hora_apertura,
                   hora_cierre
              FROM comercio.horario_sucursal
             WHERE sucursal_id = @sucursal_id
             ORDER BY dia_semana
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var filas = await conexion.QueryAsync<HorarioResponse>(sql, new { sucursal_id = sucursalId });
        return filas.ToList();
    }

    public async Task<IReadOnlyList<AsignacionResponse>> PorEmpleadoAsync(long usuarioId)
    {
        // Un empleado solo ve los locales donde está asignado (regla RN-10).
        const string sql = """
            SELECT us.sucursal_id,
                   s.nombre          AS sucursal,
                   us.cargo::text    AS cargo
              FROM comercio.usuario_sucursal us
              INNER JOIN comercio.sucursal s
                      ON s.id = us.sucursal_id
             WHERE us.usuario_id = @usuario_id
               AND s.es_activo
             ORDER BY s.nombre
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var filas = await conexion.QueryAsync<AsignacionResponse>(sql, new { usuario_id = usuarioId });
        return filas.ToList();
    }

    /// <summary>
    /// Fila intermedia: SucursalDetalleResponse lleva la lista de horarios en
    /// el constructor y Dapper no puede armarla directo desde el SELECT.
    /// </summary>
    private sealed class SucursalFila
    {
        public int SucursalId { get; set; }
        public string Sucursal { get; set; } = "";
        public string NombreComercial { get; set; } = "";
        public string Rubro { get; set; } = "";
        public string Direccion { get; set; } = "";
        public string? Telefono { get; set; }
        public int ZonaId { get; set; }
        public string Zona { get; set; } = "";
        public TimeOnly? HoraLimiteRetiro { get; set; }
    }
}
