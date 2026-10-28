-- =====================================================================
-- LABORATORIO: OPTIMIZACIÓN DE CONSULTAS Y USO DE ÍNDICES
-- Base de datos: BANCA_DIGITAL
-- IF0010 Bases de Datos II - UCR
-- ENUNCIADO PARA ESTUDIANTES
-- =====================================================================
--
-- REQUISITOS
--   * SQL Server 2016 o superior y SSMS (Azure Data Studio no muestra el
--     plan grafico con la misma comodidad; se recomienda SSMS).
--   * Ejecutar BANCA_DIGITAL.sql JUSTO ANTES de iniciar. Ese script borra
--     y recrea la base desde cero, de modo que CuentaID = 500 corresponde
--     siempre a una cuenta de laboratorio con decenas de movimientos (la
--     que usan los ejercicios 1 a 4). Si necesita repetir el laboratorio,
--     vuelva a correr BANCA_DIGITAL.sql antes de la Parte 0.
--
-- COMO SE TRABAJA
--   La Parte 0 agranda la base (mas clientes, cuentas y ~100 000
--   movimientos) para que las diferencias de rendimiento se noten.
--   Luego cada ejercicio pide escribir una consulta o un indice y
--   OBSERVAR el plan de ejecucion y las estadisticas.
--
--   Dos botones clave en SSMS:
--     Ctrl + L  -> Plan de ejecucion ESTIMADO (no ejecuta la consulta)
--     Ctrl + M  -> incluye el Plan de ejecucion REAL (ejecuta y lo dibuja)
--   El plan se lee de DERECHA a IZQUIERDA y de ARRIBA hacia ABAJO.
--
--   Algunos ejercicios traen una pequena MATRIZ DE CASOS DE PRUEBA
--   (columnas Caso, Descripcion, Esperado, Obtenido, Resultado). Si todo
--   esta bien, la columna Resultado dice 'PASA'. Los ejercicios de LECTURA
--   de plan no se validan con una tabla: traen 'Resultado esperado' en
--   texto, porque lo que se evalua es la interpretacion del plan.
-- =====================================================================


-- =====================================================================
-- PARTE 0. PREPARACION (ya resuelta, solo ejecutar)
-- Agranda la base para que los Table Scan sean costosos.
-- Ejecute esta parte una sola vez, sobre la base recien creada por
-- BANCA_DIGITAL.sql.
-- =====================================================================
USE BANCA_DIGITAL_C4H845;
GO

SET NOCOUNT ON;
GO

-- 0.2 Insertar 2000 clientes.
;WITH N AS (
    SELECT TOP (2000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Clientes (Cedula, Nombre, Email, Categoria)
SELECT 'G-' + RIGHT('0000000' + CAST(rn AS VARCHAR(7)), 7),
       'Cliente ' + CAST(rn AS VARCHAR(7)),
       'cli' + CAST(rn AS VARCHAR(7)) + '@correo.com',
       CASE rn % 3 WHEN 0 THEN 'Estandar' WHEN 1 THEN 'Oro' ELSE 'Platino' END
FROM N;
GO

-- 0.3 Insertar 3000 cuentas, repartidas entre los clientes reales.
DECLARE @maxCli INT = (SELECT MAX(ClienteID) FROM dbo.Clientes);

;WITH N AS (
    SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Cuentas (NumeroCuenta, ClienteID, TipoCuenta, Moneda,
                         Saldo, LimiteRetiroDiario, Estado)
SELECT 'LAB-' + RIGHT('0000000' + CAST(rn AS VARCHAR(7)), 7),
       ((rn - 1) % @maxCli) + 1,
       CASE rn % 2 WHEN 0 THEN 'Ahorro' ELSE 'Corriente' END,
       'CRC',
       CAST((rn % 900 + 1) * 1000 AS DECIMAL(14,2)),
       100000.00,
       CASE WHEN rn % 50 = 0 THEN 'Congelada' ELSE 'Activa' END
FROM N;
GO

-- 0.4 Insertar 100 000 movimientos, repartidos entre las cuentas de
--     laboratorio (NumeroCuenta 'LAB-...'). Asi CuentaID = 500 queda con
--     decenas de movimientos.
DECLARE @nCta INT = (SELECT COUNT(*) FROM dbo.Cuentas WHERE NumeroCuenta LIKE 'LAB-%');

;WITH Cta AS (
    SELECT CuentaID, ROW_NUMBER() OVER (ORDER BY CuentaID) AS crn
    FROM dbo.Cuentas
    WHERE NumeroCuenta LIKE 'LAB-%'
),
N AS (
    SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
)
INSERT INTO dbo.Movimientos (CuentaID, TipoMovimiento, Monto, SaldoResultante, Descripcion)
SELECT Cta.CuentaID,
       CASE N.rn % 2 WHEN 0 THEN 'Deposito' ELSE 'Retiro' END,
       CAST((N.rn % 500 + 1) * 100 AS DECIMAL(14,2)),
       CAST((N.rn % 500 + 1) * 100 AS DECIMAL(14,2)),
       'Movimiento de carga ' + CAST(N.rn AS VARCHAR(7))
FROM N
INNER JOIN Cta ON Cta.crn = ((N.rn - 1) % @nCta) + 1;
GO

-- 0.5 Actualizar estadisticas para que el optimizador tenga datos frescos.
UPDATE STATISTICS dbo.Movimientos;
UPDATE STATISTICS dbo.Cuentas;
UPDATE STATISTICS dbo.Clientes;
GO

-- 0.6 Verificacion de la preparacion.
SELECT Caso, Descripcion, Esperado, Obtenido,
       CASE WHEN Obtenido >= Esperado THEN 'PASA' ELSE 'FALLA' END AS Resultado
FROM (
    SELECT 'CP-00.1', 'Movimientos tiene al menos 100 000 filas', 100000,
           (SELECT COUNT(*) FROM dbo.Movimientos)
    UNION ALL
    SELECT 'CP-00.2', 'Cuentas tiene al menos 3000 filas', 3000,
           (SELECT COUNT(*) FROM dbo.Cuentas)
    UNION ALL
    SELECT 'CP-00.3', 'Clientes tiene al menos 2000 filas', 2000,
           (SELECT COUNT(*) FROM dbo.Clientes)
) AS t(Caso, Descripcion, Esperado, Obtenido);
GO


-- =====================================================================
-- PARTE 1. LECTURA DEL PLAN DE EJECUCION
-- =====================================================================

-- ---------------------------------------------------------------------
-- EJERCICIO 1. Identificar un Table Scan / Clustered Index Scan
-- ---------------------------------------------------------------------
-- La tabla Movimientos solo tiene indice por su llave primaria
-- (MovimientoID). La columna CuentaID NO tiene indice.
--   a) Active el plan REAL con Ctrl + M.
--   b) Ejecute la consulta de abajo (ya dada).
--   c) Observe el plan: ubique el operador mas costoso (% de costo) y
--      anote su nombre.
-- No hay que escribir codigo; solo ejecutar y observar.
-- ---------------------------------------------------------------------
SET STATISTICS IO ON;
GO
SELECT MovimientoID, CuentaID, TipoMovimiento, Monto, Fecha
FROM dbo.Movimientos
WHERE CuentaID = 500;
GO
SET STATISTICS IO OFF;
GO
-- Resultado esperado: el plan muestra un Clustered Index Scan sobre
-- Movimientos (recorre TODA la tabla). En la pestana Mensajes, las
-- "logical reads" son altas (cientos). Anote ese numero para el Ej. 2.
-- Obtenido: Clustered Index Scan (operador mas costoso), 1014 logical reads.


-- ---------------------------------------------------------------------
-- EJERCICIO 2. Crear un indice y comparar el plan
-- ---------------------------------------------------------------------
-- Cree un indice NO clusterizado sobre dbo.Movimientos(CuentaID) llamado
-- IX_Movimientos_CuentaID. Luego vuelva a ejecutar la MISMA consulta del
-- Ejercicio 1 y compare.
-- ---------------------------------------------------------------------
-- >>> ESCRIBA AQUI SU SOLUCION <<<
CREATE NONCLUSTERED INDEX IX_Movimientos_CuentaID ON dbo.Movimientos (CuentaID);

GO

-- Verificacion de que el indice se creo
SELECT Caso, Descripcion, Esperado, Obtenido,
       CASE WHEN Esperado = Obtenido THEN 'PASA' ELSE 'FALLA' END AS Resultado
FROM (
    SELECT 'CP-02.1', 'Existe el indice IX_Movimientos_CuentaID', 1,
           (SELECT COUNT(*) FROM sys.indexes
            WHERE name = 'IX_Movimientos_CuentaID'
              AND object_id = OBJECT_ID('dbo.Movimientos'))
) AS t(Caso, Descripcion, Esperado, Obtenido);
GO

-- Ahora repita la consulta con el plan real (Ctrl + M) y SET STATISTICS IO
SET STATISTICS IO ON;
GO
SELECT MovimientoID, CuentaID, TipoMovimiento, Monto, Fecha
FROM dbo.Movimientos
WHERE CuentaID = 500;
GO
SET STATISTICS IO OFF;
GO
-- Resultado esperado: el plan ahora usa un Index Seek sobre
-- IX_Movimientos_CuentaID (posiblemente con un Key Lookup). Las
-- "logical reads" bajan drasticamente respecto al Ejercicio 1.
-- Pregunta 1: ¿cuantas "logical reads" tuvo la consulta en el Ejercicio 1
-- y cuantas ahora? ¿Que operador reemplazo al scan?
-- Respuesta: Ejercicio 1 = 1014 logical reads; ahora = 115. El scan fue
-- reemplazado por un Index Seek (con Key Lookup). El indice tiene CuentaID
-- ordenado, asi que el motor va directo a las filas de la cuenta 500 en
-- vez de recorrer toda la tabla.


-- =====================================================================
-- PARTE 2. HERRAMIENTAS DE DIAGNOSTICO
-- =====================================================================

-- ---------------------------------------------------------------------
-- EJERCICIO 3. Medir una consulta con SET STATISTICS TIME e IO
-- ---------------------------------------------------------------------
-- Active las dos estadisticas y ejecute la consulta con JOIN de abajo.
-- Luego lea la pestana "Mensajes" y anote las metricas indicadas.
-- No hay que escribir codigo; solo ejecutar y leer los mensajes.
-- ---------------------------------------------------------------------
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO
SELECT c.NumeroCuenta, cl.Nombre, m.TipoMovimiento, m.Monto
FROM dbo.Movimientos m
INNER JOIN dbo.Cuentas  c  ON c.CuentaID  = m.CuentaID
INNER JOIN dbo.Clientes cl ON cl.ClienteID = c.ClienteID
WHERE m.CuentaID = 500;
GO
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO
-- Resultado esperado: en Mensajes aparecen, por cada tabla, las
-- "logical reads" y el "scan count"; y al final el CPU time y el
-- elapsed time de la consulta.
-- Pregunta 2: ¿cual es la diferencia entre "CPU time" y "elapsed time"?
-- Pregunta 3: ¿sobre cual de las tres tablas se hicieron mas lecturas
-- logicas y por que?
-- Obtenido: Movimientos = 115, Cuentas = 2, Clientes = 2 logical reads;
-- CPU time = 0 ms, elapsed time = 0-2 ms.
-- Respuesta 2: CPU time es el tiempo que el procesador trabajo en la
-- consulta; elapsed time es el tiempo total transcurrido, incluyendo
-- esperas (disco, bloqueos, red).
-- Respuesta 3: en Movimientos, porque es la tabla grande y de ella se leen
-- todas las filas de la cuenta 500; de Cuentas y Clientes solo se lee una
-- fila por su llave primaria.


-- ---------------------------------------------------------------------
-- EJERCICIO 4. Heuristicas: seleccion y proyeccion tempranas
-- ---------------------------------------------------------------------
-- La siguiente consulta trae TODAS las columnas (SELECT *) de las tres
-- tablas, cuando el reporte solo necesita: numero de cuenta, nombre del
-- cliente, tipo de movimiento y monto, de los movimientos de tipo
-- 'Deposito' de la cuenta 500.
--
-- Consulta original (poco eficiente):
--     SELECT *
--     FROM dbo.Movimientos m
--     INNER JOIN dbo.Cuentas  c  ON c.CuentaID  = m.CuentaID
--     INNER JOIN dbo.Clientes cl ON cl.ClienteID = c.ClienteID;
--
-- Reescribala aplicando dos heuristicas:
--   a) Proyeccion temprana: traer SOLO las 4 columnas necesarias.
--   b) Seleccion temprana: filtrar por CuentaID = 500 y
--      TipoMovimiento = 'Deposito' (asi se descartan filas cuanto antes).
-- ---------------------------------------------------------------------
-- >>> ESCRIBA AQUI SU SOLUCION <<<
SET STATISTICS IO ON;
GO
SELECT c.NumeroCuenta, cl.Nombre, m.TipoMovimiento, m.Monto
FROM dbo.Movimientos m
INNER JOIN dbo.Cuentas  c  ON c.CuentaID  = m.CuentaID
INNER JOIN dbo.Clientes cl ON cl.ClienteID = c.ClienteID
WHERE m.CuentaID = 500
  AND m.TipoMovimiento = 'Deposito';
GO
SET STATISTICS IO OFF;
GO
-- Obtenido: original = 1063 logical reads; reescrita = 119.

-- Resultado esperado: comparada con el SELECT * sin filtro, la consulta
-- reescrita hace muchas menos lecturas logicas y devuelve solo las filas
-- y columnas necesarias.
-- Pregunta 4: ¿por que "SELECT *" sin filtro es la peor opcion en una
-- tabla de 100 000 filas, incluso si luego la aplicacion ignora columnas?
-- Respuesta: porque el servidor ya hizo todo el trabajo antes de que la
-- aplicacion descarte columnas: sin filtro recorre toda la tabla y no usa
-- indices, y con todas las columnas mueve mas datos en memoria y por la red.


-- =====================================================================
-- PARTE 3. MANTENIMIENTO Y CRITERIO DE INDEXACION
-- =====================================================================

-- ---------------------------------------------------------------------
-- EJERCICIO 5. Diagnostico de fragmentacion
-- ---------------------------------------------------------------------
-- Ejecute la consulta de abajo (ya dada), que reporta el porcentaje de
-- fragmentacion de los indices de la base. Luego complete la tabla de
-- decision del enunciado clasificando cada caso segun esta regla:
--     < 5-10 %  -> no hacer nada
--     10 % a 30 % -> REORGANIZE
--     > 30 %    -> REBUILD
-- ---------------------------------------------------------------------
SELECT OBJECT_NAME(ips.object_id)        AS NombreTabla,
       i.name                            AS NombreIndice,
       ips.index_type_desc               AS TipoIndice,
       CAST(ips.avg_fragmentation_in_percent AS DECIMAL(5,2)) AS PorcentajeFragmentacion,
       ips.page_count                    AS CantidadPaginas
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
INNER JOIN sys.indexes i
        ON ips.object_id = i.object_id
       AND ips.index_id  = i.index_id
WHERE ips.page_count > 100       -- ignora indices muy pequenos
ORDER BY ips.avg_fragmentation_in_percent DESC;
GO
-- Escriba la sentencia ALTER INDEX que corresponderia para un indice que
-- resultara con fragmentacion ALTA (mayor a 30 %). Use como ejemplo el
-- indice IX_Movimientos_CuentaID.
-- >>> ESCRIBA AQUI SU SOLUCION <<<
ALTER INDEX IX_Movimientos_CuentaID ON dbo.Movimientos REBUILD;

-- Tabla de decision del enunciado:
-- IX_Movimientos_01   6,00 %  -> No hacer nada
-- IX_Movimientos_02  16,33 %  -> ALTER INDEX IX_Movimientos_02 ON dbo.Movimientos REORGANIZE;
-- IX_Saldos_01       86,95 %  -> ALTER INDEX IX_Saldos_01 ON dbo.Cuentas REBUILD;
-- IX_Saldos_02       26,63 %  -> ALTER INDEX IX_Saldos_02 ON dbo.Cuentas REORGANIZE;
-- IX_Clientes_01     27,56 %  -> ALTER INDEX IX_Clientes_01 ON dbo.Clientes REORGANIZE;

GO
-- Nota: en esta base recien cargada es probable que la fragmentacion
-- salga baja (casi 0 %), porque los datos se insertaron en orden. Por eso
-- la CLASIFICACION se practica con la tabla de valores del enunciado; la
-- consulta en vivo sirve para aprender a leer la vista.
-- Pregunta 5: ¿por que REORGANIZE se puede correr en horario laboral pero
-- REBUILD (en ediciones sin opcion ONLINE) se programa de madrugada?
-- Respuesta: REORGANIZE trabaja en linea con bloqueos cortos, asi que los
-- usuarios pueden seguir trabajando. REBUILD reconstruye el indice completo
-- y, sin ONLINE, bloquea la tabla mientras dura; por eso se hace cuando
-- casi no hay usuarios.


-- ---------------------------------------------------------------------
-- EJERCICIO 6. Criterio: ¿cuando NO conviene un indice?
-- ---------------------------------------------------------------------
-- Este ejercicio es de criterio, sin codigo. En el enunciado hay una
-- tabla con varios escenarios; marque para cada uno si procede o no un
-- indice y justifique en una linea. Para comprobar el caso de la columna
-- de BAJA selectividad, ejecute la consulta de abajo y observe el plan:
-- a pesar de que podria existir un indice, el optimizador prefiere un
-- scan porque el filtro devuelve una fraccion muy grande de la tabla.
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS Depositos
FROM dbo.Movimientos
WHERE TipoMovimiento = 'Deposito';   -- ~50 % de las filas
GO
-- Resultado esperado: como 'Deposito' representa cerca de la mitad de la
-- tabla (baja selectividad), un indice sobre TipoMovimiento no ayudaria;
-- el optimizador usaria un scan de todas formas.
-- Obtenido: 50 007 depositos (~50 %) con un Clustered Index Scan.
--
-- Tabla de criterio del enunciado:
-- Llave primaria de una tabla grande  -> Si: se usa para buscar y unir filas.
-- Llave foranea usada en muchos JOIN  -> Si: acelera los JOIN.
-- Columna de estado (Deposito/Retiro) -> No: baja selectividad, se hace scan igual.
-- Columna de texto largo (Descripcion)-> No: indice pesado y poco util.
-- Correo (valores unicos) en el WHERE -> Si: alta selectividad, permite Index Seek.


-- =====================================================================
-- PREGUNTAS DE REPASO
-- =====================================================================
-- 1. ¿En que direccion se lee un plan de ejecucion en SQL Server?
-- 2. ¿Que diferencia hay entre un Scan y un Seek?
-- 3. Mencione dos senales, en el plan o en las estadisticas, de que a una
--    consulta le falta un indice.
-- 4. ¿Cuáles heuristicas aplico en el Ejercicio 4 y que logra cada una?
-- 5. ¿Cuando se usa REORGANIZE y cuando REBUILD?
-- 6. De un ejemplo de columna donde NO conviene crear un indice.
--
-- Respuestas:
-- 1. De derecha a izquierda y de arriba hacia abajo.
-- 2. El Scan recorre toda la tabla; el Seek va directo a las filas que
--    cumplen el filtro usando un indice.
-- 3. Un Table Scan / Clustered Index Scan costoso que devuelve pocas filas,
--    y muchas logical reads en STATISTICS IO.
-- 4. Proyeccion temprana (solo las columnas necesarias: filas mas livianas)
--    y seleccion temprana (filtrar pronto: menos filas que procesar).
-- 5. REORGANIZE con fragmentacion entre 10 % y 30 %; REBUILD con mas de 30 %.
-- 6. TipoMovimiento: tiene pocos valores distintos (baja selectividad).


-- =====================================================================
-- LIMPIEZA (opcional)
-- =====================================================================
-- Para dejar la base como estaba, elimine el indice y los datos de carga:
--   DROP INDEX IX_Movimientos_CuentaID ON dbo.Movimientos;
--   (y vuelva a ejecutar BANCA_DIGITAL.sql para restaurar los datos).
