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

## Ejecución reproducible

La ejecución `499707929365566` terminó `SUCCESS` después de incorporar las
tareas automáticas al Job:

1. `initialize_product_cdc`: comprueba o crea `batch_1` sin sobrescribirlo;
2. `run_retail_pipeline`: procesa Bronze, Silver, SCD2 y Gold;
3. `create_metric_view`: crea y valida `retail_product_metrics`;
4. `validate_gold`, If/Else y For Each: comprueban y resumen las capas.

Esto elimina la dependencia de ejecutar manualmente SQL para una instalación
limpia mediante CI/CD.

## Evidencia CI/CD

- Validación PR retail: `SUCCESS`.
- Desarrollo: GitHub Actions run `32803455440`, `SUCCESS` en 2m54s.
- Producción: GitHub Actions run `32803696618`, `SUCCESS` en 2m56s.
- `CI_ENABLED=true`.
- Autenticación separada: `sp-dab-dev` y `sp-dab-prod` mediante OAuth M2M.
- Secretos aislados en los GitHub Environments `dev` y `prod`.
- Permiso de la fuente limitado a `USE CATALOG`, `USE SCHEMA` y `SELECT` sobre
  `sales_orders`; ambos principals tienen `CAN_USE` en el SQL Warehouse.

El workflow de desarrollo demostró la creación del lote 1 en un schema limpio,
el despliegue del Bundle y la ejecución completa del Job sin intervención
manual. La promoción `dev -> main` repitió la misma prueba en `dab_lab_prod`.

La promoción final quedó registrada en:

- PR `codex/retail-migration -> dev`: `#5`.
- Validación de PR a dev: GitHub Actions run `32803964144`, `SUCCESS`.
- Desarrollo: GitHub Actions run `32803982974`, `SUCCESS`.
- PR `dev -> main`: `#6`.
- Validación de PR a main: GitHub Actions run `32804186576`, `SUCCESS`.
- Producción: GitHub Actions run `32804204987`, `SUCCESS`.
- Job de producción: `366611526779544`.
- Pipeline de producción: `452a8dc0-d3a0-48e8-b797-a8c69b9588b1`.
- Dashboard de producción: `01f1a0318a5f197e8dcd4375b74d85b2`.

## Evidencia de gobernanza

- Usuario docente: `jg.moricem@gmail.com`.
- Objeto compartido: dashboard
  `production-luis_acuna-retail-dashboard`.
- Permiso: `CAN_READ`.
- Credenciales del dashboard publicado: embebidas por el principal de
  producción.
- No se otorgó acceso docente a Bronze, Silver, Gold, desarrollo, pipeline ni
  Job.

## Enlaces

- Pipeline: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/pipelines/74146ccc-f59f-4acc-adaf-711f1c5233bc?w=7474647652788276>
- Job: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/jobs/25235949448081?w=7474647652788276>
- Dashboard: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/dashboardsv3/01f1a02a3b671f0384f43f3748b05845/published?w=7474647652788276>
- Dashboard de producción: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/dashboardsv3/01f1a0318a5f197e8dcd4375b74d85b2/published?w=7474647652788276>
- Schema: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/explore/data/dab_lab_dev/dev_luis_acuna11_retail_luis_acuna?w=7474647652788276>
- GitHub Actions dev: <https://github.com/LuisAcuna-27/governed-retail-pipeline-databricks/actions/runs/32803455440>
- GitHub Actions prod: <https://github.com/LuisAcuna-27/governed-retail-pipeline-databricks/actions/runs/32803696618>
- GitHub Actions dev final: <https://github.com/LuisAcuna-27/governed-retail-pipeline-databricks/actions/runs/32803982974>
- GitHub Actions prod final: <https://github.com/LuisAcuna-27/governed-retail-pipeline-databricks/actions/runs/32804204987>
