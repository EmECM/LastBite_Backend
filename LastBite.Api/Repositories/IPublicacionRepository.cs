using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Dtos;
using System.Linq;

namespace LastBite.Api.Repositories;

public interface IPublicacionRepository
{
    Task<IReadOnlyList<PublicacionResponse>> VigentesAsync(int? zonaId);
    Task<PublicacionDetalleResponse?> PorIdAsync(long publicacionId);
}

/// <summary>
/// M2 · Oferta y búsqueda. Solo lectura sobre oferta.vw_publicacion_vigente,
/// que ya filtra por estado PUBLICADA y cupo disponible.
/// </summary>
public sealed class PublicacionRepository : IPublicacionRepository
{
    private readonly ConexionFactory _fabrica;

    public PublicacionRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    public async Task<IReadOnlyList<PublicacionResponse>> VigentesAsync(int? zonaId)
    {
        const string sql = """
            SELECT publicacion_id, bolsa, tipo_alimento,
                   precio_venta, valor_estimado, descuento_pct::int AS descuento_pct, cantidad_disponible,
                   fecha, hora_inicio_retiro, hora_fin_retiro,
                   sucursal_id, sucursal, nombre_comercial, rubro,
                   zona_id, zona
              FROM oferta.vw_publicacion_vigente
             WHERE (@zonaId IS NULL OR zona_id = @zonaId)
             ORDER BY hora_inicio_retiro
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        // Se lee a una clase con propiedades (no al record directo): Dapper no
        // arma bien un record de constructor posicional cuando hay columnas
        // DateOnly/TimeOnly de por medio, aunque el TypeHandler esté
        // registrado. Con propiedades sí lo respeta.
        var filas = await conexion.QueryAsync<PublicacionFila>(sql, new { zonaId });
        return filas.Select(f => new PublicacionResponse(
            f.PublicacionId, f.Bolsa, f.TipoAlimento,
            f.PrecioVenta, f.ValorEstimado, f.DescuentoPct, f.CantidadDisponible,
            f.Fecha, f.HoraInicioRetiro, f.HoraFinRetiro,
            f.SucursalId, f.Sucursal, f.NombreComercial, f.Rubro,
            f.ZonaId, f.Zona)).ToList();
    }

    public async Task<PublicacionDetalleResponse?> PorIdAsync(long publicacionId)
    {
        // La vista no trae hora_limite_retiro (es de la sucursal, no de la
        // publicación), así que se agrega con un join a vw_sucursal_activa.
        const string sql = """
            SELECT v.publicacion_id, v.bolsa, v.descripcion, v.tipo_alimento,
                   v.es_perecible, v.alergenos, v.peso_estimado_kg,
                   v.precio_venta, v.valor_estimado, v.descuento_pct::int AS descuento_pct, v.cantidad_disponible,
                   v.fecha, v.hora_inicio_retiro, v.hora_fin_retiro,
                   v.sucursal_id, v.sucursal, v.nombre_comercial,
                   v.direccion, v.zona_id, v.zona,
                   sa.hora_limite_retiro
              FROM oferta.vw_publicacion_vigente v
              INNER JOIN comercio.vw_sucursal_activa sa ON sa.sucursal_id = v.sucursal_id
             WHERE v.publicacion_id = @publicacion_id
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var fila = await conexion.QuerySingleOrDefaultAsync<PublicacionDetalleFila>(
            sql, new { publicacion_id = publicacionId });

        if (fila is null) return null;

        return new PublicacionDetalleResponse(
            fila.PublicacionId, fila.Bolsa, fila.Descripcion, fila.TipoAlimento,
            fila.EsPerecible, fila.Alergenos, fila.PesoEstimadoKg,
            fila.PrecioVenta, fila.ValorEstimado, fila.DescuentoPct, fila.CantidadDisponible,
            fila.Fecha, fila.HoraInicioRetiro, fila.HoraFinRetiro,
            fila.SucursalId, fila.Sucursal, fila.NombreComercial,
            fila.Direccion, fila.ZonaId, fila.Zona, fila.HoraLimiteRetiro);
    }

    /// <summary>Fila intermedia para VigentesAsync (ver comentario ahí).</summary>
    private sealed class PublicacionFila
    {
        public long PublicacionId { get; set; }
        public string Bolsa { get; set; } = "";
        public string TipoAlimento { get; set; } = "";
        public decimal PrecioVenta { get; set; }
        public decimal ValorEstimado { get; set; }
        public int DescuentoPct { get; set; }
        public short CantidadDisponible { get; set; }
        public DateOnly Fecha { get; set; }
        public TimeOnly HoraInicioRetiro { get; set; }
        public TimeOnly HoraFinRetiro { get; set; }
        public int SucursalId { get; set; }
        public string Sucursal { get; set; } = "";
        public string NombreComercial { get; set; } = "";
        public string Rubro { get; set; } = "";
        public int ZonaId { get; set; }
        public string Zona { get; set; } = "";
    }

    /// <summary>Fila intermedia para PorIdAsync (ver comentario ahí).</summary>
    private sealed class PublicacionDetalleFila
    {
        public long PublicacionId { get; set; }
        public string Bolsa { get; set; } = "";
        public string? Descripcion { get; set; }
        public string TipoAlimento { get; set; } = "";
        public bool EsPerecible { get; set; }
        public string? Alergenos { get; set; }
        public decimal PesoEstimadoKg { get; set; }
        public decimal PrecioVenta { get; set; }
        public decimal ValorEstimado { get; set; }
        public int DescuentoPct { get; set; }
        public short CantidadDisponible { get; set; }
        public DateOnly Fecha { get; set; }
        public TimeOnly HoraInicioRetiro { get; set; }
        public TimeOnly HoraFinRetiro { get; set; }
        public int SucursalId { get; set; }
        public string Sucursal { get; set; } = "";
        public string NombreComercial { get; set; } = "";
        public string Direccion { get; set; } = "";
        public int ZonaId { get; set; }
        public string Zona { get; set; } = "";
        public TimeOnly? HoraLimiteRetiro { get; set; }
    }
}
