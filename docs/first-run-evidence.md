# Evidencia de ejecución en desarrollo

Fecha de prueba: 24 de agosto de 2026, zona horaria de Costa Rica.

## Recursos desplegados

- Catálogo y schema: `dab_lab_dev.dev_luis_acuna11_retail_luis_acuna`.
- Volume CDC: `product_cdc`.
- Pipeline ID: `74146ccc-f59f-4acc-adaf-711f1c5233bc`.
- Job ID: `25235949448081`.
- Dashboard ID: `01f1a02a3b671f0384f43f3748b05845`.
- Fuente: `databricks_simulated_retail_customer_data.v01.sales_orders`.

## Lote 1

- Actualización full refresh: `627d2616-e6ad-472e-812f-b9eaa3f3dc25`, completada.
- Ejecución del Job: `552882189776917`, `SUCCESS`.

| Objeto | Filas |
|---|---:|
| `bronze_orders` | 4,074 |
| `bronze_product_cdc` | 99 |
| `dim_product` versiones | 99 |
| `dim_product` vigentes | 99 |
| `silver_order_items` | 7,997 |
| `gold_retail_order_items` | 7,997 |
| `gold_retail_monthly` | 427 |

Ingreso bruto comprobado: `10,458,619`.

## Expectations

El Event Log registró para `silver_order_items`:

| Expectation | Aprobados | Fallidos | Comportamiento |
|---|---:|---:|---|
| `valid_order_key` | 7,997 | 0 | FAIL UPDATE |
| `valid_product_key` | 7,997 | 0 | DROP ROW |
| `valid_commercial_values` | 7,997 | 0 | WARN |

Consulta de evidencia: statement `01f1a029-603f-1364-bce2-119aed7b4ed6`.

## Lote 2

- Ejecución del Job: `665779803870146`, `SUCCESS`.
- CDC acumulado: 102 eventos.
- Dimensión: 101 versiones, 99 vigentes.

Resultados SCD2:

- `AVqVGaCCU2_QcyX9Ozcf`: `strategic` desde `2019-08-01` hasta
  `2019-11-15`; `critical` vigente desde `2019-11-15`.
- `SYN-CONTROL-PRODUCT`: versión cerrada en `2019-11-15`.
- `SYN-NEW-PRODUCT`: versión vigente desde `2019-11-15`.

La Metric View mostró la reclasificación sin cambiar el total de ingresos:

| Nivel | Ingreso total |
|---|---:|
| `critical` | 1,084,124 |
| `strategic` | 3,861,893 |
| `managed` | 3,959,339 |
| `standard` | 1,553,263 |

## Enlaces

- Pipeline: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/pipelines/74146ccc-f59f-4acc-adaf-711f1c5233bc?w=7474647652788276>
- Job: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/jobs/25235949448081?w=7474647652788276>
- Dashboard: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/dashboardsv3/01f1a02a3b671f0384f43f3748b05845/published?w=7474647652788276>
- Schema: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/explore/data/dab_lab_dev/dev_luis_acuna11_retail_luis_acuna?w=7474647652788276>
