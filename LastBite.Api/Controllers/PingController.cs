using Dapper;
using LastBite.Api.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LastBite.Api.Controllers;

/// <summary>
/// Endpoint de verificación. No forma parte del contrato de la API: existe para
/// comprobar que el proyecto levanta y que la base responde.
/// Es el primero que hay que probar, y también el que usa el frontend para
/// verificar que alcanza la API desde el teléfono.
/// </summary>
[ApiController]
[Route("api/ping")]
[AllowAnonymous]
public sealed class PingController : ControllerBase
{
    private readonly ConexionFactory _fabrica;

    public PingController(ConexionFactory fabrica) => _fabrica = fabrica;

    /// <summary>Responde si la API está viva.</summary>
    [HttpGet]
    public IActionResult Ping() => Ok(new
    {
        estado = "ok",
        servicio = "Last Bite API",
        fecha = DateTimeOffset.Now
    });

    /// <summary>Responde si además la base de datos está alcanzable.</summary>
    [HttpGet("base")]
    public async Task<IActionResult> Base()
    {
        await using var conexion = await _fabrica.AbrirAsync();

        var tablas = await conexion.ExecuteScalarAsync<int>("""
            SELECT COUNT(*)
              FROM information_schema.tables
             WHERE table_type = 'BASE TABLE'
               AND table_schema IN ('core','seguridad','geo','comercio',
                                    'oferta','venta','finanza','social','auditoria')
            """);

        return Ok(new
        {
            estado = "ok",
            baseDatos = "lastbite",
            tablas,
            esperadas = 30
        });
    }
}
