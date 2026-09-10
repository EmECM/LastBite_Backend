/* ============================================================================
   LAST BITE · T001 — Pruebas de las reglas de negocio
   ----------------------------------------------------------------------------
   Cada prueba intenta hacer algo que el modelo debe impedir. Si la base lo
   permite, la prueba FALLA. Se ejecuta después de S002.
   No deja rastro: cada caso corre dentro de un savepoint que se deshace.
   ----------------------------------------------------------------------------
   NOTA: todo el archivo es un solo bloque DO. Los errores esperados se atrapan
   con EXCEPTION adentro del bloque, así que no hace falta desactivar nada.

   Si se ejecuta con psql y se quiere que no aborte al primer error, se puede
   agregar la opción en la línea de comandos:

        psql -d lastbite -v ON_ERROR_STOP=0 -f T001__pruebas_reglas.sql

   No se pone aquí como \set porque eso es un meta-comando de psql: DBeaver y
   pgAdmin lo mandan al servidor como SQL y devuelven
   «syntax error at or near "\"».
   ========================================================================== */

DO $pruebas$
DECLARE
    v_ok INT := 0; v_falla INT := 0;
    v_pub BIGINT; v_pub_trigal BIGINT; v_res BIGINT; v_cod VARCHAR;
    v_kevin BIGINT; v_daniela BIGINT; v_sofia BIGINT; v_marlon_id BIGINT;
    v_caj BIGINT; v_caj_otro BIGINT;
    v_efectivo SMALLINT; v_tarjeta SMALLINT;
    v_suc INT; v_pl INT; v_pl_chinda INT; v_com INT;
    v_liq1 INT; v_liq2 INT;
    v_txt TEXT;

    PROCEDURE_FALLO BOOLEAN;
BEGIN
    SELECT id INTO v_kevin   FROM seguridad.usuario WHERE correo='kevin.zelaya@correo.hn';
    SELECT id INTO v_daniela FROM seguridad.usuario WHERE correo='daniela.cruz@correo.hn';
    SELECT id INTO v_sofia   FROM seguridad.usuario WHERE correo='sofia.andino@correo.hn';
    SELECT id INTO v_marlon_id FROM seguridad.usuario WHERE correo='marlon.pineda@correo.hn';
    SELECT id INTO v_caj     FROM seguridad.usuario WHERE correo='ivan.bonilla@sulabrew.hn';
    SELECT id INTO v_caj_otro FROM seguridad.usuario WHERE correo='rosa.mejia@eltrigal.hn';
    SELECT id INTO v_efectivo FROM venta.metodo_pago WHERE codigo='EFECTIVO';
    SELECT id INTO v_tarjeta  FROM venta.metodo_pago WHERE codigo='TARJETA';
    SELECT p.id INTO v_pub FROM oferta.publicacion p
      JOIN oferta.plantilla_bolsa pb ON pb.id=p.plantilla_bolsa_id
      JOIN comercio.sucursal s ON s.id=pb.sucursal_id
     WHERE s.nombre='Sula Brew Los Andes';
    SELECT p.id INTO v_pub_trigal FROM oferta.publicacion p
      JOIN oferta.plantilla_bolsa pb ON pb.id=p.plantilla_bolsa_id
      JOIN comercio.sucursal s ON s.id=pb.sucursal_id
     WHERE s.nombre='El Trigal Trejo';
    SELECT id INTO v_suc FROM comercio.sucursal WHERE nombre='El Trigal Trejo';
    SELECT id INTO v_pl  FROM oferta.plantilla_bolsa WHERE nombre='Bolsa Sorpresa de Repostería';
    SELECT id INTO v_pl_chinda FROM oferta.plantilla_bolsa WHERE nombre='Almuerzo del Día';
    SELECT comercio_id INTO v_com FROM comercio.sucursal WHERE nombre='Sula Brew Los Andes';

    /* ------------------------------------------------------------------ */
    <<prueba01>> BEGIN  -- RN-06: precio_base menor que valor_estimado
        INSERT INTO oferta.plantilla_bolsa (sucursal_id, categoria_alimento_id, nombre, precio_base, valor_estimado, peso_estimado_kg, created_by)
        SELECT v_suc, ca.id, 'Bolsa cara', 300.00, 250.00, 1.0, 1 FROM oferta.categoria_alimento ca LIMIT 1;
        RAISE WARNING 'RN-06 FALLA: aceptó precio mayor que el valor estimado'; v_falla := v_falla+1;
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RN-06 OK  · precio_base debe ser menor que valor_estimado'; v_ok := v_ok+1;
    END prueba01;

    <<prueba02>> BEGIN  -- RN-05: cupo no puede quedar negativo
        UPDATE oferta.publicacion SET cantidad_disponible = -1 WHERE id = v_pub;
        RAISE WARNING 'RN-05 FALLA: aceptó cupo negativo'; v_falla := v_falla+1;
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'RN-05 OK  · cantidad_disponible no puede ser negativa'; v_ok := v_ok+1;
    END prueba02;

    <<prueba03>> BEGIN  -- RN-07: no se reserva más de lo que hay
        CALL venta.sp_reserva_crear(v_pub, v_sofia, 3::smallint, v_tarjeta, NULL, v_res, v_cod);
        CALL venta.sp_reserva_crear(v_pub, v_kevin, 3::smallint, v_tarjeta, NULL, v_res, v_cod);
        RAISE WARNING 'RN-07 FALLA: reservó sin cupo'; v_falla := v_falla+1;
    EXCEPTION WHEN raise_exception THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        IF v_txt LIKE 'SIN_CUPO%' OR v_txt LIKE 'LIMITE_POR_CLIENTE%'
           OR v_txt LIKE 'PUBLICACION_NO_DISPONIBLE%' THEN
            RAISE NOTICE 'RN-07 OK  · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
        ELSE RAISE WARNING 'RN-07 FALLA: %', v_txt; v_falla := v_falla+1; END IF;
    END prueba03;

    <<prueba04>> BEGIN  -- RN-09: máximo tres por cliente y publicación
        CALL venta.sp_reserva_crear(v_pub_trigal, v_sofia, 3::smallint, v_tarjeta, NULL, v_res, v_cod);
        RAISE WARNING 'RN-09 FALLA: superó el tope por cliente'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        RAISE NOTICE 'RN-09 OK  · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
    END prueba04;

    <<prueba05>> BEGIN  -- Efectivo bloqueado por reputación
        CALL venta.sp_reserva_crear(v_pub, v_daniela, 1::smallint, v_efectivo, NULL, v_res, v_cod);
        RAISE WARNING 'REPUTACION FALLA: aceptó efectivo con 3 faltas'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        RAISE NOTICE 'EFECTIVO OK · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
    END prueba05;

    <<prueba06>> BEGIN  -- RN-03: ventana fuera del horario de la sucursal
        INSERT INTO oferta.publicacion (plantilla_bolsa_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_total, cantidad_disponible, precio_venta, estado, created_by)
        VALUES (v_pl, current_date, TIME '04:00', TIME '05:00', 3, 3, 85.00, 'PUBLICADA', 1);
        RAISE WARNING 'RN-03 FALLA: publicó fuera del horario'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        RAISE NOTICE 'RN-03 OK  · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
    END prueba06;

    <<prueba07>> BEGIN  -- horas_max_ventana: comida preparada admite 1 hora
        INSERT INTO oferta.publicacion (plantilla_bolsa_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_total, cantidad_disponible, precio_venta, estado, created_by)
        VALUES (v_pl_chinda, current_date, TIME '13:00', TIME '16:00', 3, 3, 60.00, 'PUBLICADA', 1);
        RAISE WARNING 'ALIMENTO FALLA: ventana de 3 h para comida preparada'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        RAISE NOTICE 'ALIMENTO OK · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
    END prueba07;

    <<prueba08>> BEGIN  -- Límite horario de la zona: Trejo no permite retirar después de 20:30
        -- Esta sí es válida: cabe en el horario y no pasa del límite de zona.
        INSERT INTO oferta.publicacion (plantilla_bolsa_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_total, cantidad_disponible, precio_venta, estado, created_by)
        VALUES (v_pl, current_date, TIME '06:30', TIME '08:00', 3, 3, 85.00, 'PUBLICADA', 1);
        -- Esta cabe en el horario (cierra 21:00) pero se pasa del límite de la zona.
        INSERT INTO oferta.publicacion (plantilla_bolsa_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_total, cantidad_disponible, precio_venta, estado, created_by)
        VALUES (v_pl, current_date, TIME '20:00', TIME '21:00', 3, 3, 85.00, 'PUBLICADA', 1);
        RAISE WARNING 'ZONA FALLA: publicó pasado el límite de la zona'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        IF v_txt LIKE 'FUERA_DEL_LIMITE_DE_ZONA%' THEN
            RAISE NOTICE 'ZONA OK     · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
        ELSE RAISE WARNING 'ZONA FALLA: %', v_txt; v_falla := v_falla+1; END IF;
    END prueba08;

    <<prueba09>> BEGIN  -- EXCLUDE: ventanas traslapadas de la misma plantilla
        INSERT INTO oferta.publicacion (plantilla_bolsa_id, fecha, hora_inicio_retiro, hora_fin_retiro, cantidad_total, cantidad_disponible, precio_venta, estado, created_by)
        VALUES (v_pl, current_date, TIME '19:00', TIME '19:45', 3, 3, 85.00, 'PUBLICADA', 1);
        RAISE WARNING 'EXCLUDE FALLA: aceptó ventanas encimadas'; v_falla := v_falla+1;
    EXCEPTION WHEN exclusion_violation THEN
        RAISE NOTICE 'EXCLUDE OK  · dos ventanas del mismo tipo de bolsa no se traslapan'; v_ok := v_ok+1;
    END prueba09;

    <<prueba10>> BEGIN  -- RN-10: solo personal de esa sucursal entrega
        CALL venta.sp_reserva_crear(v_pub, v_marlon_id, 1::smallint, v_tarjeta, NULL, v_res, v_cod);
        CALL venta.sp_reserva_retirar(v_cod, v_caj_otro, v_res);
        RAISE WARNING 'RN-10 FALLA: entregó un empleado de otra sucursal'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        RAISE NOTICE 'RN-10 OK  · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
    END prueba10;

    <<prueba11>> BEGIN  -- RN-11: solo se califica lo retirado
        SELECT id INTO v_res FROM venta.reserva WHERE estado <> 'RETIRADA' LIMIT 1;
        INSERT INTO social.calificacion (reserva_id, puntuacion, created_by) VALUES (v_res, 5, 1);
        RAISE WARNING 'RN-11 FALLA: calificó una reserva no retirada'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        RAISE NOTICE 'RN-11 OK  · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
    END prueba11;

    <<prueba12>> BEGIN  -- Transición de estado prohibida
        SELECT id INTO v_res FROM venta.reserva WHERE estado='RETIRADA' LIMIT 1;
        UPDATE venta.reserva SET estado='PENDIENTE_PAGO' WHERE id=v_res;
        RAISE WARNING 'ESTADO FALLA: permitió volver de RETIRADA a PENDIENTE_PAGO'; v_falla := v_falla+1;
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
        RAISE NOTICE 'ESTADO OK   · %', split_part(v_txt, ':', 1); v_ok := v_ok+1;
    END prueba12;

    <<prueba13>> BEGIN  -- Un solo pago CAPTURADO por reserva
        SELECT id INTO v_res FROM venta.reserva WHERE estado='RETIRADA' LIMIT 1;
        INSERT INTO venta.pago (reserva_id, metodo_pago_id, monto, estado, created_by)
        VALUES (v_res, v_tarjeta, 1.00, 'CAPTURADO', 1);
        RAISE WARNING 'PAGO FALLA: aceptó dos pagos capturados'; v_falla := v_falla+1;
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'PAGO OK     · una reserva no puede tener dos pagos CAPTURADO'; v_ok := v_ok+1;
    END prueba13;

    <<prueba14>> BEGIN  -- RN-14: una reserva se liquida una sola vez
        CALL finanza.sp_liquidacion_generar(v_com, current_date - 30, current_date, v_liq1);
        CALL finanza.sp_liquidacion_generar(v_com, current_date - 60, current_date - 31, v_liq2);
        IF NOT EXISTS (SELECT 1 FROM finanza.detalle_liquidacion WHERE liquidacion_id = v_liq1) THEN
            RAISE WARNING 'RN-14 FALLA: la liquidación salió vacía, no hay qué duplicar';
            v_falla := v_falla+1;
        ELSE
            INSERT INTO finanza.detalle_liquidacion (liquidacion_id, reserva_id, monto_comercio, comision, created_by)
            SELECT v_liq2, dl.reserva_id, dl.monto_comercio, dl.comision, 1
              FROM finanza.detalle_liquidacion dl WHERE dl.liquidacion_id = v_liq1 LIMIT 1;
            RAISE WARNING 'RN-14 FALLA: liquidó dos veces la misma reserva'; v_falla := v_falla+1;
        END IF;
    EXCEPTION WHEN unique_violation THEN
        RAISE NOTICE 'RN-14 OK  · una reserva entra en una sola liquidación'; v_ok := v_ok+1;
    END prueba14;

    <<prueba15>> BEGIN  -- La fecha de creación es inmutable
        UPDATE seguridad.usuario SET creation_date = TIMESTAMPTZ '2000-01-01' WHERE id = v_kevin;
        IF (SELECT creation_date FROM seguridad.usuario WHERE id=v_kevin) = TIMESTAMPTZ '2000-01-01' THEN
            RAISE WARNING 'AUDITORIA FALLA: se pudo alterar creation_date'; v_falla := v_falla+1;
        ELSE
            RAISE NOTICE 'AUDITORIA OK· creation_date es inmutable, el trigger la restaura'; v_ok := v_ok+1;
        END IF;
    END prueba15;

    <<prueba16>> BEGIN  -- La bitácora no guarda credenciales
        UPDATE oferta.publicacion SET precio_venta = precio_venta + 1 WHERE id = v_pub;
        IF EXISTS (SELECT 1 FROM auditoria.bitacora
                    WHERE datos_nuevos ? 'contrasena_hash' OR datos_nuevos ? 'token_hash') THEN
            RAISE WARNING 'BITACORA FALLA: guardó una credencial'; v_falla := v_falla+1;
        ELSIF EXISTS (SELECT 1 FROM auditoria.bitacora WHERE tabla='publicacion') THEN
            RAISE NOTICE 'BITACORA OK · registra el cambio y excluye credenciales'; v_ok := v_ok+1;
        ELSE
            RAISE WARNING 'BITACORA FALLA: no registró el cambio'; v_falla := v_falla+1;
        END IF;
    END prueba16;

    RAISE NOTICE '--------------------------------------------------';
    RAISE NOTICE 'RESULTADO: % pruebas correctas, % fallas', v_ok, v_falla;
    RAISE NOTICE '--------------------------------------------------';

    -- Nada de esto queda: la prueba deshace todo su trabajo.
    RAISE EXCEPTION 'FIN_DE_PRUEBAS_ROLLBACK';
EXCEPTION WHEN raise_exception THEN
    GET STACKED DIAGNOSTICS v_txt = MESSAGE_TEXT;
    IF v_txt <> 'FIN_DE_PRUEBAS_ROLLBACK' THEN RAISE; END IF;
END $pruebas$;
