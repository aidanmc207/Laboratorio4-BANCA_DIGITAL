USE BANCA_DIGITAL_C4H845;
GO

-- 1. Vista: Resumen de clientes y cuentas activas
CREATE OR ALTER VIEW dbo.vw_ResumenClientes
AS
SELECT 
    cl.ClienteID,
    cl.Nombre,
    cl.Categoria,
    c.NumeroCuenta,
    c.TipoCuenta,
    c.Moneda,
    c.Saldo
FROM dbo.Clientes cl
INNER JOIN dbo.Cuentas c ON cl.ClienteID = c.ClienteID
WHERE c.Estado = 'Activa';
GO

-- 2. Función Escalar: Formatear moneda con símbolo
CREATE OR ALTER FUNCTION dbo.fn_FormatearMonto
(
    @Monto DECIMAL(14,2),
    @Moneda CHAR(3)
)
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN CASE 
        WHEN @Moneda = 'USD' THEN '$ ' + CONVERT(VARCHAR(20), @Monto)
        ELSE '₡ ' + CONVERT(VARCHAR(20), @Monto)
    END;
END;
GO

-- 3. Procedimiento Almacenado: Consultar Movimientos por Cuenta
CREATE OR ALTER PROCEDURE dbo.sp_ConsultarMovimientos
    @CuentaID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT MovimientoID, TipoMovimiento, Monto, SaldoResultante, Fecha, Descripcion
    FROM dbo.Movimientos
    WHERE CuentaID = @CuentaID
    ORDER BY Fecha DESC;
END;
GO