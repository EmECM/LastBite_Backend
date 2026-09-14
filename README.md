# Last Bite · Backend

API REST del proyecto **Last Bite**, un sistema tipo Too Good To Go adaptado a San Pedro Sula.
Proyecto integrador de **INF308 – Administración de Bases de Datos**, CEUTEC 2026 Q3.

**.NET 8 · Controladores · Dapper sobre Npgsql · PostgreSQL**

---

## Arrancar en cinco minutos

### 1. Levantar la base de datos

En DBeaver, conectado a la base `postgres` y en modo Auto-Commit:

```sql
CREATE DATABASE lastbite;
```

Cambiá la conexión a `lastbite` y ejecutá, en orden, con *Execute script* (Alt+X):

1. `docs/INSTALAR_TODO.sql` — crea las 30 tablas, vistas, procedimientos, triggers y datos de prueba
2. `docs/S003__contrasenas_demo.sql` — pone contraseñas válidas a los usuarios de prueba

Verificación opcional: `docs/T001__pruebas_reglas.sql` debe decir
`RESULTADO: 16 pruebas correctas, 0 fallas`.

> Requiere PostgreSQL 15 o superior con las extensiones `btree_gist` y `pg_trgm`,
> que vienen en el paquete `contrib` estándar.

### 2. Configurar la conexión

Si tu PostgreSQL tiene otro usuario o contraseña, ajustá
`LastBite.Api/appsettings.Development.json`.

### 3. Correr la API

```bash
cd LastBite.Api
dotnet restore
dotnet run
```

Abrí `http://localhost:5080/swagger`.

### 4. Verificar

| Endpoint | Qué comprueba |
|---|---|
| `GET /api/ping` | Que la API está viva |
| `GET /api/ping/base` | Que la base responde. Debe devolver **30 tablas** |
| `GET /api/zonas` | Una consulta real. Devuelve **5 zonas activas** de San Pedro Sula |

`GET /api/zonas` requiere token. Pedilo con `POST /api/auth/login` (por ejemplo con
`kevin.zelaya@correo.hn` / `LastBite2026`), copiá el `token` de la respuesta y pegalo en el
botón **Authorize** de Swagger. Sin token responde `401`, que es lo esperado.

### 5. Para probar desde el teléfono

```bash
dotnet run --urls "http://0.0.0.0:5080"
```

Pasale tu IP de la red local al equipo de frontend (`ipconfig` en Windows). El teléfono **no
puede usar `localhost`**: eso apunta al propio teléfono.

---

## Usuarios de prueba

Todos con la contraseña **`LastBite2026`**.

| Correo | Perfil |
|---|---|
| `kevin.zelaya@correo.hn` | Cliente |
| `sofia.andino@correo.hn` | Cliente |
| `marlon.pineda@correo.hn` | Cliente |
| `daniela.cruz@correo.hn` | Cliente **con 3 faltas** · sirve para probar `EFECTIVO_BLOQUEADO` |
| `rosa.mejia@eltrigal.hn` | Cajera · panel del comercio |
| `admin@lastbite.hn` | Administrador |

---

## Estructura

```
LastBite.Api/
├── Program.cs              Configuración, JWT, CORS, Swagger y dependencias
├── Common/                 Infraestructura compartida
│   ├── ConexionFactory     Abre Npgsql y fija app.usuario_id  ← clave
│   ├── ErroresMiddleware   Traduce los errores de PostgreSQL a HTTP
│   ├── ErrorResponse       { codigo, mensaje }
│   ├── TokenService        Genera el JWT
│   ├── HashService         BCrypt
│   └── ClaimsExtensions    User.ObtenerId()
├── Controllers/            Uno por recurso. Sin lógica, sin SQL
├── Services/               Interfaz e implementación. Reglas de aplicación
├── Repositories/           Todo el SQL vive acá
└── Dtos/                   Los 8 archivos con todos los DTO del contrato
```

**El flujo es siempre el mismo y ninguna capa se salta:**

```
Controller → IService → IRepository → Dapper → procedimiento o vista
```

---

## Qué ya está hecho y qué falta

**Listo:**

- Proyecto configurado con los cinco paquetes
- Las seis clases de `Common`
- Los **8 archivos de DTO** con todos los objetos del contrato
- `GET /api/ping` y `GET /api/ping/base`
- **`GET /api/zonas` completo** — controlador, servicio y repositorio, como
  rebanada de referencia del patrón
- **M0 · Identidad** — `POST /api/auth/registro`, `POST /api/auth/login`, `GET /api/auth/yo`
- **M1 · Sucursales** — `GET /api/sucursales/{id}`, `GET /api/mis-sucursales`

**Falta:** los 20 endpoints restantes. Están en la tabla de la sección 12 de
`CONTEXTO-BACKEND.md`, cada uno con su dueño.

| Módulo | Endpoints | Dueño |
|---|---|---|
| M2 · Oferta y búsqueda | 7 | Back A |
| M3 · Reserva y pago | 5 | Back B |
| M4 · Retiro | 2 | Back B |
| M5 · Cierre del día | 1 | Back B |
| M6 · Liquidación | 3 | Back B |
| M7 · Reportes | 2 | David |

---

## Reglas del proyecto

1. **Solo David escribe DDL.** Nadie ejecuta `CREATE TABLE` ni `ALTER TABLE`. Si falta una
   columna, se le pide y la agrega como migración numerada.
2. **La lógica crítica se llama, no se reimplementa.** Reservar, retirar, vencer y liquidar
   ya son procedimientos almacenados probados.
3. **Back A escribe en** `seguridad`, `geo`, `comercio` y `oferta`.
   **Back B escribe en** `venta` y `finanza`. Leer se puede todo.
4. **Toda petición autenticada fija `app.usuario_id`** al abrir la conexión, con
   `ConexionFactory.AbrirAsync(usuarioId)`. Sin eso la auditoría queda sin autor.
5. **El contrato no se cambia sin avisar al frontend.**

---

## Tres trampas que van a encontrar

**Los `ENUM` se leen como texto.** Hay que castear en el SQL: `estado::text AS estado`.
Sin el cast, Npgsql no sabe convertir `core.en_estado_reserva` a `string`.

**Las columnas llegan en snake_case.** Ya está resuelto con
`DefaultTypeMap.MatchNamesWithUnderscores = true` en `Program.cs`. Si alguien lo quita, todas
las propiedades llegan en cero o nulas.

**Los procedimientos con parámetros `OUT`** exigen que se pasen marcadores `NULL` en el `CALL`
y **devuelven una fila** con los valores de salida. Por eso se usa `QuerySingleAsync` y no
`ExecuteAsync`. Omitirlos da `procedure does not exist`.

---

## Documentación

- **`CONTEXTO-BACKEND.md`** — el documento completo. Estructura, convenciones, todos los DTO,
  el contrato de la API, los procedimientos y los errores comunes. **Empezá por acá.**
- `docs/12-mockups-completos.html` — las 39 pantallas del producto con su contrato técnico
- `docs/08-diccionario-datos-mvp.html` — las 21 tablas del MVP, columna por columna
