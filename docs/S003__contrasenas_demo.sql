/* ============================================================================
   LAST BITE · S003 — Contraseñas de los usuarios de prueba
   ----------------------------------------------------------------------------
   Los usuarios sembrados en S002 tienen '$2a$11$demo' como contrasena_hash,
   que es un marcador y no un hash válido. Con ese valor nadie puede iniciar
   sesión, porque BCrypt.Verify lo rechaza siempre.

   Este archivo los actualiza con un hash BCrypt real y verificado.

        Contraseña de todos los usuarios de prueba:  LastBite2026

   El hash usa el prefijo $2a$ y factor de costo 11, que es lo que produce y
   acepta BCrypt.Net-Next sin configuración adicional.

   SOLO DESARROLLO. No se aplica en un ambiente real.
   ========================================================================== */

UPDATE seguridad.usuario
   SET contrasena_hash        = '$2a$11$mIOP6q7Cog3J9O3avjJVJuJe0SltLTnh1Uv/Gs4FrE6PW1q4fxyIO',
       contrasena_actualizada = now(),
       modified_by            = 1,
       modification_date      = now()
 WHERE contrasena_hash = '$2a$11$demo';


/* Verificación: las seis cuentas deben quedar con el hash nuevo. */
SELECT id,
       correo,
       CASE WHEN contrasena_hash = '$2a$11$demo'
            THEN 'SIN ACTUALIZAR'
            ELSE 'LISTA' END AS estado_contrasena
  FROM seguridad.usuario
 ORDER BY id;


/* ----------------------------------------------------------------------------
   Cuentas disponibles después de aplicar este archivo:

     admin@lastbite.hn          Administrador
     kevin.zelaya@correo.hn     Cliente
     sofia.andino@correo.hn     Cliente
     marlon.pineda@correo.hn    Cliente
     daniela.cruz@correo.hn     Cliente con 3 faltas · prueba EFECTIVO_BLOQUEADO
     rosa.mejia@eltrigal.hn     Cajera · panel del comercio

   Todas con la contraseña  LastBite2026
   -------------------------------------------------------------------------- */
