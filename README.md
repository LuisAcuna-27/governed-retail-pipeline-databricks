# Governed Airline Performance Pipeline on Databricks

Proyecto final del Módulo 3 del Técnico en Ingeniería de Datos con Databricks.

El repositorio implementa un pipeline gobernado de desempeño aéreo histórico con arquitectura medallion, Lakeflow Declarative Pipelines, CDC con SCD Tipo 2, Metric Views, dashboard AI/BI y CI/CD mediante Databricks Asset Bundles y GitHub Actions.

## Pregunta de negocio

> ¿Qué aerolíneas, rutas y meses presentaron mayor riesgo operativo de retrasos, cancelaciones y desvíos durante el primer semestre de 1999?

El proyecto no presenta los resultados como desempeño actual. El periodo histórico se declara de forma explícita en la pregunta, el dashboard y el documento de decisiones.

## Fuente principal

- Marketplace: `Airline Performance Data`.
- Tabla: `databricks_airline_performance_data.v01.flights_small`.
- Volumen de origen: 10,602,522 vuelos de 1998 y 1999.
- Extracto reproducible: `Year = 1999` y `Month BETWEEN 1 AND 6`.
- Dimensión CDC: portafolio gobernado de aerolíneas.

## Arquitectura

```text
Airline Marketplace -----------------------> bronze_flights
                                                   |
JSON CDC en Unity Catalog Volume ----------> bronze_airline_cdc
                                                   |
                                      silver_flights + dim_airline SCD2
                                                   |
                                         gold_airline_monthly
                                                   |
                                    airline_performance_metrics
                                                   |
                                           Dashboard AI/BI
```

Los catálogos `dab_lab_dev` y `dab_lab_prod` separan los ambientes dentro del mismo workspace.

## Estructura

```text
.
├── databricks.yml
├── resources/              # Pipeline, Job, schema y Volume como código
├── src/                    # Transformaciones y notebooks del Job
├── sql/                    # Definición de la Metric View
├── data/cdc/               # Lotes sintéticos insert/update/delete
├── docs/                   # Plan, decisiones y checklist de evidencias
└── .github/workflows/      # Validación y despliegue dev/prod
```

## Validación y despliegue

```powershell
databricks auth login --host https://dbc-cbc2bb58-ee6e.cloud.databricks.com
databricks bundle validate -t development
databricks bundle deploy -t development
databricks bundle run -t development airline_job
```

Antes de ejecutar el pipeline se carga `data/cdc/batch_1.json` en el Volume `airline_cdc`. `batch_2.json` se reserva para la prueba funcional SCD2.

## Estrategia Git

- `feature/*`: cambios reales de código.
- `dev`: integración y despliegue al catálogo de desarrollo.
- `main`: producción; recibe cambios mediante Pull Request desde `dev`.

Los workflows requieren GitHub Environments `dev` y `prod`, credenciales OAuth M2M y la variable `CI_ENABLED=true`.
