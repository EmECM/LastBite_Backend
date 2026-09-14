using Dapper;
using LastBite.Api.Common;

namespace LastBite.Api.Repositories;

public interface IUsuarioRepository
{
    Task<UsuarioFila?> PorCorreoAsync(string correo);
    Task<UsuarioFila?> PorIdAsync(long usuarioId);
    Task<List<string>> RolesAsync(long usuarioId);
    Task<bool> CorreoExisteAsync(string correo);
    Task<bool> TelefonoExisteAsync(string telefono);
    Task<long> CrearClienteAsync(string nombres, string apellidos, string correo,
                                 string telefono, string contrasenaHash);
    Task RegistrarAccesoAsync(long usuarioId);
}

/// <summary>
/// Fila de seguridad.usuario tal como la necesita el servicio de autenticación.
/// NO es un DTO: trae el hash de la contraseña y nunca debe salir en una
/// respuesta. El servicio la convierte en UsuarioResponse.
/// </summary>
public sealed class UsuarioFila
{
    public long Id { get; set; }
    public string Nombres { get; set; } = "";
    public string Apellidos { get; set; } = "";
    public string Correo { get; set; } = "";
    public string? Telefono { get; set; }
    public string ContrasenaHash { get; set; } = "";
    public short NoShows { get; set; }
    public string Estado { get; set; } = "";
    public bool EsActivo { get; set; }
}

/// <summary>
/// M0 · Identidad. Lee y escribe en seguridad.usuario y seguridad.usuario_rol.
/// </summary>
public sealed class UsuarioRepository : IUsuarioRepository
{
    private readonly ConexionFactory _fabrica;

    public UsuarioRepository(ConexionFactory fabrica) => _fabrica = fabrica;

    public async Task<UsuarioFila?> PorCorreoAsync(string correo)
    {
        // lower() en los dos lados: así usa el índice único uq_usuario_correo_lower
        // y "Kevin.Zelaya@correo.hn" encuentra a "kevin.zelaya@correo.hn".
        // El ENUM de estado se castea a texto: Npgsql no lo convierte solo.
        const string sql = """
            SELECT id, nombres, apellidos, correo, telefono, contrasena_hash,
                   no_shows, estado::text AS estado, es_activo
              FROM seguridad.usuario
             WHERE lower(correo) = lower(@correo)
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        return await conexion.QuerySingleOrDefaultAsync<UsuarioFila>(sql, new { correo });
    }

    public async Task<UsuarioFila?> PorIdAsync(long usuarioId)
    {
        const string sql = """
            SELECT id, nombres, apellidos, correo, telefono, contrasena_hash,
                   no_shows, estado::text AS estado, es_activo
              FROM seguridad.usuario
             WHERE id = @usuario_id
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        return await conexion.QuerySingleOrDefaultAsync<UsuarioFila>(
            sql, new { usuario_id = usuarioId });
    }

    public async Task<List<string>> RolesAsync(long usuarioId)
    {
        // Códigos estables: CLIENTE, COMERCIO, ADMIN. Son los que viajan en el JWT.
        const string sql = """
            SELECT r.codigo
              FROM seguridad.usuario_rol ur
              INNER JOIN seguridad.rol r
                      ON r.id = ur.rol_id
             WHERE ur.usuario_id = @usuario_id
               AND r.es_activo
             ORDER BY r.codigo
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        var roles = await conexion.QueryAsync<string>(sql, new { usuario_id = usuarioId });
        return roles.ToList();
    }

    public async Task<bool> CorreoExisteAsync(string correo)
    {
        const string sql = """
            SELECT EXISTS (
                SELECT 1
                  FROM seguridad.usuario
                 WHERE lower(correo) = lower(@correo))
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        return await conexion.ExecuteScalarAsync<bool>(sql, new { correo });
    }

    public async Task<bool> TelefonoExisteAsync(string telefono)
    {
        // uq_usuario_telefono: dos cuentas no pueden compartir teléfono.
        const string sql = """
            SELECT EXISTS (
                SELECT 1
                  FROM seguridad.usuario
                 WHERE telefono = @telefono)
            """;

        await using var conexion = await _fabrica.AbrirAsync();
        return await conexion.ExecuteScalarAsync<bool>(sql, new { telefono });
    }

    public async Task<long> CrearClienteAsync(string nombres, string apellidos, string correo,
                                              string telefono, string contrasenaHash)
    {
        // Estado ACTIVO, cero faltas y fechas de auditoría los pone la base.
        // correo_verificado va en true porque el MVP no verifica correos.
        const string sqlUsuario = """
            INSERT INTO seguridad.usuario
                   (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado)
            VALUES (@nombres, @apellidos, @correo, @telefono, @contrasena_hash, true)
            RETURNING id
            """;

        const string sqlRol = """
            INSERT INTO seguridad.usuario_rol (usuario_id, rol_id)
            SELECT @usuario_id, r.id
              FROM seguridad.rol r
             WHERE r.codigo = 'CLIENTE'
            """;

        // Sin usuario en sesión: quien se registra todavía no existe, así que
        // los triggers dejan created_by = 1, el usuario de sistema.
        await using var conexion = await _fabrica.AbrirAsync();

        // Dos tablas que deben cuadrar: o se crean las dos filas o ninguna.
        await using var tx = await conexion.BeginTransactionAsync();
        try
        {
            var usuarioId = await conexion.ExecuteScalarAsync<long>(sqlUsuario, new
            {
                nombres,
                apellidos,
                correo,
                telefono,
                contrasena_hash = contrasenaHash
            }, tx);

            var filas = await conexion.ExecuteAsync(sqlRol, new { usuario_id = usuarioId }, tx);
            if (filas != 1)
            {
                throw new InvalidOperationException(
                    "No existe el rol CLIENTE en seguridad.rol. Revisar los datos semilla.");
            }

            await tx.CommitAsync();
            return usuarioId;
        }
        catch
        {
            await tx.RollbackAsync();
            throw;   // que lo traduzca el middleware
        }
    }

    public async Task RegistrarAccesoAsync(long usuarioId)
    {
        const string sql = """
            UPDATE seguridad.usuario
               SET ultimo_acceso = now()
             WHERE id = @usuario_id
            """;

        // Escribe, así que se publica el usuario: modified_by queda con su id.
        await using var conexion = await _fabrica.AbrirAsync(usuarioId);
        await conexion.ExecuteAsync(sql, new { usuario_id = usuarioId });
    }
}
