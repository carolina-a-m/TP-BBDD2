-- ============================================================
-- TP BDD2 2026 - Grupo G06 / G15
-- Script 02: bd_datawarehouse_2025_G15 - Creacion completa desde cero
-- Incluye todas las tablas del DW, filas sentinel y PK correcta
-- ============================================================

USE [bd_datawarehouse_2025_G15]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ============================================================
-- DIMENSIONES
-- ============================================================

-- DIM_TIEMPO
CREATE TABLE [dbo].[DIM_TIEMPO](
    [SK_TIEMPO]          INT IDENTITY(1,1) PRIMARY KEY,
    [Fecha]              DATE         NOT NULL,
    [Dia]                INT          NOT NULL,
    [Mes]                INT          NOT NULL,
    [NombreMes]          VARCHAR(20)  NOT NULL,
    [Trimestre]          INT          NOT NULL,
    [Semestre]           INT          NOT NULL,
    [Anio]               INT          NOT NULL,
    [DiaSemana]          INT          NOT NULL,
    [NombreDiaSemana]    VARCHAR(20)  NOT NULL,
    [EsFinDeSemana]      BIT          NOT NULL,
    [EsFeriado]          BIT          NOT NULL,
    [NombreFeriado]      VARCHAR(100) NULL
) ON [PRIMARY]
GO

-- DIM_PRODUCTO
CREATE TABLE [dbo].[DIM_PRODUCTO](
    [SK_PRODUCTO]        INT IDENTITY(1,1) PRIMARY KEY,
    [ProductoID]         INT          NOT NULL,
    [Detalle]            VARCHAR(100) NOT NULL,
    [Rubro]              VARCHAR(50)  NOT NULL,
    [Presentacion]       VARCHAR(100) NOT NULL,
    [EsDiet]             BIT          NOT NULL,
    [CapacidadML]        INT          NOT NULL,
    [TipoEnvase]         VARCHAR(20)  NOT NULL
) ON [PRIMARY]
GO

-- DIM_CLIENTE
CREATE TABLE [dbo].[DIM_CLIENTE](
    [SK_CLIENTE]         INT IDENTITY(1,1) PRIMARY KEY,
    [CustomerID]         VARCHAR(50)  NOT NULL,
    [NombreCompleto]     VARCHAR(100) NOT NULL,
    [FechaNacimiento]    DATE         NULL,
    [TipoCliente]        VARCHAR(20)  NOT NULL,
    [Ciudad]             VARCHAR(100) NULL,
    [Estado]             VARCHAR(100) NULL,
    [Region]             VARCHAR(100) NULL,
    [ZipCode]            VARCHAR(100) NULL
) ON [PRIMARY]
GO

-- DIM_EMPLEADO
-- Incluye fila sentinel SK=-1 para el employee_id 536871149
-- que existe en ventas historicas pero no en el archivo de empleados
CREATE TABLE [dbo].[DIM_EMPLEADO](
    [SK_EMPLEADO]        INT IDENTITY(1,1) PRIMARY KEY,
    [EmployeeID]         VARCHAR(50)  NOT NULL,
    [NombreCompleto]     VARCHAR(100) NOT NULL,
    [Genero]             VARCHAR(10)  NULL,
    [Categoria]          VARCHAR(50)  NULL,
    [FechaIngreso]       DATE         NULL,
    [NivelEducativo]     VARCHAR(50)  NULL,
    [Edad]               INT          NULL,
    [FechaNacimiento]    DATE         NULL,
    [Antiguedad]         INT          NULL,
    [GrupoEtario]        VARCHAR(30)  NULL
) ON [PRIMARY]
GO

-- Fila sentinel DIM_EMPLEADO
SET IDENTITY_INSERT dbo.DIM_EMPLEADO ON;
INSERT INTO dbo.DIM_EMPLEADO
    (SK_EMPLEADO, EmployeeID, NombreCompleto, Genero, Categoria,
     FechaIngreso, NivelEducativo, Edad, FechaNacimiento, Antiguedad, GrupoEtario)
VALUES
    (-1, '536871149', 'N/A', 'N/A', 'N/A', NULL, 'N/A', NULL, NULL, NULL, 'N/A');
SET IDENTITY_INSERT dbo.DIM_EMPLEADO OFF;
GO

-- DIM_GEOGRAFIA
-- Las 275 filas se cargan via Dim-regiones.dtsx desde stg_regiones_G06
-- Incluye fila sentinel SK=-1 para ventas historicas que no tienen region
CREATE TABLE [dbo].[DIM_GEOGRAFIA](
    [SK_GEOGRAFIA]       INT IDENTITY(1,1) PRIMARY KEY,
    [Region]             VARCHAR(100) NOT NULL,
    [Estado]             VARCHAR(100) NOT NULL,
    [Ciudad]             VARCHAR(100) NOT NULL,
    [ZipCode]            VARCHAR(100) NULL
) ON [PRIMARY]
GO

-- Fila sentinel DIM_GEOGRAFIA
SET IDENTITY_INSERT dbo.DIM_GEOGRAFIA ON;
INSERT INTO dbo.DIM_GEOGRAFIA (SK_GEOGRAFIA, Region, Estado, Ciudad, ZipCode)
VALUES (-1, 'N/A', 'N/A', 'N/A', 'N/A');
SET IDENTITY_INSERT dbo.DIM_GEOGRAFIA OFF;
GO

-- DIM_SUCURSAL
-- Solo 2 valores de negocio: 1=Retail, 2=Wholesale
-- Incluye fila sentinel SK=-1 para ventas historicas que no tienen sucursal
CREATE TABLE [dbo].[DIM_SUCURSAL](
    [SK_SUCURSAL]        INT IDENTITY(1,1) PRIMARY KEY,
    [SucursalID]         INT          NOT NULL,
    [TipoSucursal]       VARCHAR(50)  NOT NULL
) ON [PRIMARY]
GO

-- Filas de negocio DIM_SUCURSAL
SET IDENTITY_INSERT dbo.DIM_SUCURSAL ON;
INSERT INTO dbo.DIM_SUCURSAL (SK_SUCURSAL, SucursalID, TipoSucursal)
VALUES
    (-1, -1, 'N/A'),     -- sentinel para ventas historicas sin sucursal
    (1,   1, 'Retail'),
    (2,   2, 'Wholesale');
SET IDENTITY_INSERT dbo.DIM_SUCURSAL OFF;
GO


-- ============================================================
-- FACT TABLES
-- ============================================================

-- FACT_VENTAS
-- PK: (BillingID, SK_PRODUCTO) — granularidad: linea de producto por factura
-- Cambio respecto al original: PK original era (SK_TIEMPO, SK_PRODUCTO,
-- SK_CLIENTE, SK_EMPLEADO, SK_GEOGRAFIA, BillingID) lo cual generaba
-- duplicados porque multiples filas del mismo billing+producto violaban la constraint.
-- Columnas agregadas respecto al original: SK_SUCURSAL, Total, TotalDescuento
CREATE TABLE [dbo].[FACT_VENTAS](
    [SK_TIEMPO]           INT            NOT NULL,
    [SK_PRODUCTO]         INT            NOT NULL,
    [SK_CLIENTE]          INT            NOT NULL,
    [SK_EMPLEADO]         INT            NOT NULL,
    [SK_GEOGRAFIA]        INT            NOT NULL,
    [SK_SUCURSAL]         INT            NULL,
    [BillingID]           INT            NOT NULL,
    [Cantidad]            INT            NOT NULL,
    [Litros]              DECIMAL(18,2)  NOT NULL,
    [MontoBruto]          DECIMAL(18,2)  NOT NULL,
    [Total]               DECIMAL(18,2)  NOT NULL,
    [PorcentajeDescuento] DECIMAL(5,2)   NULL,
    [TotalDescuento]      DECIMAL(18,2)  NOT NULL,
    [MontoNeto]           DECIMAL(18,2)  NOT NULL,
    CONSTRAINT PK_FACT_VENTAS PRIMARY KEY (BillingID, SK_PRODUCTO),
    CONSTRAINT FK_FACT_VENTAS_TIEMPO    FOREIGN KEY (SK_TIEMPO)    REFERENCES DIM_TIEMPO(SK_TIEMPO),
    CONSTRAINT FK_FACT_VENTAS_PRODUCTO  FOREIGN KEY (SK_PRODUCTO)  REFERENCES DIM_PRODUCTO(SK_PRODUCTO),
    CONSTRAINT FK_FACT_VENTAS_CLIENTE   FOREIGN KEY (SK_CLIENTE)   REFERENCES DIM_CLIENTE(SK_CLIENTE),
    CONSTRAINT FK_FACT_VENTAS_EMPLEADO  FOREIGN KEY (SK_EMPLEADO)  REFERENCES DIM_EMPLEADO(SK_EMPLEADO),
    CONSTRAINT FK_FACT_VENTAS_GEOGRAFIA FOREIGN KEY (SK_GEOGRAFIA) REFERENCES DIM_GEOGRAFIA(SK_GEOGRAFIA),
    CONSTRAINT FK_FACT_VENTAS_SUCURSAL  FOREIGN KEY (SK_SUCURSAL)  REFERENCES DIM_SUCURSAL(SK_SUCURSAL)
) ON [PRIMARY]
GO

-- FACT_STOCK
CREATE TABLE [dbo].[FACT_STOCK](
    [SK_TIEMPO]      INT            NOT NULL,
    [SK_PRODUCTO]    INT            NOT NULL,
    [Variacion]      DECIMAL(18,2)  NOT NULL,
    [StockAcumulado] DECIMAL(18,2)  NOT NULL,
    CONSTRAINT PK_FACT_STOCK    PRIMARY KEY (SK_TIEMPO, SK_PRODUCTO),
    CONSTRAINT FK_FACT_STOCK_TIEMPO   FOREIGN KEY (SK_TIEMPO)   REFERENCES DIM_TIEMPO(SK_TIEMPO),
    CONSTRAINT FK_FACT_STOCK_PRODUCTO FOREIGN KEY (SK_PRODUCTO) REFERENCES DIM_PRODUCTO(SK_PRODUCTO)
) ON [PRIMARY]
GO


-- ============================================================
-- VERIFICACION POST-CREACION
-- Ejecutar despues de correr todos los paquetes SSIS
-- ============================================================

-- Verificar filas sentinel
SELECT SK_GEOGRAFIA, Region FROM dbo.DIM_GEOGRAFIA  WHERE SK_GEOGRAFIA = -1;
SELECT SK_EMPLEADO,  EmployeeID FROM dbo.DIM_EMPLEADO   WHERE SK_EMPLEADO  = -1;
SELECT SK_SUCURSAL,  TipoSucursal FROM dbo.DIM_SUCURSAL WHERE SK_SUCURSAL  = -1;

-- Verificar PK de FACT_VENTAS (debe mostrar BillingID y SK_PRODUCTO)
SELECT i.name, c.name AS columna
FROM sys.indexes i
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.is_primary_key = 1 AND OBJECT_NAME(i.object_id) = 'FACT_VENTAS';

-- Verificar carga de FACT_VENTAS (debe dar 1.655.278 filas)
SELECT COUNT(*) AS total_filas FROM dbo.FACT_VENTAS;
GO
