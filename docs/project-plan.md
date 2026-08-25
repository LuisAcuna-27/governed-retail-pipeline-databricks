# Plan aprobado del proyecto

## Objetivo

Construir y demostrar un pipeline gobernado que identifique las aerolíneas, rutas y meses con mayor riesgo operativo de retrasos, cancelaciones y desvíos durante el primer semestre de 1999.

## Alcance de datos

- Fuente de solo lectura: Airline Performance Data desde Databricks Marketplace.
- Extracto reproducible: `Year = 1999` y `Month BETWEEN 1 AND 6`.
- Volumen esperado: aproximadamente 2.5 millones de vuelos.
- Llave natural: fecha, aerolínea, vuelo, origen, destino y hora programada.
- Dimensión SCD2: portafolio gobernado de aerolíneas, llave `carrier_code`.

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
- Bronze del hecho y del CDC implementadas como Streaming Tables.
- AUTO CDC SCD2 y al menos dos expectations con comportamientos distintos.
- Evidencia de la dimensión antes y después del segundo batch.
- Job exitoso con rama condicional visible.
- Metric View con al menos dos dimensiones y dos medidas.
- Dashboard con al menos dos visualizaciones.
- PR feature -> dev y dev -> main con checks y despliegues visibles.
- Acceso docente limitado al objeto de producción autorizado.
