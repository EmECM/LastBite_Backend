# Contexto para el equipo de BACKEND · Last Bite

> **Cómo usar este documento.** Pegalo completo como primer mensaje en un chat nuevo.
> Está escrito para alguien que no participó de las sesiones de diseño: acá está todo,
> desde qué es el proyecto hasta el nombre exacto de cada clase que hay que escribir.
>
> **Documento maestro que lo acompaña:** `12-mockups-completos.html`, en la misma carpeta.
> Tiene las 39 pantallas del producto, y cada una lleva un bloque de *contrato técnico*
> con su endpoint, sus clases de C# y sus DTO. Este documento y ese HTML dicen lo mismo:
> si algo no coincide, manda el HTML.

---

## 1. Qué es el proyecto

**Last Bite** es un clon de Too Good To Go adaptado a San Pedro Sula, Honduras. Comercios con
excedente de comida del día publican "bolsas sorpresa" a precio reducido; el cliente las reserva
desde la app, paga, y las retira presencialmente en una ventana horaria.

Proyecto integrador de **INF308 – Administración de Bases de Datos**, CEUTEC, 2026 Q3.
Equipo de 5 personas. El entregable es una **demo funcional**, no un producto de producción.

**El camino dorado** —la cadena que debe funcionar de punta a punta— es:

```
publicar → buscar → reservar → pagar → retirar
```

---

## 2. Lo más importante que hay que entender antes de escribir código

**La base de datos ya está terminada, probada y no se toca.** Tiene 30 tablas en 9 esquemas,
11 tipos `ENUM`, 6 dominios, 3 vistas, 3 vistas materializadas, 15 rutinas y 35 triggers.
El archivo de pruebas pasa 16 de 16 reglas de negocio.

Eso cambia por completo el trabajo del backend:

- **La lógica crítica ya existe** como procedimientos almacenados. Reservar, retirar, vencer y
  liquidar **se llaman, no se reimplementan**.
- **Las validaciones ya existen** como restricciones y triggers. El backend no las repite: las
  deja fallar y **traduce el error a HTTP**.
- **Las consultas complejas ya existen** como vistas. El backend hace `SELECT` sobre ellas, no
  arma los `JOIN` de nuevo.

En varios endpoints el trabajo real es: recibir el DTO, abrir la conexión, llamar al
procedimiento, mapear el resultado y devolverlo.

---

## 3. Arranque · lo primero que hay que hacer

### 3.1 Levantar la base

```sql
-- Conectado a la base "postgres", en modo Auto-Commit:
CREATE DATABASE lastbite;
```

Luego cambiás la conexión a `lastbite` y ejecutás, en este orden, desde `BBDD/db/`:

1. **`INSTALAR_TODO.sql`** — crea todo y carga datos de prueba. En DBeaver: *Execute script* (Alt+X).
2. **`S003__contrasenas_demo.sql`** — pone contraseñas válidas a los usuarios de prueba.

Verificación opcional: `T001__pruebas_reglas.sql` debe decir
`RESULTADO: 16 pruebas correctas, 0 fallas`.

Requiere PostgreSQL 15 o superior con las extensiones `btree_gist` y `pg_trgm` (vienen en el
paquete `contrib` estándar).

### 3.2 Usuarios de prueba

Todos con la contraseña **`LastBite2026`** después de aplicar `S003`.

| Correo | Perfil | Para qué sirve |
|---|---|---|
| `kevin.zelaya@correo.hn` | Cliente | Flujo normal de compra |
| `sofia.andino@correo.hn` | Cliente | Segundo cliente, probar concurrencia |
| `marlon.pineda@correo.hn` | Cliente | — |
| `daniela.cruz@correo.hn` | Cliente con **3 faltas** | Probar `EFECTIVO_BLOQUEADO` |
| `rosa.mejia@eltrigal.hn` | Cajera | Panel del comercio y entrega |
| `admin@lastbite.hn` | Administrador | — |

### 3.3 Crear el proyecto

```bash
dotnet new webapi -n LastBite.Api --framework net8.0 --use-controllers
cd LastBite.Api

dotnet add package Npgsql
dotnet add package Dapper
dotnet add package BCrypt.Net-Next
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Swashbuckle.AspNetCore
```

**Decisiones tomadas:** .NET 8 (LTS), controladores clásicos con atributos —no minimal APIs— y
**un solo proyecto con carpetas**, no una solución por capas. El plazo es corto y el equipo tiene
poca experiencia; repartir el código en cuatro proyectos cuesta días en resolver referencias y no
aporta nada a la demo.

### 3.4 La URL base y la red

Esto bloquea el primer día si no se acuerda. El teléfono **no puede usar `localhost`**: eso apunta
al propio teléfono, no a la computadora donde corre la API.

```bash
# La API debe escuchar en todas las interfaces, no solo en loopback
dotnet run --urls "http://0.0.0.0:5080"
```

Quien levanta la API le pasa su **IP de la red local** al resto del equipo (`ipconfig` en Windows,
algo como `192.168.1.15`). El frontend apunta a `http://192.168.1.15:5080`. Todos tienen que estar
en la misma red wifi.

---

## 4. Estructura del proyecto

```
LastBite.Api/
├── Program.cs
├── appsettings.json
├── appsettings.Development.json
├── LastBite.Api.csproj
│
├── Controllers/                    ← 12 archivos, uno por recurso
│   ├── AuthController.cs
│   ├── ZonasController.cs
│   ├── SucursalesController.cs
│   ├── CategoriasAlimentoController.cs
│   ├── PublicacionesController.cs
│   ├── PlantillasController.cs
│   ├── MetodosPagoController.cs
│   ├── ReservasController.cs
│   ├── RetirosController.cs
│   ├── MantenimientoController.cs
│   ├── LiquidacionesController.cs
│   └── ReportesController.cs
│
├── Services/                       ← interfaz + implementación, en el mismo archivo
│   ├── IAuthService.cs
│   ├── ISucursalService.cs
│   ├── IPublicacionService.cs
│   ├── IPlantillaService.cs
│   ├── IReservaService.cs
│   ├── IPagoService.cs
│   ├── IRetiroService.cs
│   ├── ILiquidacionService.cs
│   ├── IReporteService.cs
│   └── IMantenimientoService.cs
│
├── Repositories/                   ← todo el SQL vive acá y en ningún otro lado
│   ├── IUsuarioRepository.cs
│   ├── IZonaRepository.cs
│   ├── ISucursalRepository.cs
│   ├── ICatalogoRepository.cs
│   ├── IPublicacionRepository.cs
│   ├── IPlantillaRepository.cs
│   ├── IReservaRepository.cs
│   ├── IPagoRepository.cs
│   ├── IRetiroRepository.cs
│   ├── ILiquidacionRepository.cs
│   ├── IReporteRepository.cs
│   └── IMantenimientoRepository.cs
│
├── Dtos/                           ← un archivo por grupo
│   ├── AuthDtos.cs
│   ├── CatalogoDtos.cs
│   ├── SucursalDtos.cs
│   ├── PublicacionDtos.cs
│   ├── ReservaDtos.cs
│   ├── RetiroDtos.cs
│   ├── LiquidacionDtos.cs
│   └── ReporteDtos.cs
│
└── Common/
    ├── ConexionFactory.cs          ← abre Npgsql y fija app.usuario_id
    ├── ErroresMiddleware.cs        ← traduce los errores de PostgreSQL a HTTP
    ├── ErrorResponse.cs
    ├── TokenService.cs             ← genera y valida el JWT
    ├── HashService.cs              ← BCrypt
    └── ClaimsExtensions.cs         ← User.ObtenerId()
```

**Regla de oro:** el flujo es siempre
`Controller → IService → IRepository → Dapper → base`.
Ninguna capa se salta. El controlador no tiene SQL. El repositorio no tiene reglas de negocio.

---

## 5. Convenciones de nombres

| Elemento | Convención | Ejemplo |
|---|---|---|
| Controlador | Recurso en **plural** + `Controller` | `ReservasController` |
| Servicio | Entidad en **singular**, con interfaz | `IReservaService` / `ReservaService` |
| Repositorio | Igual que el servicio | `IReservaRepository` / `ReservaRepository` |
| DTO de entrada | Acción + entidad + `Request` | `CrearReservaRequest` |
| DTO de salida | Entidad + `Response` | `ReservaResponse` |
| Método asíncrono | Termina en `Async` | `CrearAsync` |
| Clases, métodos, propiedades | PascalCase | `PublicacionId` |
| Parámetros y variables locales | camelCase | `usuarioId` |
| Campos privados | guion bajo + camelCase | `_reservaService` |
| Ruta del controlador | minúsculas, plural | `[Route("api/reservas")]` |
| Parámetros de Dapper | snake\_case, igual que en el SQL | `@publicacion_id` |

**Verbos HTTP:** `GET` para leer, `POST` para crear o ejecutar una acción. No usamos `PUT`,
`PATCH` ni `DELETE` en el MVP: el modelo no borra nada y las modificaciones se hacen por acción,
no por reemplazo de recurso.

**Códigos de estado:** `200` leer, `201` crear, `400` datos inválidos, `401` sin token,
`403` sin permiso, `404` no existe, `409` conflicto con una regla de negocio, `500` error nuestro.

---

## 6. Program.cs

```csharp
using System.Text;
using System.Text.Json.Serialization;
using Dapper;
using LastBite.Api.Common;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// Dapper: las vistas devuelven columnas en snake_case y las propiedades son PascalCase.
// Sin esta línea, cantidad_disponible NO se mapea a CantidadDisponible.
DefaultTypeMap.MatchNamesWithUnderscores = true;

builder.Services.AddControllers()
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        o.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    });

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// CORS abierto: es una demo en red local, no un servicio público.
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Jwt:Issuer"],
            ValidAudience = builder.Configuration["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Clave"]!))
        };
    });

builder.Services.AddAuthorization();

// Infraestructura
builder.Services.AddSingleton<ConexionFactory>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<HashService>();

// Servicios y repositorios (agregar acá cada uno que se cree)
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUsuarioRepository, UsuarioRepository>();
builder.Services.AddScoped<IReservaService, ReservaService>();
builder.Services.AddScoped<IReservaRepository, ReservaRepository>();
// ... el resto

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();
app.UseCors();
app.UseMiddleware<ErroresMiddleware>();   // antes de la autenticación
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

app.Run();
```

**appsettings.Development.json**

```json
{
  "ConnectionStrings": {
    "LastBite": "Host=localhost;Port=5432;Database=lastbite;Username=postgres;Password=postgres"
  },
  "Jwt": {
    "Issuer": "LastBite",
    "Audience": "LastBiteApp",
    "Clave": "clave-de-desarrollo-minimo-32-caracteres-1234",
    "HorasVigencia": 12
  }
}
```

---

## 7. Common · la infraestructura que usan todos

### 7.1 ConexionFactory

Es la pieza más importante del proyecto. Abre la conexión y **fija `app.usuario_id`**, que es de
donde los 35 triggers de auditoría sacan quién hizo cada cambio. Si no se fija, la bitácora queda
sin autor y pierde todo su valor.

```csharp
namespace LastBite.Api.Common;

public sealed class ConexionFactory
{
    private readonly string _cadena;

    public ConexionFactory(IConfiguration config)
        => _cadena = config.GetConnectionString("LastBite")!;

    /// <summary>Abre una conexión y, si hay usuario, lo publica para los triggers.</summary>
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
```

> Npgsql limpia el estado de la conexión al devolverla al pool, así que la variable no se filtra
> a la siguiente petición. Aun así se fija **en cada apertura**, nunca una sola vez al arrancar.

### 7.2 ErrorResponse y el middleware de errores

Los procedimientos lanzan `RAISE EXCEPTION` con `ERRCODE = 'P0001'` y un mensaje que **empieza con
un código en mayúsculas**. En Npgsql eso llega como `PostgresException` con `SqlState == "P0001"`.
Un solo middleware lo traduce; los controladores no llevan `try/catch`.

```csharp
public sealed record ErrorResponse(string Codigo, string Mensaje);

public sealed class ErroresMiddleware
{
    private readonly RequestDelegate _siguiente;
    private readonly ILogger<ErroresMiddleware> _log;

    // Código del procedimiento  ->  estado HTTP
    private static readonly Dictionary<string, int> Mapa = new()
    {
        ["CANTIDAD_INVALIDA"]         = 400,
        ["METODO_PAGO_INVALIDO"]      = 400,
        ["PERIODO_INVALIDO"]          = 400,
        ["USUARIO_NO_ACTIVO"]         = 403,
        ["EMPLEADO_AJENO"]            = 403,
        ["PUBLICACION_INEXISTENTE"]   = 404,
        ["CODIGO_INEXISTENTE"]        = 404,
        ["PUBLICACION_NO_DISPONIBLE"] = 409,
        ["SIN_CUPO"]                  = 409,
        ["LIMITE_POR_CLIENTE"]        = 409,
        ["EFECTIVO_BLOQUEADO"]        = 409,
        ["RESERVA_NO_ENTREGABLE"]     = 409,
        ["FUERA_DE_VENTANA"]          = 409,
        ["VENTANA_MUY_LARGA"]         = 409,
        ["FUERA_DE_HORARIO"]          = 409,
        ["FUERA_DEL_LIMITE_DE_ZONA"]  = 409,
        ["TRANSICION_INVALIDA"]       = 409,
        ["SIN_TARIFA_VIGENTE"]        = 500,
    };

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await _siguiente(ctx);
        }
        catch (PostgresException ex) when (ex.SqlState == "P0001")
        {
            // "SIN_CUPO: quedan 0 bolsas"  ->  codigo = SIN_CUPO
            var codigo = ex.MessageText.Split(':')[0].Trim();
            var estado = Mapa.TryGetValue(codigo, out var e) ? e : 400;
            await Responder(ctx, estado, new ErrorResponse(codigo, ex.MessageText));
        }
        catch (PostgresException ex) when (ex.SqlState == "23505")   // UNIQUE
        {
            await Responder(ctx, 409, new ErrorResponse("DUPLICADO", "Ese registro ya existe."));
        }
        catch (PostgresException ex) when (ex.SqlState == "23503")   // FOREIGN KEY
        {
            await Responder(ctx, 409, new ErrorResponse("REFERENCIA_INVALIDA",
                "El registro referenciado no existe o tiene dependencias."));
        }
        catch (PostgresException ex) when (ex.SqlState == "23514")   // CHECK
        {
            await Responder(ctx, 400, new ErrorResponse("DATO_INVALIDO",
                "Un valor no cumple las reglas del modelo."));
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Error no controlado");
            await Responder(ctx, 500, new ErrorResponse("ERROR_INTERNO",
                "Ocurrió un error inesperado."));
        }
    }

    private static async Task Responder(HttpContext ctx, int estado, ErrorResponse cuerpo)
    {
        ctx.Response.StatusCode = estado;
        ctx.Response.ContentType = "application/json";
        await ctx.Response.WriteAsJsonAsync(cuerpo);
    }
}
```

### 7.3 TokenService, HashService y ClaimsExtensions

```csharp
public sealed class HashService
{
    public string Hash(string contrasena) => BCrypt.Net.BCrypt.HashPassword(contrasena, 11);
    public bool Verificar(string contrasena, string hash)
        => BCrypt.Net.BCrypt.Verify(contrasena, hash);
}

public sealed class TokenService
{
    public string Generar(long usuarioId, string correo, IEnumerable<string> roles) { /* JWT */ }
}

public static class ClaimsExtensions
{
    public static long ObtenerId(this ClaimsPrincipal user)
        => long.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);
}
```

El token lleva tres *claims*: `NameIdentifier` con el id del usuario, `Email` con el correo y un
`Role` por cada rol (`CLIENTE`, `COMERCIO`, `ADMIN`).

---

## 8. Dapper · cómo se consulta

### 8.1 Reglas que evitan la mayoría de los problemas

1. **`DefaultTypeMap.MatchNamesWithUnderscores = true`** en `Program.cs`. Sin eso, las columnas
   `snake_case` de las vistas no se mapean a las propiedades `PascalCase`.
2. **Los `ENUM` se leen como texto.** Hay que castear en el SQL: `estado::text AS estado`. Sin el
   cast, Npgsql no sabe convertir el tipo `core.en_estado_reserva` a `string` y falla.
3. **El dinero es `decimal`**, nunca `double` ni `float`.
4. **`timestamptz` se lee como `DateTimeOffset`**. Si se usa `DateTime`, Npgsql exige que sea UTC.
5. **`date` es `DateOnly` y `time` es `TimeOnly`** (soportado desde Npgsql 6).
6. **Todo método es asíncrono** y usa `await using` para la conexión.

### 8.2 Consulta simple sobre una vista

```csharp
public async Task<IReadOnlyList<PublicacionResponse>> VigentesAsync(int? zonaId, short? categoriaId)
{
    const string sql = """
        SELECT publicacion_id, bolsa, descripcion, tipo_alimento,
               precio_venta, valor_estimado, descuento_pct, cantidad_disponible,
               fecha, hora_inicio_retiro, hora_fin_retiro,
               sucursal_id, sucursal, nombre_comercial, rubro,
               direccion, zona_id, zona, alergenos, peso_estimado_kg
          FROM oferta.vw_publicacion_vigente
         WHERE (@zonaId      IS NULL OR zona_id = @zonaId)
           AND (@categoriaId IS NULL OR categoria_alimento_id = @categoriaId)
         ORDER BY hora_inicio_retiro
        """;

    await using var conexion = await _fabrica.AbrirAsync();
    var filas = await conexion.QueryAsync<PublicacionResponse>(sql, new { zonaId, categoriaId });
    return filas.ToList();
}
```

### 8.3 Procedimiento con parámetros de salida — el detalle crítico

En PostgreSQL, un procedimiento con parámetros `OUT` **exige que se pasen marcadores para esos
parámetros** en el `CALL`, y la llamada **devuelve una fila** con los valores de salida.
Verificado en PostgreSQL 16:

```sql
CALL sp_demo(7, NULL, NULL);   -- devuelve una fila: o_id = 70, o_cod = 'LB-7'
CALL sp_demo(7);               -- ERROR: procedure sp_demo(integer) does not exist
```

Por eso se usa **`QuerySingleAsync`, no `ExecuteAsync`**:

```csharp
public async Task<ReservaCreadaResponse> CrearAsync(CrearReservaRequest p, long usuarioId)
{
    // Los tres NULL finales son p_mpu_id (tarjeta guardada, sin uso en el MVP)
    // y los dos parámetros OUT: o_reserva_id y o_codigo.
    const string sql = """
        CALL venta.sp_reserva_crear(@publicacion_id, @usuario_id, @cantidad,
                                    @metodo_pago_id, NULL, NULL, NULL)
        """;

    await using var conexion = await _fabrica.AbrirAsync(usuarioId);

    var salida = await conexion.QuerySingleAsync<ReservaCreadaSalida>(sql, new
    {
        publicacion_id = p.PublicacionId,
        usuario_id     = usuarioId,
        cantidad       = p.Cantidad,
        metodo_pago_id = p.MetodoPagoId
    });

    return new ReservaCreadaResponse(salida.O_reserva_id, salida.O_codigo, ...);
}

// Clase interna que refleja las columnas OUT que devuelve el CALL
private sealed class ReservaCreadaSalida
{
    public long O_reserva_id { get; set; }
    public string O_codigo { get; set; } = "";
}
```

### 8.4 Las cuatro rutinas de la base

```sql
-- Crea la reserva: bloquea la publicación, valida cupo, horario, zona, tope por
-- cliente y método de pago, calcula montos con la tarifa vigente y genera el código.
venta.sp_reserva_crear(
    IN  p_publicacion_id BIGINT, IN p_usuario_id BIGINT, IN p_cantidad SMALLINT,
    IN  p_metodo_pago_id SMALLINT, IN p_mpu_id INT,
    OUT o_reserva_id BIGINT, OUT o_codigo VARCHAR)

-- Valida el código en el mostrador y marca la entrega.
venta.sp_reserva_retirar(
    IN p_codigo VARCHAR, IN p_empleado_id BIGINT, OUT o_reserva_id BIGINT)

-- Vence publicaciones fuera de ventana y marca las reservas no retiradas.
oferta.sp_publicacion_vencer(OUT o_publicaciones INT, OUT o_reservas INT)

-- Agrupa reservas retiradas del periodo y arma la liquidación del comercio.
finanza.sp_liquidacion_generar(
    IN p_comercio_id INT, IN p_desde DATE, IN p_hasta DATE, OUT o_liquidacion_id INT)

-- Devuelve la tarifa aplicable. La usa sp_reserva_crear internamente.
finanza.fn_tarifa_vigente(p_categoria_comercio_id SMALLINT, p_fecha DATE) RETURNS finanza.tarifa
```

### 8.5 Transacciones

Solo hacen falta cuando una operación escribe en dos tablas y ambas deben cuadrar. El caso típico
es el pago: se inserta en `venta.pago` y se actualiza el estado de la reserva.

```csharp
await using var conexion = await _fabrica.AbrirAsync(usuarioId);
await using var tx = await conexion.BeginTransactionAsync();
try
{
    await conexion.ExecuteAsync(sqlInsertarPago, parametros, tx);
    await conexion.ExecuteAsync(sqlConfirmarReserva, new { id }, tx);
    await tx.CommitAsync();
}
catch
{
    await tx.RollbackAsync();
    throw;   // que lo traduzca el middleware
}
```

**No hace falta transacción para llamar a los procedimientos**: ellos manejan la suya adentro.

---

## 9. Mapeo de tipos

| PostgreSQL | C# | Notas |
|---|---|---|
| `bigint` | `long` | Todos los `id` de tablas grandes |
| `integer` | `int` | |
| `smallint` | `short` | Cantidades, ids de catálogos |
| `numeric(12,2)` / `core.dm_dinero` | `decimal` | **Nunca** `double` ni `float` |
| `numeric(6,2)` | `decimal` | Pesos y porcentajes |
| `varchar` / `text` | `string` | |
| `boolean` | `bool` | |
| `date` | `DateOnly` | Npgsql 6+ |
| `time` | `TimeOnly` | Horas de pared, sin zona |
| `timestamptz` | `DateTimeOffset` | Si se usa `DateTime`, debe ser UTC |
| `jsonb` | `string` | Solo la bitácora; no se expone en la API |
| `inet` | `IPAddress` | Solo auditoría |
| `core.en_*` (ENUM) | `string` | **Requiere `::text` en el SELECT** |

Valores de los enumerados que viajan por la API:

```
en_estado_usuario      ACTIVO · SUSPENDIDO · ELIMINADO
en_estado_comercio     PENDIENTE · ACTIVO · SUSPENDIDO
en_cargo               PROPIETARIO · ENCARGADO · CAJERO
en_estado_publicacion  PROGRAMADA · PUBLICADA · AGOTADA · VENCIDA · CANCELADA
en_estado_reserva      PENDIENTE_PAGO · CONFIRMADA · RETIRADA · NO_RETIRADA · CANCELADA · REEMBOLSADA
en_estado_pago         PENDIENTE · EN_VERIFICACION · CAPTURADO · FALLIDO · REEMBOLSADO
en_tipo_tarifa         PORCENTUAL · FIJA
```

---

## 10. Los DTO, completos

Van en `Dtos/`, agrupados por archivo. Se usan `record` para los de salida (son inmutables) y
`class` con `set` para los de entrada, que es lo que el enlazador de modelos necesita.

### AuthDtos.cs

```csharp
public sealed class RegistroRequest
{
    public string Nombres { get; set; } = "";
    public string Apellidos { get; set; } = "";
    public string Correo { get; set; } = "";
    public string Telefono { get; set; } = "";
    public string Contrasena { get; set; } = "";
}

public sealed class LoginRequest
{
    public string Correo { get; set; } = "";
    public string Contrasena { get; set; } = "";
}

public sealed record UsuarioResponse(
    long Id, string Nombres, string Apellidos, string Correo,
    string? Telefono, List<string> Roles, short NoShows, string Estado);

public sealed record LoginResponse(string Token, UsuarioResponse Usuario);
```

### CatalogoDtos.cs

```csharp
public sealed record ZonaResponse(
    int Id, string Nombre, string Ciudad, TimeOnly? HoraLimiteRetiro, int BolsasDisponibles);

public sealed record CategoriaAlimentoResponse(
    short Id, string Nombre, bool EsPerecible, short HorasMaxVentana);

public sealed record MetodoPagoResponse(
    short Id, string Codigo, string Nombre, bool RequiereConfirmacionEnSitio, short OrdenPresentacion);
```

### SucursalDtos.cs

```csharp
public sealed record SucursalResponse(
    int SucursalId, string Sucursal, string NombreComercial, string Rubro,
    string Direccion, decimal Latitud, decimal Longitud,
    int ZonaId, string Zona, string Ciudad, TimeOnly? HoraLimiteRetiro);

public sealed record HorarioResponse(short DiaSemana, TimeOnly HoraApertura, TimeOnly HoraCierre);

public sealed record SucursalDetalleResponse(
    int SucursalId, string Sucursal, string NombreComercial, string Rubro,
    string Direccion, string? Telefono, int ZonaId, string Zona,
    TimeOnly? HoraLimiteRetiro, List<HorarioResponse> Horarios);

public sealed record AsignacionResponse(int SucursalId, string Sucursal, string Cargo);
```

### PublicacionDtos.cs

```csharp
public sealed record PublicacionResponse(
    long PublicacionId, string Bolsa, string TipoAlimento,
    decimal PrecioVenta, decimal ValorEstimado, int DescuentoPct,
    short CantidadDisponible, DateOnly Fecha,
    TimeOnly HoraInicioRetiro, TimeOnly HoraFinRetiro,
    int SucursalId, string Sucursal, string NombreComercial, string Rubro,
    int ZonaId, string Zona);

public sealed record PublicacionDetalleResponse(
    long PublicacionId, string Bolsa, string? Descripcion, string TipoAlimento,
    bool EsPerecible, string? Alergenos, decimal PesoEstimadoKg,
    decimal PrecioVenta, decimal ValorEstimado, int DescuentoPct,
    short CantidadDisponible, DateOnly Fecha,
    TimeOnly HoraInicioRetiro, TimeOnly HoraFinRetiro,
    int SucursalId, string Sucursal, string NombreComercial,
    string Direccion, int ZonaId, string Zona, TimeOnly? HoraLimiteRetiro);

public sealed record PublicacionPanelResponse(
    long Id, string Bolsa, DateOnly Fecha,
    TimeOnly HoraInicioRetiro, TimeOnly HoraFinRetiro, decimal PrecioVenta,
    short CantidadTotal, short CantidadDisponible, short Reservadas, string Estado);

public sealed class CrearPublicacionRequest
{
    public int PlantillaBolsaId { get; set; }
    public DateOnly Fecha { get; set; }
    public TimeOnly HoraInicioRetiro { get; set; }
    public TimeOnly HoraFinRetiro { get; set; }
    public short CantidadTotal { get; set; }
    public decimal PrecioVenta { get; set; }
}

public sealed record PublicacionCreadaResponse(long Id, string Estado);

public sealed record PlantillaResponse(
    int Id, string Nombre, string? Descripcion, short CategoriaAlimentoId,
    string TipoAlimento, decimal PrecioBase, decimal ValorEstimado,
    decimal PesoEstimadoKg, bool RequiereRefrigeracion, string? Alergenos, bool EsActivo);

public sealed class CrearPlantillaRequest
{
    public string Nombre { get; set; } = "";
    public short CategoriaAlimentoId { get; set; }
    public string? Descripcion { get; set; }
    public decimal PrecioBase { get; set; }
    public decimal ValorEstimado { get; set; }
    public decimal PesoEstimadoKg { get; set; }
    public bool RequiereRefrigeracion { get; set; }
    public string? Alergenos { get; set; }
}
```

### ReservaDtos.cs

```csharp
public sealed class CrearReservaRequest
{
    public long PublicacionId { get; set; }
    public short Cantidad { get; set; }
    public short MetodoPagoId { get; set; }
}

public sealed record ReservaCreadaResponse(
    long ReservaId, string Codigo, decimal Total, string Estado);

public sealed record ReservaResponse(
    long ReservaId, string Codigo, string EstadoReserva, string EstadoPago,
    string Bolsa, string Sucursal, string NombreComercial,
    short Cantidad, decimal Total, DateOnly Fecha,
    TimeOnly HoraInicioRetiro, TimeOnly HoraFinRetiro);

public sealed record ReservaDetalleResponse(
    long ReservaId, string Codigo, string EstadoReserva, string EstadoPago,
    string Bolsa, string Sucursal, string NombreComercial, string Direccion,
    short Cantidad, decimal PrecioUnitario, decimal Subtotal, decimal Isv, decimal Total,
    string? MetodoPago, DateOnly Fecha,
    TimeOnly HoraInicioRetiro, TimeOnly HoraFinRetiro, DateTimeOffset? RetiroDate);

public sealed record PagoResponse(string EstadoPago, string EstadoReserva);
```

### RetiroDtos.cs

```csharp
public sealed class EntregarRequest
{
    public string Codigo { get; set; } = "";
}

public sealed record EntregaResponse(
    long ReservaId, string Estado, string Cliente, string Bolsa, short Cantidad);

public sealed record ReservaPanelResponse(
    long ReservaId, string Codigo, string Cliente, string? ClienteTelefono,
    string Bolsa, short Cantidad, decimal Total, string EstadoReserva, string EstadoPago,
    TimeOnly HoraInicioRetiro, TimeOnly HoraFinRetiro,
    DateTimeOffset? RetiroDate, string? EntregadoPor);

public sealed record CierreResponse(int Publicaciones, int Reservas);
```

### LiquidacionDtos.cs y ReporteDtos.cs

```csharp
public sealed record LiquidacionResponse(
    int Id, DateOnly Desde, DateOnly Hasta, int Reservas,
    decimal Ventas, decimal Comision, decimal Total, string Estado);

public sealed record DetalleLiquidacionResponse(
    string Codigo, DateOnly Fecha, string Bolsa, decimal Monto);

public sealed record LiquidacionDetalleResponse(
    int Id, DateOnly Desde, DateOnly Hasta, decimal Ventas, decimal Comision,
    decimal Total, string Estado, List<DetalleLiquidacionResponse> Detalle);

public sealed class GenerarLiquidacionRequest
{
    public int ComercioId { get; set; }
    public DateOnly Desde { get; set; }
    public DateOnly Hasta { get; set; }
}

public sealed record VentaDiariaResponse(
    DateOnly Fecha, int ZonaId, string Zona, string Rubro,
    int Reservas, decimal TotalVendido, decimal Comision, int NoShows);

public sealed record RankingResponse(
    int SucursalId, string Sucursal, string NombreComercial,
    int Calificaciones, decimal? Promedio, int Retiradas, int NoRetiradas);
```

---

## 11. Un recurso completo, de punta a punta

Este es el patrón que se repite en los doce controladores.

```csharp
// ---------- Controllers/ReservasController.cs
[ApiController]
[Route("api/reservas")]
[Authorize]
public sealed class ReservasController : ControllerBase
{
    private readonly IReservaService _servicio;
    public ReservasController(IReservaService servicio) => _servicio = servicio;

    [HttpPost]
    public async Task<ActionResult<ReservaCreadaResponse>> Crear(CrearReservaRequest peticion)
    {
        if (peticion.Cantidad is < 1 or > 3)
            return BadRequest(new ErrorResponse("CANTIDAD_INVALIDA", "Entre 1 y 3 bolsas."));

        var creada = await _servicio.CrearAsync(peticion, User.ObtenerId());
        return Created($"/api/reservas/{creada.ReservaId}", creada);
    }

    [HttpGet("mias")]
    public async Task<ActionResult<IReadOnlyList<ReservaResponse>>> Mias(
        [FromQuery] string estado = "activas")
        => Ok(await _servicio.MisReservasAsync(User.ObtenerId(), estado));

    [HttpGet("{id:long}")]
    public async Task<ActionResult<ReservaDetalleResponse>> PorId(long id)
    {
        var reserva = await _servicio.ObtenerAsync(id, User.ObtenerId());
        return reserva is null ? NotFound() : Ok(reserva);
    }

    [HttpPost("{id:long}/pago")]
    public async Task<ActionResult<PagoResponse>> Pagar(long id)
        => Ok(await _servicio.PagarAsync(id, User.ObtenerId()));
}

// ---------- Services/IReservaService.cs
public interface IReservaService
{
    Task<ReservaCreadaResponse> CrearAsync(CrearReservaRequest peticion, long usuarioId);
    Task<IReadOnlyList<ReservaResponse>> MisReservasAsync(long usuarioId, string estado);
    Task<ReservaDetalleResponse?> ObtenerAsync(long reservaId, long usuarioId);
    Task<PagoResponse> PagarAsync(long reservaId, long usuarioId);
}

public sealed class ReservaService : IReservaService
{
    private readonly IReservaRepository _repo;
    public ReservaService(IReservaRepository repo) => _repo = repo;

    public Task<ReservaCreadaResponse> CrearAsync(CrearReservaRequest p, long usuarioId)
        => _repo.CrearAsync(p, usuarioId);   // la regla vive en el procedimiento

    public async Task<ReservaDetalleResponse?> ObtenerAsync(long reservaId, long usuarioId)
    {
        var reserva = await _repo.PorIdAsync(reservaId);
        // Regla de aplicación: nadie ve la reserva de otro.
        if (reserva is null || reserva.ClienteId != usuarioId) return null;
        return reserva;
    }
    // ...
}

// ---------- Repositories/IReservaRepository.cs
public interface IReservaRepository
{
    Task<ReservaCreadaResponse> CrearAsync(CrearReservaRequest peticion, long usuarioId);
    Task<IReadOnlyList<ReservaResponse>> PorClienteAsync(long usuarioId, string estado);
    Task<ReservaDetalleResponse?> PorIdAsync(long reservaId);
}
```

**Dónde va cada cosa.** La validación de forma —que la cantidad esté entre 1 y 3, que el correo
tenga arroba— va en el controlador. La regla de aplicación —que nadie vea la reserva de otro— va
en el servicio. La regla de negocio —que no se pueda reservar sin cupo— **ya está en la base** y
no se reimplementa en ningún lado.

---

## 12. Contrato de API completo

24 endpoints. `A` es Back A, `B` es Back B, `D` es David.

| # | Verbo | Ruta | Entrada | Salida | Dueño |
|---|---|---|---|---|---|
| 1 | POST | `/api/auth/registro` | `RegistroRequest` | `201 UsuarioResponse` | A |
| 2 | POST | `/api/auth/login` | `LoginRequest` | `200 LoginResponse` | A |
| 3 | GET | `/api/auth/yo` | — | `200 UsuarioResponse` | A |
| 4 | GET | `/api/zonas` | — | `200 List<ZonaResponse>` | A |
| 5 | GET | `/api/categorias-alimento` | — | `200 List<CategoriaAlimentoResponse>` | A |
| 6 | GET | `/api/sucursales/{id}` | — | `200 SucursalDetalleResponse` | A |
| 7 | GET | `/api/mis-sucursales` | — | `200 List<AsignacionResponse>` | A |
| 8 | GET | `/api/publicaciones` | `?zonaId=&categoriaId=` | `200 List<PublicacionResponse>` | A |
| 9 | GET | `/api/publicaciones/{id}` | — | `200 PublicacionDetalleResponse` | A |
| 10 | GET | `/api/sucursales/{id}/plantillas` | — | `200 List<PlantillaResponse>` | A |
| 11 | POST | `/api/sucursales/{id}/plantillas` | `CrearPlantillaRequest` | `201 { id }` | A |
| 12 | POST | `/api/publicaciones` | `CrearPublicacionRequest` | `201 PublicacionCreadaResponse` | A |
| 13 | GET | `/api/sucursales/{id}/publicaciones` | `?fecha=` | `200 List<PublicacionPanelResponse>` | A |
| 14 | GET | `/api/metodos-pago` | — | `200 List<MetodoPagoResponse>` | B |
| 15 | POST | `/api/reservas` | `CrearReservaRequest` | `201 ReservaCreadaResponse` | B |
| 16 | POST | `/api/reservas/{id}/pago` | — | `200 PagoResponse` | B |
| 17 | GET | `/api/reservas/mias` | `?estado=activas\|historial` | `200 List<ReservaResponse>` | B |
| 18 | GET | `/api/reservas/{id}` | — | `200 ReservaDetalleResponse` | B |
| 19 | GET | `/api/sucursales/{id}/reservas` | `?fecha=` | `200 List<ReservaPanelResponse>` | B |
| 20 | POST | `/api/retiros` | `EntregarRequest` | `200 EntregaResponse` | B |
| 21 | POST | `/api/mantenimiento/vencer-publicaciones` | — | `200 CierreResponse` | B |
| 22 | GET | `/api/liquidaciones` | `?comercioId=` | `200 List<LiquidacionResponse>` | B |
| 23 | POST | `/api/liquidaciones` | `GenerarLiquidacionRequest` | `201 { liquidacionId }` | B |
| 24 | GET | `/api/liquidaciones/{id}` | — | `200 LiquidacionDetalleResponse` | B |
| 25 | GET | `/api/reportes/venta-diaria` | — | `200 List<VentaDiariaResponse>` | D |
| 26 | GET | `/api/reportes/ranking-sucursales` | — | `200 List<RankingResponse>` | D |

Todos requieren token salvo `registro` y `login`.

**Formato del error, igual en todos:**

```json
{ "codigo": "SIN_CUPO", "mensaje": "SIN_CUPO: quedan 0 bolsas" }
```

---

## 13. Vistas disponibles — úsenlas en vez de rearmar los JOIN

| Vista | Columnas que devuelve |
|---|---|
| `comercio.vw_sucursal_activa` | `sucursal_id, sucursal, direccion, latitud, longitud, comercio_id, nombre_comercial, rubro, zona_id, zona, ciudad, hora_limite_retiro` |
| `oferta.vw_publicacion_vigente` | `publicacion_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_disponible, precio_venta, plantilla_id, bolsa, descripcion, valor_estimado, alergenos, peso_estimado_kg, tipo_alimento, es_perecible, sucursal_id, sucursal, direccion, latitud, longitud, nombre_comercial, rubro, zona_id, zona, descuento_pct` |
| `venta.vw_reserva_detalle` | `reserva_id, codigo, estado_reserva, cantidad, precio_unitario, subtotal, isv, total, comision_plataforma, monto_comercio, fecha_reserva, retiro_date, cliente_id, cliente, cliente_telefono, fecha, hora_inicio_retiro, hora_fin_retiro, bolsa, sucursal_id, sucursal, comercio_id, nombre_comercial, estado_pago, metodo_pago` |
| `core.mv_impacto_usuario` | `usuario_id, bolsas_rescatadas, kg_rescatados, kg_co2_evitados, ahorro_total` |
| `core.mv_ranking_sucursal` | `sucursal_id, sucursal, nombre_comercial, calificaciones, promedio, retiradas, no_retiradas` |
| `core.mv_venta_diaria` | `fecha, zona_id, zona, rubro, reservas, total_vendido, comision, no_shows` |

`oferta.vw_publicacion_vigente` **ya filtra** por estado publicado, con cupo y dentro de la ventana.
No hay que repetir ese filtro en el `WHERE`.

Las materializadas no se actualizan solas. Antes de la demo:

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_venta_diaria;
REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_ranking_sucursal;
REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_impacto_usuario;
```

---

## 14. Alcance · qué se construye y qué no

De 8 módulos se llevan **7**, uno degradado.

| Módulo | Qué es | Dueño | Estado |
|---|---|---|---|
| M0 | Identidad y acceso | Back A | Obligatorio |
| M1 | Comercios y sucursales | Back A | Obligatorio |
| M2 | Oferta y búsqueda | Back A | Obligatorio |
| M3 | Reserva y pago | Back B | Obligatorio |
| M4 | Retiro y validación | Back B | Obligatorio |
| M6 | Liquidación | Back B | Solo lectura |
| M7 | Consultas de negocio | David | Solo lectura |
| M5 | Reloj de vencimiento | Back B | **Degradado a un endpoint manual** |

**Fuera de alcance — no implementar:** notificaciones push, consola administrativa, Row Level
Security (el archivo `V014` existe pero **no se aplica**), calificaciones, favoritos, recuperación
de contraseña, bloqueo por intentos fallidos, búsqueda geográfica y por trigramas, tarjetas
guardadas, pasarela de pago real (**el pago se simula y siempre aprueba**) y lectura de QR
(**el código se teclea**).

Las 9 tablas que sostienen esas funciones **están creadas** en la base; simplemente no reciben
escrituras. No hay que borrarlas.

---

## 15. Reglas de negocio que la base ya hace cumplir

No se reimplementan, pero hay que conocerlas para entender por qué algo falla:

- Máximo **3 bolsas** por cliente en una misma publicación
- Un cliente con **3 o más faltas** (`no_shows`) no puede pagar en efectivo
- La ventana de retiro debe caber en el **horario de la sucursal**
- La ventana no puede exceder las **horas máximas de la categoría** (comida preparada: 1 hora)
- No se puede retirar **fuera de la ventana**
- El **precio de venta debe ser menor** que el valor estimado
- Una reserva **no puede tener dos pagos** en estado `CAPTURADO`
- Una reserva entra en **una sola liquidación**
- Las transiciones de estado inválidas se rechazan por trigger
- `creation_date` es inmutable: si alguien la cambia, un trigger la restaura

---

## 16. Reglas de trabajo del equipo

1. **Solo David escribe DDL.** Nadie ejecuta `CREATE TABLE` ni `ALTER TABLE`. Si falta una
   columna, se le pide y él la agrega como migración numerada. Los archivos aplicados son
   inmutables.
2. **La lógica crítica se llama, no se reimplementa.** Si el procedimiento está mal, se corrige
   el procedimiento.
3. **Back A y Back B no escriben en las mismas tablas.** Back A escribe en `seguridad`, `geo`,
   `comercio` y `oferta`. Back B escribe en `venta` y `finanza`. Leer se puede todo.
4. **Toda petición autenticada fija `app.usuario_id`** al abrir la conexión.
5. **El contrato de la sección 12 no se cambia sin avisar al frontend.**
6. El camino dorado se prueba completo en cada integración.

---

## 17. Orden de trabajo sugerido

**Back A**

1. `ConexionFactory`, `ErroresMiddleware`, `TokenService`, `HashService` — los usa todo el resto
2. `AuthController` completo: registro, login, yo
3. `ZonasController` y `CategoriasAlimentoController` — son dos `SELECT`, dan confianza rápido
4. `PublicacionesController.Listar` sobre la vista vigente — desbloquea la pantalla principal
5. `SucursalesController` y `PlantillasController`
6. `PublicacionesController.Crear` — el que más triggers dispara

**Back B**

1. Esperar a que Back A tenga el login, o generar un token a mano para probar
2. `MetodosPagoController` — un `SELECT`, sirve de calentamiento
3. `ReservasController.Crear` llamando a `sp_reserva_crear` — **el más importante del proyecto**
4. `ReservasController.Pagar` con transacción
5. `RetirosController` llamando a `sp_reserva_retirar`
6. `MantenimientoController`, y al final `LiquidacionesController`

---

## 18. Errores comunes · lo que va a pasar

| Síntoma | Causa | Solución |
|---|---|---|
| `procedure ... does not exist` al llamar un `sp` | Faltan los `NULL` de los parámetros `OUT` | Pasarlos y usar `QuerySingleAsync` |
| Todas las propiedades vienen en cero o nulas | Falta `MatchNamesWithUnderscores` | Agregar la línea en `Program.cs` |
| `column "estado" is of type core.en_... ` | Se leyó un `ENUM` sin castear | `estado::text AS estado` |
| Los montos pierden centavos | Se usó `double` | Usar `decimal` |
| `Cannot write DateTime with Kind=Local` | `timestamptz` con `DateTime` local | Usar `DateTimeOffset` |
| La bitácora queda sin autor | No se fijó `app.usuario_id` | Usar siempre `ConexionFactory.AbrirAsync(usuarioId)` |
| El teléfono no conecta | La API escucha solo en `localhost` | `--urls "http://0.0.0.0:5080"` y usar la IP de la red |
| Login siempre falla | No se aplicó `S003` | Ejecutar `S003__contrasenas_demo.sql` |
| `403` al entregar una bolsa | El empleado no pertenece a esa sucursal | Es correcto: es la regla `EMPLEADO_AJENO` |

---

## 19. Documentos de referencia

En `SEMANA 6/PROYECTO/BBDD/`:

- **`12-mockups-completos.html`** — las 39 pantallas con su contrato técnico. **El documento maestro.**
- `db/INSTALAR_TODO.sql` — instalador de un paso
- `db/S003__contrasenas_demo.sql` — contraseñas de prueba
- `db/README.md` — orden de ejecución y convenciones de la base
- `08-diccionario-datos-mvp.html` — las 21 tablas del MVP, columna por columna
- `07-reparto-mvp.html` — el recorte de alcance en detalle
- `10-flujo-y-pantallas.html` — el flujo de negocio por entidades

---

## 20. Qué se espera de este chat

Ayudar a construir la API REST en .NET 8 con Dapper sobre la base ya existente, respetando que:

- **No se modifica el esquema.** Si hace falta un cambio, se le pide a David.
- **No se reimplementa la lógica de negocio** que ya está en los procedimientos.
- **El código se mantiene simple.** Es un proyecto universitario con plazo corto: controladores,
  servicios y repositorios directos. Sin mediadores, sin repositorio genérico, sin capas de más.
- La prioridad absoluta es que el **camino dorado** funcione de punta a punta.
