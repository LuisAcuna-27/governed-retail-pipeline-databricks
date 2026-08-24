# Plan aprobado del proyecto

## Objetivo

Construir y demostrar un pipeline gobernado de observaciones meteorológicas que responda qué estaciones y zonas del Caribe y del corredor tropical americano presentaron mayor exposición histórica a calor extremo y precipitación intensa entre 2022 y febrero de 2024.

## Alcance de datos

- Fuente de solo lectura: NOAA GHCN-Daily desde Databricks Marketplace.
- Filtro reproducible: `date >= 2022-01-01`, latitud `[5, 25]`, longitud `[-100, -60]`.
- Volumen esperado: aproximadamente 114 mil observaciones.
- Llave natural del hecho: `station + date`.
- Dimensión SCD2: portafolio gobernado de estaciones, llave `station_id`.

## Fases

1. Repositorio, Bundle y branches `dev`/`main`.
2. Recursos de Unity Catalog, Volume y carga del batch 1.
3. Pipeline Bronze/Silver con expectations y AUTO CDC SCD2.
4. Carga del batch 2 y evidencia insert/update/delete.
5. Gold, Metric View y dashboard AI/BI.
6. Job con If/Else, parámetros y notificaciones.
7. Service principals, GitHub Environments y workflows CI/CD.
8. Pruebas funcionales, grants, capturas y documento de decisiones.

## Criterios de aceptación

- `databricks bundle validate` exitoso en development y production.
- Pipeline ejecutado con Event Log y al menos dos expectations con comportamientos distintos.
- Evidencia SCD2 antes y después del segundo batch.
- Job exitoso y rama condicional visible.
- Metric View con al menos dos dimensiones y dos medidas.
- Dashboard con al menos dos visualizaciones.
- PR feature -> dev y dev -> main con checks y despliegues visibles.
- Acceso docente limitado a Metric View/Gold o dashboard de producción.
