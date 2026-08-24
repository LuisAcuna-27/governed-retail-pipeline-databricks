# Governed Weather Pipeline on Databricks

Proyecto final del Modulo 3 del Tecnico en Ingenieria de Datos con Databricks.

El proyecto construye un pipeline gobernado de observaciones meteorologicas NOAA con arquitectura medallion, Lakeflow Declarative Pipelines, CDC con SCD Tipo 2, Metric Views, un dashboard AI/BI y despliegue CI/CD mediante Databricks Asset Bundles y GitHub Actions.

## Caso de negocio

**Pregunta:** Que estaciones y zonas del Caribe y del corredor tropical americano presentaron mayor exposicion historica a calor extremo y precipitacion intensa entre 2022 y febrero de 2024?

## Fuente principal

- Marketplace: `Daily Weather Observations | NOAA`
- Tabla: `rearc_daily_weather_observations_noaa.esg_noaa_ghcn.noaa_ghcn_daily`
- Extracto reproducible: fechas desde `2022-01-01`, latitud entre 5 y 25, longitud entre -100 y -60.
- Dimension CDC: portafolio gobernado de estaciones meteorologicas.

El desarrollo se realiza en la branch `dev` y se promueve a `main` mediante Pull Request.
