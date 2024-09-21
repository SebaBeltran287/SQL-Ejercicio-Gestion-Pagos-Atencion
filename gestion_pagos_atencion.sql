-- Creación de tablas principales

-- Tabla ATENCION para registrar las atenciones realizadas a los pacientes
CREATE TABLE ATENCION (
    ATE_ID NUMBER PRIMARY KEY,
    PACIENTE_ID NUMBER,
    FECHA_ATENCION DATE,
    MONTO_TOTAL NUMBER(10, 2)
);

-- Tabla PAGO_ATENCION para registrar los pagos de las atenciones
CREATE TABLE PAGO_ATENCION (
    PAGO_ID NUMBER PRIMARY KEY,
    ATE_ID NUMBER,
    FECHA_PAGO DATE,
    MONTO_PAGO NUMBER(10, 2),
    OBS_PAGO VARCHAR2(255),
    FOREIGN KEY (ATE_ID) REFERENCES ATENCION(ATE_ID)
);

-- Tabla RESUMEN_PAGO para consolidar los pagos de cada atención
CREATE TABLE RESUMEN_PAGO (
    ATE_ID NUMBER PRIMARY KEY,
    CANTIDAD_PAGOS NUMBER,
    MONTO_PAGOS NUMBER(10, 2),
    SALDO NUMBER(10, 2),
    FOREIGN KEY (ATE_ID) REFERENCES ATENCION(ATE_ID)
);

-- Tabla ERRORES_PROCESO para registrar los errores ocurridos en los procedimientos
CREATE TABLE ERRORES_PROCESO (
    ID_ERROR NUMBER PRIMARY KEY,
    CODIGO VARCHAR2(50),
    DESCRIPCION VARCHAR2(255)
);

-- Creación de secuencias para las claves primarias
CREATE SEQUENCE SEQ_PAGO_ATENCION;
CREATE SEQUENCE SEQ_ERRORES_PROCESO;

-- -----------------------------------------------
-- Procedimiento para registrar un pago
-- Objetivo del Procedimiento:
-- 		Registrar un nuevo pago para una atención y validar reglas de negocio.
-- Parámetros de Entrada:
--     p_ate_id: ID de la atención para la cual se hace el pago.
--     p_fecha_pago: Fecha en la que se realiza el pago.
--     p_monto_pago: Monto que se está pagando.
--     p_obs_pago: Observaciones del pago (puede ser nulo).
CREATE OR REPLACE PROCEDURE spRegistrarPago (
    p_ate_id IN NUMBER,
    p_fecha_pago IN DATE,
    p_monto_pago IN NUMBER,
    p_obs_pago IN VARCHAR2
) AS
    v_saldo_actual NUMBER;
    v_monto_pagado NUMBER;
BEGIN
    -- Validación: Fecha del pago no puede ser anterior a la fecha actual
    IF p_fecha_pago < SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'La fecha de pago no puede ser anterior a la fecha actual');
    END IF;

    -- Obtener el saldo actual de la atención
    SELECT SALDO INTO v_saldo_actual FROM RESUMEN_PAGO WHERE ATE_ID = p_ate_id;

    -- Validación: Monto del pago no puede ser mayor al saldo pendiente
    IF p_monto_pago > v_saldo_actual THEN
        RAISE_APPLICATION_ERROR(-20002, 'El monto del pago no puede ser mayor al saldo pendiente');
    END IF;

    -- Insertar el pago en la tabla PAGO_ATENCION
    INSERT INTO PAGO_ATENCION (PAGO_ID, ATE_ID, FECHA_PAGO, MONTO_PAGO, OBS_PAGO)
    VALUES (SEQ_PAGO_ATENCION.NEXTVAL, p_ate_id, p_fecha_pago, p_monto_pago, p_obs_pago);

    -- Actualizar la tabla RESUMEN_PAGO con el nuevo saldo
    SELECT SUM(MONTO_PAGO) INTO v_monto_pagado FROM PAGO_ATENCION WHERE ATE_ID = p_ate_id;
    
    UPDATE RESUMEN_PAGO
    SET CANTIDAD_PAGOS = CANTIDAD_PAGOS + 1,
        MONTO_PAGOS = v_monto_pagado,
        SALDO = (SELECT MONTO_TOTAL FROM ATENCION WHERE ATE_ID = p_ate_id) - v_monto_pagado
    WHERE ATE_ID = p_ate_id;

    -- Confirmar la transacción
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        -- Registrar error en la tabla ERRORES_PROCESO
        INSERT INTO ERRORES_PROCESO (ID_ERROR, CODIGO, DESCRIPCION)
        VALUES (SEQ_ERRORES_PROCESO.NEXTVAL, SQLCODE, SQLERRM);
        ROLLBACK;
END;
/

-- -----------------------------------------------
-- Procedimiento para actualizar todos los pagos y saldos en la tabla RESUMEN_PAGO
-- Objetivo del Procedimiento:
-- 		Calcular los pagos consolidados de todas las atenciones y actualizar los saldos.
CREATE OR REPLACE PROCEDURE spActualizarPagosTotales AS
BEGIN
    -- Limpiar la tabla RESUMEN_PAGO antes de iniciar el proceso
    DELETE FROM RESUMEN_PAGO;

    -- Insertar el resumen de pagos para cada atención
    INSERT INTO RESUMEN_PAGO (ATE_ID, CANTIDAD_PAGOS, MONTO_PAGOS, SALDO)
    SELECT ATE_ID,
           COUNT(PAGO_ID),
           SUM(MONTO_PAGO),
           (SELECT MONTO_TOTAL FROM ATENCION WHERE ATE_ID = PAGO_ATENCION.ATE_ID) - SUM(MONTO_PAGO)
    FROM PAGO_ATENCION
    GROUP BY ATE_ID;

    -- Confirmar la transacción
    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        -- Registrar error en la tabla ERRORES_PROCESO
        INSERT INTO ERRORES_PROCESO (ID_ERROR, CODIGO, DESCRIPCION)
        VALUES (SEQ_ERRORES_PROCESO.NEXTVAL, SQLCODE, SQLERRM);
        ROLLBACK;
END;
/

-- -----------------------------------------------
-- Trigger para validar que la fecha de pago no sea anterior a la fecha actual
CREATE OR REPLACE TRIGGER trg_validar_fecha_pago
BEFORE INSERT ON PAGO_ATENCION
FOR EACH ROW
BEGIN
    IF :NEW.FECHA_PAGO < SYSDATE THEN
        RAISE_APPLICATION_ERROR(-20001, 'La fecha de pago no puede ser anterior a la fecha actual');
    END IF;
END;
/

-- -----------------------------------------------
-- Trigger para validar que el monto del pago no sea mayor al saldo pendiente
CREATE OR REPLACE TRIGGER trg_validar_monto_pago
BEFORE INSERT ON PAGO_ATENCION
FOR EACH ROW
DECLARE
    v_saldo_actual NUMBER;
BEGIN
    SELECT SALDO INTO v_saldo_actual FROM RESUMEN_PAGO WHERE ATE_ID = :NEW.ATE_ID;
    IF :NEW.MONTO_PAGO > v_saldo_actual THEN
        RAISE_APPLICATION_ERROR(-20002, 'El monto del pago no puede ser mayor al saldo pendiente');
    END IF;
END;
/
