using Dapper;
using Npgsql;

namespace LastBite.Api.Common;

/// <summary>
/// Abre conexiones a PostgreSQL y publica el usuario de la aplicación.
///
/// Es la pieza más importante de la infraestructura. Los 35 triggers de auditoría
/// de la base leen la variable de sesión "app.usuario_id" para saber quién hizo
/// cada cambio. Si no se fija, la bitácora queda sin autor y pierde su valor.
///
/// Npgsql limpia el estado de la conexión al devolverla al pool, así que la
/// variable no se filtra a la siguiente petición. Aun así se fija en cada
/// apertura, nunca una sola vez al arrancar.
/// </summary>
public sealed class ConexionFactory
{
    private readonly string _cadena;

    public ConexionFactory(IConfiguration configuracion)
    {
        _cadena = configuracion.GetConnectionString("LastBite")
            ?? throw new InvalidOperationException(
                "Falta la cadena de conexión 'LastBite' en appsettings.");
    }

    /// <summary>
    /// Abre una conexión. Si se pasa el usuario, lo publica para los triggers.
    /// Se debe pasar SIEMPRE que la operación vaya a escribir.
    /// </summary>
    public async Task<NpgsqlConnection> AbrirAsync(long? usuarioId = null)
    {
        var conexion = new NpgsqlConnection(_cadena);
        await conexion.OpenAsync();

        if (usuarioId is not null)
        {
            await conexion.ExecuteAsync(
                "SELECT set_config('app.usuario_id', @id, false)",
                new { id = usuarioId.Value.ToString() });
        }

        return conexion;
    }
}
