UPDATE t
SET t.EsFeriado = 1,
    t.NombreFeriado = h.HOLIDAY
FROM [dbo].[DIM_TIEMPO] t
JOIN bd_staging_2026_G06.dbo.stg_holidays_G06 h
    ON CAST(h.[DATE] AS DATE) = t.Fecha;
