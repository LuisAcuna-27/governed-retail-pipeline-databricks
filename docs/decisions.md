# Documento de decisiones - borrador vivo

## Dataset y caso de negocio

Se eligió NOAA GHCN-Daily porque ofrece volumen, cobertura temporal, coordenadas y métricas meteorológicas aptas para agregación. El extracto regional es determinístico y reduce el costo de ejecución sin convertir el dataset en una muestra arbitraria.

## Dimensión CDC

La dimensión representa el portafolio de estaciones gobernadas. Sus atributos `coverage_tier` y `monitoring_status` pueden cambiar con el tiempo y justifican un historial SCD Tipo 2. El batch 2 actualiza Juan Santamaría, inserta Tampico y elimina Puerto Lempira.

## Capas

- Bronze conserva el hecho del Marketplace y los eventos CDC del Volume.
- Silver normaliza tipos, unidades, nombres, duplicados y reglas de calidad.
- Gold une el hecho con la versión vigente de `dim_station` y calcula métricas mensuales.
- La Metric View expone nombres de negocio y es la única fuente del dashboard.

## Expectations

- Estación nula: `DROP ROW`, porque una observación sin llave no puede relacionarse ni deduplicarse.
- Coordenadas inválidas: `FAIL UPDATE`, porque invalidan el alcance geográfico completo del pipeline.
- Temperatura máxima menor que mínima: `WARN`, porque debe observarse como problema de calidad sin perder automáticamente el registro fuente.

## Pendiente de completar con evidencia

- Capturas batch 1/batch 2 y explicación de `__START_AT`/`__END_AT`.
- Grafo y corrida exitosa del Job.
- Pull Requests y GitHub Actions.
- Dashboard y principales insights.
- Grant de Unity Catalog.
- Reflexión final.
