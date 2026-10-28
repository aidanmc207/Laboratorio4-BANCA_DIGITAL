-- =====================================================================
-- LABORATORIO No.5 - SOLUCION
-- SEGURIDAD: LOGINS, USUARIOS, ROLES Y PERMISOS (GRANT, REVOKE Y DENY)
-- Base de datos: BANCA_DIGITAL
-- IF0010 Bases de Datos II - UCR
--
-- Requisitos (en este orden):
--   1. BANCA_DIGITAL.sql
--   2. BANCA_DIGITAL_NUEVOS_OBJETOS.sql
--
-- Las pruebas usan suplantacion: EXECUTE AS USER = '...' ... REVERT.
-- Los errores de permisos que aparecen en las pruebas son ESPERADOS y
-- sirven como evidencia (229 = permiso denegado sobre el objeto,
-- 230 = permiso denegado sobre la columna, 262 = permiso denegado en la BD).
-- =====================================================================

-- =====================================================================
-- LIMPIEZA: permite ejecutar el script varias veces
-- =====================================================================
USE BANCA_DIGITAL;
GO

DROP VIEW  IF EXISTS AuditoriaLocal.vw_SaldosPorMoneda;
DROP TABLE IF EXISTS AuditoriaLocal.Hallazgos;
DROP VIEW  IF EXISTS dbo.vw_PruebaAuditor;
GO

IF SCHEMA_ID('AuditoriaLocal') IS NOT NULL DROP SCHEMA AuditoriaLocal;
GO

DROP USER IF EXISTS usr_auditor;
DROP USER IF EXISTS usr_cajero;
DROP USER IF EXISTS usr_soporte;
DROP USER IF EXISTS usr_admin;
GO

DROP ROLE IF EXISTS Rol_Auditoria;
DROP ROLE IF EXISTS Rol_Operadores;
DROP ROLE IF EXISTS Rol_Administracion;
GO

USE master;
GO

IF SUSER_ID('login_auditor') IS NOT NULL DROP LOGIN login_auditor;
IF SUSER_ID('login_cajero')  IS NOT NULL DROP LOGIN login_cajero;
IF SUSER_ID('login_soporte') IS NOT NULL DROP LOGIN login_soporte;
IF SUSER_ID('login_admin')   IS NOT NULL DROP LOGIN login_admin;
GO

-- =====================================================================
-- EJERCICIO 1: CREACION DE LOGINS Y USUARIOS DE BASE DE DATOS
-- =====================================================================

-- 1. Login a nivel de servidor para el auditor
CREATE LOGIN login_auditor
    WITH PASSWORD = 'fg46qa95AB++*',
         DEFAULT_DATABASE = BANCA_DIGITAL,
         CHECK_POLICY = ON;
GO

-- 3. Login para el cajero (misma contrasena)
CREATE LOGIN login_cajero
    WITH PASSWORD = 'fg46qa95AB++*',
         DEFAULT_DATABASE = BANCA_DIGITAL,
         CHECK_POLICY = ON;
GO

-- Logins de apoyo para el Ejercicio 3.5 (soporte) y 4.3 (administrador)
CREATE LOGIN login_soporte
    WITH PASSWORD = 'fg46qa95AB++*',
         DEFAULT_DATABASE = BANCA_DIGITAL,
         CHECK_POLICY = ON;
GO

CREATE LOGIN login_admin
    WITH PASSWORD = 'fg46qa95AB++*',
         DEFAULT_DATABASE = BANCA_DIGITAL,
         CHECK_POLICY = ON;
GO

USE BANCA_DIGITAL;
GO

-- 2. Usuario de BD asociado al login del auditor
CREATE USER usr_auditor FOR LOGIN login_auditor WITH DEFAULT_SCHEMA = dbo;

-- 3. Usuario de BD del cajero
CREATE USER usr_cajero  FOR LOGIN login_cajero  WITH DEFAULT_SCHEMA = dbo;

-- Usuarios de apoyo
CREATE USER usr_soporte FOR LOGIN login_soporte WITH DEFAULT_SCHEMA = dbo;
CREATE USER usr_admin   FOR LOGIN login_admin   WITH DEFAULT_SCHEMA = dbo;
GO

-- PRUEBA: logins y usuarios creados
SELECT sp.name AS LoginServidor, dp.name AS UsuarioBD, dp.type_desc, dp.default_schema_name
FROM sys.database_principals dp
INNER JOIN sys.server_principals sp ON sp.sid = dp.sid
WHERE dp.name IN ('usr_auditor', 'usr_cajero', 'usr_soporte', 'usr_admin');
GO

-- =====================================================================
-- EJERCICIO 2: CREACION Y GESTION DE ROLES
-- =====================================================================

-- 1. y 2. Roles de base de datos
CREATE ROLE Rol_Auditoria;
CREATE ROLE Rol_Operadores;
CREATE ROLE Rol_Administracion;   -- apoyo para el Ejercicio 4.3
GO

-- 3. y 4. Asignacion de miembros
ALTER ROLE Rol_Auditoria      ADD MEMBER usr_auditor;
ALTER ROLE Rol_Operadores     ADD MEMBER usr_cajero;
ALTER ROLE Rol_Administracion ADD MEMBER usr_admin;
GO

-- PRUEBA: miembros de cada rol
SELECT r.name AS Rol, m.name AS Miembro
FROM sys.database_role_members rm
INNER JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
INNER JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name IN ('Rol_Auditoria', 'Rol_Operadores', 'Rol_Administracion');
GO

-- PRUEBA: sin permisos todavia, el auditor no puede leer
EXECUTE AS USER = 'usr_auditor';
GO
SELECT USER_NAME() AS UsuarioActual;
SELECT * FROM dbo.Cuentas;                         -- Error 229 (esperado)
GO
REVERT;
GO

-- =====================================================================
-- EJERCICIO 3: PERMISOS GRANULARES SOBRE TABLAS (GRANT, REVOKE, DENY)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 Consulta general de auditoria: SELECT sobre todas las tablas
-- ---------------------------------------------------------------------
GRANT SELECT ON dbo.Clientes       TO Rol_Auditoria;
GRANT SELECT ON dbo.Cuentas        TO Rol_Auditoria;
GRANT SELECT ON dbo.Movimientos    TO Rol_Auditoria;
GRANT SELECT ON dbo.Transferencias TO Rol_Auditoria;
GRANT SELECT ON dbo.LogErrores     TO Rol_Auditoria;
GO

-- PRUEBA 3.1
EXECUTE AS USER = 'usr_auditor';
GO
SELECT USER_NAME() AS UsuarioActual;
SELECT * FROM dbo.Clientes;                        -- OK
SELECT * FROM dbo.Cuentas;                         -- OK
SELECT * FROM dbo.Movimientos;                     -- OK
SELECT * FROM dbo.Transferencias;                  -- OK
SELECT * FROM dbo.LogErrores;                      -- OK
UPDATE dbo.Cuentas SET Saldo = 0 WHERE CuentaID = 1;   -- Error 229 (solo lectura)
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.2 Insercion operativa: INSERT en Movimientos y Transferencias
-- ---------------------------------------------------------------------
GRANT INSERT ON dbo.Movimientos    TO Rol_Operadores;
GRANT INSERT ON dbo.Transferencias TO Rol_Operadores;
GO

-- PRUEBA 3.2
EXECUTE AS USER = 'usr_cajero';
GO
SELECT USER_NAME() AS UsuarioActual;
INSERT INTO dbo.Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
VALUES (1, 'Deposito', 1000, 501000, 'Prueba Lab 5 - cajero');               -- OK
INSERT INTO dbo.Transferencias (CuentaOrigenID, CuentaDestinoID, Monto, Estado, Detalle)
VALUES (1, 3, 1000, 'Completada', 'Prueba Lab 5 - cajero');                   -- OK
SELECT * FROM dbo.Movimientos;                     -- Error 229 (no tiene SELECT)
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.3 DENY de cualquier acceso a LogErrores para Rol_Operadores
-- ---------------------------------------------------------------------
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.LogErrores TO Rol_Operadores;
GO

-- PRUEBA 3.3
EXECUTE AS USER = 'usr_cajero';
GO
SELECT * FROM dbo.LogErrores;                                              -- Error 229
INSERT INTO dbo.LogErrores (Procedimiento, NumeroError, Mensaje)
VALUES ('Prueba', 1, 'Intento del cajero');                                -- Error 229
UPDATE dbo.LogErrores SET Mensaje = 'x';                                   -- Error 229
DELETE FROM dbo.LogErrores;                                                -- Error 229
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.4 REVOKE unicamente del INSERT sobre Transferencias
-- ---------------------------------------------------------------------
REVOKE INSERT ON dbo.Transferencias FROM Rol_Operadores;
GO

-- PRUEBA 3.4
EXECUTE AS USER = 'usr_cajero';
GO
INSERT INTO dbo.Transferencias (CuentaOrigenID, CuentaDestinoID, Monto, Estado, Detalle)
VALUES (1, 3, 1000, 'Completada', 'Prueba Lab 5 - tras REVOKE');            -- Error 229
INSERT INTO dbo.Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
VALUES (1, 'Deposito', 1000, 502000, 'Prueba Lab 5 - tras REVOKE');          -- OK (se conserva)
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.5 Permiso por columnas: usr_soporte no ve la Cedula
-- ---------------------------------------------------------------------
GRANT SELECT ON dbo.Clientes (ClienteID, Nombre, Email, Categoria, Activo) TO usr_soporte;
GO

-- PRUEBA 3.5
EXECUTE AS USER = 'usr_soporte';
GO
SELECT USER_NAME() AS UsuarioActual;
SELECT ClienteID, Nombre, Email, Categoria, Activo FROM dbo.Clientes;   -- OK
SELECT Cedula FROM dbo.Clientes;                                        -- Error 230
SELECT * FROM dbo.Clientes;                                             -- Error 230 (incluye Cedula)
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.6 UPDATE limitado a la columna Estado de Cuentas
-- Para usar un WHERE el usuario necesita SELECT sobre las columnas del
-- filtro; se le da SELECT solo sobre las columnas que identifican la
-- cuenta. Saldo y Moneda no se pueden modificar.
-- ---------------------------------------------------------------------
GRANT UPDATE ON dbo.Cuentas (Estado) TO usr_cajero;
GRANT SELECT ON dbo.Cuentas (CuentaID, NumeroCuenta, Estado) TO usr_cajero;
GO

-- PRUEBA 3.6
EXECUTE AS USER = 'usr_cajero';
GO
UPDATE dbo.Cuentas SET Estado = 'Congelada' WHERE NumeroCuenta = 'CR-005';   -- OK
UPDATE dbo.Cuentas SET Estado = 'Activa'    WHERE NumeroCuenta = 'CR-005';   -- OK (reactiva)
SELECT NumeroCuenta, Estado FROM dbo.Cuentas WHERE NumeroCuenta = 'CR-005';  -- OK
UPDATE dbo.Cuentas SET Saldo  = 9999999 WHERE NumeroCuenta = 'CR-005';       -- Error 230
UPDATE dbo.Cuentas SET Moneda = 'USD'   WHERE NumeroCuenta = 'CR-005';       -- Error 230
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.7 GRANT al rol vs DENY directo al usuario: gana el DENY
-- ---------------------------------------------------------------------
GRANT SELECT ON dbo.Clientes TO Rol_Operadores;
DENY  SELECT ON dbo.Clientes TO usr_cajero;
GO

-- PRUEBA 3.7: el DENY tiene precedencia sobre el GRANT heredado del rol
EXECUTE AS USER = 'usr_cajero';
GO
SELECT USER_NAME() AS UsuarioActual,
       IS_ROLEMEMBER('Rol_Operadores') AS EsMiembroDeRolOperadores,
       HAS_PERMS_BY_NAME('dbo.Clientes', 'OBJECT', 'SELECT') AS TienePermisoSelect;  -- 0
SELECT * FROM dbo.Clientes;                                                       -- Error 229
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.8 GRANT DELETE y REVOKE inmediato: queda solo la lectura
-- ---------------------------------------------------------------------
GRANT  DELETE ON dbo.Movimientos TO Rol_Auditoria;
REVOKE DELETE ON dbo.Movimientos FROM Rol_Auditoria;
GO

-- PRUEBA 3.8
SELECT USER_NAME(grantee_principal_id) AS Principal, permission_name, state_desc
FROM sys.database_permissions
WHERE major_id = OBJECT_ID('dbo.Movimientos')
  AND grantee_principal_id = USER_ID('Rol_Auditoria');   -- solo SELECT / GRANT

EXECUTE AS USER = 'usr_auditor';
GO
SELECT COUNT(*) AS CantidadMovimientos FROM dbo.Movimientos;   -- OK
DELETE FROM dbo.Movimientos WHERE MovimientoID = -1;           -- Error 229
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 3.9 Apertura de cuentas: INSERT en Clientes y Cuentas
-- ---------------------------------------------------------------------
GRANT INSERT ON dbo.Clientes TO Rol_Operadores;
GRANT INSERT ON dbo.Cuentas  TO Rol_Operadores;
GO

-- PRUEBA 3.9
EXECUTE AS USER = 'usr_cajero';
GO
INSERT INTO dbo.Clientes (Cedula, Nombre, Email, Categoria)
VALUES ('7-7777-7777', 'Cliente Lab5', 'cliente.lab5@correo.com', 'Estandar');   -- OK
INSERT INTO dbo.Cuentas (NumeroCuenta, ClienteID, TipoCuenta, Moneda, Saldo, LimiteRetiroDiario)
VALUES ('CR-LAB5', 1, 'Ahorro', 'CRC', 0, 100000);                                -- OK
GO
REVERT;
GO

SELECT * FROM dbo.Clientes WHERE Cedula = '7-7777-7777';
SELECT * FROM dbo.Cuentas  WHERE NumeroCuenta = 'CR-LAB5';
GO

-- ---------------------------------------------------------------------
-- 3.10 Limpieza completa de permisos sobre Transferencias
-- REVOKE elimina tanto GRANT como DENY, dejando el estado heredado.
-- ---------------------------------------------------------------------
REVOKE SELECT, INSERT, UPDATE, DELETE, REFERENCES, ALTER, CONTROL,
       TAKE OWNERSHIP, VIEW DEFINITION, VIEW CHANGE TRACKING
    ON dbo.Transferencias FROM Rol_Operadores;
GO

-- PRUEBA 3.10: no quedan permisos explicitos del rol sobre Transferencias
SELECT COUNT(*) AS PermisosDeRolOperadoresSobreTransferencias
FROM sys.database_permissions
WHERE major_id = OBJECT_ID('dbo.Transferencias')
  AND grantee_principal_id = USER_ID('Rol_Operadores');   -- 0
GO

-- =====================================================================
-- EJERCICIO 4: PERMISOS SOBRE VISTAS, FUNCIONES Y PROCEDIMIENTOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 4.1 EXECUTE sobre sp_ConsultarMovimientos y fn_FormatearMonto
-- ---------------------------------------------------------------------
GRANT EXECUTE ON dbo.sp_ConsultarMovimientos TO usr_cajero;
GRANT EXECUTE ON dbo.fn_FormatearMonto       TO usr_cajero;
GO

-- PRUEBA 4.1: por encadenamiento de propiedad (dbo es dueno del
-- procedimiento y de la tabla) el cajero ve los movimientos aunque no
-- tenga SELECT sobre dbo.Movimientos.
EXECUTE AS USER = 'usr_cajero';
GO
EXEC dbo.sp_ConsultarMovimientos @CuentaID = 1;                    -- OK
SELECT dbo.fn_FormatearMonto(150000, 'CRC') AS MontoCRC,
       dbo.fn_FormatearMonto(3000,   'USD') AS MontoUSD;           -- OK
SELECT * FROM dbo.Movimientos;                                     -- Error 229
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 4.2 SELECT sobre la vista vw_ResumenClientes
-- ---------------------------------------------------------------------
GRANT SELECT ON dbo.vw_ResumenClientes TO Rol_Operadores;
GO

-- PRUEBA 4.2: el cajero lee la vista aunque tenga DENY SELECT sobre
-- Clientes (3.7): la cadena de propiedad no revisa permisos de la tabla.
EXECUTE AS USER = 'usr_cajero';
GO
SELECT * FROM dbo.vw_ResumenClientes;                              -- OK
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 4.3 EXECUTE de ReiniciarDatos solo para el administrador; DENY al cajero
-- El procedimiento usa SET IDENTITY_INSERT, que exige ALTER sobre la
-- tabla (la cadena de propiedad no cubre esa instruccion), por eso el
-- rol de administracion recibe ALTER sobre las tablas que se recargan.
-- ---------------------------------------------------------------------
GRANT EXECUTE ON dbo.ReiniciarDatos TO usr_admin;
GRANT ALTER   ON dbo.Clientes TO Rol_Administracion;
GRANT ALTER   ON dbo.Cuentas  TO Rol_Administracion;
DENY  EXECUTE ON dbo.ReiniciarDatos TO usr_cajero;
GO

-- PRUEBA 4.3
EXECUTE AS USER = 'usr_cajero';
GO
EXEC dbo.ReiniciarDatos;                                           -- Error 229
GO
REVERT;
GO

EXECUTE AS USER = 'usr_admin';
GO
SELECT USER_NAME() AS UsuarioActual;
EXEC dbo.ReiniciarDatos;                                           -- OK
GO
REVERT;
GO

SELECT NumeroCuenta, Saldo, Estado FROM dbo.Cuentas;               -- datos originales
GO

-- =====================================================================
-- EJERCICIO 5: PERMISOS DDL DE CREACION Y ADMINISTRACION DE OBJETOS
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.1 CREATE VIEW y CREATE PROCEDURE para usr_auditor
-- 5.3 CREATE FUNCTION exclusivo para usr_auditor
-- ---------------------------------------------------------------------
GRANT CREATE VIEW, CREATE PROCEDURE TO usr_auditor;
GRANT CREATE FUNCTION TO usr_auditor;
GO

-- ---------------------------------------------------------------------
-- 5.2 CREATE TABLE para usr_cajero
-- ---------------------------------------------------------------------
GRANT CREATE TABLE TO usr_cajero;
GO

-- ---------------------------------------------------------------------
-- 5.4 ALTER sobre el esquema dbo para usr_auditor
-- (Los permisos CREATE requieren ademas ALTER sobre el esquema destino)
-- ---------------------------------------------------------------------
GRANT ALTER ON SCHEMA::dbo TO usr_auditor;
GO

-- PRUEBA 5.1 / 5.3 / 5.4: el auditor crea objetos en dbo
EXECUTE AS USER = 'usr_auditor';
GO
EXEC ('CREATE OR ALTER VIEW dbo.vw_PruebaAuditor AS
       SELECT NumeroCuenta, Saldo FROM dbo.Cuentas;');                       -- OK
EXEC ('CREATE OR ALTER PROCEDURE dbo.sp_PruebaAuditor AS
       SELECT COUNT(*) AS Total FROM dbo.LogErrores;');                      -- OK
EXEC ('CREATE OR ALTER FUNCTION dbo.fn_PruebaAuditor() RETURNS INT AS
       BEGIN RETURN 1; END;');                                               -- OK
SELECT name, type_desc FROM sys.objects
WHERE name IN ('vw_PruebaAuditor', 'sp_PruebaAuditor', 'fn_PruebaAuditor');
GO
REVERT;
GO

DROP PROCEDURE IF EXISTS dbo.sp_PruebaAuditor;
DROP FUNCTION  IF EXISTS dbo.fn_PruebaAuditor;
GO

-- PRUEBA 5.2: el permiso CREATE TABLE quedo asignado al cajero
EXECUTE AS USER = 'usr_cajero';
GO
SELECT HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE TABLE') AS PuedeCrearTablas;   -- 1
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 5.5 DENY CREATE VIEW y CREATE FUNCTION a usr_cajero
-- ---------------------------------------------------------------------
DENY CREATE VIEW, CREATE FUNCTION TO usr_cajero;
GO

-- PRUEBA 5.5
EXECUTE AS USER = 'usr_cajero';
GO
SELECT HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE VIEW')     AS PuedeCrearVistas,     -- 0
       HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE FUNCTION') AS PuedeCrearFunciones;  -- 0
GO
EXEC ('CREATE VIEW dbo.vw_PruebaCajero AS SELECT 1 AS Uno;');                          -- Error 262
GO
EXEC ('CREATE FUNCTION dbo.fn_PruebaCajero() RETURNS INT AS BEGIN RETURN 1; END;');    -- Error 262
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 5.6 REVOKE CREATE TABLE a usr_cajero
-- ---------------------------------------------------------------------
REVOKE CREATE TABLE FROM usr_cajero;
GO

-- PRUEBA 5.6
EXECUTE AS USER = 'usr_cajero';
GO
SELECT HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE TABLE') AS PuedeCrearTablas;   -- 0
EXEC ('CREATE TABLE dbo.TablaCajero (ID INT);');                                  -- Error 262
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 5.7 ALTER exclusivamente sobre la tabla LogErrores para Rol_Auditoria
-- ---------------------------------------------------------------------
GRANT ALTER ON dbo.LogErrores TO Rol_Auditoria;
GO

-- PRUEBA 5.7
EXECUTE AS USER = 'usr_auditor';
GO
ALTER TABLE dbo.LogErrores ADD Observacion VARCHAR(200) NULL;      -- OK
ALTER TABLE dbo.LogErrores DROP COLUMN Observacion;                -- OK (se deja como estaba)
GO
REVERT;
GO

-- Para comprobar que el ALTER es exclusivo de LogErrores se quita
-- temporalmente el ALTER sobre el esquema dbo (5.4), que lo cubriria todo.
REVOKE ALTER ON SCHEMA::dbo FROM usr_auditor;
GO
EXECUTE AS USER = 'usr_auditor';
GO
ALTER TABLE dbo.Movimientos ADD Observacion VARCHAR(200) NULL;     -- Error 1088 (sin ALTER)
GO
REVERT;
GO
GRANT ALTER ON SCHEMA::dbo TO usr_auditor;                         -- se restaura 5.4
GO

-- ---------------------------------------------------------------------
-- 5.8 VIEW DEFINITION a nivel de base de datos para usr_cajero
-- ---------------------------------------------------------------------

-- Antes del permiso: la definicion no es visible (NULL)
EXECUTE AS USER = 'usr_cajero';
GO
SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ConsultarMovimientos')) AS DefinicionAntes;   -- NULL
GO
REVERT;
GO

GRANT VIEW DEFINITION TO usr_cajero;
GO

-- PRUEBA 5.8
EXECUTE AS USER = 'usr_cajero';
GO
SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.sp_ConsultarMovimientos')) AS DefinicionDespues; -- texto
EXEC sp_helptext 'dbo.vw_ResumenClientes';                                                -- OK
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 5.9 Esquema AuditoriaLocal administrado por usr_auditor
-- ---------------------------------------------------------------------
CREATE SCHEMA AuditoriaLocal AUTHORIZATION dbo;
GO

GRANT ALTER, INSERT, SELECT ON SCHEMA::AuditoriaLocal TO usr_auditor;
GO

-- Tabla de apoyo para probar INSERT/SELECT dentro del esquema
CREATE TABLE AuditoriaLocal.Hallazgos (
    HallazgoID  INT IDENTITY(1,1) PRIMARY KEY,
    Descripcion VARCHAR(200) NOT NULL,
    Fecha       DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- PRUEBA 5.9
EXECUTE AS USER = 'usr_auditor';
GO
INSERT INTO AuditoriaLocal.Hallazgos (Descripcion)
VALUES ('Cuenta CR-007 congelada con saldo disponible');                     -- OK
SELECT * FROM AuditoriaLocal.Hallazgos;                                      -- OK
EXEC ('CREATE VIEW AuditoriaLocal.vw_SaldosPorMoneda AS
       SELECT Moneda, SUM(Saldo) AS SaldoTotal
       FROM dbo.Cuentas GROUP BY Moneda;');                                  -- OK
SELECT * FROM AuditoriaLocal.vw_SaldosPorMoneda;                             -- OK
GO
REVERT;
GO

-- ---------------------------------------------------------------------
-- 5.10 REVOKE de CREATE VIEW, CREATE PROCEDURE y CREATE FUNCTION
-- ---------------------------------------------------------------------
REVOKE CREATE VIEW, CREATE PROCEDURE, CREATE FUNCTION FROM usr_auditor;
GO

-- PRUEBA 5.10
EXECUTE AS USER = 'usr_auditor';
GO
SELECT HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE VIEW')      AS PuedeCrearVistas,          -- 0
       HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE PROCEDURE') AS PuedeCrearProcedimientos,  -- 0
       HAS_PERMS_BY_NAME(NULL, 'DATABASE', 'CREATE FUNCTION')  AS PuedeCrearFunciones;       -- 0
EXEC ('CREATE VIEW AuditoriaLocal.vw_Prueba2 AS SELECT 1 AS Uno;');                          -- Error 262
GO
REVERT;
GO

-- =====================================================================
-- RESUMEN FINAL DE PERMISOS
-- =====================================================================
SELECT pr.name                       AS Principal,
       pr.type_desc                  AS TipoPrincipal,
       pe.class_desc                 AS Clase,
       CASE pe.class
            WHEN 0 THEN DB_NAME()
            WHEN 1 THEN OBJECT_SCHEMA_NAME(pe.major_id) + '.' + OBJECT_NAME(pe.major_id)
            WHEN 3 THEN SCHEMA_NAME(pe.major_id)
       END                           AS Objeto,
       COL_NAME(pe.major_id, pe.minor_id) AS Columna,
       pe.permission_name            AS Permiso,
       pe.state_desc                 AS Estado
FROM sys.database_permissions pe
INNER JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name IN ('usr_auditor', 'usr_cajero', 'usr_soporte', 'usr_admin',
                  'Rol_Auditoria', 'Rol_Operadores', 'Rol_Administracion')
  AND pe.permission_name <> 'CONNECT'
ORDER BY pr.name, Clase, Objeto, Columna, Permiso;
GO
