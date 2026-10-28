-- =====================================================================
-- LABORATORIO No.4 - SOLUCION
-- TRANSACCIONES, CONCURRENCIA, MANEJO DE ERRORES,
-- FUNCIONES Y PROCEDIMIENTOS ALMACENADOS
-- Base de datos: BANCA_DIGITAL_C4H845
-- IF0010 Bases de Datos II - UCR
--
-- Requisito: ejecutar primero BANCA_DIGITAL.sql
-- Los ejercicios de la Parte 2 requieren dos sesiones de SSMS; vienen
-- comentados (/* ... */) para copiarlos en la sesion correspondiente.
-- =====================================================================

USE BANCA_DIGITAL_C4H845;
GO

-- =====================================================================
-- PARTE 1: TRANSACCIONES - COMMIT, ROLLBACK Y SAVE TRANSACTION
-- =====================================================================

-- ---------------------------------------------------------------------
-- Ejercicio 1: Transferencia manual con COMMIT y ROLLBACK
-- ---------------------------------------------------------------------
EXEC dbo.ReiniciarDatos;
GO

-- a. Transferir 50 000 de CR-001 a CR-003 con COMMIT
BEGIN TRANSACTION;

    UPDATE Cuentas SET Saldo = Saldo - 50000 WHERE NumeroCuenta = 'CR-001';
    UPDATE Cuentas SET Saldo = Saldo + 50000 WHERE NumeroCuenta = 'CR-003';

    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'TransfEnviada', 50000, Saldo, 'Transferencia a CR-003'
    FROM Cuentas WHERE NumeroCuenta = 'CR-001';

    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'TransfRecibida', 50000, Saldo, 'Transferencia desde CR-001'
    FROM Cuentas WHERE NumeroCuenta = 'CR-003';

    SELECT @@TRANCOUNT AS TranCountAntesDelCommit;   -- 1

COMMIT TRANSACTION;

SELECT @@TRANCOUNT AS TranCountDespuesDelCommit;     -- 0
SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta IN ('CR-001', 'CR-003');
-- CR-001 = 450000.00 / CR-003 = 130000.00
GO

-- b. Transferir 30 000 de CR-004 a CR-005, terminando con ROLLBACK
BEGIN TRANSACTION;

    UPDATE Cuentas SET Saldo = Saldo - 30000 WHERE NumeroCuenta = 'CR-004';
    UPDATE Cuentas SET Saldo = Saldo + 30000 WHERE NumeroCuenta = 'CR-005';

    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'TransfEnviada', 30000, Saldo, 'Transferencia a CR-005'
    FROM Cuentas WHERE NumeroCuenta = 'CR-004';

    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'TransfRecibida', 30000, Saldo, 'Transferencia desde CR-004'
    FROM Cuentas WHERE NumeroCuenta = 'CR-005';

    -- Antes del ROLLBACK: la transaccion ve sus propios cambios
    SELECT 'Antes del ROLLBACK' AS Momento, NumeroCuenta, Saldo
    FROM Cuentas WHERE NumeroCuenta IN ('CR-004', 'CR-005');
    -- CR-004 = 1170000.00 / CR-005 = 55000.00

ROLLBACK TRANSACTION;

SELECT 'Despues del ROLLBACK' AS Momento, NumeroCuenta, Saldo
FROM Cuentas WHERE NumeroCuenta IN ('CR-004', 'CR-005');
-- CR-004 = 1200000.00 / CR-005 = 25000.00
GO

-- ---------------------------------------------------------------------
-- Ejercicio 2: Un error a la mitad de la transaccion
-- ---------------------------------------------------------------------

-- a. XACT_ABORT OFF: el UPDATE que viola el CHECK falla, pero el COMMIT
--    confirma el credito. Se "crea" dinero.
EXEC dbo.ReiniciarDatos;
GO

SET XACT_ABORT OFF;
BEGIN TRANSACTION;
    UPDATE Cuentas SET Saldo = Saldo + 100000 WHERE NumeroCuenta = 'CR-003';  -- credito
    UPDATE Cuentas SET Saldo = Saldo - 100000 WHERE NumeroCuenta = 'CR-005';  -- debito (falla: 547)
COMMIT TRANSACTION;

SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta IN ('CR-003', 'CR-005');
-- CR-003 = 180000.00 / CR-005 = 25000.00  (inconsistente)
GO

-- b. XACT_ABORT ON: el error aborta el lote y revierte toda la transaccion.
EXEC dbo.ReiniciarDatos;
GO

SET XACT_ABORT ON;
BEGIN TRANSACTION;
    UPDATE Cuentas SET Saldo = Saldo + 100000 WHERE NumeroCuenta = 'CR-003';  -- credito
    UPDATE Cuentas SET Saldo = Saldo - 100000 WHERE NumeroCuenta = 'CR-005';  -- debito (falla: 547)
COMMIT TRANSACTION;

SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta IN ('CR-003', 'CR-005');
GO

-- Consulta en una ejecucion aparte (el lote anterior se aborto)
SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta IN ('CR-003', 'CR-005');
-- CR-003 = 80000.00 / CR-005 = 25000.00
SET XACT_ABORT OFF;
GO

-- c. Transferencia segura con TRY...CATCH (sin depender de XACT_ABORT)
EXEC dbo.ReiniciarDatos;
GO

SET XACT_ABORT OFF;
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE Cuentas SET Saldo = Saldo + 100000 WHERE NumeroCuenta = 'CR-003';  -- credito
        UPDATE Cuentas SET Saldo = Saldo - 100000 WHERE NumeroCuenta = 'CR-005';  -- debito
    COMMIT TRANSACTION;
    PRINT 'Transferencia completada.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT 'Transferencia revertida. Error ' + CAST(ERROR_NUMBER() AS VARCHAR(10))
        + ': ' + ERROR_MESSAGE();
END CATCH;

SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta IN ('CR-003', 'CR-005');
-- CR-003 = 80000.00 / CR-005 = 25000.00
GO

-- ---------------------------------------------------------------------
-- Ejercicio 3: Pago de servicios con SAVE TRANSACTION
-- ---------------------------------------------------------------------
EXEC dbo.ReiniciarDatos;
GO

BEGIN TRANSACTION;

    -- Luz
    SAVE TRANSACTION PagoLuz;
    UPDATE Cuentas SET Saldo = Saldo - 45000 WHERE NumeroCuenta = 'CR-002';
    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'Retiro', 45000, Saldo, 'Pago de luz'
    FROM Cuentas WHERE NumeroCuenta = 'CR-002';

    IF (SELECT Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-002') < 10000
    BEGIN
        ROLLBACK TRANSACTION PagoLuz;
        PRINT 'Pago de luz rechazado: no se cumple el saldo minimo.';
    END;

    -- Agua
    SAVE TRANSACTION PagoAgua;
    UPDATE Cuentas SET Saldo = Saldo - 30000 WHERE NumeroCuenta = 'CR-002';
    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'Retiro', 30000, Saldo, 'Pago de agua'
    FROM Cuentas WHERE NumeroCuenta = 'CR-002';

    IF (SELECT Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-002') < 10000
    BEGIN
        ROLLBACK TRANSACTION PagoAgua;
        PRINT 'Pago de agua rechazado: no se cumple el saldo minimo.';
    END;

    -- Internet
    SAVE TRANSACTION PagoInternet;
    UPDATE Cuentas SET Saldo = Saldo - 70000 WHERE NumeroCuenta = 'CR-002';
    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'Retiro', 70000, Saldo, 'Pago de internet'
    FROM Cuentas WHERE NumeroCuenta = 'CR-002';

    IF (SELECT Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-002') < 10000
    BEGIN
        ROLLBACK TRANSACTION PagoInternet;
        PRINT 'Pago de internet rechazado: no se cumple el saldo minimo.';
        SELECT @@TRANCOUNT AS TranCountTrasRollbackPagoInternet;   -- 1
    END;

COMMIT TRANSACTION;

SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-002';   -- 75000.00
SELECT TipoMovimiento, Monto, SaldoResultante, Descripcion
FROM Movimientos
WHERE CuentaID = 2 AND Descripcion LIKE 'Pago de %';                       -- luz y agua
GO

-- =====================================================================
-- PARTE 2: CONCURRENCIA Y NIVELES DE AISLAMIENTO (dos sesiones)
-- Ejecute EXEC dbo.ReiniciarDatos; antes de cada ejercicio.
-- =====================================================================

/* ---------------------------------------------------------------------
   Ejercicio 4: Lectura sucia en la aprobacion de un credito
   ---------------------------------------------------------------------

-- (1) SESION A (cajero)
BEGIN TRANSACTION;
UPDATE Cuentas SET Saldo = Saldo + 1000000 WHERE NumeroCuenta = 'CR-005';
-- No ejecute COMMIT todavia

-- (2) SESION B (analista)
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-005';
-- Ve 1025000.00 (dato no confirmado)

-- (3) SESION A
ROLLBACK TRANSACTION;

-- (4) SESION B
SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-005';
-- Ve 25000.00

-- Repeticion con READ COMMITTED en la Sesion B:
-- (2) SESION B
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-005';
-- Queda en espera (bloqueada por el lock X de la Sesion A) hasta el
-- ROLLBACK del paso (3); luego devuelve 25000.00
*/

/* ---------------------------------------------------------------------
   Ejercicio 5: Lectura no repetible y lectura fantasma
   ---------------------------------------------------------------------

-- (1) SESION A (auditor)
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;   -- luego repetir con SERIALIZABLE
BEGIN TRANSACTION;
SELECT Saldo FROM Cuentas WHERE CuentaID = 4;
SELECT COUNT(*) AS CantidadMovimientos FROM Movimientos WHERE CuentaID = 4;

-- (2) SESION B: primero el INSERT y observe; luego el UPDATE
INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
VALUES (4, 'Deposito', 5000, 1205000, 'Deposito concurrente');
-- REPEATABLE READ: se ejecuta de inmediato (fantasma)
-- SERIALIZABLE   : queda en espera (bloqueo de rango)

UPDATE Cuentas SET Saldo = Saldo + 5000 WHERE CuentaID = 4;
-- En ambos niveles queda en espera (lock S retenido sobre la fila)

-- (3) SESION A
SELECT Saldo FROM Cuentas WHERE CuentaID = 4;
SELECT COUNT(*) AS CantidadMovimientos FROM Movimientos WHERE CuentaID = 4;
COMMIT TRANSACTION;
-- REPEATABLE READ: saldo igual (1200000), cantidad de 1 a 2 (fantasma)
-- SERIALIZABLE   : saldo igual y cantidad igual (1)
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;   -- restaurar nivel por defecto
*/

/* ---------------------------------------------------------------------
   Ejercicio 6: Actualizacion perdida entre dos cajeros
   ---------------------------------------------------------------------

-- a. Ejecutar en SESION A y, antes de 10 s, en SESION B
DECLARE @Saldo DECIMAL(14,2);
BEGIN TRANSACTION;
    SELECT @Saldo = Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-003';
    WAITFOR DELAY '00:00:10';
    UPDATE Cuentas SET Saldo = @Saldo - 30000 WHERE NumeroCuenta = 'CR-003';
COMMIT TRANSACTION;
SELECT Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-003';
-- Saldo final: 50000.00 (se perdio uno de los retiros)

-- b. Reiniciar datos y ejecutar en ambas sesiones con UPDLOCK
DECLARE @Saldo DECIMAL(14,2);
BEGIN TRANSACTION;
    SELECT @Saldo = Saldo FROM Cuentas WITH (UPDLOCK) WHERE NumeroCuenta = 'CR-003';
    WAITFOR DELAY '00:00:10';
    UPDATE Cuentas SET Saldo = @Saldo - 30000 WHERE NumeroCuenta = 'CR-003';
COMMIT TRANSACTION;
SELECT Saldo FROM Cuentas WHERE NumeroCuenta = 'CR-003';
-- Saldo final: 20000.00 (la Sesion B espera a que A confirme)

-- Pregunta 11: alternativa sin variable intermedia (lectura y escritura atomicas)
UPDATE Cuentas SET Saldo = Saldo - 30000 WHERE NumeroCuenta = 'CR-003';
*/

/* ---------------------------------------------------------------------
   Ejercicio 7: Interbloqueo entre transferencias opuestas
   ---------------------------------------------------------------------

-- a. (1) SESION A
BEGIN TRANSACTION;
    UPDATE Cuentas SET Saldo = Saldo - 10000 WHERE NumeroCuenta = 'CR-001';
    WAITFOR DELAY '00:00:10';
    UPDATE Cuentas SET Saldo = Saldo + 10000 WHERE NumeroCuenta = 'CR-004';
COMMIT TRANSACTION;

-- a. (2) SESION B (antes de 10 s)
BEGIN TRANSACTION;
    UPDATE Cuentas SET Saldo = Saldo - 20000 WHERE NumeroCuenta = 'CR-004';
    WAITFOR DELAY '00:00:10';
    UPDATE Cuentas SET Saldo = Saldo + 20000 WHERE NumeroCuenta = 'CR-001';
COMMIT TRANSACTION;
-- Una sesion recibe el error 1205 (victima del interbloqueo) y su
-- transaccion se revierte; la otra confirma.

-- b. Mismo orden en ambas: primero la de menor CuentaID (CR-001 = 1, CR-004 = 4)
-- SESION A
BEGIN TRANSACTION;
    UPDATE Cuentas SET Saldo = Saldo - 10000 WHERE NumeroCuenta = 'CR-001';
    WAITFOR DELAY '00:00:10';
    UPDATE Cuentas SET Saldo = Saldo + 10000 WHERE NumeroCuenta = 'CR-004';
COMMIT TRANSACTION;

-- SESION B
BEGIN TRANSACTION;
    UPDATE Cuentas SET Saldo = Saldo + 20000 WHERE NumeroCuenta = 'CR-001';
    WAITFOR DELAY '00:00:10';
    UPDATE Cuentas SET Saldo = Saldo - 20000 WHERE NumeroCuenta = 'CR-004';
COMMIT TRANSACTION;
-- B espera a A y luego termina. Saldos finales: CR-001 = 510000, CR-004 = 1190000
*/

-- =====================================================================
-- PARTE 3: MANEJO DE ERRORES CON TRY...CATCH
-- =====================================================================

-- ---------------------------------------------------------------------
-- Ejercicio 8: Bitacora de errores
-- ---------------------------------------------------------------------
EXEC dbo.ReiniciarDatos;
GO

-- a. Movimiento con monto negativo (CHECK Monto > 0 -> error 547)
BEGIN TRY
    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    VALUES (1, 'Deposito', -5000, 495000, 'Monto negativo');
END TRY
BEGIN CATCH
    INSERT INTO LogErrores (Procedimiento, NumeroError, Mensaje, Linea)
    VALUES ('Ejercicio 8', ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE());
END CATCH;

-- b. Cuenta con NumeroCuenta duplicado (UNIQUE -> error 2627)
BEGIN TRY
    INSERT INTO Cuentas (NumeroCuenta, ClienteID, TipoCuenta, Moneda, Saldo, LimiteRetiroDiario)
    VALUES ('CR-001', 2, 'Ahorro', 'CRC', 0, 100000);
END TRY
BEGIN CATCH
    INSERT INTO LogErrores (Procedimiento, NumeroError, Mensaje, Linea)
    VALUES ('Ejercicio 8', ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE());
END CATCH;

-- c. Deposito en CR-007 validando el estado (THROW 50001)
BEGIN TRY
    IF (SELECT Estado FROM Cuentas WHERE NumeroCuenta = 'CR-007') <> 'Activa'
        THROW 50001, 'La cuenta CR-007 no está activa.', 1;

    UPDATE Cuentas SET Saldo = Saldo + 10000 WHERE NumeroCuenta = 'CR-007';
    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
    SELECT CuentaID, 'Deposito', 10000, Saldo, 'Deposito en ventanilla'
    FROM Cuentas WHERE NumeroCuenta = 'CR-007';
END TRY
BEGIN CATCH
    INSERT INTO LogErrores (Procedimiento, NumeroError, Mensaje, Linea)
    VALUES ('Ejercicio 8', ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE());
END CATCH;

SELECT * FROM LogErrores;   -- 547, 2627, 50001
GO

-- ---------------------------------------------------------------------
-- Ejercicio 9: XACT_STATE() y XACT_ABORT
-- ---------------------------------------------------------------------

-- Con XACT_ABORT OFF -> XACT_STATE = 1, el movimiento se conserva
EXEC dbo.ReiniciarDatos;
GO

SET XACT_ABORT OFF;
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
        VALUES (1, 'Deposito', 1000, 501000, 'Movimiento de prueba');
        UPDATE Cuentas SET Saldo = Saldo / 0 WHERE CuentaID = 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    PRINT 'XACT_STATE = ' + CAST(XACT_STATE() AS VARCHAR);
    IF XACT_STATE() = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Se conservo el trabajo previo al error.';
    END
    ELSE IF XACT_STATE() = -1
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'La transaccion estaba condenada y se revirtio.';
    END;
END CATCH;

SELECT * FROM Movimientos WHERE Descripcion = 'Movimiento de prueba';   -- 1 fila
GO

-- Con XACT_ABORT ON -> XACT_STATE = -1, el movimiento se revierte
EXEC dbo.ReiniciarDatos;
GO

SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
        VALUES (1, 'Deposito', 1000, 501000, 'Movimiento de prueba');
        UPDATE Cuentas SET Saldo = Saldo / 0 WHERE CuentaID = 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    PRINT 'XACT_STATE = ' + CAST(XACT_STATE() AS VARCHAR);
    IF XACT_STATE() = 1
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'Se conservo el trabajo previo al error.';
    END
    ELSE IF XACT_STATE() = -1
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT 'La transaccion estaba condenada y se revirtio.';
    END;
END CATCH;

SELECT * FROM Movimientos WHERE Descripcion = 'Movimiento de prueba';   -- 0 filas
SET XACT_ABORT OFF;
GO

-- =====================================================================
-- PARTE 4: FUNCIONES ESCALARES Y DE TABLA
-- =====================================================================

-- ---------------------------------------------------------------------
-- Ejercicio 10: Funcion escalar dbo.CalcularComision
-- ---------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.CalcularComision
(
    @Monto     DECIMAL(14,2),
    @Categoria VARCHAR(20)
)
RETURNS DECIMAL(14,2)
AS
BEGIN
    DECLARE @Comision DECIMAL(14,2);

    IF @Monto IS NULL OR @Monto <= 0
        RETURN 0;

    SET @Comision =
        CASE @Categoria
            WHEN 'Estandar' THEN
                CASE WHEN @Monto * 0.01 < 500 THEN 500 ELSE @Monto * 0.01 END
            WHEN 'Oro'      THEN @Monto * 0.005
            WHEN 'Platino'  THEN 0
            ELSE 0
        END;

    RETURN @Comision;
END;
GO

SELECT dbo.CalcularComision(100000, 'Estandar') AS Caso1,   -- 1000.00
       dbo.CalcularComision(20000,  'Estandar') AS Caso2,   -- 500.00 (aplica el minimo)
       dbo.CalcularComision(100000, 'Oro')      AS Caso3,   -- 500.00
       dbo.CalcularComision(100000, 'Platino')  AS Caso4,   -- 0.00
       dbo.CalcularComision(-50,    'Oro')      AS Caso5;   -- 0.00
GO

-- ---------------------------------------------------------------------
-- Ejercicio 11: Funcion de tabla dbo.EstadoCuenta
-- Fecha es DATETIME: se usa "< @Hasta + 1 dia" para incluir todo el
-- ultimo dia (Fecha <= '2026-09-10' excluiria el 10/09 a las 14:30).
-- ---------------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.EstadoCuenta
(
    @NumeroCuenta VARCHAR(20),
    @Desde        DATE,
    @Hasta        DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT m.Fecha, m.TipoMovimiento, m.Monto, m.SaldoResultante, m.Descripcion
    FROM Movimientos m
    INNER JOIN Cuentas c ON c.CuentaID = m.CuentaID
    WHERE c.NumeroCuenta = @NumeroCuenta
      AND m.Fecha >= @Desde
      AND m.Fecha <  DATEADD(DAY, 1, CAST(@Hasta AS DATETIME))
);
GO

EXEC dbo.ReiniciarDatos;
GO

SELECT * FROM dbo.EstadoCuenta('CR-003', '2026-09-01', '2026-09-30') ORDER BY Fecha;  -- 2 filas
SELECT * FROM dbo.EstadoCuenta('CR-003', '2026-09-10', '2026-09-10');                 -- 1 fila
GO

-- =====================================================================
-- PARTE 5: PROCEDIMIENTOS ALMACENADOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- Ejercicio 12: Procedimiento dbo.Depositar
-- Errores: 50010 monto invalido, 50011 cuenta inexistente,
--          50012 cuenta no activa
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.Depositar
    @NumeroCuenta VARCHAR(20),
    @Monto        DECIMAL(14,2),
    @NuevoSaldo   DECIMAL(14,2) OUTPUT,
    @Resultado    VARCHAR(200)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CuentaID INT,
            @Estado   VARCHAR(20);

    SET @NuevoSaldo = NULL;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Monto IS NULL OR @Monto <= 0
            THROW 50010, 'El monto del deposito debe ser mayor a cero.', 1;

        SELECT @CuentaID = CuentaID, @Estado = Estado
        FROM Cuentas WITH (UPDLOCK, HOLDLOCK)
        WHERE NumeroCuenta = @NumeroCuenta;

        IF @CuentaID IS NULL
            THROW 50011, 'La cuenta no existe.', 1;

        IF @Estado <> 'Activa'
            THROW 50012, 'La cuenta no esta activa.', 1;

        UPDATE Cuentas
        SET Saldo = Saldo + @Monto
        WHERE CuentaID = @CuentaID;

        SELECT @NuevoSaldo = Saldo FROM Cuentas WHERE CuentaID = @CuentaID;

        INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
        VALUES (@CuentaID, 'Deposito', @Monto, @NuevoSaldo, 'Deposito');

        COMMIT TRANSACTION;

        SET @Resultado = 'Deposito exitoso. Nuevo saldo: ' + CAST(@NuevoSaldo AS VARCHAR(20));
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @NuevoSaldo = NULL;
        SET @Resultado  = LEFT('Error: ' + ERROR_MESSAGE(), 200);

        INSERT INTO LogErrores (Procedimiento, NumeroError, Mensaje, Linea)
        VALUES ('dbo.Depositar', ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE());
    END CATCH;
END;
GO

EXEC dbo.ReiniciarDatos;
GO

DECLARE @Saldo DECIMAL(14,2), @Msg VARCHAR(200);
EXEC dbo.Depositar 'CR-005', 25000, @Saldo OUTPUT, @Msg OUTPUT;  PRINT @Msg;  -- nuevo saldo 50000
EXEC dbo.Depositar 'CR-005', -100,  @Saldo OUTPUT, @Msg OUTPUT;  PRINT @Msg;  -- monto invalido
EXEC dbo.Depositar 'CR-007', 5000,  @Saldo OUTPUT, @Msg OUTPUT;  PRINT @Msg;  -- cuenta congelada
EXEC dbo.Depositar 'CR-999', 5000,  @Saldo OUTPUT, @Msg OUTPUT;  PRINT @Msg;  -- cuenta inexistente
SELECT * FROM LogErrores;
GO

-- ---------------------------------------------------------------------
-- Ejercicio 13: Procedimiento dbo.Retirar con limite diario
-- Errores: 50020 monto invalido, 50021 cuenta inexistente,
--          50022 cuenta no activa, 50023 saldo insuficiente,
--          50024 limite diario excedido
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.Retirar
    @NumeroCuenta VARCHAR(20),
    @Monto        DECIMAL(14,2),
    @Resultado    VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CuentaID      INT,
            @Estado        VARCHAR(20),
            @Saldo         DECIMAL(14,2),
            @Limite        DECIMAL(14,2),
            @RetiradoHoy   DECIMAL(14,2),
            @NuevoSaldo    DECIMAL(14,2);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Monto IS NULL OR @Monto <= 0
            THROW 50020, 'El monto del retiro debe ser mayor a cero.', 1;

        -- Bloqueo de la cuenta: dos retiros simultaneos no leen el mismo saldo
        SELECT @CuentaID = CuentaID,
               @Estado   = Estado,
               @Saldo    = Saldo,
               @Limite   = LimiteRetiroDiario
        FROM Cuentas WITH (UPDLOCK, HOLDLOCK)
        WHERE NumeroCuenta = @NumeroCuenta;

        -- Prueba de concurrencia (opcional): descomentar temporalmente
        -- WAITFOR DELAY '00:00:10';

        IF @CuentaID IS NULL
            THROW 50021, 'La cuenta no existe.', 1;

        IF @Estado <> 'Activa'
            THROW 50022, 'La cuenta no esta activa.', 1;

        IF @Saldo < @Monto
            THROW 50023, 'Saldo insuficiente.', 1;

        SELECT @RetiradoHoy = ISNULL(SUM(Monto), 0)
        FROM Movimientos
        WHERE CuentaID = @CuentaID
          AND TipoMovimiento = 'Retiro'
          AND Fecha >= CAST(GETDATE() AS DATE)
          AND Fecha <  DATEADD(DAY, 1, CAST(CAST(GETDATE() AS DATE) AS DATETIME));

        IF @RetiradoHoy + @Monto > @Limite
            THROW 50024, 'El retiro excede el limite diario de la cuenta.', 1;

        SET @NuevoSaldo = @Saldo - @Monto;

        UPDATE Cuentas
        SET Saldo = @NuevoSaldo
        WHERE CuentaID = @CuentaID;

        INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
        VALUES (@CuentaID, 'Retiro', @Monto, @NuevoSaldo, 'Retiro');

        COMMIT TRANSACTION;

        SET @Resultado = 'Retiro exitoso. Nuevo saldo: ' + CAST(@NuevoSaldo AS VARCHAR(20));
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @Resultado = LEFT('Error: ' + ERROR_MESSAGE(), 200);

        INSERT INTO LogErrores (Procedimiento, NumeroError, Mensaje, Linea)
        VALUES ('dbo.Retirar', ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_LINE());
    END CATCH;
END;
GO

EXEC dbo.ReiniciarDatos;
GO

DECLARE @Msg VARCHAR(200);
EXEC dbo.Retirar 'CR-003', 60000,  @Msg OUTPUT;  PRINT @Msg;  -- exitoso (queda 20000)
EXEC dbo.Retirar 'CR-003', 30000,  @Msg OUTPUT;  PRINT @Msg;  -- saldo insuficiente
EXEC dbo.Retirar 'CR-004', 300000, @Msg OUTPUT;  PRINT @Msg;  -- exitoso
EXEC dbo.Retirar 'CR-004', 250000, @Msg OUTPUT;  PRINT @Msg;  -- excede el limite diario (500000)
SELECT * FROM LogErrores;
GO

/* Prueba de concurrencia (opcional, 2 sesiones):
   1. Descomentar el WAITFOR DELAY dentro de dbo.Retirar y recrearlo.
   2. EXEC dbo.ReiniciarDatos;
   3. Ejecutar casi al mismo tiempo en la Sesion A y en la Sesion B:
        DECLARE @Msg VARCHAR(200);
        EXEC dbo.Retirar 'CR-003', 50000, @Msg OUTPUT; PRINT @Msg;
      Solo uno se aprueba; el otro obtiene "Saldo insuficiente" (80000 - 50000 = 30000).
   4. Volver a comentar el WAITFOR y recrear el procedimiento.
*/

-- ---------------------------------------------------------------------
-- Ejercicio 14: Procedimiento dbo.Transferir
-- Errores: 50030 misma cuenta, 50031 monto invalido,
--          50032 cuenta origen inexistente, 50033 cuenta destino inexistente,
--          50034 cuenta origen no activa, 50035 cuenta destino no activa,
--          50036 monedas distintas, 50037 saldo insuficiente
-- ---------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.Transferir
    @CuentaOrigen  VARCHAR(20),
    @CuentaDestino VARCHAR(20),
    @Monto         DECIMAL(14,2),
    @Resultado     VARCHAR(200) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrigenID       INT,
            @DestinoID      INT,
            @EstadoOrigen   VARCHAR(20),
            @EstadoDestino  VARCHAR(20),
            @MonedaOrigen   CHAR(3),
            @MonedaDestino  CHAR(3),
            @Categoria      VARCHAR(20),
            @Comision       DECIMAL(14,2) = 0,
            @SaldoOrigen    DECIMAL(14,2),
            @SaldoDestino   DECIMAL(14,2),
            @PrimerID       INT,
            @SegundoID      INT,
            @Mensaje        VARCHAR(4000);

    -- Se resuelven fuera de la transaccion para poder registrar la
    -- transferencia rechazada en el CATCH
    SELECT @OrigenID = CuentaID FROM Cuentas WHERE NumeroCuenta = @CuentaOrigen;
    SELECT @DestinoID = CuentaID FROM Cuentas WHERE NumeroCuenta = @CuentaDestino;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cuentas distintas y monto valido
        IF @CuentaOrigen = @CuentaDestino
            THROW 50030, 'La cuenta de origen y la de destino deben ser distintas.', 1;

        IF @Monto IS NULL OR @Monto <= 0
            THROW 50031, 'El monto de la transferencia debe ser mayor a cero.', 1;

        -- 2. Existencia, estado y moneda
        IF @OrigenID IS NULL
            THROW 50032, 'La cuenta de origen no existe.', 1;

        IF @DestinoID IS NULL
            THROW 50033, 'La cuenta de destino no existe.', 1;

        SELECT @EstadoOrigen = c.Estado, @MonedaOrigen = c.Moneda, @Categoria = cl.Categoria
        FROM Cuentas c
        INNER JOIN Clientes cl ON cl.ClienteID = c.ClienteID
        WHERE c.CuentaID = @OrigenID;

        SELECT @EstadoDestino = Estado, @MonedaDestino = Moneda
        FROM Cuentas
        WHERE CuentaID = @DestinoID;

        IF @EstadoOrigen <> 'Activa'
            THROW 50034, 'La cuenta de origen no esta activa.', 1;

        IF @EstadoDestino <> 'Activa'
            THROW 50035, 'La cuenta de destino no esta activa.', 1;

        IF @MonedaOrigen <> @MonedaDestino
            THROW 50036, 'Las cuentas tienen monedas distintas.', 1;

        -- 3. Comision segun la categoria del cliente de origen
        SET @Comision = dbo.CalcularComision(@Monto, @Categoria);

        -- 4. Bloqueo de ambas cuentas en orden ascendente de CuentaID
        SET @PrimerID  = CASE WHEN @OrigenID < @DestinoID THEN @OrigenID  ELSE @DestinoID END;
        SET @SegundoID = CASE WHEN @OrigenID < @DestinoID THEN @DestinoID ELSE @OrigenID  END;

        SELECT @SaldoOrigen = CASE WHEN CuentaID = @OrigenID THEN Saldo ELSE @SaldoOrigen END
        FROM Cuentas WITH (UPDLOCK, HOLDLOCK)
        WHERE CuentaID = @PrimerID;

        SELECT @SaldoOrigen = CASE WHEN CuentaID = @OrigenID THEN Saldo ELSE @SaldoOrigen END
        FROM Cuentas WITH (UPDLOCK, HOLDLOCK)
        WHERE CuentaID = @SegundoID;

        -- 5. El saldo de origen debe cubrir monto + comision
        IF @SaldoOrigen < @Monto + @Comision
            THROW 50037, 'Saldo insuficiente para cubrir el monto y la comision.', 1;

        -- 6. Actualizar saldos y registrar movimientos y transferencia
        UPDATE Cuentas SET Saldo = Saldo - (@Monto + @Comision) WHERE CuentaID = @OrigenID;
        UPDATE Cuentas SET Saldo = Saldo + @Monto               WHERE CuentaID = @DestinoID;

        SELECT @SaldoDestino = Saldo FROM Cuentas WHERE CuentaID = @DestinoID;

        INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
        VALUES (@OrigenID, 'TransfEnviada', @Monto, @SaldoOrigen - @Monto,
                'Transferencia a ' + @CuentaDestino);

        INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
        VALUES (@DestinoID, 'TransfRecibida', @Monto, @SaldoDestino,
                'Transferencia desde ' + @CuentaOrigen);

        IF @Comision > 0
            INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
            VALUES (@OrigenID, 'Comision', @Comision, @SaldoOrigen - @Monto - @Comision,
                    'Comision por transferencia a ' + @CuentaDestino);

        INSERT INTO Transferencias (CuentaOrigenID, CuentaDestinoID, Monto, Comision, Estado, Detalle)
        VALUES (@OrigenID, @DestinoID, @Monto, @Comision, 'Completada', 'Transferencia exitosa');

        COMMIT TRANSACTION;

        SET @Resultado = 'Transferencia completada. Comision: ' + CAST(@Comision AS VARCHAR(20));
    END TRY
    BEGIN CATCH
        SET @Mensaje = ERROR_MESSAGE();

        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        -- 7. Se registra despues del ROLLBACK para que no se revierta
        IF @OrigenID IS NOT NULL AND @DestinoID IS NOT NULL
            INSERT INTO Transferencias (CuentaOrigenID, CuentaDestinoID, Monto, Comision, Estado, Detalle)
            VALUES (@OrigenID, @DestinoID, @Monto, ISNULL(@Comision, 0), 'Rechazada', LEFT(@Mensaje, 500));

        INSERT INTO LogErrores (Procedimiento, NumeroError, Mensaje, Linea)
        VALUES ('dbo.Transferir', ERROR_NUMBER(), @Mensaje, ERROR_LINE());

        SET @Resultado = LEFT('Error: ' + @Mensaje, 200);
    END CATCH;
END;
GO

EXEC dbo.ReiniciarDatos;
GO

DECLARE @Msg VARCHAR(200);
EXEC dbo.Transferir 'CR-001', 'CR-003', 100000, @Msg OUTPUT; PRINT @Msg;  -- completada
EXEC dbo.Transferir 'CR-005', 'CR-003', 50000,  @Msg OUTPUT; PRINT @Msg;  -- saldo insuficiente
EXEC dbo.Transferir 'CR-001', 'CR-006', 10000,  @Msg OUTPUT; PRINT @Msg;  -- monedas distintas
EXEC dbo.Transferir 'CR-001', 'CR-007', 10000,  @Msg OUTPUT; PRINT @Msg;  -- destino congelado
EXEC dbo.Transferir 'CR-001', 'CR-001', 10000,  @Msg OUTPUT; PRINT @Msg;  -- misma cuenta

SELECT * FROM Transferencias;
SELECT NumeroCuenta, Saldo FROM Cuentas WHERE NumeroCuenta IN ('CR-001', 'CR-003');
-- CR-001 = 399500.00 / CR-003 = 180000.00
SELECT * FROM Movimientos WHERE Fecha >= CAST(GETDATE() AS DATE);   -- 3 movimientos
SELECT * FROM LogErrores;
GO
