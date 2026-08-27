# Governed Retail Order Analytics Pipeline on Databricks

Proyecto final del Módulo 3 del Técnico en Ingeniería de Datos con Databricks.
Implementa una arquitectura medallion gobernada con Lakeflow Declarative
Pipelines, Auto Loader, AUTO CDC SCD Tipo 2, Metric Views, Lakeflow Jobs,
Databricks Asset Bundles y GitHub Actions.

## Pregunta de negocio

> ¿Cómo se distribuyen los ingresos, unidades y pedidos mensuales entre los
> productos y niveles del portafolio, y cómo cambia el análisis cuando un
> producto se reclasifica?

## Datos seleccionados

- Listing: `Simulated Retail Customer Data` de Databricks Marketplace.
- Tabla de hechos: `databricks_simulated_retail_customer_data.v01.sales_orders`.
- Fuente: 4,074 snapshots de órdenes; el pipeline conserva el snapshot más
  reciente de 4,000 órdenes y genera 7,997 líneas de producto.
- Periodo de los datos: 2019-08-01 a 2019-11-14. Es un escenario simulado e
  histórico; no se presenta como desempeño comercial actual.
- Dimensión propia: portafolio gobernado de productos, definido para el
  proyecto y actualizado mediante dos lotes JSON.

La tabla `sales_orders` se adapta mejor a la rúbrica que la opción aérea: tiene
una llave de orden explícita, productos embebidos que permiten modelar el grano
de línea y una unión natural con la dimensión CDC por `product_id`.

## Arquitectura

```text
Marketplace sales_orders ----------------------> bronze_orders (streaming)
                                                        |
JSON en Unity Catalog Volume -> Auto Loader -> bronze_product_cdc (streaming)
                                                        |
                               silver_order_items + dim_product SCD2
                                                        |
                                      gold_retail_order_items
                                                        |
                                        gold_retail_monthly
                                                        |
                                       retail_product_metrics
                                                        |
                                            Dashboard AI/BI
```

`sales_orders` es el hecho y no recibe CDC. El CDC se aplica a la dimensión
independiente `dim_product`; su llave de negocio es `product_id` y el orden de
los cambios lo controla `sequence_ts`.

## Componentes principales

- [`src/retail_pipeline.sql`](src/retail_pipeline.sql): Bronze, Silver, SCD2 y Gold.
- [`sql/generate_batch_1.sql`](sql/generate_batch_1.sql): lote inicial generado
  a partir de los 98 productos reales, más un registro sintético de control.
- [`data/cdc/batch_2.json`](data/cdc/batch_2.json): UPDATE, INSERT y DELETE.
- [`sql/metric_view.sql`](sql/metric_view.sql): capa semántica gobernada.
- [`dashboards/retail_dashboard.lvdash.json`](dashboards/retail_dashboard.lvdash.json):
  dashboard AI/BI que consulta la Metric View.
- [`sql/explore_dataset.sql`](sql/explore_dataset.sql): recorrido reproducible.
- [`docs/dataset-walkthrough.md`](docs/dataset-walkthrough.md): explicación del
  dataset, llaves, capas y relación con la rúbrica.
- [`docs/first-run-evidence.md`](docs/first-run-evidence.md): ejecuciones y
  resultados comprobados en Databricks.

## Despliegue en desarrollo

```powershell
databricks auth login --host https://dbc-cbc2bb58-ee6e.cloud.databricks.com
databricks bundle validate -t development
databricks bundle deploy -t development
databricks bundle run -t development retail_job
```

El primer lote se genera ejecutando `sql/generate_batch_1.sql` después de crear
el schema y el Volume. El Job ejecuta esta inicialización automáticamente y la
omite de forma idempotente cuando `batch_1` ya existe. También crea o reemplaza
la Metric View después del pipeline. Tras la primera ejecución se carga
`batch_2.json` en la raíz del Volume y se vuelve a ejecutar el Job para demostrar
el historial SCD2.

## Ambientes y estrategia Git

- `feature/*`: desarrollo aislado.
- `dev`: integración y despliegue a `dab_lab_dev`.
- `main`: producción en `dab_lab_prod`, mediante Pull Request desde `dev`.
- GitHub Environments: `dev` y `prod` con credenciales OAuth M2M.
- Los workflows permanecen protegidos por `CI_ENABLED` y usan credenciales OAuth
  M2M almacenadas por separado en los Environments `dev` y `prod`.

## Acceso docente gobernado

El dashboard de producción está publicado con credenciales embebidas y comparte
únicamente permiso `CAN_READ` con `jg.moricem@gmail.com`. Este acceso no concede
permisos directos sobre Bronze, Silver, Gold, el catálogo de desarrollo, el
pipeline ni el Job.

- Dashboard de producción: <https://dbc-cbc2bb58-ee6e.cloud.databricks.com/dashboardsv3/01f1a0318a5f197e8dcd4375b74d85b2/published?w=7474647652788276>
