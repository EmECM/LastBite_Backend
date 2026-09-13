using Npgsql;

namespace LastBite.Api.Common;

/// <summary>
/// Traduce los errores de PostgreSQL a respuestas HTTP.
///
/// Los procedimientos de la base lanzan RAISE EXCEPTION con ERRCODE = 'P0001' y
/// un mensaje que empieza con un código en mayúsculas, por ejemplo:
///
///     SIN_CUPO: quedan 0 bolsas
///
/// Gracias a este middleware, los controladores NO llevan try/catch: dejan que
/// el error suba y acá se convierte en el estado que corresponde.
/// </summary>
public sealed class ErroresMiddleware
{
    private readonly RequestDelegate _siguiente;
    private readonly ILogger<ErroresMiddleware> _log;

    public ErroresMiddleware(RequestDelegate siguiente, ILogger<ErroresMiddleware> log)
    {
        _siguiente = siguiente;
        _log = log;
    }

    /// <summary>Código que lanza el procedimiento y estado HTTP que le corresponde.</summary>
    private static readonly Dictionary<string, int> Mapa = new()
    {
        // 400 · el cliente mandó algo inválido
        ["CANTIDAD_INVALIDA"]         = StatusCodes.Status400BadRequest,
        ["METODO_PAGO_INVALIDO"]      = StatusCodes.Status400BadRequest,
        ["PERIODO_INVALIDO"]          = StatusCodes.Status400BadRequest,

        // 403 · no tiene permiso
        ["USUARIO_NO_ACTIVO"]         = StatusCodes.Status403Forbidden,
        ["EMPLEADO_AJENO"]            = StatusCodes.Status403Forbidden,

        // 404 · no existe
        ["PUBLICACION_INEXISTENTE"]   = StatusCodes.Status404NotFound,
        ["CODIGO_INEXISTENTE"]        = StatusCodes.Status404NotFound,

        // 409 · choca con una regla de negocio
        ["PUBLICACION_NO_DISPONIBLE"] = StatusCodes.Status409Conflict,
        ["SIN_CUPO"]                  = StatusCodes.Status409Conflict,
        ["LIMITE_POR_CLIENTE"]        = StatusCodes.Status409Conflict,
        ["EFECTIVO_BLOQUEADO"]        = StatusCodes.Status409Conflict,
        ["RESERVA_NO_ENTREGABLE"]     = StatusCodes.Status409Conflict,
        ["FUERA_DE_VENTANA"]          = StatusCodes.Status409Conflict,
        ["VENTANA_MUY_LARGA"]         = StatusCodes.Status409Conflict,
        ["FUERA_DE_HORARIO"]          = StatusCodes.Status409Conflict,
        ["FUERA_DEL_LIMITE_DE_ZONA"]  = StatusCodes.Status409Conflict,
        ["TRANSICION_INVALIDA"]       = StatusCodes.Status409Conflict,

        // 500 · es un problema nuestro de datos, no del cliente
        ["SIN_TARIFA_VIGENTE"]        = StatusCodes.Status500InternalServerError,
    };

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await _siguiente(ctx);
        }
        catch (ReglaAplicacionException ex)
        {
            // La lanzan los servicios: credenciales incorrectas, correo repetido...
            _log.LogWarning("Regla de aplicación rechazada: {Codigo}", ex.Codigo);
            await ResponderAsync(ctx, ex.Estado, new ErrorResponse(ex.Codigo, ex.Message));
        }
        catch (PostgresException ex) when (ex.SqlState == "P0001")
        {
            // "SIN_CUPO: quedan 0 bolsas"  ->  codigo = "SIN_CUPO"
            var codigo = ex.MessageText.Split(':')[0].Trim();
            var estado = Mapa.TryGetValue(codigo, out var e)
                ? e
                : StatusCodes.Status400BadRequest;

            _log.LogWarning("Regla de negocio rechazada: {Codigo}", codigo);
            await ResponderAsync(ctx, estado, new ErrorResponse(codigo, ex.MessageText));
        }
        catch (PostgresException ex) when (ex.SqlState == "23505")   // UNIQUE
        {
            _log.LogWarning(ex, "Violación de unicidad");
            await ResponderAsync(ctx, StatusCodes.Status409Conflict,
                new ErrorResponse("DUPLICADO", "Ese registro ya existe."));
        }
        catch (PostgresException ex) when (ex.SqlState == "23503")   // FOREIGN KEY
        {
            _log.LogWarning(ex, "Violación de integridad referencial");
            await ResponderAsync(ctx, StatusCodes.Status409Conflict,
                new ErrorResponse("REFERENCIA_INVALIDA",
                    "El registro referenciado no existe o tiene dependencias."));
        }
        catch (PostgresException ex) when (ex.SqlState == "23514")   // CHECK
        {
            _log.LogWarning(ex, "Violación de restricción CHECK");
            await ResponderAsync(ctx, StatusCodes.Status400BadRequest,
                new ErrorResponse("DATO_INVALIDO",
                    "Un valor no cumple las reglas del modelo."));
        }
        catch (PostgresException ex) when (ex.SqlState == "23502")   // NOT NULL
        {
            _log.LogWarning(ex, "Falta un campo obligatorio");
            await ResponderAsync(ctx, StatusCodes.Status400BadRequest,
                new ErrorResponse("CAMPO_REQUERIDO", "Falta un campo obligatorio."));
        }
        catch (NpgsqlException ex)
        {
            _log.LogError(ex, "No se pudo conectar a la base de datos");
            await ResponderAsync(ctx, StatusCodes.Status503ServiceUnavailable,
                new ErrorResponse("BASE_NO_DISPONIBLE",
                    "No se pudo conectar a la base de datos."));
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Error no controlado");
            await ResponderAsync(ctx, StatusCodes.Status500InternalServerError,
                new ErrorResponse("ERROR_INTERNO", "Ocurrió un error inesperado."));
        }
    }

    private static async Task ResponderAsync(HttpContext ctx, int estado, ErrorResponse cuerpo)
    {
        if (ctx.Response.HasStarted)
        {
            // La respuesta ya empezó a escribirse; no se puede cambiar el estado.
            return;
        }

        ctx.Response.Clear();
        ctx.Response.StatusCode = estado;
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsJsonAsync(cuerpo);
    }
}
