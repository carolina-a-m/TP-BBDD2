# TP Final - Bases de Datos 2 - TUIA 2026
## Grupo G06 / G15

Data Warehouse para The Drinking Company (TDC), construido con SQL Server, SSIS y Power BI.

---

## Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `01_staging_G06_completo.sql` | Creación completa de `bd_staging_2026_G06`: tablas y vistas |
| `02_datawarehouse_G15_completo.sql` | Creación completa de `bd_datawarehouse_2025_G15`: dimensiones, facts, sentinels y PK |
| `TP-BDD2.zip` | Proyecto SSIS completo con todos los paquetes `.dtsx` |

---

## Bases de datos (backups)

Los archivos `.bak` están en Google Drive por límite de tamaño de GitHub:

🔗 **[Descargar backups desde Google Drive]([https://drive.google.com/file/d/17wfydg1AL2gYeOuLpkYpDbT2WzbH1YUf/view?usp=drive_link](https://drive.google.com/drive/folders/1fzU8gUplK1PsnpUnH14lYZTV_7Fy3opW?usp=drive_link)**

Contiene:
- `bd_datawarehouse_2025_G15.bak`
- `bd_staging_2026_G06.bak`

---

## Instrucciones para restaurar

### 1. Restaurar las bases de datos

En SSMS, click derecho en **Databases** → **Restore Database**:
- En **Source** seleccioná **Device** → buscás el `.bak`
- Restaurá primero `bd_staging_2026_G06`
- Luego `bd_datawarehouse_2025_G15`

### 2. Abrir el proyecto SSIS

- Descomprimí `TP-BDD2.zip`
- Abrí `TP_BDD2_2026.sln` con Visual Studio
- En cada Connection Manager actualizá el nombre del servidor local (reemplazá `COMPUDEPEPERINA\SQLEXPRESS` por el tuyo)

### 3. Orden de ejecución de paquetes

Ejecutar en este orden desde Visual Studio:

**Dimensiones primero:**
1. `Dim-billing.dtsx`
2. `Dim-customers.dtsx`
3. `Dim-empleados.dtsx`
4. `Dim-holidays.dtsx`
5. `Dim-productos.dtsx`
6. `Dim-regiones.dtsx`
7. `Dim-stock.dtsx`

**Facts después:**

8. `Fact-stock.dtsx`
9. `Fact-ventas.dtsx`

---

## Notas importantes

- Los scripts SQL crean las bases **desde cero**. Si ya existen las bases, borrarlas antes de ejecutar los scripts.
- `bd_datawarehouse_2025_G15` incluye filas sentinel (SK = -1) en DIM_GEOGRAFIA, DIM_EMPLEADO y DIM_SUCURSAL para manejar ventas históricas sin datos geográficos ni de sucursal.
- La PK de `FACT_VENTAS` es `(BillingID, SK_PRODUCTO)` — granularidad por línea de producto por factura.
- `Fact-ventas.dtsx` tarda aproximadamente 7 minutos en ejecutarse (1.655.278 filas).
- El componente **Búsqueda Geografía** en `Fact-ventas.dtsx` usa modo **Partial cache** y join por columna `Region`.

---

## Fuentes de datos externas

| Fuente | Servidor | Base | Usuario | Contraseña |
|---|---|---|---|---|
| SQL Server (histórico) | `server-tuia.database.windows.net` | `TDChistorySales` | `alumno` | `tp#BBDD2` |
| MySQL (ventas actuales) | `132.226.43.0:3306` | `sales` | `alumno` | `tp#BBDD2` |
