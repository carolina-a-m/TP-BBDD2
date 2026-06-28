-- ============================================================
-- TP BDD2 2026 - Grupo G06 / G15
-- Script 01: bd_staging_2026_G06 - Creacion completa desde cero
-- Incluye todas las tablas de staging y la vista final
-- ============================================================

USE [bd_staging_2026_G06]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- TABLAS DE STAGING
-- ============================================================

-- Ventas actuales: cabecera (fuente MySQL - sales.billing)
CREATE TABLE [dbo].[stg_billing_G06](
    [id]          [int] NULL,
    [billing_id]  [int] NULL,
    [date]        [datetime] NULL,
    [customer_id] [int] NULL,
    [employee_id] [int] NULL,
    [product_id]  [int] NULL,
    [quantity]    [int] NULL,
    [region]      [varchar](45) NULL
) ON [PRIMARY]
GO

-- Ventas actuales: detalle de lineas (fuente MySQL - sales.billing_detail)
CREATE TABLE [dbo].[stg_billing_detail_G06](
    [billing_id]  [int] NULL,
    [product_id]  [int] NULL,
    [quantity]    [int] NULL
) ON [PRIMARY]
GO

-- Ventas historicas (fuente SQL Server 2000-2008 - TDChistorySales)
-- No tiene region ni branch_id: se manejan con sentinel -1 en la vista
CREATE TABLE [dbo].[stg_billing_history_G06](
    [id]          [int] NULL,
    [billing_id]  [int] NULL,
    [date]        [datetime] NULL,
    [customer_id] [int] NULL,
    [employee_id] [int] NULL,
    [product_id]  [int] NULL,
    [quantity]    [int] NULL
) ON [PRIMARY]
GO

-- Precios de productos a lo largo del tiempo (fuente MySQL - sales.prices)
CREATE TABLE [dbo].[stg_prices_G06](
    [product_id]  [nvarchar](255) NULL,
    [date]        [nvarchar](255) NULL,
    [price]       [nvarchar](255) NULL
) ON [PRIMARY]
GO

-- Descuentos aplicables a facturas (fuente MySQL - sales.discounts)
CREATE TABLE [dbo].[stg_discounts_G06](
    [discount_id]   [nvarchar](255) NULL,
    [from]          [nvarchar](255) NULL,
    [until]         [nvarchar](255) NULL,
    [total_billing] [nvarchar](255) NULL,
    [percentage]    [nvarchar](255) NULL
) ON [PRIMARY]
GO

-- Clientes mayoristas (fuente XML - customer_W.xml)
CREATE TABLE [dbo].[stg_customer_may_G06](
    [CUSTOMER_ID]  [nvarchar](255) NULL,
    [FULL_NAME]    [nvarchar](255) NULL,
    [BIRTH_DATE]   [nvarchar](255) NULL,
    [CITY]         [nvarchar](255) NULL,
    [STATE]        [nvarchar](255) NULL,
    [ZIPCODE]      [nvarchar](255) NULL
) ON [PRIMARY]
GO

-- Clientes minoristas (fuente XML - customer_R.xml)
CREATE TABLE [dbo].[stg_customer_min_G06](
    [CUSTOMER_ID]  [nvarchar](255) NULL,
    [FULL_NAME]    [nvarchar](255) NULL,
    [BIRTH_DATE]   [nvarchar](255) NULL,
    [CITY]         [nvarchar](255) NULL,
    [STATE]        [nvarchar](255) NULL,
    [ZIPCODE]      [nvarchar](255) NULL
) ON [PRIMARY]
GO

-- Empleados (fuente XLS - Employee.xls)
CREATE TABLE [dbo].[stg_empleados_G06](
    [EMPLOYEE_ID]     [nvarchar](255) NULL,
    [FULL_NAME]       [nvarchar](255) NULL,
    [CATEGORY]        [nvarchar](255) NULL,
    [EMPLOYMENT_DATE] [nvarchar](255) NULL,
    [BIRTH_DATE]      [nvarchar](255) NULL,
    [EDUCATION_LEVEL] [nvarchar](255) NULL,
    [GENDER]          [nvarchar](255) NULL
) ON [PRIMARY]
GO

-- Feriados (fuente XLS - Holidays.xls)
CREATE TABLE [dbo].[stg_holidays_G06](
    [DATE]    [nvarchar](255) NULL,
    [HOLIDAY] [nvarchar](255) NULL
) ON [PRIMARY]
GO

-- Productos (fuente TXT - Products.txt)
CREATE TABLE [dbo].[stg_productos_G06](
    [CodProducto]          [varchar](100) NULL,
    [DescrProducto]        [varchar](100) NULL,
    [PresentacionProducto] [varchar](100) NULL
) ON [PRIMARY]
GO

-- Regiones/ciudades (fuente TXT - Regions.txt)
CREATE TABLE [dbo].[stg_regiones_G06](
    [Region]    [varchar](100) NULL,
    [Estado]    [varchar](100) NULL,
    [Ciudad]    [varchar](100) NULL,
    [CodPostal] [varchar](100) NULL
) ON [PRIMARY]
GO

-- Stock de productos (fuente TXT - Stock.txt)
CREATE TABLE [dbo].[stg_stock_G06](
    [CodProdStock] [varchar](100) NULL,
    [Fecha]        [varchar](100) NULL,
    [Variation]    [decimal](18, 2) NULL
) ON [PRIMARY]
GO


-- ============================================================
-- VISTA: vw_stg_ventas_procesadas (version final)
--
-- Cambios respecto al original:
--   1. VentasHistoricas: region = 'N/A' (la fuente historica no tiene region)
--   2. VentasHistoricas: branch_id = -1 (la fuente historica no tiene sucursal)
--   3. VentasActuales: region mapea 'NORTH' -> 'Central' para alinear con DIM_GEOGRAFIA
--   4. VentasActuales: GROUP BY para consolidar lineas duplicadas por producto
--   5. VentasDeduplicadas: CTE nuevo que elimina duplicados BillingID+ProductoID
--      que aparecen cuando un billing_id existe en AMBAS fuentes (historica y actual)
--   6. Precio vigente via OUTER APPLY sobre stg_prices_G06
--   7. Descuento por factura: maximo porcentaje aplicable segun fecha y monto total
--   8. Join con DIM_PRODUCTO para obtener CapacidadML y calcular Litros
-- ============================================================

CREATE VIEW [dbo].[vw_stg_ventas_procesadas] AS
WITH
VentasHistoricas AS (
    SELECT
        billing_id,
        [date]        AS Fecha,
        customer_id,
        employee_id,
        product_id,
        SUM(quantity) AS quantity,
        -1            AS branch_id,   -- sentinel: historico no tiene sucursal
        'N/A'         AS region       -- sentinel: historico no tiene region
    FROM dbo.stg_billing_history_G06
    WHERE product_id IS NOT NULL
    GROUP BY billing_id, [date], customer_id, employee_id, product_id
),
VentasActuales AS (
    SELECT
        b.billing_id,
        b.[date]          AS Fecha,
        b.customer_id,
        b.employee_id,
        bd.product_id,
        SUM(bd.quantity)  AS quantity,
        b.branch_id,
        CASE
            WHEN UPPER(b.region) = 'NORTH' THEN 'Central'
            ELSE b.region
        END               AS region
    FROM dbo.stg_billing_G06 b
    INNER JOIN dbo.stg_billing_detail_G06 bd ON b.billing_id = bd.billing_id
    WHERE bd.product_id IS NOT NULL
    GROUP BY b.billing_id, b.[date], b.customer_id, b.employee_id,
             bd.product_id, b.branch_id, b.region
),
VentasUnificadas AS (
    SELECT * FROM VentasHistoricas
    UNION ALL
    SELECT * FROM VentasActuales
),
VentasDeduplicadas AS (
    -- Consolida casos donde el mismo billing_id+product_id aparece
    -- en ambas fuentes (historica y actual)
    SELECT
        billing_id,
        MIN(Fecha)       AS Fecha,
        customer_id,
        employee_id,
        product_id,
        SUM(quantity)    AS quantity,
        MIN(branch_id)   AS branch_id,
        MIN(region)      AS region
    FROM VentasUnificadas
    GROUP BY billing_id, customer_id, employee_id, product_id
),
VentasConPrecio AS (
    SELECT
        v.*,
        ISNULL(p.PriceVigente, 0)                        AS PrecioUnitario,
        v.quantity * ISNULL(p.PriceVigente, 0)           AS MontoBrutoLinea
    FROM VentasDeduplicadas v
    OUTER APPLY (
        SELECT TOP 1 TRY_CAST(pr.price AS DECIMAL(18,2)) AS PriceVigente
        FROM dbo.stg_prices_G06 pr
        WHERE TRY_CAST(pr.product_id AS INT) = v.product_id
          AND TRY_CAST(pr.[date] AS DATETIME) <= v.Fecha
        ORDER BY TRY_CAST(pr.[date] AS DATETIME) DESC
    ) p
),
CabeceraFactura AS (
    SELECT
        billing_id,
        MIN(Fecha)           AS FechaFactura,
        SUM(MontoBrutoLinea) AS TotalFactura
    FROM VentasConPrecio
    GROUP BY billing_id
),
DescuentoPorFactura AS (
    -- Aplica el mejor descuento (mayor porcentaje) vigente para la fecha y monto
    SELECT
        cf.billing_id,
        cf.TotalFactura,
        ISNULL(MAX(TRY_CAST(d.percentage AS DECIMAL(5,2))), 0) AS PorcentajeDescuento
    FROM CabeceraFactura cf
    LEFT JOIN dbo.stg_discounts_G06 d
        ON cf.FechaFactura >= TRY_CAST(d.[from] AS DATETIME)
        AND (d.[until] IS NULL OR cf.FechaFactura <= TRY_CAST(d.[until] AS DATETIME))
        AND cf.TotalFactura >= TRY_CAST(d.total_billing AS DECIMAL(18,2))
    GROUP BY cf.billing_id, cf.TotalFactura
)
SELECT
    CAST(v.Fecha AS DATE)                                                             AS FechaVenta,
    v.billing_id                                                                      AS BillingID,
    CAST(v.customer_id AS VARCHAR(50))                                                AS CustomerID,
    CAST(v.employee_id AS VARCHAR(50))                                                AS EmployeeID,
    v.product_id                                                                      AS ProductoID,
    v.branch_id                                                                       AS BranchID,
    v.region                                                                          AS Region,
    v.quantity                                                                        AS Cantidad,
    CAST((v.quantity * dp.CapacidadML) / 1000.0 AS DECIMAL(18,2))                   AS Litros,
    CAST(v.MontoBrutoLinea AS DECIMAL(18,2))                                         AS MontoBruto,
    CAST(df.TotalFactura AS DECIMAL(18,2))                                           AS Total,
    CAST(df.PorcentajeDescuento AS DECIMAL(5,2))                                     AS PorcentajeDescuento,
    CAST(df.TotalFactura * df.PorcentajeDescuento / 100.0 AS DECIMAL(18,2))         AS TotalDescuento,
    CAST(df.TotalFactura * (1.0 - df.PorcentajeDescuento / 100.0) AS DECIMAL(18,2)) AS MontoNeto
FROM VentasConPrecio v
INNER JOIN DescuentoPorFactura df ON v.billing_id = df.billing_id
INNER JOIN bd_datawarehouse_2025_G15.dbo.DIM_PRODUCTO dp ON v.product_id = dp.ProductoID
WHERE v.Fecha IS NOT NULL;
GO


-- ============================================================
-- VISTA: vw_stg_stock_procesado
-- Una fila por (dia, producto) con stock acumulado al final del dia
-- Fuente: stg_stock_G06 (TXT Stock.txt)
-- Fecha en formato MM/DD/YYYY HH:MM:SS
-- ============================================================

CREATE VIEW [dbo].[vw_stg_stock_procesado] AS
WITH movimientos AS (
    SELECT
        CONVERT(DATE, LEFT(LTRIM(RTRIM(s.Fecha)), 10), 101) AS FechaMovimiento,
        CAST(s.CodProdStock AS INT)                          AS ProductoID,
        s.Variation                                          AS Variacion,
        SUM(s.Variation) OVER (
            PARTITION BY s.CodProdStock
            ORDER BY CONVERT(DATE, LEFT(LTRIM(RTRIM(s.Fecha)), 10), 101),
                     s.Variation
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                    AS StockAcumulado,
        ROW_NUMBER() OVER (
            PARTITION BY CAST(s.CodProdStock AS INT),
                         CONVERT(DATE, LEFT(LTRIM(RTRIM(s.Fecha)), 10), 101)
            ORDER BY CONVERT(DATE, LEFT(LTRIM(RTRIM(s.Fecha)), 10), 101) DESC,
                     s.Variation DESC
        )                                                    AS rn
    FROM [dbo].[stg_stock_G06] s
)
SELECT FechaMovimiento, ProductoID, Variacion, StockAcumulado
FROM movimientos
WHERE rn = 1;
GO
