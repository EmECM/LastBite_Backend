using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Dapper;
using LastBite.Api.Common;
using LastBite.Api.Repositories;
using LastBite.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------------------
// Dapper: las vistas de la base devuelven columnas en snake_case y nuestras
// propiedades son PascalCase. Sin esta línea, cantidad_disponible NO se mapea
// a CantidadDisponible y todo llega en cero o nulo.
// ---------------------------------------------------------------------------
DefaultTypeMap.MatchNamesWithUnderscores = true;

// ---------------------------------------------------------------------------
// Dapper 2.1.79 no convierte las columnas date y time a DateOnly y TimeOnly,
// que son los tipos que usan los DTO. Sin estas dos líneas, cualquier DTO con
// horarios o fechas revienta al leerse. Ver Common/FechaHoraTypeHandlers.cs.
// ---------------------------------------------------------------------------
SqlMapper.AddTypeHandler(new DateOnlyTypeHandler());
SqlMapper.AddTypeHandler(new TimeOnlyTypeHandler());

// ---------------------------------------------------------------------------
// Controladores y JSON
// ---------------------------------------------------------------------------
builder.Services.AddControllers()
    .AddJsonOptions(o =>
    {
        o.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
        o.JsonSerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
    });

// ---------------------------------------------------------------------------
// Swagger, con el botón de "Authorize" para pegar el token
// ---------------------------------------------------------------------------
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Last Bite API",
        Version = "v1",
        Description = "API del proyecto Last Bite · INF308 CEUTEC"
    });

    o.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Pegá solo el token, sin la palabra Bearer."
    });

    o.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// ---------------------------------------------------------------------------
// CORS abierto: esto corre en una red local para una demo, no es un servicio
// público. Permite que la app de Flutter conecte desde el teléfono.
// ---------------------------------------------------------------------------
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));

// ---------------------------------------------------------------------------
// Autenticación con JWT
// ---------------------------------------------------------------------------
var jwtClave = builder.Configuration["Jwt:Clave"]
    ?? throw new InvalidOperationException("Falta Jwt:Clave en la configuración.");

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
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtClave)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

builder.Services.AddAuthorization();

// ---------------------------------------------------------------------------
// Infraestructura
// ---------------------------------------------------------------------------
builder.Services.AddSingleton<ConexionFactory>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<HashService>();

// ---------------------------------------------------------------------------
// Servicios y repositorios
//
// Cada quien agrega acá los suyos, en su bloque, para no chocar al unir
// el trabajo. Mantener el orden alfabético dentro de cada bloque.
// ---------------------------------------------------------------------------

// --- Compartido -------------------------------------------------------------
builder.Services.AddScoped<IZonaRepository, ZonaRepository>();
builder.Services.AddScoped<IZonaService, ZonaService>();

// --- Back A · M0 identidad, M1 comercios, M2 oferta -------------------------
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ISucursalRepository, SucursalRepository>();
builder.Services.AddScoped<ISucursalService, SucursalService>();
builder.Services.AddScoped<IUsuarioRepository, UsuarioRepository>();

// --- Back B · M3 reserva, M4 retiro, M6 liquidación -------------------------
// builder.Services.AddScoped<IReservaRepository, ReservaRepository>();
// builder.Services.AddScoped<IReservaService, ReservaService>();

var app = builder.Build();

// ---------------------------------------------------------------------------
// Tubería de peticiones. El orden importa.
// ---------------------------------------------------------------------------
app.UseSwagger();
app.UseSwaggerUI(o => o.DocumentTitle = "Last Bite API");

app.UseCors();

// El middleware de errores va ANTES de la autenticación, para que también
// atrape lo que falle ahí adentro.
app.UseMiddleware<ErroresMiddleware>();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
