/* ============================================================================
   LAST BITE · INSTALADOR COMPLETO
   ----------------------------------------------------------------------------
   Este archivo es la concatenación, en orden, de los scripts V001 a V013 más
   los datos semilla (S001) y los datos de prueba (S002). Está pensado para
   levantar la base de cero en la máquina de cada integrante del equipo.

   GENERADO AUTOMÁTICAMENTE. No se edita: si hace falta un cambio, se corrige
   el archivo de origen y se vuelve a generar este.

   ----------------------------------------------------------------------------
   PASO 0 — conectado a la base "postgres", en modo Auto-Commit:

       CREATE DATABASE lastbite;

   PASO 1 — cambiar la conexión a la base "lastbite" y ejecutar este archivo
   completo. En DBeaver: Execute script (Alt+X), NO Execute statement (Ctrl+Enter).

   Desde la terminal:

       psql -d lastbite -v ON_ERROR_STOP=1 -f INSTALAR_TODO.sql

   ----------------------------------------------------------------------------
   NO INCLUIDOS AQUÍ, a propósito:

     V014__seguridad_rls_y_permisos.sql
         GRANT/REVOKE y Row Level Security. Se aplica hasta que la
         autenticación de la aplicación esté funcionando; si se aplica antes,
         el equipo pierde acceso a las tablas mientras desarrolla.

     T001__pruebas_reglas.sql
         Las 16 pruebas de reglas de negocio. Se ejecuta aparte, después de
         esta instalación, para verificar que todo quedó bien.

   ----------------------------------------------------------------------------
   ADVERTENCIA: este script asume una base RECIÉN CREADA y vacía. No es
   idempotente: si se ejecuta dos veces sobre la misma base fallará porque los
   objetos ya existen. Para reinstalar, eliminar la base y volver al Paso 0.

   PostgreSQL 15 o superior. Escrito para 18.4.
   ========================================================================== */




-- ==========================================================================
-- ARCHIVO: V001__esquemas_y_roles.sql
-- Esquemas, roles y extensiones
-- ==========================================================================

/* ============================================================================
   LAST BITE · V001 — Esquemas y roles
   ----------------------------------------------------------------------------
   Crea la separación por esquemas y los cuatro roles del sistema.
   Se ejecuta conectado a la base lastbite, como superusuario o dueño.
   ========================================================================== */

CREATE SCHEMA IF NOT EXISTS core;        -- dominios, tipos, funciones, secuencias
CREATE SCHEMA IF NOT EXISTS seguridad;   -- identidad y acceso
CREATE SCHEMA IF NOT EXISTS geo;         -- jerarquía territorial
CREATE SCHEMA IF NOT EXISTS comercio;    -- socios y puntos de retiro
CREATE SCHEMA IF NOT EXISTS oferta;      -- qué se vende y cuánto hay hoy
CREATE SCHEMA IF NOT EXISTS venta;       -- reservas y pagos
CREATE SCHEMA IF NOT EXISTS finanza;     -- tarifas y liquidaciones
CREATE SCHEMA IF NOT EXISTS social;      -- calificaciones, favoritos, avisos
CREATE SCHEMA IF NOT EXISTS auditoria;   -- bitácora, solo escritura

COMMENT ON SCHEMA core      IS 'Infraestructura: dominios, tipos, funciones utilitarias y secuencias.';
COMMENT ON SCHEMA seguridad IS 'Identidad y acceso: usuarios, roles, sesiones e intentos de acceso.';
COMMENT ON SCHEMA geo       IS 'Jerarquía territorial: departamento, ciudad y zona.';
COMMENT ON SCHEMA comercio  IS 'Comercios afiliados, sucursales, horarios y personal de mostrador.';
COMMENT ON SCHEMA oferta    IS 'Catálogo de alimentos, plantillas de bolsa y publicaciones diarias.';
COMMENT ON SCHEMA venta     IS 'Métodos de pago, reservas e intentos de cobro.';
COMMENT ON SCHEMA finanza   IS 'Tarifas vigentes y liquidaciones a los comercios.';
COMMENT ON SCHEMA social    IS 'Calificaciones, favoritos y notificaciones.';
COMMENT ON SCHEMA auditoria IS 'Bitácora de cambios. Solo se agrega, nunca se edita.';


/* ---------------------------------------------------------------------------
   Roles. Ninguno es superusuario y la aplicación nunca es dueña de las tablas.
   Cambie las contraseñas antes de usar esto fuera de desarrollo.
   --------------------------------------------------------------------------- */
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lb_owner') THEN
        CREATE ROLE lb_owner NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lb_app') THEN
        CREATE ROLE lb_app    LOGIN PASSWORD 'CambiarEnDespliegue_App';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lb_batch') THEN
        CREATE ROLE lb_batch  LOGIN PASSWORD 'CambiarEnDespliegue_Batch';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'lb_report') THEN
        CREATE ROLE lb_report LOGIN PASSWORD 'CambiarEnDespliegue_Report';
    END IF;
END $$;

COMMENT ON ROLE lb_owner  IS 'Dueño del DDL. No inicia sesión.';
COMMENT ON ROLE lb_app    IS 'La aplicación. Lee y escribe, nunca borra.';
COMMENT ON ROLE lb_batch  IS 'Procesos programados: vencer publicaciones y liquidar.';
COMMENT ON ROLE lb_report IS 'Solo lectura, para reportes.';

-- El search_path se fija por rol para no depender de la sesión.
ALTER ROLE lb_app    SET search_path = venta, oferta, comercio, seguridad, geo, social, core, public;
ALTER ROLE lb_batch  SET search_path = oferta, venta, finanza, social, core, public;
ALTER ROLE lb_report SET search_path = core, public;

-- Extensiones necesarias:
--   btree_gist  -> restricción EXCLUDE de ventanas traslapadas (V006)
--   pg_trgm     -> búsqueda por nombre de comercio (V005)
CREATE EXTENSION IF NOT EXISTS btree_gist;
CREATE EXTENSION IF NOT EXISTS pg_trgm;



-- ==========================================================================
-- ARCHIVO: V002__dominios_tipos_y_funciones.sql
-- Dominios, tipos ENUM, funciones y correlativos
-- ==========================================================================

/* ============================================================================
   LAST BITE · V002 — Dominios, tipos enumerados y funciones utilitarias
   ----------------------------------------------------------------------------
   Todo lo que las demás tablas usan como tipo. Se define una sola vez.
   ========================================================================== */

/* --------------------------- DOMINIOS ------------------------------------ */
-- Dinero: NUMERIC siempre, nunca FLOAT, y nunca negativo.
CREATE DOMAIN core.dm_dinero AS NUMERIC(12,2)
    CHECK (VALUE >= 0);

-- Registro Tributario Nacional: catorce dígitos exactos.
CREATE DOMAIN core.dm_rtn AS CHAR(14)
    CHECK (VALUE ~ '^[0-9]{14}$');

CREATE DOMAIN core.dm_correo AS VARCHAR(120)
    CHECK (VALUE ~* '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$');

CREATE DOMAIN core.dm_tel_hn AS VARCHAR(15)
    CHECK (VALUE ~ '^\+504[0-9]{8}$');

-- Coordenadas con seis decimales: precisión de centímetros, sin error de redondeo.
CREATE DOMAIN core.dm_latitud  AS NUMERIC(9,6) CHECK (VALUE BETWEEN  -90 AND  90);
CREATE DOMAIN core.dm_longitud AS NUMERIC(9,6) CHECK (VALUE BETWEEN -180 AND 180);

COMMENT ON DOMAIN core.dm_dinero IS 'Importes en lempiras. NUMERIC(12,2) no negativo.';
COMMENT ON DOMAIN core.dm_rtn    IS 'RTN hondureño: catorce dígitos.';


/* --------------------------- TIPOS ENUMERADOS ----------------------------- */
-- Conjuntos cerrados. Pesan menos que el texto y aparecen en el catálogo,
-- que es donde el front end puede leerlos para armar sus filtros.
CREATE TYPE core.en_estado_usuario     AS ENUM ('ACTIVO','SUSPENDIDO','ELIMINADO');
CREATE TYPE core.en_tipo_token         AS ENUM ('RECUPERACION','VERIFICACION_CORREO');
CREATE TYPE core.en_estado_comercio    AS ENUM ('PENDIENTE','ACTIVO','SUSPENDIDO');
CREATE TYPE core.en_cargo              AS ENUM ('PROPIETARIO','ENCARGADO','CAJERO');
CREATE TYPE core.en_estado_publicacion AS ENUM ('PROGRAMADA','PUBLICADA','AGOTADA','VENCIDA','CANCELADA');
CREATE TYPE core.en_estado_reserva     AS ENUM ('PENDIENTE_PAGO','CONFIRMADA','RETIRADA','NO_RETIRADA','CANCELADA','REEMBOLSADA');
CREATE TYPE core.en_estado_pago        AS ENUM ('PENDIENTE','EN_VERIFICACION','CAPTURADO','FALLIDO','REEMBOLSADO');
CREATE TYPE core.en_estado_liquidacion AS ENUM ('CALCULADA','PAGADA','ANULADA');
CREATE TYPE core.en_tipo_tarifa        AS ENUM ('PORCENTUAL','FIJA');
CREATE TYPE core.en_tipo_notificacion  AS ENUM ('NUEVA_PUBLICACION','RECORDATORIO_RETIRO','PAGO','LIQUIDACION','SISTEMA');
CREATE TYPE core.en_accion             AS ENUM ('INSERT','UPDATE','DELETE');


/* --------------------------- PARÁMETROS DEL SISTEMA ----------------------- */
CREATE TABLE core.parametro (
    clave         VARCHAR(40)  NOT NULL,
    valor         VARCHAR(200) NOT NULL,
    descripcion   VARCHAR(200),
    CONSTRAINT pk_parametro PRIMARY KEY (clave)
);
COMMENT ON TABLE core.parametro IS 'Valores de configuración que el negocio puede cambiar sin tocar código.';


/* --------------------------- FUNCIONES UTILITARIAS ------------------------ */
/* Quién es la persona detrás de la conexión.
   La aplicación se conecta con un solo rol de PostgreSQL, así que le informa
   el usuario de negocio por sesión:  SET LOCAL app.usuario_id = '57';
   Si nadie lo fijó, responde 1, que es el usuario de sistema.               */
CREATE OR REPLACE FUNCTION core.fn_usuario_actual()
RETURNS BIGINT
LANGUAGE sql STABLE AS $$
    SELECT coalesce(
        nullif(current_setting('app.usuario_id', true), '')::bigint,
        1
    );
$$;

COMMENT ON FUNCTION core.fn_usuario_actual() IS
    'Usuario de negocio de la sesión, tomado de app.usuario_id. Devuelve 1 (sistema) si no está fijado.';


/* Llena y protege las columnas de auditoría.
   Una sola función sirve para las veinte tablas de nivel A y B: lo único que
   se repite es la línea del CREATE TRIGGER.                                  */
CREATE OR REPLACE FUNCTION core.fn_auditoria_fila()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        NEW.creation_date     := now();
        NEW.created_by        := coalesce(NEW.created_by, core.fn_usuario_actual());
        NEW.modification_date := NULL;
        NEW.modified_by       := NULL;
    ELSE
        NEW.creation_date     := OLD.creation_date;   -- inmutables
        NEW.created_by        := OLD.created_by;
        NEW.modification_date := now();
        NEW.modified_by       := core.fn_usuario_actual();
    END IF;
    RETURN NEW;
END $$;

/* Variante para las tablas de nivel C, que solo tienen las dos de alta. */
CREATE OR REPLACE FUNCTION core.fn_auditoria_alta()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    NEW.creation_date := now();
    NEW.created_by    := coalesce(NEW.created_by, core.fn_usuario_actual());
    RETURN NEW;
END $$;


/* Correlativos de negocio.
   Una secuencia no se bloquea entre transacciones, a diferencia de una tabla
   contador. Deja huecos si una transacción falla, lo cual está bien para un
   código de retiro y no lo estaría para una numeración fiscal.              */
CREATE SEQUENCE core.sq_reserva_codigo START 1;

CREATE OR REPLACE FUNCTION core.fn_siguiente_codigo(p_prefijo TEXT)
RETURNS TEXT
LANGUAGE sql AS $$
    SELECT p_prefijo || '-' || to_char(current_date, 'YYYY') || '-' ||
           lpad(nextval('core.sq_reserva_codigo')::text, 6, '0');
$$;

COMMENT ON FUNCTION core.fn_siguiente_codigo(TEXT) IS
    'Genera códigos tipo LB-2026-000123 sin bloquear entre transacciones.';



-- ==========================================================================
-- ARCHIVO: V003__seguridad.sql
-- Identidad y acceso
-- ==========================================================================

/* ============================================================================
   LAST BITE · V003 — Esquema seguridad
   ----------------------------------------------------------------------------
   Identidad y acceso. Una sola identidad por persona, sin importar cuántos
   papeles cumpla: el dueño de la panadería también compra bolsas.
   ========================================================================== */

/* --------------------------------- usuario -------------------------------
   Nivel de auditoría A. Es la tabla raíz del sistema: created_by de todas
   las demás apunta aquí.                                                    */
CREATE TABLE seguridad.usuario (
    id                     BIGINT GENERATED ALWAYS AS IDENTITY,
    nombres                VARCHAR(60)     NOT NULL,
    apellidos              VARCHAR(60)     NOT NULL,
    correo                 core.dm_correo  NOT NULL,
    telefono               core.dm_tel_hn,
    contrasena_hash        VARCHAR(255)    NOT NULL,
    contrasena_actualizada TIMESTAMPTZ     NOT NULL DEFAULT now(),
    correo_verificado      BOOLEAN         NOT NULL DEFAULT false,
    intentos_fallidos      SMALLINT        NOT NULL DEFAULT 0,
    bloqueado_hasta        TIMESTAMPTZ,
    no_shows               SMALLINT        NOT NULL DEFAULT 0,
    ultimo_acceso          TIMESTAMPTZ,
    estado                 core.en_estado_usuario NOT NULL DEFAULT 'ACTIVO',
    created_by             BIGINT          NOT NULL,
    creation_date          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    modified_by            BIGINT,
    modification_date      TIMESTAMPTZ,
    es_activo              BOOLEAN         NOT NULL DEFAULT true,
    CONSTRAINT pk_usuario          PRIMARY KEY (id),
    CONSTRAINT uq_usuario_correo   UNIQUE (correo),
    CONSTRAINT uq_usuario_telefono UNIQUE (telefono),
    CONSTRAINT ck_usuario_intentos CHECK (intentos_fallidos >= 0),
    CONSTRAINT ck_usuario_noshows  CHECK (no_shows >= 0)
);

/* Las llaves de auditoría se autorreferencian. Son DEFERRABLE porque el
   usuario de sistema, que es la primera fila de la base, se apunta a sí mismo
   y sin diferir la verificación ese INSERT sería imposible.                 */
ALTER TABLE seguridad.usuario
    ADD CONSTRAINT fk_usuario_created_by  FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED,
    ADD CONSTRAINT fk_usuario_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id)
        ON UPDATE RESTRICT ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;

-- El correo se compara sin distinguir mayúsculas al iniciar sesión.
CREATE UNIQUE INDEX uq_usuario_correo_lower ON seguridad.usuario (lower(correo));
CREATE INDEX ix_usuario_created_by  ON seguridad.usuario (created_by);
CREATE INDEX ix_usuario_modified_by ON seguridad.usuario (modified_by);

COMMENT ON COLUMN seguridad.usuario.no_shows IS
    'Reservas apartadas y no retiradas. Es lo que habilita o bloquea el pago en efectivo.';
COMMENT ON COLUMN seguridad.usuario.contrasena_hash IS
    'Hash calculado en la aplicación (bcrypt o Argon2). Nunca se calcula en la base: la contraseña viajaría en el SQL.';


/* ----------------------------------- rol ---------------------------------- */
CREATE TABLE seguridad.rol (
    id                SMALLINT GENERATED ALWAYS AS IDENTITY,
    codigo            VARCHAR(20)  NOT NULL,
    nombre            VARCHAR(50)  NOT NULL,
    descripcion       VARCHAR(150),
    created_by        BIGINT       NOT NULL,
    creation_date     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    modified_by       BIGINT,
    modification_date TIMESTAMPTZ,
    es_activo         BOOLEAN      NOT NULL DEFAULT true,
    CONSTRAINT pk_rol            PRIMARY KEY (id),
    CONSTRAINT uq_rol_codigo     UNIQUE (codigo),
    CONSTRAINT fk_rol_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_rol_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_rol_created_by  ON seguridad.rol (created_by);
CREATE INDEX ix_rol_modified_by ON seguridad.rol (modified_by);


/* ------------------------------- usuario_rol ------------------------------
   Nivel C. La combinación es la llave: el duplicado es imposible por diseño.
   created_by responde quién hizo administrador a quién.                     */
CREATE TABLE seguridad.usuario_rol (
    usuario_id    BIGINT      NOT NULL,
    rol_id        SMALLINT    NOT NULL,
    created_by    BIGINT      NOT NULL,
    creation_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_usuario_rol PRIMARY KEY (usuario_id, rol_id),
    CONSTRAINT fk_usuario_rol_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_rol_rol FOREIGN KEY (rol_id)
        REFERENCES seguridad.rol (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_rol_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_usuario_rol_rol        ON seguridad.usuario_rol (rol_id);
CREATE INDEX ix_usuario_rol_created_by ON seguridad.usuario_rol (created_by);


/* --------------------------------- sesion ---------------------------------
   Nivel B. Un JWT no se puede invalidar; el refresh token sí, y vive aquí.
   Sin esta tabla, cerrar sesión sería una mentira del front end.            */
CREATE TABLE seguridad.sesion (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY,
    usuario_id         BIGINT      NOT NULL,
    token_hash         CHAR(64)    NOT NULL,   -- SHA-256 en hexadecimal
    dispositivo        VARCHAR(120),
    direccion_ip       INET,
    expira             TIMESTAMPTZ NOT NULL,
    revocado_date      TIMESTAMPTZ,
    revocado_motivo    VARCHAR(40),
    reemplazada_por_id BIGINT,
    created_by         BIGINT      NOT NULL,
    creation_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by        BIGINT,
    modification_date  TIMESTAMPTZ,
    CONSTRAINT pk_sesion        PRIMARY KEY (id),
    CONSTRAINT uq_sesion_token  UNIQUE (token_hash),
    CONSTRAINT ck_sesion_expira CHECK (expira > creation_date),
    CONSTRAINT fk_sesion_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sesion_reemplazo FOREIGN KEY (reemplazada_por_id)
        REFERENCES seguridad.sesion (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sesion_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sesion_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_sesion_usuario     ON seguridad.sesion (usuario_id);
CREATE INDEX ix_sesion_reemplazo   ON seguridad.sesion (reemplazada_por_id);
CREATE INDEX ix_sesion_created_by  ON seguridad.sesion (created_by);
CREATE INDEX ix_sesion_modified_by ON seguridad.sesion (modified_by);
CREATE INDEX ixp_sesion_vigente    ON seguridad.sesion (usuario_id, expira)
    WHERE revocado_date IS NULL;

COMMENT ON COLUMN seguridad.sesion.token_hash IS
    'Hash del refresh token, nunca el token. Un respaldo robado no entrega sesiones utilizables.';


/* --------------------------- token_recuperacion ---------------------------
   Nivel C. Un solo uso y vida corta: por eso va aparte de sesion.           */
CREATE TABLE seguridad.token_recuperacion (
    id            BIGINT GENERATED ALWAYS AS IDENTITY,
    usuario_id    BIGINT             NOT NULL,
    tipo          core.en_tipo_token NOT NULL,
    token_hash    CHAR(64)           NOT NULL,
    expira        TIMESTAMPTZ        NOT NULL,
    usado_date    TIMESTAMPTZ,
    created_by    BIGINT             NOT NULL,
    creation_date TIMESTAMPTZ        NOT NULL DEFAULT now(),
    CONSTRAINT pk_token_recuperacion PRIMARY KEY (id),
    CONSTRAINT uq_token_recuperacion UNIQUE (token_hash),
    CONSTRAINT ck_token_expira       CHECK (expira > creation_date),
    CONSTRAINT fk_token_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_token_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_token_usuario    ON seguridad.token_recuperacion (usuario_id);
CREATE INDEX ix_token_created_by ON seguridad.token_recuperacion (created_by);
-- Un solo token abierto por usuario y tipo.
CREATE UNIQUE INDEX uq_token_activo
    ON seguridad.token_recuperacion (usuario_id, tipo) WHERE usado_date IS NULL;


/* ----------------------------- intento_acceso -----------------------------
   Nivel D: la fila es el registro. Sin ella no hay forma de frenar la fuerza
   bruta ni de responder desde dónde entraron a una cuenta.                  */
CREATE TABLE seguridad.intento_acceso (
    id               BIGINT GENERATED ALWAYS AS IDENTITY,
    correo_intentado VARCHAR(120) NOT NULL,   -- texto: el correo puede no existir
    usuario_id       BIGINT,
    exito            BOOLEAN      NOT NULL,
    motivo           VARCHAR(40),             -- CLAVE_INVALIDA · BLOQUEADO · SUSPENDIDO
    direccion_ip     INET,
    user_agent       VARCHAR(200),
    fecha            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_intento_acceso PRIMARY KEY (id),
    CONSTRAINT fk_intento_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_intento_usuario      ON seguridad.intento_acceso (usuario_id);
CREATE INDEX ix_intento_correo_fecha ON seguridad.intento_acceso (lower(correo_intentado), fecha DESC);
CREATE INDEX brin_intento_fecha      ON seguridad.intento_acceso USING brin (fecha);



-- ==========================================================================
-- ARCHIVO: V004__geo.sql
-- Jerarquía territorial
-- ==========================================================================

/* ============================================================================
   LAST BITE · V004 — Esquema geo
   ----------------------------------------------------------------------------
   Jerarquía territorial de tres niveles. Se ve exagerada para una sola ciudad
   y es a propósito: el día que Last Bite abra en La Ceiba no hay que rediseñar.
   ========================================================================== */

CREATE TABLE geo.departamento (
    id                SMALLINT GENERATED ALWAYS AS IDENTITY,
    nombre            VARCHAR(50) NOT NULL,
    created_by        BIGINT      NOT NULL,
    creation_date     TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by       BIGINT,
    modification_date TIMESTAMPTZ,
    es_activo         BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT pk_departamento        PRIMARY KEY (id),
    CONSTRAINT uq_departamento_nombre UNIQUE (nombre),
    CONSTRAINT fk_departamento_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_departamento_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_departamento_created_by  ON geo.departamento (created_by);
CREATE INDEX ix_departamento_modified_by ON geo.departamento (modified_by);


CREATE TABLE geo.ciudad (
    id                SMALLINT GENERATED ALWAYS AS IDENTITY,
    departamento_id   SMALLINT    NOT NULL,
    nombre            VARCHAR(60) NOT NULL,
    es_operativa      BOOLEAN     NOT NULL DEFAULT false,
    created_by        BIGINT      NOT NULL,
    creation_date     TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by       BIGINT,
    modification_date TIMESTAMPTZ,
    es_activo         BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT pk_ciudad        PRIMARY KEY (id),
    CONSTRAINT uq_ciudad_nombre UNIQUE (departamento_id, nombre),
    CONSTRAINT fk_ciudad_departamento FOREIGN KEY (departamento_id)
        REFERENCES geo.departamento (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ciudad_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_ciudad_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_ciudad_departamento ON geo.ciudad (departamento_id);
CREATE INDEX ix_ciudad_created_by   ON geo.ciudad (created_by);
CREATE INDEX ix_ciudad_modified_by  ON geo.ciudad (modified_by);

COMMENT ON COLUMN geo.ciudad.es_operativa IS
    'Si Last Bite ya opera ahí. Permite tener el catálogo del país sin ofrecer servicio donde no hay comercios.';


CREATE TABLE geo.zona (
    id                 INT GENERATED ALWAYS AS IDENTITY,
    ciudad_id          SMALLINT    NOT NULL,
    nombre             VARCHAR(80) NOT NULL,
    latitud_centro     core.dm_latitud,
    longitud_centro    core.dm_longitud,
    hora_limite_retiro TIME,
    created_by         BIGINT      NOT NULL,
    creation_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by        BIGINT,
    modification_date  TIMESTAMPTZ,
    es_activo          BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT pk_zona        PRIMARY KEY (id),
    CONSTRAINT uq_zona_nombre UNIQUE (ciudad_id, nombre),
    CONSTRAINT fk_zona_ciudad FOREIGN KEY (ciudad_id)
        REFERENCES geo.ciudad (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_zona_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_zona_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_zona_ciudad      ON geo.zona (ciudad_id);
CREATE INDEX ix_zona_created_by  ON geo.zona (created_by);
CREATE INDEX ix_zona_modified_by ON geo.zona (modified_by);

COMMENT ON COLUMN geo.zona.hora_limite_retiro IS
    'Adaptación local: hora máxima a la que puede cerrar una ventana de retiro en esa zona. Nulo = sin restricción.';
COMMENT ON COLUMN geo.zona.es_activo IS
    'Apaga la zona para el lanzamiento por etapas: no aparece en búsquedas ni acepta sucursales nuevas.';



-- ==========================================================================
-- ARCHIVO: V005__comercio.sql
-- Socios y puntos de retiro
-- ==========================================================================

/* ============================================================================
   LAST BITE · V005 — Esquema comercio
   ----------------------------------------------------------------------------
   El comercio es con quien se firma; la sucursal es a donde se camina.
   Son dos cosas distintas y por eso son dos tablas.
   ========================================================================== */

CREATE TABLE comercio.categoria_comercio (
    id                SMALLINT GENERATED ALWAYS AS IDENTITY,
    nombre            VARCHAR(50) NOT NULL,
    descripcion       VARCHAR(150),
    created_by        BIGINT      NOT NULL,
    creation_date     TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by       BIGINT,
    modification_date TIMESTAMPTZ,
    es_activo         BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT pk_categoria_comercio        PRIMARY KEY (id),
    CONSTRAINT uq_categoria_comercio_nombre UNIQUE (nombre),
    CONSTRAINT fk_categoria_comercio_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_categoria_comercio_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_categoria_comercio_created_by  ON comercio.categoria_comercio (created_by);
CREATE INDEX ix_categoria_comercio_modified_by ON comercio.categoria_comercio (modified_by);


CREATE TABLE comercio.comercio (
    id                     INT GENERATED ALWAYS AS IDENTITY,
    rtn                    core.dm_rtn     NOT NULL,
    razon_social           VARCHAR(120)    NOT NULL,
    nombre_comercial       VARCHAR(120)    NOT NULL,
    categoria_comercio_id  SMALLINT        NOT NULL,
    correo_contacto        core.dm_correo  NOT NULL,
    telefono               core.dm_tel_hn  NOT NULL,
    cuenta_bancaria        VARCHAR(30),
    fecha_afiliacion       DATE            NOT NULL DEFAULT current_date,
    estado                 core.en_estado_comercio NOT NULL DEFAULT 'PENDIENTE',
    created_by             BIGINT          NOT NULL,
    creation_date          TIMESTAMPTZ     NOT NULL DEFAULT now(),
    modified_by            BIGINT,
    modification_date      TIMESTAMPTZ,
    es_activo              BOOLEAN         NOT NULL DEFAULT true,
    CONSTRAINT pk_comercio     PRIMARY KEY (id),
    CONSTRAINT uq_comercio_rtn UNIQUE (rtn),
    CONSTRAINT fk_comercio_categoria FOREIGN KEY (categoria_comercio_id)
        REFERENCES comercio.categoria_comercio (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_comercio_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_comercio_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_comercio_categoria   ON comercio.comercio (categoria_comercio_id);
CREATE INDEX ix_comercio_created_by  ON comercio.comercio (created_by);
CREATE INDEX ix_comercio_modified_by ON comercio.comercio (modified_by);
-- Búsqueda por nombre parcial: un LIKE '%pan%' no usa un B-tree, con trigramas sí.
CREATE INDEX ix_comercio_nombre_trgm
    ON comercio.comercio USING gin (nombre_comercial gin_trgm_ops);

COMMENT ON COLUMN comercio.comercio.estado IS
    'Interruptor general: suspender el comercio apaga todas sus sucursales de una vez.';


CREATE TABLE comercio.sucursal (
    id                  INT GENERATED ALWAYS AS IDENTITY,
    comercio_id         INT              NOT NULL,
    zona_id             INT              NOT NULL,
    nombre              VARCHAR(80)      NOT NULL,
    direccion           VARCHAR(200)     NOT NULL,
    latitud             core.dm_latitud  NOT NULL,
    longitud            core.dm_longitud NOT NULL,
    telefono            core.dm_tel_hn,
    licencia_sanitaria  VARCHAR(30),
    licencia_vence      DATE,
    created_by          BIGINT           NOT NULL,
    creation_date       TIMESTAMPTZ      NOT NULL DEFAULT now(),
    modified_by         BIGINT,
    modification_date   TIMESTAMPTZ,
    es_activo           BOOLEAN          NOT NULL DEFAULT true,
    CONSTRAINT pk_sucursal        PRIMARY KEY (id),
    CONSTRAINT uq_sucursal_nombre UNIQUE (comercio_id, nombre),
    CONSTRAINT fk_sucursal_comercio FOREIGN KEY (comercio_id)
        REFERENCES comercio.comercio (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sucursal_zona FOREIGN KEY (zona_id)
        REFERENCES geo.zona (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sucursal_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_sucursal_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_sucursal_comercio    ON comercio.sucursal (comercio_id);
CREATE INDEX ix_sucursal_zona        ON comercio.sucursal (zona_id);
CREATE INDEX ix_sucursal_created_by  ON comercio.sucursal (created_by);
CREATE INDEX ix_sucursal_modified_by ON comercio.sucursal (modified_by);
-- Búsqueda por cercanía sin PostGIS: índice sobre el punto.
CREATE INDEX ix_sucursal_ubicacion
    ON comercio.sucursal USING gist (point(longitud::float8, latitud::float8));

COMMENT ON COLUMN comercio.sucursal.licencia_vence IS
    'Si caduca, el sistema bloquea publicaciones nuevas de esta sucursal (RN-02).';


CREATE TABLE comercio.horario_sucursal (
    id             INT GENERATED ALWAYS AS IDENTITY,
    sucursal_id    INT         NOT NULL,
    dia_semana     SMALLINT    NOT NULL,      -- 1 lunes … 7 domingo
    hora_apertura  TIME        NOT NULL,
    hora_cierre    TIME        NOT NULL,
    created_by     BIGINT      NOT NULL,
    creation_date  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_horario_sucursal  PRIMARY KEY (id),
    CONSTRAINT uq_horario_sucursal  UNIQUE (sucursal_id, dia_semana),
    CONSTRAINT ck_horario_dia       CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT ck_horario_rango     CHECK (hora_cierre > hora_apertura),
    CONSTRAINT fk_horario_sucursal FOREIGN KEY (sucursal_id)
        REFERENCES comercio.sucursal (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_horario_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_horario_sucursal   ON comercio.horario_sucursal (sucursal_id);
CREATE INDEX ix_horario_created_by ON comercio.horario_sucursal (created_by);


/* --------------------------- usuario_sucursal -----------------------------
   Quién puede operar el panel de qué local. Es la base de la seguridad a nivel
   de fila: lo que impide que la cajera de un local valide códigos de otro.   */
CREATE TABLE comercio.usuario_sucursal (
    usuario_id    BIGINT        NOT NULL,
    sucursal_id   INT           NOT NULL,
    cargo         core.en_cargo NOT NULL,
    created_by    BIGINT        NOT NULL,
    creation_date TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT pk_usuario_sucursal PRIMARY KEY (usuario_id, sucursal_id),
    CONSTRAINT fk_usuario_sucursal_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_sucursal_sucursal FOREIGN KEY (sucursal_id)
        REFERENCES comercio.sucursal (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_usuario_sucursal_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_usuario_sucursal_sucursal   ON comercio.usuario_sucursal (sucursal_id);
CREATE INDEX ix_usuario_sucursal_created_by ON comercio.usuario_sucursal (created_by);



-- ==========================================================================
-- ARCHIVO: V006__oferta.sql
-- Catálogo y publicaciones
-- ==========================================================================

/* ============================================================================
   LAST BITE · V006 — Esquema oferta
   ----------------------------------------------------------------------------
   Aquí vive la decisión estructural del modelo: separar el "qué vendo"
   (plantilla_bolsa, definida una vez) del "cuántas tengo hoy" (publicacion).
   ========================================================================== */

CREATE TABLE oferta.categoria_alimento (
    id                 SMALLINT GENERATED ALWAYS AS IDENTITY,
    nombre             VARCHAR(50) NOT NULL,
    es_perecible       BOOLEAN     NOT NULL DEFAULT false,
    horas_max_ventana  SMALLINT    NOT NULL DEFAULT 3,
    created_by         BIGINT      NOT NULL,
    creation_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by        BIGINT,
    modification_date  TIMESTAMPTZ,
    es_activo          BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT pk_categoria_alimento        PRIMARY KEY (id),
    CONSTRAINT uq_categoria_alimento_nombre UNIQUE (nombre),
    CONSTRAINT ck_categoria_alimento_horas  CHECK (horas_max_ventana BETWEEN 1 AND 12),
    CONSTRAINT fk_categoria_alimento_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_categoria_alimento_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_categoria_alimento_created_by  ON oferta.categoria_alimento (created_by);
CREATE INDEX ix_categoria_alimento_modified_by ON oferta.categoria_alimento (modified_by);

COMMENT ON COLUMN oferta.categoria_alimento.horas_max_ventana IS
    'Adaptación local: cuántas horas puede durar la ventana de retiro de este alimento. Con el calor de SPS, la comida preparada no aguanta tres horas en el mostrador.';


CREATE TABLE oferta.factor_impacto (
    id                    SMALLINT GENERATED ALWAYS AS IDENTITY,
    categoria_alimento_id SMALLINT      NOT NULL,
    kg_co2_por_kg         NUMERIC(6,3)  NOT NULL,
    fuente                VARCHAR(150),
    vigente_desde         DATE          NOT NULL DEFAULT current_date,
    vigente_hasta         DATE,
    created_by            BIGINT        NOT NULL,
    creation_date         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    modified_by           BIGINT,
    modification_date     TIMESTAMPTZ,
    es_activo             BOOLEAN       NOT NULL DEFAULT true,
    CONSTRAINT pk_factor_impacto       PRIMARY KEY (id),
    CONSTRAINT ck_factor_impacto_valor CHECK (kg_co2_por_kg > 0),
    CONSTRAINT ck_factor_impacto_vig   CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
    CONSTRAINT fk_factor_impacto_categoria FOREIGN KEY (categoria_alimento_id)
        REFERENCES oferta.categoria_alimento (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_factor_impacto_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_factor_impacto_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_factor_impacto_categoria  ON oferta.factor_impacto (categoria_alimento_id);
CREATE INDEX ix_factor_impacto_created_by ON oferta.factor_impacto (created_by);
CREATE INDEX ix_factor_impacto_modified_by ON oferta.factor_impacto (modified_by);
-- Un solo factor vigente por categoría.
CREATE UNIQUE INDEX uq_factor_impacto_vigente
    ON oferta.factor_impacto (categoria_alimento_id) WHERE vigente_hasta IS NULL;


CREATE TABLE oferta.plantilla_bolsa (
    id                     INT GENERATED ALWAYS AS IDENTITY,
    sucursal_id            INT            NOT NULL,
    categoria_alimento_id  SMALLINT       NOT NULL,
    nombre                 VARCHAR(80)    NOT NULL,
    descripcion            TEXT,
    precio_base            core.dm_dinero NOT NULL,
    valor_estimado         core.dm_dinero NOT NULL,
    peso_estimado_kg       NUMERIC(6,2)   NOT NULL,
    requiere_refrigeracion BOOLEAN        NOT NULL DEFAULT false,
    alergenos              VARCHAR(150),
    created_by             BIGINT         NOT NULL,
    creation_date          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    modified_by            BIGINT,
    modification_date      TIMESTAMPTZ,
    es_activo              BOOLEAN        NOT NULL DEFAULT true,
    CONSTRAINT pk_plantilla_bolsa      PRIMARY KEY (id),
    CONSTRAINT uq_plantilla_bolsa      UNIQUE (sucursal_id, nombre),
    -- RN-06: el precio debe ser menor que el valor real del contenido.
    CONSTRAINT ck_plantilla_precio     CHECK (precio_base < valor_estimado),
    CONSTRAINT ck_plantilla_peso       CHECK (peso_estimado_kg > 0),
    CONSTRAINT fk_plantilla_sucursal FOREIGN KEY (sucursal_id)
        REFERENCES comercio.sucursal (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_plantilla_categoria FOREIGN KEY (categoria_alimento_id)
        REFERENCES oferta.categoria_alimento (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_plantilla_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_plantilla_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_plantilla_sucursal   ON oferta.plantilla_bolsa (sucursal_id);
CREATE INDEX ix_plantilla_categoria  ON oferta.plantilla_bolsa (categoria_alimento_id);
CREATE INDEX ix_plantilla_created_by ON oferta.plantilla_bolsa (created_by);
CREATE INDEX ix_plantilla_modified_by ON oferta.plantilla_bolsa (modified_by);

COMMENT ON COLUMN oferta.plantilla_bolsa.alergenos IS
    'Obligación de información al consumidor. Es la línea entre una sorpresa agradable y una emergencia médica.';


/* --------------------------------- publicacion ----------------------------
   La oferta concreta de un día. Nivel de auditoría B: se modifica por cambio
   de estado y jamás se desactiva.                                            */
CREATE TABLE oferta.publicacion (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY,
    plantilla_bolsa_id  INT            NOT NULL,
    fecha               DATE           NOT NULL DEFAULT current_date,
    hora_inicio_retiro  TIME           NOT NULL,
    hora_fin_retiro     TIME           NOT NULL,
    cantidad_total      SMALLINT       NOT NULL,
    cantidad_disponible SMALLINT       NOT NULL,
    precio_venta        core.dm_dinero NOT NULL,
    estado              core.en_estado_publicacion NOT NULL DEFAULT 'PROGRAMADA',
    created_by          BIGINT         NOT NULL,
    creation_date       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    modified_by         BIGINT,
    modification_date   TIMESTAMPTZ,
    CONSTRAINT pk_publicacion PRIMARY KEY (id),
    -- RN-04: la ventana tiene que ser coherente.
    CONSTRAINT ck_publicacion_ventana  CHECK (hora_fin_retiro > hora_inicio_retiro),
    -- RN-05: el cupo nunca es negativo ni mayor que lo publicado.
    CONSTRAINT ck_publicacion_total    CHECK (cantidad_total > 0),
    CONSTRAINT ck_publicacion_cantidad CHECK (cantidad_disponible BETWEEN 0 AND cantidad_total),
    CONSTRAINT fk_publicacion_plantilla FOREIGN KEY (plantilla_bolsa_id)
        REFERENCES oferta.plantilla_bolsa (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_publicacion_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_publicacion_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_publicacion_plantilla   ON oferta.publicacion (plantilla_bolsa_id);
CREATE INDEX ix_publicacion_created_by  ON oferta.publicacion (created_by);
CREATE INDEX ix_publicacion_modified_by ON oferta.publicacion (modified_by);

/* El índice del sistema. Es LA consulta de la app: solo indexa las filas
   PUBLICADA con cupo, que son cientos, no el histórico de millones.
   El INCLUDE evita ir a la tabla (index-only scan).                         */
CREATE INDEX ixp_publicacion_vigente
    ON oferta.publicacion (fecha, hora_fin_retiro)
    INCLUDE (plantilla_bolsa_id, precio_venta, cantidad_disponible)
    WHERE estado = 'PUBLICADA' AND cantidad_disponible > 0;

/* Una sucursal no puede publicar el mismo tipo de bolsa dos veces el mismo día
   con horarios encimados. Esto no lo resuelve un UNIQUE ni un CHECK, porque
   compara una fila contra otras: se necesita EXCLUDE con btree_gist.        */
ALTER TABLE oferta.publicacion
    ADD CONSTRAINT ex_publicacion_ventana
    EXCLUDE USING gist (
        plantilla_bolsa_id WITH =,
        tsrange(fecha + hora_inicio_retiro, fecha + hora_fin_retiro) WITH &&
    ) WHERE (estado <> 'CANCELADA');

COMMENT ON COLUMN oferta.publicacion.cantidad_disponible IS
    'Desnormalización deliberada: se podría derivar contando reservas, pero el listado la consulta decenas de veces por minuto. Se descuenta con la fila bloqueada.';
COMMENT ON COLUMN oferta.publicacion.precio_venta IS
    'Precio congelado del día. Puede diferir del precio_base: un martes flojo se remata más barato.';



-- ==========================================================================
-- ARCHIVO: V007__venta.sql
-- Reservas y pagos
-- ==========================================================================

/* ============================================================================
   LAST BITE · V007 — Esquema venta
   ----------------------------------------------------------------------------
   El corazón transaccional. Aquí vive la adaptación de pago más importante
   para Honduras: los dos carriles, prepago y efectivo.
   ========================================================================== */

CREATE TABLE venta.metodo_pago (
    id                             SMALLINT GENERATED ALWAYS AS IDENTITY,
    codigo                         VARCHAR(20) NOT NULL,
    nombre                         VARCHAR(50) NOT NULL,
    requiere_confirmacion_en_sitio BOOLEAN     NOT NULL DEFAULT false,
    orden_presentacion             SMALLINT    NOT NULL DEFAULT 100,
    created_by                     BIGINT      NOT NULL,
    creation_date                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                    BIGINT,
    modification_date              TIMESTAMPTZ,
    es_activo                      BOOLEAN     NOT NULL DEFAULT true,
    CONSTRAINT pk_metodo_pago        PRIMARY KEY (id),
    CONSTRAINT uq_metodo_pago_codigo UNIQUE (codigo),
    CONSTRAINT fk_metodo_pago_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_metodo_pago_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_metodo_pago_created_by  ON venta.metodo_pago (created_by);
CREATE INDEX ix_metodo_pago_modified_by ON venta.metodo_pago (modified_by);

COMMENT ON COLUMN venta.metodo_pago.requiere_confirmacion_en_sitio IS
    'La bandera que separa los dos carriles. Verdadero para efectivo: la reserva no queda prepagada y el comercio asume el riesgo del no-show.';


CREATE TABLE venta.metodo_pago_usuario (
    id                INT GENERATED ALWAYS AS IDENTITY,
    usuario_id        BIGINT       NOT NULL,
    metodo_pago_id    SMALLINT     NOT NULL,
    alias             VARCHAR(40),
    token_externo     VARCHAR(120) NOT NULL,
    marca             VARCHAR(20),
    ultimos4          CHAR(4),
    es_predeterminado BOOLEAN      NOT NULL DEFAULT false,
    created_by        BIGINT       NOT NULL,
    creation_date     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_metodo_pago_usuario PRIMARY KEY (id),
    CONSTRAINT uq_metodo_pago_token   UNIQUE (token_externo),
    CONSTRAINT ck_metodo_pago_ultimos CHECK (ultimos4 IS NULL OR ultimos4 ~ '^[0-9]{4}$'),
    CONSTRAINT fk_mpu_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_mpu_metodo FOREIGN KEY (metodo_pago_id)
        REFERENCES venta.metodo_pago (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_mpu_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_mpu_usuario    ON venta.metodo_pago_usuario (usuario_id);
CREATE INDEX ix_mpu_metodo     ON venta.metodo_pago_usuario (metodo_pago_id);
CREATE INDEX ix_mpu_created_by ON venta.metodo_pago_usuario (created_by);
-- Un solo instrumento predeterminado por usuario.
CREATE UNIQUE INDEX uq_mpu_predeterminado
    ON venta.metodo_pago_usuario (usuario_id) WHERE es_predeterminado;

COMMENT ON COLUMN venta.metodo_pago_usuario.token_externo IS
    'Referencia del procesador de pagos. RN-15: nunca se guarda el número de tarjeta.';


/* ---------------------------------- reserva -------------------------------
   El registro del que cuelga todo el dinero del sistema. Nivel B.
   No hay columna fecha_reserva: esa es creation_date de la auditoría.       */
CREATE TABLE venta.reserva (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY,
    codigo              VARCHAR(20)    NOT NULL,
    publicacion_id      BIGINT         NOT NULL,
    cliente_usuario_id  BIGINT         NOT NULL,
    cantidad            SMALLINT       NOT NULL DEFAULT 1,
    precio_unitario     core.dm_dinero NOT NULL,
    subtotal            core.dm_dinero NOT NULL,
    isv                 core.dm_dinero NOT NULL,
    total               NUMERIC(12,2)  GENERATED ALWAYS AS (subtotal + isv) STORED,
    comision_plataforma core.dm_dinero NOT NULL,
    monto_comercio      core.dm_dinero NOT NULL,
    estado              core.en_estado_reserva NOT NULL DEFAULT 'PENDIENTE_PAGO',
    retiro_date         TIMESTAMPTZ,
    entrega_usuario_id  BIGINT,
    cancelacion_motivo  VARCHAR(120),
    created_by          BIGINT         NOT NULL,
    creation_date       TIMESTAMPTZ    NOT NULL DEFAULT now(),
    modified_by         BIGINT,
    modification_date   TIMESTAMPTZ,
    CONSTRAINT pk_reserva        PRIMARY KEY (id),
    CONSTRAINT uq_reserva_codigo UNIQUE (codigo),                       -- RN-08
    CONSTRAINT ck_reserva_cantidad CHECK (cantidad BETWEEN 1 AND 3),    -- RN-09
    -- Un CHECK puede relacionar dos columnas de la misma fila: si está
    -- retirada, tiene que haber hora de retiro y quién la entregó.
    CONSTRAINT ck_reserva_retiro CHECK (
        (estado = 'RETIRADA' AND retiro_date IS NOT NULL AND entrega_usuario_id IS NOT NULL)
        OR (estado <> 'RETIRADA')
    ),
    CONSTRAINT fk_reserva_publicacion FOREIGN KEY (publicacion_id)
        REFERENCES oferta.publicacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_reserva_cliente FOREIGN KEY (cliente_usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_reserva_entrega FOREIGN KEY (entrega_usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_reserva_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_reserva_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_reserva_publicacion  ON venta.reserva (publicacion_id);
CREATE INDEX ix_reserva_entrega      ON venta.reserva (entrega_usuario_id);
CREATE INDEX ix_reserva_created_by   ON venta.reserva (created_by);
CREATE INDEX ix_reserva_modified_by  ON venta.reserva (modified_by);
-- Historial del cliente, ya ordenado.
CREATE INDEX ix_reserva_cliente_fecha
    ON venta.reserva (cliente_usuario_id, creation_date DESC);
-- Lo que busca el proceso del reloj: reservas confirmadas que hay que vencer.
CREATE INDEX ixp_reserva_por_vencer
    ON venta.reserva (publicacion_id) WHERE estado = 'CONFIRMADA';

COMMENT ON COLUMN venta.reserva.codigo IS
    'Lo que se dicta en voz alta en el mostrador. Es la llave de negocio; el id nunca sale a la pantalla.';
COMMENT ON COLUMN venta.reserva.comision_plataforma IS
    'RN-13: la tarifa vigente en la fecha de la reserva, copiada. Cambiar la tarifa mañana no altera el dinero que ya se debía ayer.';


/* ------------------------------------ pago --------------------------------
   Cada INTENTO de cobro, no solo el exitoso.                                */
CREATE TABLE venta.pago (
    id                     BIGINT GENERATED ALWAYS AS IDENTITY,
    reserva_id             BIGINT         NOT NULL,
    metodo_pago_id         SMALLINT       NOT NULL,
    metodo_pago_usuario_id INT,
    monto                  core.dm_dinero NOT NULL,
    referencia_externa     VARCHAR(80),
    estado                 core.en_estado_pago NOT NULL DEFAULT 'PENDIENTE',
    mensaje_error          VARCHAR(200),
    created_by             BIGINT         NOT NULL,
    creation_date          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    modified_by            BIGINT,
    modification_date      TIMESTAMPTZ,
    CONSTRAINT pk_pago PRIMARY KEY (id),
    CONSTRAINT fk_pago_reserva FOREIGN KEY (reserva_id)
        REFERENCES venta.reserva (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pago_metodo FOREIGN KEY (metodo_pago_id)
        REFERENCES venta.metodo_pago (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pago_mpu FOREIGN KEY (metodo_pago_usuario_id)
        REFERENCES venta.metodo_pago_usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pago_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pago_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_pago_reserva     ON venta.pago (reserva_id);
CREATE INDEX ix_pago_metodo      ON venta.pago (metodo_pago_id);
CREATE INDEX ix_pago_mpu         ON venta.pago (metodo_pago_usuario_id);
CREATE INDEX ix_pago_created_by  ON venta.pago (created_by);
CREATE INDEX ix_pago_modified_by ON venta.pago (modified_by);

/* Una reserva no puede tener dos pagos exitosos. Los intentos fallidos sí
   pueden repetirse: por eso el índice es parcial y no una restricción única. */
CREATE UNIQUE INDEX uq_pago_capturado
    ON venta.pago (reserva_id) WHERE estado = 'CAPTURADO';



-- ==========================================================================
-- ARCHIVO: V008__finanza.sql
-- Tarifas y liquidaciones
-- ==========================================================================

/* ============================================================================
   LAST BITE · V008 — Esquema finanza
   ----------------------------------------------------------------------------
   Cuánto gana la plataforma y cuánto se le paga al comercio.
   ========================================================================== */

CREATE TABLE finanza.tarifa (
    id                    SMALLINT GENERATED ALWAYS AS IDENTITY,
    categoria_comercio_id SMALLINT,                 -- nulo = tarifa general
    tipo                  core.en_tipo_tarifa NOT NULL DEFAULT 'PORCENTUAL',
    valor                 NUMERIC(6,2) NOT NULL,
    vigente_desde         DATE         NOT NULL DEFAULT current_date,
    vigente_hasta         DATE,
    created_by            BIGINT       NOT NULL,
    creation_date         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    modified_by           BIGINT,
    modification_date     TIMESTAMPTZ,
    es_activo             BOOLEAN      NOT NULL DEFAULT true,
    CONSTRAINT pk_tarifa       PRIMARY KEY (id),
    CONSTRAINT ck_tarifa_valor CHECK (valor > 0),
    CONSTRAINT ck_tarifa_pct   CHECK (tipo <> 'PORCENTUAL' OR valor <= 100),
    CONSTRAINT ck_tarifa_vig   CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
    CONSTRAINT fk_tarifa_categoria FOREIGN KEY (categoria_comercio_id)
        REFERENCES comercio.categoria_comercio (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_tarifa_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_tarifa_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_tarifa_categoria   ON finanza.tarifa (categoria_comercio_id);
CREATE INDEX ix_tarifa_created_by  ON finanza.tarifa (created_by);
CREATE INDEX ix_tarifa_modified_by ON finanza.tarifa (modified_by);
-- Una sola tarifa general vigente, y una sola vigente por categoría.
CREATE UNIQUE INDEX uq_tarifa_general_vigente
    ON finanza.tarifa ((1)) WHERE categoria_comercio_id IS NULL AND vigente_hasta IS NULL;
CREATE UNIQUE INDEX uq_tarifa_categoria_vigente
    ON finanza.tarifa (categoria_comercio_id) WHERE vigente_hasta IS NULL;

COMMENT ON TABLE finanza.tarifa IS
    'RN-13. Cambiar de tarifa es cerrar una fila y abrir otra, nunca editar la existente.';


CREATE TABLE finanza.liquidacion (
    id                      INT GENERATED ALWAYS AS IDENTITY,
    comercio_id             INT            NOT NULL,
    periodo_inicio          DATE           NOT NULL,
    periodo_fin             DATE           NOT NULL,
    cantidad_reservas       INT            NOT NULL DEFAULT 0,
    total_ventas            core.dm_dinero NOT NULL DEFAULT 0,
    total_comision          core.dm_dinero NOT NULL DEFAULT 0,
    monto_neto              core.dm_dinero NOT NULL DEFAULT 0,
    estado                  core.en_estado_liquidacion NOT NULL DEFAULT 'CALCULADA',
    pago_date               TIMESTAMPTZ,
    referencia_transferencia VARCHAR(60),
    created_by              BIGINT         NOT NULL,
    creation_date           TIMESTAMPTZ    NOT NULL DEFAULT now(),
    modified_by             BIGINT,
    modification_date       TIMESTAMPTZ,
    CONSTRAINT pk_liquidacion      PRIMARY KEY (id),
    -- Hace imposible liquidar dos veces el mismo período: el error más caro
    -- que puede cometer esta plataforma.
    CONSTRAINT uq_liquidacion_periodo UNIQUE (comercio_id, periodo_inicio, periodo_fin),
    CONSTRAINT ck_liquidacion_periodo CHECK (periodo_fin >= periodo_inicio),
    CONSTRAINT fk_liquidacion_comercio FOREIGN KEY (comercio_id)
        REFERENCES comercio.comercio (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_liquidacion_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_liquidacion_modified_by FOREIGN KEY (modified_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_liquidacion_comercio    ON finanza.liquidacion (comercio_id);
CREATE INDEX ix_liquidacion_created_by  ON finanza.liquidacion (created_by);
CREATE INDEX ix_liquidacion_modified_by ON finanza.liquidacion (modified_by);


CREATE TABLE finanza.detalle_liquidacion (
    liquidacion_id INT            NOT NULL,
    reserva_id     BIGINT         NOT NULL,
    monto_comercio core.dm_dinero NOT NULL,
    comision       core.dm_dinero NOT NULL,
    created_by     BIGINT         NOT NULL,
    creation_date  TIMESTAMPTZ    NOT NULL DEFAULT now(),
    CONSTRAINT pk_detalle_liquidacion PRIMARY KEY (liquidacion_id, reserva_id),
    -- RN-14: única en TODA la tabla, no solo dentro de su liquidación.
    -- Eso es lo que hace imposible pagar dos veces la misma venta.
    CONSTRAINT uq_detalle_liquidacion_reserva UNIQUE (reserva_id),
    CONSTRAINT fk_detalle_liquidacion FOREIGN KEY (liquidacion_id)
        REFERENCES finanza.liquidacion (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_reserva FOREIGN KEY (reserva_id)
        REFERENCES venta.reserva (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_detalle_liquidacion_created_by ON finanza.detalle_liquidacion (created_by);



-- ==========================================================================
-- ARCHIVO: V009__social.sql
-- Calificaciones, favoritos y notificaciones
-- ==========================================================================

/* ============================================================================
   LAST BITE · V009 — Esquema social
   ----------------------------------------------------------------------------
   En un modelo donde el cliente compra algo cuyo contenido no conoce,
   la confianza no es un extra: es el producto.
   ========================================================================== */

/* La llave primaria es la reserva. Eso hace imposible calificar dos veces la
   misma compra, y también calificar algo que no se compró (RN-11).          */
CREATE TABLE social.calificacion (
    reserva_id    BIGINT       NOT NULL,
    puntuacion    SMALLINT     NOT NULL,
    comentario    VARCHAR(300),
    created_by    BIGINT       NOT NULL,
    creation_date TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_calificacion         PRIMARY KEY (reserva_id),
    CONSTRAINT ck_calificacion_puntaje CHECK (puntuacion BETWEEN 1 AND 5),
    CONSTRAINT fk_calificacion_reserva FOREIGN KEY (reserva_id)
        REFERENCES venta.reserva (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_calificacion_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_calificacion_created_by ON social.calificacion (created_by);


CREATE TABLE social.favorito (
    usuario_id    BIGINT      NOT NULL,
    sucursal_id   INT         NOT NULL,
    created_by    BIGINT      NOT NULL,
    creation_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_favorito PRIMARY KEY (usuario_id, sucursal_id),
    CONSTRAINT fk_favorito_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_favorito_sucursal FOREIGN KEY (sucursal_id)
        REFERENCES comercio.sucursal (id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_favorito_created_by FOREIGN KEY (created_by)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_favorito_sucursal   ON social.favorito (sucursal_id);
CREATE INDEX ix_favorito_created_by ON social.favorito (created_by);

COMMENT ON TABLE social.favorito IS
    'A quién avisar cuando esa sucursal publique. Es lo que convierte una publicación de las 5:40 en una venta a las 6:03.';


/* Nivel D: la fila es el registro, no lleva columnas de auditoría.          */
CREATE TABLE social.notificacion (
    id            BIGINT GENERATED ALWAYS AS IDENTITY,
    usuario_id    BIGINT       NOT NULL,
    tipo          core.en_tipo_notificacion NOT NULL,
    titulo        VARCHAR(80)  NOT NULL,
    mensaje       VARCHAR(250) NOT NULL,
    entidad_tipo  VARCHAR(20),          -- a qué tabla apunta
    entidad_id    BIGINT,               -- sin FK: apunta a tablas distintas
    es_leida      BOOLEAN      NOT NULL DEFAULT false,
    envio_date    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_notificacion PRIMARY KEY (id),
    CONSTRAINT fk_notificacion_usuario FOREIGN KEY (usuario_id)
        REFERENCES seguridad.usuario (id) ON UPDATE RESTRICT ON DELETE RESTRICT
);
CREATE INDEX ix_notificacion_usuario ON social.notificacion (usuario_id);
CREATE INDEX ixp_notificacion_sin_leer
    ON social.notificacion (usuario_id, envio_date DESC) WHERE NOT es_leida;
CREATE INDEX brin_notificacion_fecha ON social.notificacion USING brin (envio_date);



-- ==========================================================================
-- ARCHIVO: V010__auditoria.sql
-- Bitácora
-- ==========================================================================

/* ============================================================================
   LAST BITE · V010 — Esquema auditoria
   ----------------------------------------------------------------------------
   Las columnas de auditoría dicen quién y cuándo. Esta tabla dice QUÉ:
   el valor anterior y el nuevo, fila completa.
   ========================================================================== */

CREATE TABLE auditoria.bitacora (
    id                BIGINT GENERATED ALWAYS AS IDENTITY,
    esquema           VARCHAR(20)     NOT NULL,
    tabla             VARCHAR(40)     NOT NULL,
    registro_id       BIGINT          NOT NULL,   -- sin FK: apunta a 29 tablas
    accion            core.en_accion  NOT NULL,
    datos_anteriores  JSONB,
    datos_nuevos      JSONB,
    usuario_id        BIGINT          NOT NULL,
    usuario_bd        VARCHAR(60)     NOT NULL,
    direccion_ip      INET,
    fecha             TIMESTAMPTZ     NOT NULL DEFAULT now(),
    CONSTRAINT pk_bitacora PRIMARY KEY (id)
);

CREATE INDEX ix_bitacora_registro ON auditoria.bitacora (esquema, tabla, registro_id);
CREATE INDEX ix_bitacora_usuario  ON auditoria.bitacora (usuario_id);
/* BRIN en vez de B-tree: la tabla solo se agrega y se consulta por rango de
   fechas. Un BRIN ocupa kilobytes donde un B-tree ocuparía megabytes.       */
CREATE INDEX brin_bitacora_fecha ON auditoria.bitacora USING brin (fecha);

COMMENT ON TABLE auditoria.bitacora IS
    'Retención: doce meses en línea, el resto exportado. Cuando pase de unos millones de filas se particiona por rango de fecha.';
COMMENT ON COLUMN auditoria.bitacora.registro_id IS
    'Sin FK a propósito: apunta a muchas tablas, y una FK real impediría conservar el rastro de algo que se borró.';



-- ==========================================================================
-- ARCHIVO: V011__triggers.sql
-- Triggers de auditoría y reglas de estado
-- ==========================================================================

/* ============================================================================
   LAST BITE · V011 — Triggers de auditoría, bitácora y transiciones de estado
   ========================================================================== */

/* ---------------------------------------------------------------------------
   1. Auditoría de fila.
   Una sola función sirve para todas: lo único que se repite es el
   CREATE TRIGGER, y eso se genera recorriendo el catálogo.
   --------------------------------------------------------------------------- */
DO $bloque$
DECLARE
    v_tabla TEXT;
    -- Nivel A y B: las cuatro columnas de auditoría.
    v_completo TEXT[] := ARRAY[
        'seguridad.usuario', 'seguridad.rol', 'seguridad.sesion',
        'geo.departamento', 'geo.ciudad', 'geo.zona',
        'comercio.categoria_comercio', 'comercio.comercio', 'comercio.sucursal',
        'oferta.categoria_alimento', 'oferta.factor_impacto',
        'oferta.plantilla_bolsa', 'oferta.publicacion',
        'venta.metodo_pago', 'venta.reserva', 'venta.pago',
        'finanza.tarifa', 'finanza.liquidacion'
    ];
    -- Nivel C: solo created_by y creation_date.
    v_alta TEXT[] := ARRAY[
        'seguridad.usuario_rol', 'seguridad.token_recuperacion',
        'comercio.horario_sucursal', 'comercio.usuario_sucursal',
        'venta.metodo_pago_usuario',
        'finanza.detalle_liquidacion',
        'social.calificacion', 'social.favorito'
    ];
BEGIN
    FOREACH v_tabla IN ARRAY v_completo LOOP
        EXECUTE format(
            'CREATE TRIGGER tr_%s_biu_auditoria BEFORE INSERT OR UPDATE ON %s
             FOR EACH ROW EXECUTE FUNCTION core.fn_auditoria_fila()',
            split_part(v_tabla, '.', 2), v_tabla);
    END LOOP;

    FOREACH v_tabla IN ARRAY v_alta LOOP
        EXECUTE format(
            'CREATE TRIGGER tr_%s_bi_auditoria BEFORE INSERT ON %s
             FOR EACH ROW EXECUTE FUNCTION core.fn_auditoria_alta()',
            split_part(v_tabla, '.', 2), v_tabla);
    END LOOP;
END $bloque$;


/* ---------------------------------------------------------------------------
   2. Bitácora con JSONB.
   Guardar la fila completa permite consultarla después con operadores de JSON
   sin haber decidido de antemano qué columnas auditar.
   Se aplica SOLO a las cinco tablas sensibles: ponerlo en todas duplicaría el
   volumen de escritura del sistema.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION auditoria.fn_bitacora()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_ant JSONB;
    v_nue JSONB;
    -- Columnas que NUNCA entran a la bitácora. Sin esto, la auditoría se
    -- convierte en el archivo de credenciales del sistema.
    v_ocultas TEXT[] := ARRAY['contrasena_hash','token_hash','token_externo'];
BEGIN
    IF TG_OP <> 'INSERT' THEN
        v_ant := to_jsonb(OLD) - v_ocultas;
    END IF;
    IF TG_OP <> 'DELETE' THEN
        v_nue := to_jsonb(NEW) - v_ocultas;
    END IF;

    INSERT INTO auditoria.bitacora
        (esquema, tabla, registro_id, accion, datos_anteriores, datos_nuevos,
         usuario_id, usuario_bd, direccion_ip, fecha)
    VALUES (
        TG_TABLE_SCHEMA,
        TG_TABLE_NAME,
        coalesce((v_nue->>'id')::bigint, (v_ant->>'id')::bigint, 0),
        TG_OP::core.en_accion,
        v_ant,
        v_nue,
        core.fn_usuario_actual(),
        session_user,
        inet_client_addr(),
        now()
    );

    RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END $$;

CREATE TRIGGER tr_tarifa_aiud_bitacora
    AFTER INSERT OR UPDATE OR DELETE ON finanza.tarifa
    FOR EACH ROW EXECUTE FUNCTION auditoria.fn_bitacora();
CREATE TRIGGER tr_plantilla_bolsa_aiud_bitacora
    AFTER INSERT OR UPDATE OR DELETE ON oferta.plantilla_bolsa
    FOR EACH ROW EXECUTE FUNCTION auditoria.fn_bitacora();
CREATE TRIGGER tr_publicacion_aiud_bitacora
    AFTER INSERT OR UPDATE OR DELETE ON oferta.publicacion
    FOR EACH ROW EXECUTE FUNCTION auditoria.fn_bitacora();
CREATE TRIGGER tr_reserva_aiud_bitacora
    AFTER INSERT OR UPDATE OR DELETE ON venta.reserva
    FOR EACH ROW EXECUTE FUNCTION auditoria.fn_bitacora();
CREATE TRIGGER tr_liquidacion_aiud_bitacora
    AFTER INSERT OR UPDATE OR DELETE ON finanza.liquidacion
    FOR EACH ROW EXECUTE FUNCTION auditoria.fn_bitacora();


/* ---------------------------------------------------------------------------
   3. Transiciones de estado prohibidas.
   El CHECK valida un valor; esto valida un CAMBIO de valor. No se puede pasar
   de NO_RETIRADA a RETIRADA aunque el cliente aparezca tarde.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION venta.fn_valida_estado_reserva()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    IF NOT (
        (OLD.estado = 'PENDIENTE_PAGO' AND NEW.estado IN ('CONFIRMADA','CANCELADA','REEMBOLSADA'))
     OR (OLD.estado = 'CONFIRMADA'     AND NEW.estado IN ('RETIRADA','NO_RETIRADA','CANCELADA'))
     OR (OLD.estado = 'CANCELADA'      AND NEW.estado  = 'REEMBOLSADA')
    ) THEN
        RAISE EXCEPTION 'TRANSICION_INVALIDA: no se puede pasar de % a %', OLD.estado, NEW.estado
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER tr_reserva_bu_estado
    BEFORE UPDATE OF estado ON venta.reserva
    FOR EACH ROW EXECUTE FUNCTION venta.fn_valida_estado_reserva();


CREATE OR REPLACE FUNCTION oferta.fn_valida_estado_publicacion()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.estado = NEW.estado THEN
        RETURN NEW;
    END IF;

    IF NOT (
        (OLD.estado = 'PROGRAMADA' AND NEW.estado IN ('PUBLICADA','CANCELADA'))
     OR (OLD.estado = 'PUBLICADA'  AND NEW.estado IN ('AGOTADA','VENCIDA','CANCELADA'))
     OR (OLD.estado = 'AGOTADA'    AND NEW.estado IN ('VENCIDA','PUBLICADA'))
    ) THEN
        RAISE EXCEPTION 'TRANSICION_INVALIDA: no se puede pasar de % a %', OLD.estado, NEW.estado
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER tr_publicacion_bu_estado
    BEFORE UPDATE OF estado ON oferta.publicacion
    FOR EACH ROW EXECUTE FUNCTION oferta.fn_valida_estado_publicacion();


/* ---------------------------------------------------------------------------
   4. RN-02 y RN-03: una publicación solo nace si la sucursal puede publicar
   y si la ventana cabe en el horario y en el límite del alimento.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION oferta.fn_valida_publicacion()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    r RECORD;
    v_dia SMALLINT := EXTRACT(ISODOW FROM NEW.fecha)::SMALLINT;
    v_horas NUMERIC;
BEGIN
    SELECT s.id, s.es_activo, s.licencia_vence, c.estado AS estado_comercio,
           z.hora_limite_retiro, ca.horas_max_ventana
      INTO r
      FROM oferta.plantilla_bolsa pb
      JOIN comercio.sucursal s  ON s.id = pb.sucursal_id
      JOIN comercio.comercio c  ON c.id = s.comercio_id
      JOIN geo.zona z           ON z.id = s.zona_id
      JOIN oferta.categoria_alimento ca ON ca.id = pb.categoria_alimento_id
     WHERE pb.id = NEW.plantilla_bolsa_id;

    -- RN-02
    IF NOT r.es_activo OR r.estado_comercio <> 'ACTIVO' THEN
        RAISE EXCEPTION 'SUCURSAL_NO_HABILITADA: el comercio o la sucursal no están activos'
            USING ERRCODE = 'P0001';
    END IF;
    IF r.licencia_vence IS NOT NULL AND r.licencia_vence < NEW.fecha THEN
        RAISE EXCEPTION 'LICENCIA_VENCIDA: la licencia sanitaria venció el %', r.licencia_vence
            USING ERRCODE = 'P0001';
    END IF;

    -- RN-03: la ventana cabe en el horario de ese día.
    IF NOT EXISTS (
        SELECT 1 FROM comercio.horario_sucursal h
         WHERE h.sucursal_id = r.id
           AND h.dia_semana  = v_dia
           AND NEW.hora_inicio_retiro >= h.hora_apertura
           AND NEW.hora_fin_retiro    <= h.hora_cierre
    ) THEN
        RAISE EXCEPTION 'FUERA_DE_HORARIO: la ventana no cabe en el horario de la sucursal'
            USING ERRCODE = 'P0001';
    END IF;

    -- Límite por tipo de alimento (adaptación al clima de SPS).
    v_horas := EXTRACT(EPOCH FROM (NEW.hora_fin_retiro - NEW.hora_inicio_retiro)) / 3600.0;
    IF v_horas > r.horas_max_ventana THEN
        RAISE EXCEPTION 'VENTANA_MUY_LARGA: este alimento admite como máximo % horas', r.horas_max_ventana
            USING ERRCODE = 'P0001';
    END IF;

    -- Límite por zona.
    IF r.hora_limite_retiro IS NOT NULL AND NEW.hora_fin_retiro > r.hora_limite_retiro THEN
        RAISE EXCEPTION 'FUERA_DEL_LIMITE_DE_ZONA: en esta zona no se puede retirar después de %', r.hora_limite_retiro
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END $$;

CREATE TRIGGER tr_publicacion_bi_valida
    BEFORE INSERT ON oferta.publicacion
    FOR EACH ROW EXECUTE FUNCTION oferta.fn_valida_publicacion();


/* ---------------------------------------------------------------------------
   5. RN-11: solo se califica una reserva RETIRADA.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION social.fn_valida_calificacion()
RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM venta.reserva r
                    WHERE r.id = NEW.reserva_id AND r.estado = 'RETIRADA') THEN
        RAISE EXCEPTION 'RESERVA_NO_RETIRADA: solo se puede calificar una bolsa que se retiró'
            USING ERRCODE = 'P0001';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER tr_calificacion_bi_valida
    BEFORE INSERT ON social.calificacion
    FOR EACH ROW EXECUTE FUNCTION social.fn_valida_calificacion();



-- ==========================================================================
-- ARCHIVO: V012__vistas.sql
-- Vistas y vistas materializadas
-- ==========================================================================

/* ============================================================================
   LAST BITE · V012 — Vistas y vistas materializadas
   ----------------------------------------------------------------------------
   Lo que se calcula no se guarda. La calificación promedio, los kilos
   rescatados y el CO2 evitado no son columnas: son vistas.
   ========================================================================== */

/* Filtra sucursales operables. Evita que cada consulta repita el filtro
   y se olvide en alguna.                                                    */
CREATE OR REPLACE VIEW comercio.vw_sucursal_activa AS
SELECT s.id            AS sucursal_id,
       s.nombre        AS sucursal,
       s.direccion,
       s.latitud,
       s.longitud,
       c.id            AS comercio_id,
       c.nombre_comercial,
       cc.nombre       AS rubro,
       z.id            AS zona_id,
       z.nombre        AS zona,
       ci.nombre       AS ciudad,
       z.hora_limite_retiro
  FROM comercio.sucursal s
  JOIN comercio.comercio c            ON c.id  = s.comercio_id
  JOIN comercio.categoria_comercio cc ON cc.id = c.categoria_comercio_id
  JOIN geo.zona z                     ON z.id  = s.zona_id
  JOIN geo.ciudad ci                  ON ci.id = z.ciudad_id
 WHERE s.es_activo
   AND c.estado = 'ACTIVO'
   AND z.es_activo
   AND (s.licencia_vence IS NULL OR s.licencia_vence >= current_date);


/* El listado principal de la app: publicaciones con cupo, ya unidas. */
CREATE OR REPLACE VIEW oferta.vw_publicacion_vigente AS
SELECT p.id                  AS publicacion_id,
       p.fecha,
       p.hora_inicio_retiro,
       p.hora_fin_retiro,
       p.cantidad_disponible,
       p.precio_venta,
       pb.id                 AS plantilla_id,
       pb.nombre             AS bolsa,
       pb.descripcion,
       pb.valor_estimado,
       pb.alergenos,
       pb.peso_estimado_kg,
       ca.nombre             AS tipo_alimento,
       ca.es_perecible,
       sa.sucursal_id,
       sa.sucursal,
       sa.direccion,
       sa.latitud,
       sa.longitud,
       sa.nombre_comercial,
       sa.rubro,
       sa.zona_id,
       sa.zona,
       round(100 - (p.precio_venta / nullif(pb.valor_estimado,0) * 100)) AS descuento_pct
  FROM oferta.publicacion p
  JOIN oferta.plantilla_bolsa pb        ON pb.id = p.plantilla_bolsa_id
  JOIN oferta.categoria_alimento ca     ON ca.id = pb.categoria_alimento_id
  JOIN comercio.vw_sucursal_activa sa   ON sa.sucursal_id = pb.sucursal_id
 WHERE p.estado = 'PUBLICADA'
   AND p.cantidad_disponible > 0
   AND p.fecha = current_date
   AND p.hora_fin_retiro > localtime;


/* Panel del comercio: reservas con cliente, sucursal y estado de pago. */
CREATE OR REPLACE VIEW venta.vw_reserva_detalle AS
SELECT r.id                AS reserva_id,
       r.codigo,
       r.estado            AS estado_reserva,
       r.cantidad,
       r.precio_unitario,
       r.subtotal,
       r.isv,
       r.total,
       r.comision_plataforma,
       r.monto_comercio,
       r.creation_date     AS fecha_reserva,
       r.retiro_date,
       u.id                AS cliente_id,
       u.nombres || ' ' || u.apellidos AS cliente,
       u.telefono          AS cliente_telefono,
       p.fecha,
       p.hora_inicio_retiro,
       p.hora_fin_retiro,
       pb.nombre           AS bolsa,
       s.id                AS sucursal_id,
       s.nombre            AS sucursal,
       c.id                AS comercio_id,
       c.nombre_comercial,
       pg.estado           AS estado_pago,
       mp.codigo           AS metodo_pago
  FROM venta.reserva r
  JOIN seguridad.usuario u        ON u.id  = r.cliente_usuario_id
  JOIN oferta.publicacion p       ON p.id  = r.publicacion_id
  JOIN oferta.plantilla_bolsa pb  ON pb.id = p.plantilla_bolsa_id
  JOIN comercio.sucursal s        ON s.id  = pb.sucursal_id
  JOIN comercio.comercio c        ON c.id  = s.comercio_id
  LEFT JOIN LATERAL (
        SELECT pa.estado, pa.metodo_pago_id
          FROM venta.pago pa
         WHERE pa.reserva_id = r.id
         ORDER BY (pa.estado = 'CAPTURADO') DESC, pa.id DESC
         LIMIT 1
  ) pg ON true
  LEFT JOIN venta.metodo_pago mp ON mp.id = pg.metodo_pago_id;


/* ---------------------------------------------------------------------------
   Vistas materializadas: lo que se calcula caro y se consulta seguido, pero
   no necesita estar al segundo. REFRESH CONCURRENTLY exige un índice único.
   --------------------------------------------------------------------------- */

CREATE MATERIALIZED VIEW core.mv_impacto_usuario AS
SELECT u.id                                            AS usuario_id,
       count(*)                                        AS bolsas_rescatadas,
       round(sum(pb.peso_estimado_kg * r.cantidad), 2)  AS kg_rescatados,
       round(sum(pb.peso_estimado_kg * r.cantidad * coalesce(fi.kg_co2_por_kg, 2.5)), 2) AS kg_co2_evitados,
       round(sum((pb.valor_estimado - r.precio_unitario) * r.cantidad), 2) AS ahorro_total
  FROM venta.reserva r
  JOIN seguridad.usuario u          ON u.id  = r.cliente_usuario_id
  JOIN oferta.publicacion p         ON p.id  = r.publicacion_id
  JOIN oferta.plantilla_bolsa pb    ON pb.id = p.plantilla_bolsa_id
  LEFT JOIN oferta.factor_impacto fi
         ON fi.categoria_alimento_id = pb.categoria_alimento_id
        AND fi.vigente_hasta IS NULL
 WHERE r.estado = 'RETIRADA'
 GROUP BY u.id;

CREATE UNIQUE INDEX uq_mv_impacto_usuario ON core.mv_impacto_usuario (usuario_id);


CREATE MATERIALIZED VIEW core.mv_ranking_sucursal AS
SELECT s.id                                   AS sucursal_id,
       s.nombre                               AS sucursal,
       c.nombre_comercial,
       count(cal.reserva_id)                  AS calificaciones,
       round(avg(cal.puntuacion), 2)          AS promedio,
       count(r.id) FILTER (WHERE r.estado = 'RETIRADA')     AS retiradas,
       count(r.id) FILTER (WHERE r.estado = 'NO_RETIRADA')  AS no_retiradas
  FROM comercio.sucursal s
  JOIN comercio.comercio c       ON c.id  = s.comercio_id
  LEFT JOIN oferta.plantilla_bolsa pb ON pb.sucursal_id = s.id
  LEFT JOIN oferta.publicacion p      ON p.plantilla_bolsa_id = pb.id
  LEFT JOIN venta.reserva r           ON r.publicacion_id = p.id
  LEFT JOIN social.calificacion cal   ON cal.reserva_id = r.id
 GROUP BY s.id, s.nombre, c.nombre_comercial;

CREATE UNIQUE INDEX uq_mv_ranking_sucursal ON core.mv_ranking_sucursal (sucursal_id);


CREATE MATERIALIZED VIEW core.mv_venta_diaria AS
SELECT p.fecha,
       z.id                                   AS zona_id,
       z.nombre                               AS zona,
       cc.nombre                              AS rubro,
       count(r.id)                            AS reservas,
       sum(r.total)                           AS total_vendido,
       sum(r.comision_plataforma)             AS comision,
       count(r.id) FILTER (WHERE r.estado = 'NO_RETIRADA') AS no_shows
  FROM venta.reserva r
  JOIN oferta.publicacion p      ON p.id  = r.publicacion_id
  JOIN oferta.plantilla_bolsa pb ON pb.id = p.plantilla_bolsa_id
  JOIN comercio.sucursal s       ON s.id  = pb.sucursal_id
  JOIN comercio.comercio c       ON c.id  = s.comercio_id
  JOIN comercio.categoria_comercio cc ON cc.id = c.categoria_comercio_id
  JOIN geo.zona z                ON z.id  = s.zona_id
 WHERE r.estado IN ('RETIRADA','NO_RETIRADA')
 GROUP BY p.fecha, z.id, z.nombre, cc.nombre;

CREATE UNIQUE INDEX uq_mv_venta_diaria ON core.mv_venta_diaria (fecha, zona_id, rubro);


/* Refresco de las tres. CONCURRENTLY no bloquea lecturas. */
CREATE OR REPLACE PROCEDURE core.sp_refrescar_vistas()
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_impacto_usuario;
    REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_ranking_sucursal;
    REFRESH MATERIALIZED VIEW CONCURRENTLY core.mv_venta_diaria;
END $$;



-- ==========================================================================
-- ARCHIVO: V013__procedimientos.sql
-- Procedimientos almacenados
-- ==========================================================================

/* ============================================================================
   LAST BITE · V013 — Procedimientos de negocio
   ----------------------------------------------------------------------------
   Lo que debe ser atómico o inviolable vive aquí, no en C#. Cuatro operaciones
   califican: reservar, retirar, vencer y liquidar.
   ========================================================================== */

/* ---------------------------------------------------------------------------
   Tarifa vigente en una fecha dada, para un rubro. La general (categoría nula)
   es el respaldo cuando no hay una específica.  RN-13.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE FUNCTION finanza.fn_tarifa_vigente(
    p_categoria_comercio_id SMALLINT,
    p_fecha                 DATE DEFAULT current_date
)
RETURNS finanza.tarifa
LANGUAGE sql STABLE AS $$
    SELECT t.*
      FROM finanza.tarifa t
     WHERE t.es_activo
       AND t.vigente_desde <= p_fecha
       AND (t.vigente_hasta IS NULL OR t.vigente_hasta >= p_fecha)
       AND (t.categoria_comercio_id = p_categoria_comercio_id
            OR t.categoria_comercio_id IS NULL)
     ORDER BY (t.categoria_comercio_id IS NOT NULL) DESC, t.vigente_desde DESC
     LIMIT 1;
$$;


/* ---------------------------------------------------------------------------
   sp_reserva_crear — el corazón del sistema.
   Bloquea la fila de la publicación, valida, descuenta y crea la reserva y el
   intento de pago. Todo o nada.
   Reglas que hace cumplir: RN-07 (publicación vigente con cupo), RN-09 (máximo
   tres por cliente y publicación), RN-13 (tarifa del día), y el control del
   carril de efectivo por reputación.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE PROCEDURE venta.sp_reserva_crear(
    IN  p_publicacion_id   BIGINT,
    IN  p_usuario_id       BIGINT,
    IN  p_cantidad         SMALLINT,
    IN  p_metodo_pago_id   SMALLINT,
    IN  p_mpu_id           INT,          -- sin DEFAULT: PostgreSQL no admite
                                                 -- parámetros OUT después de uno con valor por defecto
    OUT o_reserva_id       BIGINT,
    OUT o_codigo           VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    v_pub          RECORD;
    v_metodo       RECORD;
    v_usuario      RECORD;
    v_categoria    SMALLINT;
    v_tarifa       finanza.tarifa;
    v_isv_pct      NUMERIC := 0.15;
    v_subtotal     NUMERIC(12,2);
    v_isv          NUMERIC(12,2);
    v_base         NUMERIC(12,2);
    v_comision     NUMERIC(12,2);
    v_ya_reservado SMALLINT;
    v_estado       core.en_estado_reserva;
    v_estado_pago  core.en_estado_pago;
BEGIN
    IF p_cantidad IS NULL OR p_cantidad < 1 THEN
        RAISE EXCEPTION 'CANTIDAD_INVALIDA' USING ERRCODE = 'P0001';
    END IF;

    /* El segundo cliente que pida la última bolsa espera aquí. Este bloqueo,
       y no el CHECK, es lo que resuelve la carrera por el cupo.             */
    SELECT p.*, pb.categoria_alimento_id, s.comercio_id, c.categoria_comercio_id
      INTO v_pub
      FROM oferta.publicacion p
      JOIN oferta.plantilla_bolsa pb ON pb.id = p.plantilla_bolsa_id
      JOIN comercio.sucursal s       ON s.id  = pb.sucursal_id
      JOIN comercio.comercio c       ON c.id  = s.comercio_id
     WHERE p.id = p_publicacion_id
       FOR UPDATE OF p;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'PUBLICACION_INEXISTENTE' USING ERRCODE = 'P0001';
    END IF;

    -- RN-07
    IF v_pub.estado <> 'PUBLICADA' THEN
        RAISE EXCEPTION 'PUBLICACION_NO_DISPONIBLE: estado %', v_pub.estado USING ERRCODE = 'P0001';
    END IF;
    IF v_pub.cantidad_disponible < p_cantidad THEN
        RAISE EXCEPTION 'SIN_CUPO: quedan % bolsas', v_pub.cantidad_disponible USING ERRCODE = 'P0001';
    END IF;

    -- RN-09: no más de tres bolsas de la misma publicación por cliente.
    SELECT coalesce(sum(cantidad), 0) INTO v_ya_reservado
      FROM venta.reserva
     WHERE publicacion_id = p_publicacion_id
       AND cliente_usuario_id = p_usuario_id
       AND estado NOT IN ('CANCELADA','REEMBOLSADA');

    IF v_ya_reservado + p_cantidad > 3 THEN
        RAISE EXCEPTION 'LIMITE_POR_CLIENTE: ya tiene % de un máximo de 3', v_ya_reservado
            USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_usuario FROM seguridad.usuario WHERE id = p_usuario_id;
    IF v_usuario.estado <> 'ACTIVO' THEN
        RAISE EXCEPTION 'USUARIO_NO_ACTIVO' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_metodo FROM venta.metodo_pago WHERE id = p_metodo_pago_id AND es_activo;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'METODO_PAGO_INVALIDO' USING ERRCODE = 'P0001';
    END IF;

    /* Adaptación local: el efectivo se le retira a quien ya faltó tres veces.
       La reputación reemplaza a la tarjeta como garantía.                    */
    IF v_metodo.requiere_confirmacion_en_sitio AND v_usuario.no_shows >= 3 THEN
        RAISE EXCEPTION 'EFECTIVO_BLOQUEADO: % faltas acumuladas, debe prepagar', v_usuario.no_shows
            USING ERRCODE = 'P0001';
    END IF;

    -- Importes. Se copian en la reserva: son hechos históricos.
    v_subtotal := round(v_pub.precio_venta * p_cantidad, 2);
    v_base     := round(v_subtotal / (1 + v_isv_pct), 2);
    v_isv      := v_subtotal - v_base;

    v_tarifa := finanza.fn_tarifa_vigente(v_pub.categoria_comercio_id, v_pub.fecha);
    IF v_tarifa IS NULL THEN
        RAISE EXCEPTION 'SIN_TARIFA_VIGENTE' USING ERRCODE = 'P0001';
    END IF;

    v_comision := CASE
        WHEN v_tarifa.tipo = 'PORCENTUAL' THEN round(v_base * v_tarifa.valor / 100, 2)
        ELSE round(v_tarifa.valor * p_cantidad, 2)
    END;

    -- Prepago digital nace CONFIRMADA; el efectivo queda pendiente.
    IF v_metodo.requiere_confirmacion_en_sitio THEN
        v_estado      := 'PENDIENTE_PAGO';
        v_estado_pago := 'PENDIENTE';
    ELSE
        v_estado      := 'CONFIRMADA';
        v_estado_pago := 'CAPTURADO';
    END IF;

    o_codigo := core.fn_siguiente_codigo('LB');

    INSERT INTO venta.reserva
        (codigo, publicacion_id, cliente_usuario_id, cantidad, precio_unitario,
         subtotal, isv, comision_plataforma, monto_comercio, estado, created_by)
    VALUES
        (o_codigo, p_publicacion_id, p_usuario_id, p_cantidad, v_pub.precio_venta,
         v_base, v_isv, v_comision, v_base - v_comision, v_estado, p_usuario_id)
    RETURNING id INTO o_reserva_id;

    INSERT INTO venta.pago
        (reserva_id, metodo_pago_id, metodo_pago_usuario_id, monto, estado, created_by)
    VALUES
        (o_reserva_id, p_metodo_pago_id, p_mpu_id, v_subtotal, v_estado_pago, p_usuario_id);

    -- Se descuenta el cupo y, si se agotó, la publicación cambia sola.
    UPDATE oferta.publicacion
       SET cantidad_disponible = cantidad_disponible - p_cantidad,
           estado = CASE WHEN cantidad_disponible - p_cantidad = 0
                         THEN 'AGOTADA'::core.en_estado_publicacion
                         ELSE estado END
     WHERE id = p_publicacion_id;
END $$;


/* ---------------------------------------------------------------------------
   sp_reserva_retirar — validación en el mostrador.
   RN-10: dentro de la ventana y solo por personal de esa sucursal.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE PROCEDURE venta.sp_reserva_retirar(
    IN  p_codigo         VARCHAR,
    IN  p_empleado_id    BIGINT,
    OUT o_reserva_id     BIGINT
)
LANGUAGE plpgsql AS $$
DECLARE
    v RECORD;
BEGIN
    SELECT r.id, r.estado, p.fecha, p.hora_inicio_retiro, p.hora_fin_retiro,
           pb.sucursal_id
      INTO v
      FROM venta.reserva r
      JOIN oferta.publicacion p      ON p.id  = r.publicacion_id
      JOIN oferta.plantilla_bolsa pb ON pb.id = p.plantilla_bolsa_id
     WHERE r.codigo = p_codigo
       FOR UPDATE OF r;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'CODIGO_INEXISTENTE' USING ERRCODE = 'P0001';
    END IF;

    IF v.estado <> 'CONFIRMADA' THEN
        RAISE EXCEPTION 'RESERVA_NO_ENTREGABLE: estado %', v.estado USING ERRCODE = 'P0001';
    END IF;

    -- RN-10, primera mitad: la ventana.
    IF NOT (current_date = v.fecha
            AND localtime BETWEEN v.hora_inicio_retiro AND v.hora_fin_retiro) THEN
        RAISE EXCEPTION 'FUERA_DE_VENTANA: el retiro es de % a % del %',
            v.hora_inicio_retiro, v.hora_fin_retiro, v.fecha USING ERRCODE = 'P0001';
    END IF;

    -- RN-10, segunda mitad: quien entrega pertenece a esa sucursal.
    IF NOT EXISTS (SELECT 1 FROM comercio.usuario_sucursal us
                    WHERE us.usuario_id = p_empleado_id
                      AND us.sucursal_id = v.sucursal_id) THEN
        RAISE EXCEPTION 'EMPLEADO_AJENO: esa persona no pertenece a esta sucursal'
            USING ERRCODE = 'P0001';
    END IF;

    UPDATE venta.reserva
       SET estado = 'RETIRADA',
           retiro_date = now(),
           entrega_usuario_id = p_empleado_id
     WHERE id = v.id;

    o_reserva_id := v.id;
END $$;


/* ---------------------------------------------------------------------------
   sp_publicacion_vencer — el actor que no es persona.
   Vence publicaciones, marca reservas no retiradas y suma la falta.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE PROCEDURE oferta.sp_publicacion_vencer(
    OUT o_publicaciones INT,
    OUT o_reservas      INT
)
LANGUAGE plpgsql AS $$
BEGIN
    -- 1. Publicaciones cuya ventana ya cerró.
    WITH vencidas AS (
        UPDATE oferta.publicacion
           SET estado = 'VENCIDA'
         WHERE estado IN ('PUBLICADA','AGOTADA')
           AND (fecha < current_date
                OR (fecha = current_date AND hora_fin_retiro < localtime))
        RETURNING id
    )
    SELECT count(*) INTO o_publicaciones FROM vencidas;

    -- 2. Reservas confirmadas que nadie recogió.
    WITH no_retiradas AS (
        UPDATE venta.reserva r
           SET estado = 'NO_RETIRADA'
          FROM oferta.publicacion p
         WHERE p.id = r.publicacion_id
           AND r.estado = 'CONFIRMADA'
           AND p.estado = 'VENCIDA'
        RETURNING r.cliente_usuario_id
    )
    SELECT count(*) INTO o_reservas FROM no_retiradas;

    -- 3. El contador de faltas, que es lo que sostiene el carril del efectivo.
    UPDATE seguridad.usuario u
       SET no_shows = u.no_shows + s.faltas
      FROM (SELECT r.cliente_usuario_id, count(*)::smallint AS faltas
              FROM venta.reserva r
              JOIN oferta.publicacion p ON p.id = r.publicacion_id
             WHERE r.estado = 'NO_RETIRADA'
               AND r.modification_date >= now() - interval '1 minute'
             GROUP BY r.cliente_usuario_id) s
     WHERE u.id = s.cliente_usuario_id;
END $$;


/* ---------------------------------------------------------------------------
   sp_liquidacion_generar — el corte del período.
   RN-14: una reserva entra en una sola liquidación; las reembolsadas y
   canceladas no se liquidan. Es idempotente por período gracias a la
   restricción única de la cabecera.
   --------------------------------------------------------------------------- */
CREATE OR REPLACE PROCEDURE finanza.sp_liquidacion_generar(
    IN  p_comercio_id    INT,
    IN  p_desde          DATE,
    IN  p_hasta          DATE,
    OUT o_liquidacion_id INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_cant INT;
BEGIN
    IF p_hasta < p_desde THEN
        RAISE EXCEPTION 'PERIODO_INVALIDO' USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO finanza.liquidacion (comercio_id, periodo_inicio, periodo_fin, created_by)
    VALUES (p_comercio_id, p_desde, p_hasta, core.fn_usuario_actual())
    RETURNING id INTO o_liquidacion_id;

    /* Solo RETIRADA y NO_RETIRADA: en ambos casos el cliente pagó.
       El UNIQUE de detalle_liquidacion.reserva_id impide que una venta que ya
       entró en otro corte se vuelva a pagar.                                */
    INSERT INTO finanza.detalle_liquidacion
        (liquidacion_id, reserva_id, monto_comercio, comision, created_by)
    SELECT o_liquidacion_id, r.id, r.monto_comercio, r.comision_plataforma,
           core.fn_usuario_actual()
      FROM venta.reserva r
      JOIN oferta.publicacion p      ON p.id  = r.publicacion_id
      JOIN oferta.plantilla_bolsa pb ON pb.id = p.plantilla_bolsa_id
      JOIN comercio.sucursal s       ON s.id  = pb.sucursal_id
     WHERE s.comercio_id = p_comercio_id
       AND p.fecha BETWEEN p_desde AND p_hasta
       AND r.estado IN ('RETIRADA','NO_RETIRADA')
       AND NOT EXISTS (SELECT 1 FROM finanza.detalle_liquidacion dl
                        WHERE dl.reserva_id = r.id);

    GET DIAGNOSTICS v_cant = ROW_COUNT;

    UPDATE finanza.liquidacion l
       SET cantidad_reservas = v_cant,
           total_ventas   = coalesce(t.ventas, 0),
           total_comision = coalesce(t.comision, 0),
           monto_neto     = coalesce(t.neto, 0)
      FROM (SELECT sum(dl.monto_comercio + dl.comision) AS ventas,
                   sum(dl.comision)                     AS comision,
                   sum(dl.monto_comercio)               AS neto
              FROM finanza.detalle_liquidacion dl
             WHERE dl.liquidacion_id = o_liquidacion_id) t
     WHERE l.id = o_liquidacion_id;
END $$;



-- ==========================================================================
-- ARCHIVO: S001__datos_semilla.sql
-- Catálogos base (todos los ambientes)
-- ==========================================================================

/* ============================================================================
   LAST BITE · S001 — Datos semilla
   ----------------------------------------------------------------------------
   Catálogos que el sistema necesita para arrancar. Va en TODOS los ambientes,
   incluido producción.
   ========================================================================== */

/* El usuario de sistema es la primera fila de la base y se apunta a sí mismo.
   Por eso las llaves de auditoría de seguridad.usuario son DEFERRABLE.       */
INSERT INTO seguridad.usuario
    (nombres, apellidos, correo, contrasena_hash, correo_verificado, estado, created_by)
VALUES
    ('Sistema', 'Last Bite', 'sistema@lastbite.hn', '-', true, 'ACTIVO', 1);

INSERT INTO seguridad.rol (codigo, nombre, descripcion, created_by) VALUES
    ('CLIENTE',  'Cliente',        'Busca, reserva y retira bolsas.', 1),
    ('COMERCIO', 'Comercio',       'Publica bolsas y valida códigos en el mostrador.', 1),
    ('ADMIN',    'Administrador',  'Verifica afiliaciones, define tarifas y liquida.', 1);

/* ------------------------------ Geografía --------------------------------- */
INSERT INTO geo.departamento (nombre, created_by) VALUES
    ('Cortés', 1), ('Francisco Morazán', 1), ('Atlántida', 1), ('Yoro', 1);

INSERT INTO geo.ciudad (departamento_id, nombre, es_operativa, created_by)
SELECT d.id, v.nombre, v.op, 1
  FROM (VALUES ('Cortés','San Pedro Sula', true),
               ('Cortés','Choloma', false),
               ('Cortés','La Lima', false),
               ('Cortés','Villanueva', false),
               ('Francisco Morazán','Tegucigalpa', false),
               ('Atlántida','La Ceiba', false)) AS v(depto, nombre, op)
  JOIN geo.departamento d ON d.nombre = v.depto;

/* Zonas reales de San Pedro Sula. La hora límite de retiro es la adaptación
   operativa: en algunos sectores no es razonable pedir que alguien camine
   hasta allá a las nueve de la noche.                                        */
INSERT INTO geo.zona (ciudad_id, nombre, latitud_centro, longitud_centro, hora_limite_retiro, es_activo, created_by)
SELECT c.id, v.nombre, v.lat, v.lon, v.limite, v.activa, 1
  FROM (VALUES
        ('Barrio Los Andes',        15.505000, -88.025000, NULL,          true),  -- zona céntrica y transitada: sin restricción
        ('Colonia Trejo',           15.518000, -88.033000, TIME '20:30', true),
        ('Barrio Guamilito',        15.508000, -88.033000, TIME '19:30', true),
        ('Avenida Circunvalación',  15.512000, -88.020000, TIME '21:00', true),
        ('Barrio Río de Piedras',   15.500000, -88.030000, TIME '19:30', true),
        ('Colonia Juan Lindo',      15.530000, -88.040000, TIME '20:00', false),
        ('Barrio El Benque',        15.503000, -88.026000, TIME '19:00', false)
       ) AS v(nombre, lat, lon, limite, activa)
  JOIN geo.ciudad c ON c.nombre = 'San Pedro Sula';

/* ------------------------- Rubros y alimentos ------------------------------ */
INSERT INTO comercio.categoria_comercio (nombre, descripcion, created_by) VALUES
    ('Panadería y repostería', 'Panaderías, reposterías y pastelerías.', 1),
    ('Cafetería',              'Cafeterías y coffee shops.', 1),
    ('Restaurante y comedor',  'Restaurantes, comedores y buffets.', 1),
    ('Supermercado',           'Supermercados y tiendas de conveniencia.', 1),
    ('Hotel',                  'Hoteles con servicio de alimentos.', 1),
    ('Puesto de mercado',      'Puestos de mercados municipales.', 1);

/* horas_max_ventana es el límite sanitario por tipo de alimento. */
INSERT INTO oferta.categoria_alimento (nombre, es_perecible, horas_max_ventana, created_by) VALUES
    ('Panadería',           false, 3, 1),
    ('Sándwiches',          false, 3, 1),
    ('Comida preparada',    true,  1, 1),
    ('Frutas y verduras',   true,  2, 1),
    ('Lácteos',             true,  2, 1),
    ('Abarrotes',           false, 4, 1);

/* Factores de impacto. La fuente se guarda para que el dato sea defendible. */
INSERT INTO oferta.factor_impacto (categoria_alimento_id, kg_co2_por_kg, fuente, created_by)
SELECT ca.id, v.factor, 'Estimación del proyecto a partir de literatura de huella de carbono alimentaria', 1
  FROM (VALUES ('Panadería', 1.600), ('Sándwiches', 2.100),
               ('Comida preparada', 3.400), ('Frutas y verduras', 0.900),
               ('Lácteos', 2.800), ('Abarrotes', 1.200)) AS v(nombre, factor)
  JOIN oferta.categoria_alimento ca ON ca.nombre = v.nombre;

/* ------------------------------ Pagos -------------------------------------
   La bandera requiere_confirmacion_en_sitio es la que separa los dos carriles. */
INSERT INTO venta.metodo_pago (codigo, nombre, requiere_confirmacion_en_sitio, orden_presentacion, created_by) VALUES
    ('TARJETA',         'Tarjeta de crédito o débito', false, 1, 1),
    ('BILLETERA_MOVIL', 'Billetera móvil',             false, 2, 1),
    ('TRANSFERENCIA',   'Transferencia bancaria',      false, 3, 1),
    ('EFECTIVO',        'Efectivo al retirar',         true,  4, 1);

/* ------------------------------ Tarifas ------------------------------------
   Porcentual y no fija: con tickets de 40 a 120 lempiras, un monto plano se
   comería el margen.                                                          */
INSERT INTO finanza.tarifa (categoria_comercio_id, tipo, valor, created_by) VALUES
    (NULL, 'PORCENTUAL', 20.00, 1);          -- general
INSERT INTO finanza.tarifa (categoria_comercio_id, tipo, valor, created_by)
SELECT cc.id, 'PORCENTUAL', 15.00, 1
  FROM comercio.categoria_comercio cc WHERE cc.nombre = 'Puesto de mercado';

/* --------------------------- Parámetros ------------------------------------ */
INSERT INTO core.parametro (clave, valor, descripcion) VALUES
    ('ISV_PORCENTAJE',         '15',  'Impuesto sobre ventas vigente en Honduras.'),
    ('MAX_BOLSAS_POR_RESERVA', '3',   'RN-09: tope de bolsas por cliente y publicación.'),
    ('NO_SHOWS_BLOQUEO',       '3',   'Faltas a partir de las cuales se retira el pago en efectivo.'),
    ('HORAS_CANCELACION',      '2',   'RN-12: antelación mínima para cancelar.'),
    ('MONEDA',                 'HNL', 'Moneda del sistema.');



-- ==========================================================================
-- ARCHIVO: S002__datos_prueba.sql
-- Datos ficticios de SPS (solo desarrollo)
-- ==========================================================================

/* ============================================================================
   LAST BITE · S002 — Datos de prueba
   ----------------------------------------------------------------------------
   SOLO para desarrollo y demostración. Nunca en producción.
   Comercios inventados; los barrios y colonias sí son de San Pedro Sula.
   Reproduce el martes del ejemplo: publicar, reservar, retirar, no-show
   y liquidar, usando los procedimientos reales y no INSERT sueltos.
   ========================================================================== */

DO $prueba$
DECLARE
    v_ini   TIME;
    v_fin   TIME;
    v_trigal        INT;  v_suc_trigal   INT;  v_pl_trigal INT;  v_pub_trigal BIGINT;
    v_brew          INT;  v_suc_brew     INT;  v_pl_brew   INT;  v_pub_brew   BIGINT;
    v_chinda        INT;  v_suc_chinda   INT;
    v_admin BIGINT; v_kevin BIGINT; v_sofia BIGINT; v_marlon BIGINT; v_daniela BIGINT;
    v_caj_trigal BIGINT;  v_caj_brew BIGINT;
    v_id_tarjeta SMALLINT; v_id_efectivo SMALLINT;
    v_reserva BIGINT; v_codigo VARCHAR;
    v_res2 BIGINT;    v_cod2  VARCHAR;
    v_liq INT; v_pubs INT; v_ress INT;
BEGIN
    /* Ventana que envuelve la hora actual, para que el retiro de más abajo
       caiga dentro sin importar a qué hora se ejecute el script.            */
    v_ini := greatest((localtime - interval '30 minutes')::time, TIME '00:05');
    v_fin := least((localtime + interval '60 minutes')::time, TIME '23:50');

    SELECT id INTO v_id_tarjeta  FROM venta.metodo_pago WHERE codigo = 'TARJETA';
    SELECT id INTO v_id_efectivo FROM venta.metodo_pago WHERE codigo = 'EFECTIVO';

    /* ------------------------------ personas ------------------------------ */
    INSERT INTO seguridad.usuario (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado, created_by)
    VALUES ('Admin','Last Bite','admin@lastbite.hn','+50497000001','$2a$11$demo', true, 1)
    RETURNING id INTO v_admin;

    INSERT INTO seguridad.usuario (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado, created_by)
    VALUES ('Kevin','Zelaya','kevin.zelaya@correo.hn','+50497001111','$2a$11$demo', true, 1)
    RETURNING id INTO v_kevin;

    INSERT INTO seguridad.usuario (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado, created_by)
    VALUES ('Sofía','Andino','sofia.andino@correo.hn','+50497002222','$2a$11$demo', true, 1)
    RETURNING id INTO v_sofia;

    INSERT INTO seguridad.usuario (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado, created_by)
    VALUES ('Marlon','Pineda','marlon.pineda@correo.hn','+50497003333','$2a$11$demo', true, 1)
    RETURNING id INTO v_marlon;

    -- Daniela ya faltó tres veces: no debería poder pagar en efectivo.
    INSERT INTO seguridad.usuario (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado, no_shows, created_by)
    VALUES ('Daniela','Cruz','daniela.cruz@correo.hn','+50497004444','$2a$11$demo', true, 3, 1)
    RETURNING id INTO v_daniela;

    INSERT INTO seguridad.usuario (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado, created_by)
    VALUES ('Rosa','Mejía','rosa.mejia@eltrigal.hn','+50497005555','$2a$11$demo', true, 1)
    RETURNING id INTO v_caj_trigal;

    INSERT INTO seguridad.usuario (nombres, apellidos, correo, telefono, contrasena_hash, correo_verificado, created_by)
    VALUES ('Iván','Bonilla','ivan.bonilla@sulabrew.hn','+50497006666','$2a$11$demo', true, 1)
    RETURNING id INTO v_caj_brew;

    INSERT INTO seguridad.usuario_rol (usuario_id, rol_id, created_by)
    SELECT u.id, r.id, 1
      FROM (VALUES (v_admin,'ADMIN'), (v_kevin,'CLIENTE'), (v_sofia,'CLIENTE'),
                   (v_marlon,'CLIENTE'), (v_daniela,'CLIENTE'),
                   (v_caj_trigal,'COMERCIO'), (v_caj_brew,'COMERCIO')) AS u(id, cod)
      JOIN seguridad.rol r ON r.codigo = u.cod;

    /* ------------------------------ comercios ----------------------------- */
    INSERT INTO comercio.comercio (rtn, razon_social, nombre_comercial, categoria_comercio_id, correo_contacto, telefono, cuenta_bancaria, estado, created_by)
    SELECT '05019012345678','Reposteria El Trigal S. de R.L.','Repostería El Trigal', cc.id,
           'contacto@eltrigal.hn','+50425500001','01-234-567890','ACTIVO', 1
      FROM comercio.categoria_comercio cc WHERE cc.nombre = 'Panadería y repostería'
    RETURNING id INTO v_trigal;

    INSERT INTO comercio.comercio (rtn, razon_social, nombre_comercial, categoria_comercio_id, correo_contacto, telefono, cuenta_bancaria, estado, created_by)
    SELECT '05019087654321','Cafe Sula Brew S.A.','Café Sula Brew', cc.id,
           'hola@sulabrew.hn','+50425500002','01-234-567891','ACTIVO', 1
      FROM comercio.categoria_comercio cc WHERE cc.nombre = 'Cafetería'
    RETURNING id INTO v_brew;

    INSERT INTO comercio.comercio (rtn, razon_social, nombre_comercial, categoria_comercio_id, correo_contacto, telefono, estado, created_by)
    SELECT '05019011223344','Comedor Dona Chinda','Comedor Doña Chinda', cc.id,
           'chinda@correo.hn','+50425500003','ACTIVO', 1
      FROM comercio.categoria_comercio cc WHERE cc.nombre = 'Restaurante y comedor'
    RETURNING id INTO v_chinda;

    /* ------------------------------ sucursales ---------------------------- */
    INSERT INTO comercio.sucursal (comercio_id, zona_id, nombre, direccion, latitud, longitud, telefono, licencia_sanitaria, licencia_vence, created_by)
    SELECT v_trigal, z.id, 'El Trigal Trejo', 'Col. Trejo, dos cuadras al sur del parque',
           15.518200, -88.033400, '+50425500001', 'LS-2026-0141', current_date + 180, 1
      FROM geo.zona z WHERE z.nombre = 'Colonia Trejo'
    RETURNING id INTO v_suc_trigal;

    INSERT INTO comercio.sucursal (comercio_id, zona_id, nombre, direccion, latitud, longitud, telefono, licencia_sanitaria, licencia_vence, created_by)
    SELECT v_brew, z.id, 'Sula Brew Los Andes', 'Barrio Los Andes, frente al bulevar',
           15.505400, -88.025600, '+50425500002', 'LS-2026-0207', current_date + 240, 1
      FROM geo.zona z WHERE z.nombre = 'Barrio Los Andes'
    RETURNING id INTO v_suc_brew;

    INSERT INTO comercio.sucursal (comercio_id, zona_id, nombre, direccion, latitud, longitud, licencia_sanitaria, licencia_vence, created_by)
    SELECT v_chinda, z.id, 'Doña Chinda Guamilito', 'Barrio Guamilito, interior del mercado',
           15.508300, -88.033100, 'LS-2026-0388', current_date + 90, 1
      FROM geo.zona z WHERE z.nombre = 'Barrio Guamilito'
    RETURNING id INTO v_suc_chinda;

    /* Horarios. El Trigal y Doña Chinda tienen horario realista de barrio.
       Sula Brew se deja abierto todo el día para que este script se pueda
       ejecutar a cualquier hora y la demostración del retiro siempre corra. */
    INSERT INTO comercio.horario_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, created_by)
    SELECT s.id, d.dia, TIME '06:00', TIME '21:00', 1
      FROM (VALUES (v_suc_trigal),(v_suc_chinda)) AS s(id),
           generate_series(1,7) AS d(dia);

    INSERT INTO comercio.horario_sucursal (sucursal_id, dia_semana, hora_apertura, hora_cierre, created_by)
    SELECT v_suc_brew, d.dia, TIME '00:00', TIME '23:59', 1
      FROM generate_series(1,7) AS d(dia);

    INSERT INTO comercio.usuario_sucursal (usuario_id, sucursal_id, cargo, created_by) VALUES
        (v_caj_trigal, v_suc_trigal, 'ENCARGADO', 1),
        (v_caj_brew,   v_suc_brew,   'ENCARGADO', 1);

    /* ------------------------------ plantillas ---------------------------- */
    INSERT INTO oferta.plantilla_bolsa (sucursal_id, categoria_alimento_id, nombre, descripcion, precio_base, valor_estimado, peso_estimado_kg, alergenos, created_by)
    SELECT v_suc_trigal, ca.id, 'Bolsa Sorpresa de Repostería',
           'Pan dulce, semitas y lo que quede de la vitrina del día.',
           85.00, 250.00, 1.20, 'Gluten, lácteos, huevo', 1
      FROM oferta.categoria_alimento ca WHERE ca.nombre = 'Panadería'
    RETURNING id INTO v_pl_trigal;

    INSERT INTO oferta.plantilla_bolsa (sucursal_id, categoria_alimento_id, nombre, descripcion, precio_base, valor_estimado, peso_estimado_kg, alergenos, created_by)
    SELECT v_suc_brew, ca.id, 'Bolsa de Cafetería',
           'Sándwiches y repostería del mostrador.',
           110.00, 320.00, 0.90, 'Gluten, lácteos', 1
      FROM oferta.categoria_alimento ca WHERE ca.nombre = 'Sándwiches'
    RETURNING id INTO v_pl_brew;

    -- El comedor sí crea su plantilla, pero su alimento admite una sola hora
    -- de ventana: por eso más abajo no publica.
    INSERT INTO oferta.plantilla_bolsa (sucursal_id, categoria_alimento_id, nombre, descripcion, precio_base, valor_estimado, peso_estimado_kg, created_by)
    SELECT v_suc_chinda, ca.id, 'Almuerzo del Día',
           'Plato del día que quedó del almuerzo.', 60.00, 150.00, 0.80, 1
      FROM oferta.categoria_alimento ca WHERE ca.nombre = 'Comida preparada';

    /* ---------------------------- publicaciones --------------------------- */
    -- El Trigal publica su ventana real de la tarde: 6:30 a 7:30 p. m.
    INSERT INTO oferta.publicacion (plantilla_bolsa_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_total, cantidad_disponible, precio_venta, estado, created_by)
    VALUES (v_pl_trigal, current_date, TIME '18:30', TIME '19:30', 6, 6, 85.00, 'PUBLICADA', v_caj_trigal)
    RETURNING id INTO v_pub_trigal;

    -- Sula Brew publica la ventana que envuelve la hora actual: es la que se
    -- usa para demostrar el retiro end to end.
    INSERT INTO oferta.publicacion (plantilla_bolsa_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_total, cantidad_disponible, precio_venta, estado, created_by)
    VALUES (v_pl_brew, current_date, v_ini, v_fin, 4, 4, 110.00, 'PUBLICADA', v_caj_brew)
    RETURNING id INTO v_pub_brew;

    /* ------------------------ reservas por procedimiento ------------------ */
    -- Kevin paga con tarjeta en Sula Brew: la reserva nace CONFIRMADA.
    CALL venta.sp_reserva_crear(v_pub_brew, v_kevin, 1::smallint, v_id_tarjeta, NULL, v_reserva, v_codigo);
    -- Sofía paga en efectivo en El Trigal: queda PENDIENTE_PAGO.
    CALL venta.sp_reserva_crear(v_pub_trigal, v_sofia, 2::smallint, v_id_efectivo, NULL, v_res2, v_cod2);
    -- Marlon reserva en El Trigal con tarjeta.
    CALL venta.sp_reserva_crear(v_pub_trigal, v_marlon, 1::smallint, v_id_tarjeta, NULL, v_res2, v_cod2);

    /* Daniela tiene tres faltas: si se descomenta, el procedimiento levanta
       EFECTIVO_BLOQUEADO. Queda comentado para no abortar la carga.
       CALL venta.sp_reserva_crear(v_pub_trigal, v_daniela, 1::smallint, v_id_efectivo, NULL, v_res2, v_cod2);
    */

    /* ------------------------------- retiro -------------------------------- */
    -- Kevin llega y Iván valida su código, dentro de la ventana.
    CALL venta.sp_reserva_retirar(v_codigo, v_caj_brew, v_reserva);

    -- Y califica, que solo se puede porque la reserva está RETIRADA.
    INSERT INTO social.calificacion (reserva_id, puntuacion, comentario, created_by)
    VALUES (v_reserva, 5, 'Buenísimo, venía llena de semitas.', v_kevin);

    /* ------------------------------ favoritos ------------------------------ */
    INSERT INTO social.favorito (usuario_id, sucursal_id, created_by) VALUES
        (v_kevin,  v_suc_trigal, v_kevin),
        (v_sofia,  v_suc_trigal, v_sofia),
        (v_marlon, v_suc_trigal, v_marlon);

    RAISE NOTICE 'Datos de prueba cargados. Ventana usada: % a %. Código retirado: %', v_ini, v_fin, v_codigo;
END $prueba$;



-- ==========================================================================
-- VERIFICACIÓN FINAL
-- ==========================================================================
-- Debe devolver 30 tablas repartidas en los 9 esquemas del proyecto.

SELECT table_schema  AS esquema,
       COUNT(*)      AS tablas
FROM information_schema.tables
WHERE table_type = 'BASE TABLE'
  AND table_schema IN ('core','seguridad','geo','comercio','oferta',
                       'venta','finanza','social','auditoria')
GROUP BY table_schema
ORDER BY table_schema;

-- Objetos de programación creados
SELECT 'vistas'          AS objeto, COUNT(*) FROM information_schema.views
    WHERE table_schema NOT IN ('pg_catalog','information_schema')
UNION ALL
SELECT 'vistas materializadas', COUNT(*) FROM pg_matviews
UNION ALL
SELECT 'procedimientos y funciones', COUNT(*) FROM information_schema.routines
    WHERE routine_schema NOT IN ('pg_catalog','information_schema')
UNION ALL
SELECT 'triggers', COUNT(DISTINCT trigger_name) FROM information_schema.triggers
    WHERE trigger_schema NOT IN ('pg_catalog','information_schema');

-- ==========================================================================
-- FIN DEL INSTALADOR
-- Siguiente paso sugerido: ejecutar T001__pruebas_reglas.sql
-- La corrida esperada es: RESULTADO: 16 pruebas correctas, 0 fallas
-- ==========================================================================
