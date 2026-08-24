# Governed Weather Pipeline on Databricks

Proyecto final del Módulo 3 del Técnico en Ingeniería de Datos con Databricks.

El repositorio implementa un pipeline gobernado de observaciones meteorológicas NOAA con arquitectura medallion, Lakeflow Declarative Pipelines, CDC con SCD Tipo 2, Metric Views, dashboard AI/BI y CI/CD mediante Databricks Asset Bundles y GitHub Actions.

## Pregunta de negocio

> ¿Qué estaciones y zonas del Caribe y del corredor tropical americano presentaron mayor exposición histórica a calor extremo y precipitación intensa entre 2022 y febrero de 2024?

## Fuente principal

- Marketplace: `Daily Weather Observations | NOAA`
- Tabla: `rearc_daily_weather_observations_noaa.esg_noaa_ghcn.noaa_ghcn_daily`
- Extracto reproducible: fecha desde `2022-01-01`, latitud entre 5 y 25 y longitud entre -100 y -60.
- Perfil del extracto: aproximadamente 114,439 observaciones, 214 estaciones y 19 prefijos territoriales.
- Dimensión CDC: portafolio gobernado de estaciones meteorológicas.

## Arquitectura

```text
NOAA Marketplace --------------------------> bronze_weather
                                                    |
JSON CDC en Unity Catalog Volume ----------> bronze_station_cdc
                                                    |
                                      silver_weather + dim_station SCD2
                                                    |
                                         gold_weather_monthly
                                                    |
                                           weather_metrics
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
├── docs/                   # Plan, decisiones, arquitectura y evidencias
└── .github/workflows/      # Validación y despliegue dev/prod
```

## Requisitos locales

- Databricks CLI autenticado contra el workspace.
- Acceso al catálogo compartido de NOAA.
- Permisos para crear schemas, Volumes, pipelines y Jobs en los catálogos dev/prod.

## Validación y despliegue

```powershell
databricks auth login --host https://dbc-cbc2bb58-ee6e.cloud.databricks.com
databricks bundle validate -t development
databricks bundle deploy -t development
databricks bundle run -t development weather_job
```

Antes de ejecutar el pipeline se deben cargar `data/cdc/batch_1.json` y, durante la prueba funcional, `data/cdc/batch_2.json` al Volume `station_cdc` del ambiente correspondiente.

## Estrategia Git

- `dev`: integración y despliegue al catálogo de desarrollo.
- `main`: producción; solo recibe cambios mediante Pull Request desde `dev`.
- Las features se desarrollan en branches `feature/*` y se integran mediante Pull Request.

Los workflows requieren los GitHub Environments `dev` y `prod`, sus credenciales OAuth M2M y la variable de repositorio `CI_ENABLED=true`.
