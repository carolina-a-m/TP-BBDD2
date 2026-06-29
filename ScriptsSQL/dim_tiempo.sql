DELETE FROM [dbo].[DIM_TIEMPO];

DECLARE @vFechaDesde DATE = '2000-01-01';
DECLARE @vFechaHasta DATE = '2099-12-31';

;WITH Fechas (Fecha) AS (
    SELECT @vFechaDesde
    UNION ALL
    SELECT DATEADD(d,1,Fecha)
    FROM Fechas
    WHERE Fecha < @vFechaHasta)
INSERT INTO [dbo].[DIM_TIEMPO]
    (Fecha, Dia, Mes, NombreMes, Trimestre, Semestre, Anio, DiaSemana, NombreDiaSemana, EsFinDeSemana, EsFeriado, NombreFeriado)
SELECT
    Fecha,
    DAY(Fecha) AS Dia,
    MONTH(Fecha) AS Mes,
    DATENAME(MONTH,Fecha) AS NombreMes,
    DATEPART(QQ,Fecha) AS Trimestre,
    (DATEPART(QQ,Fecha) + 1) / 2 AS Semestre,
    YEAR(Fecha) AS Anio,
    DATEPART(DW,Fecha) AS DiaSemana,
    DATENAME(DW,Fecha) AS NombreDiaSemana,
    CASE WHEN DATEPART(DW,Fecha) IN (1,7) THEN 1 ELSE 0 END AS EsFinDeSemana,
    0 AS EsFeriado,
    NULL AS NombreFeriado
FROM Fechas
OPTION (MAXRECURSION 0);
