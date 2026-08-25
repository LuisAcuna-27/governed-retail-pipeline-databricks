# Documento de decisiones - borrador vivo

## Dataset y caso de negocio

Se evaluó primero NOAA GHCN-Daily por su actualidad y riqueza climática. La exploración confirmó buena calidad, pero la ejecución del pipeline devolvió `DS_TIME_TRAVEL_NOT_PERMITTED`: el proveedor permite consultas batch, pero no comparte el historial Delta requerido por `STREAM()`. La alternativa batch también fue rechazada por `CREATE_APPEND_ONCE_FLOW_FROM_BATCH_QUERY_NOT_ALLOWED`. Como la rúbrica exige una Bronze Streaming Table del hecho, se aplicó el plan de contingencia documentado.

Airline Performance Data sí admite streaming desde Marketplace y contiene 10,602,522 filas. Se utiliza un extracto determinístico del primer semestre de 1999. La antigüedad se reconoce expresamente: el dashboard responde una pregunta histórica y no pretende describir operaciones actuales.

## Dimensión CDC

La dimensión representa el portafolio gobernado de aerolíneas. El batch 2 actualiza American Airlines, inserta Southwest Airlines y elimina `ZZ`, un registro sintético de control creado únicamente para demostrar el delete sin retirar una aerolínea real del análisis Gold.

## Capas

- Bronze conserva el hecho del Marketplace y los eventos CDC del Volume.
- Silver tipa fechas y métricas, normaliza códigos, elimina duplicados y deriva ruta, hora y resultado operativo.
- Gold une los vuelos con la versión vigente de `dim_airline` y calcula métricas mensuales por aerolínea y ruta.
- La Metric View expone medidas y dimensiones de negocio y será la única fuente del dashboard.

## Expectations

- Ruta sin origen o destino: `DROP ROW`, porque no puede alimentar agregaciones por ruta.
- Distancia no positiva: `FAIL UPDATE`, porque indicaría corrupción de una métrica estructural del hecho.
- Retraso de llegada ausente en un vuelo no cancelado ni desviado: `WARN`, porque debe observarse sin descartar automáticamente el registro.

## Pendiente de completar con evidencia

- Capturas batch 1/batch 2 y explicación de `__START_AT`/`__END_AT`.
- Grafo y corrida exitosa del Job.
- Pull Requests y GitHub Actions.
- Dashboard y principales insights.
- Grant de Unity Catalog.
- Reflexión final.
