using System.Text.RegularExpressions;
using LastBite.Api.Common;
using LastBite.Api.Dtos;
using LastBite.Api.Repositories;

namespace LastBite.Api.Services;

public interface IAuthService
{
    Task<UsuarioResponse> RegistrarAsync(RegistroRequest peticion);
    Task<LoginResponse> LoginAsync(LoginRequest peticion);
    Task<UsuarioResponse> ObtenerActualAsync(long usuarioId);
}

/// <summary>
/// M0 · Identidad. Registro, login y perfil del usuario en sesión.
///
/// Las reglas de aplicación de este módulo viven acá:
///   - El correo y el teléfono no se repiten           -> 409
///   - Correo o contraseña incorrectos                  -> 401
///   - Cuenta SUSPENDIDA, ELIMINADA o dada de baja       -> 403 USUARIO_NO_ACTIVO
/// Se rechazan lanzando ReglaAplicacionException; el middleware arma la respuesta.
/// </summary>
public sealed class AuthService : IAuthService
{
    private readonly IUsuarioRepository _repositorio;
    private readonly HashService _hash;
    private readonly TokenService _token;

    public AuthService(IUsuarioRepository repositorio, HashService hash, TokenService token)
    {
        _repositorio = repositorio;
        _hash = hash;
        _token = token;
    }

    public async Task<UsuarioResponse> RegistrarAsync(RegistroRequest peticion)
    {
        var correo = peticion.Correo.Trim().ToLowerInvariant();
        var telefono = NormalizarTelefono(peticion.Telefono);

        // Se revisa antes de insertar para devolver un código claro. Si dos
        // registros llegan a la vez, igual lo frena el índice único y el
        // middleware responde DUPLICADO.
        if (await _repositorio.CorreoExisteAsync(correo))
        {
            throw new ReglaAplicacionException(StatusCodes.Status409Conflict,
                "CORREO_DUPLICADO", "Ya existe una cuenta con ese correo.");
        }

        if (await _repositorio.TelefonoExisteAsync(telefono))
        {
            throw new ReglaAplicacionException(StatusCodes.Status409Conflict,
                "TELEFONO_DUPLICADO", "Ya existe una cuenta con ese teléfono.");
        }

        // La contraseña nunca llega a la base: solo el hash BCrypt.
        var usuarioId = await _repositorio.CrearClienteAsync(
            peticion.Nombres.Trim(),
            peticion.Apellidos.Trim(),
            correo,
            telefono,
            _hash.Hash(peticion.Contrasena));

        return await ObtenerActualAsync(usuarioId);
    }

    public async Task<LoginResponse> LoginAsync(LoginRequest peticion)
    {
        var usuario = await _repositorio.PorCorreoAsync(peticion.Correo.Trim());

        // Mismo mensaje si el correo no existe o si la contraseña no coincide:
        // así no se le revela a un extraño qué correos están registrados.
        if (usuario is null || !_hash.Verificar(peticion.Contrasena, usuario.ContrasenaHash))
        {
            throw new ReglaAplicacionException(StatusCodes.Status401Unauthorized,
                "CREDENCIALES_INVALIDAS", "Correo o contraseña incorrectos.");
        }

        ValidarActivo(usuario);

        var roles = await _repositorio.RolesAsync(usuario.Id);
        await _repositorio.RegistrarAccesoAsync(usuario.Id);

        var token = _token.Generar(usuario.Id, usuario.Correo, roles);
        return new LoginResponse(token, ArmarRespuesta(usuario, roles));
    }

    public async Task<UsuarioResponse> ObtenerActualAsync(long usuarioId)
    {
        // Si el token es válido pero el usuario ya no existe, la sesión no sirve.
        var usuario = await _repositorio.PorIdAsync(usuarioId)
            ?? throw new ReglaAplicacionException(StatusCodes.Status401Unauthorized,
                "SESION_INVALIDA", "El usuario de la sesión ya no existe.");

        // Una cuenta suspendida después de iniciar sesión deja de entrar.
        ValidarActivo(usuario);

        var roles = await _repositorio.RolesAsync(usuario.Id);
        return ArmarRespuesta(usuario, roles);
    }

    private static void ValidarActivo(UsuarioFila usuario)
    {
        if (usuario.Estado != "ACTIVO" || !usuario.EsActivo)
        {
            throw new ReglaAplicacionException(StatusCodes.Status403Forbidden,
                "USUARIO_NO_ACTIVO", "La cuenta está suspendida o eliminada.");
        }
    }

    private static UsuarioResponse ArmarRespuesta(UsuarioFila usuario, List<string> roles)
        => new(usuario.Id,
               usuario.Nombres,
               usuario.Apellidos,
               usuario.Correo,
               usuario.Telefono,
               roles,
               usuario.NoShows,
               usuario.Estado);

    /// <summary>
    /// Deja el teléfono en el único formato que acepta el dominio core.dm_tel_hn:
    /// +504 seguido de 8 dígitos. Acepta lo que la gente suele escribir:
    ///   "+504 9700 1111", "504-9700-1111", "9700 1111"  ->  "+50497001111"
    /// </summary>
    private static string NormalizarTelefono(string telefono)
    {
        var limpio = telefono.Replace(" ", "").Replace("-", "");

        if (limpio.Length == 8) limpio = "+504" + limpio;
        else if (limpio.Length == 11 && limpio.StartsWith("504")) limpio = "+" + limpio;

        if (!Regex.IsMatch(limpio, @"^\+504[0-9]{8}$"))
        {
            throw new ReglaAplicacionException(StatusCodes.Status400BadRequest,
                "TELEFONO_INVALIDO", "El teléfono debe tener 8 dígitos, con o sin +504.");
        }

        return limpio;
    }
}
