-- =====================================================================
-- LABORATORIO: TRANSACCIONES, CONCURRENCIA, MANEJO DE ERRORES,
--              FUNCIONES Y PROCEDIMIENTOS ALMACENADOS
-- Base de datos: BANCA_DIGITAL_C4H845
-- IF0010 Bases de Datos II - UCR
-- =====================================================================

USE master;
GO

IF DB_ID('BANCA_DIGITAL_C4H845') IS NOT NULL
BEGIN
    ALTER DATABASE BANCA_DIGITAL_C4H845 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BANCA_DIGITAL_C4H845;
END;
GO

CREATE DATABASE BANCA_DIGITAL_C4H845;
GO

USE BANCA_DIGITAL_C4H845;
GO

-- =====================================================================
-- TABLAS
-- =====================================================================

CREATE TABLE Clientes (
    ClienteID  INT IDENTITY(1,1) PRIMARY KEY,
    Cedula     VARCHAR(20)  NOT NULL UNIQUE,
    Nombre     VARCHAR(100) NOT NULL,
    Email      VARCHAR(100) NOT NULL,
    Categoria  VARCHAR(20)  NOT NULL DEFAULT 'Estandar'
        CHECK (Categoria IN ('Estandar', 'Oro', 'Platino')),
    Activo     BIT NOT NULL DEFAULT 1
);
GO

CREATE TABLE Cuentas (
    CuentaID           INT IDENTITY(1,1) PRIMARY KEY,
    NumeroCuenta       VARCHAR(20)   NOT NULL UNIQUE,
    ClienteID          INT           NOT NULL FOREIGN KEY REFERENCES Clientes(ClienteID),
    TipoCuenta         VARCHAR(20)   NOT NULL CHECK (TipoCuenta IN ('Ahorro', 'Corriente')),
    Moneda             CHAR(3)       NOT NULL CHECK (Moneda IN ('CRC', 'USD')),
    Saldo              DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (Saldo >= 0),
    LimiteRetiroDiario DECIMAL(14,2) NOT NULL,
    Estado             VARCHAR(20)   NOT NULL DEFAULT 'Activa'
        CHECK (Estado IN ('Activa', 'Congelada', 'Cerrada')),
    FechaApertura      DATE          NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE Movimientos (
    MovimientoID    INT IDENTITY(1,1) PRIMARY KEY,
    CuentaID        INT           NOT NULL FOREIGN KEY REFERENCES Cuentas(CuentaID),
    TipoMovimiento  VARCHAR(20)   NOT NULL
        CHECK (TipoMovimiento IN ('Deposito', 'Retiro', 'TransfEnviada',
                                  'TransfRecibida', 'Comision')),
    Monto           DECIMAL(14,2) NOT NULL CHECK (Monto > 0),
    SaldoResultante DECIMAL(14,2) NOT NULL,
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    Descripcion     VARCHAR(200)  NULL
);
GO

CREATE TABLE Transferencias (
    TransferenciaID INT IDENTITY(1,1) PRIMARY KEY,
    CuentaOrigenID  INT           NOT NULL FOREIGN KEY REFERENCES Cuentas(CuentaID),
    CuentaDestinoID INT           NOT NULL FOREIGN KEY REFERENCES Cuentas(CuentaID),
    Monto           DECIMAL(14,2) NOT NULL,
    Comision        DECIMAL(14,2) NOT NULL DEFAULT 0,
    Estado          VARCHAR(20)   NOT NULL CHECK (Estado IN ('Completada', 'Rechazada')),
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    Detalle         VARCHAR(500)  NULL
);
GO

CREATE TABLE LogErrores (
    LogID         INT IDENTITY(1,1) PRIMARY KEY,
    Procedimiento VARCHAR(100)  NOT NULL,
    NumeroError   INT           NOT NULL,
    Mensaje       VARCHAR(4000) NOT NULL,
    Linea         INT           NULL,
    Usuario       VARCHAR(100)  NOT NULL DEFAULT SUSER_SNAME(),
    Fecha         DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- =====================================================================
-- PROCEDIMIENTO DE APOYO: reinicia los datos de prueba a su estado
-- original, SIN borrar las funciones ni los procedimientos creados.
-- Uso:  EXEC dbo.ReiniciarDatos;
-- =====================================================================

CREATE PROCEDURE dbo.ReiniciarDatos
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM Transferencias;
    DELETE FROM Movimientos;
    DELETE FROM LogErrores;
    DELETE FROM Cuentas;
    DELETE FROM Clientes;

    SET IDENTITY_INSERT Clientes ON;
    INSERT INTO Clientes (ClienteID, Cedula, Nombre, Email, Categoria) VALUES
    (1, '1-1111-1111', 'Ana Vargas',      'ana.vargas@correo.com',      'Oro'),
    (2, '2-2222-2222', 'Luis Mora',       'luis.mora@correo.com',       'Estandar'),
    (3, '3-3333-3333', 'Sofia Rojas',     'sofia.rojas@correo.com',     'Platino'),
    (4, '4-4444-4444', 'Carlos Jimenez',  'carlos.jimenez@correo.com',  'Estandar'),
    (5, '5-5555-5555', 'Maria Fernandez', 'maria.fernandez@correo.com', 'Oro'),
    (6, '6-6666-6666', 'Diego Solano',    'diego.solano@correo.com',    'Estandar');
    SET IDENTITY_INSERT Clientes OFF;

    SET IDENTITY_INSERT Cuentas ON;
    INSERT INTO Cuentas (CuentaID, NumeroCuenta, ClienteID, TipoCuenta, Moneda,
                         Saldo, LimiteRetiroDiario, Estado, FechaApertura) VALUES
    (1, 'CR-001', 1, 'Ahorro',    'CRC',  500000.00, 300000.00, 'Activa',    '2026-09-01'),
    (2, 'CR-002', 1, 'Corriente', 'CRC',  150000.00, 200000.00, 'Activa',    '2026-09-02'),
    (3, 'CR-003', 2, 'Ahorro',    'CRC',   80000.00, 100000.00, 'Activa',    '2026-09-03'),
    (4, 'CR-004', 3, 'Ahorro',    'CRC', 1200000.00, 500000.00, 'Activa',    '2026-09-05'),
    (5, 'CR-005', 4, 'Ahorro',    'CRC',   25000.00, 100000.00, 'Activa',    '2026-09-06'),
    (6, 'CR-006', 5, 'Ahorro',    'USD',    3000.00,   1000.00, 'Activa',    '2026-09-07'),
    (7, 'CR-007', 6, 'Ahorro',    'CRC',   60000.00, 100000.00, 'Congelada', '2026-09-08'),
    (8, 'CR-008', 2, 'Corriente', 'CRC',       0.00, 100000.00, 'Cerrada',   '2026-09-04');
    SET IDENTITY_INSERT Cuentas OFF;

    -- Formato ISO con 'T' para evitar ambigüedades de fecha en servidores en español
    INSERT INTO Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante,
                             Fecha, Descripcion) VALUES
    (1, 'Deposito',  500000.00,  500000.00, '2026-09-01T09:00:00', 'Deposito de apertura'),
    (2, 'Deposito',  150000.00,  150000.00, '2026-09-02T10:15:00', 'Deposito de apertura'),
    (3, 'Deposito',  100000.00,  100000.00, '2026-09-03T08:30:00', 'Deposito de apertura'),
    (3, 'Retiro',     20000.00,   80000.00, '2026-09-10T14:30:00', 'Retiro en cajero'),
    (4, 'Deposito', 1200000.00, 1200000.00, '2026-09-05T11:00:00', 'Deposito de apertura'),
    (5, 'Deposito',   25000.00,   25000.00, '2026-09-06T16:45:00', 'Deposito de apertura'),
    (6, 'Deposito',    3000.00,    3000.00, '2026-09-07T09:20:00', 'Deposito de apertura'),
    (7, 'Deposito',   60000.00,   60000.00, '2026-09-08T13:10:00', 'Deposito de apertura');
END;
GO

EXEC dbo.ReiniciarDatos;
GO

-- Verificación rápida
SELECT c.NumeroCuenta, cl.Nombre, cl.Categoria, c.TipoCuenta, c.Moneda,
       c.Saldo, c.LimiteRetiroDiario, c.Estado
FROM Cuentas c
INNER JOIN Clientes cl ON cl.ClienteID = c.ClienteID
ORDER BY c.CuentaID;
GO
