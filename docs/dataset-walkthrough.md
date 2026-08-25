# Guía completa del dataset y su uso en el proyecto

## 1. Qué entrega originalmente Databricks Marketplace

El listing instala el catálogo compartido `databricks_airline_performance_data`.
Dentro del esquema `v01` existen cuatro tablas originales del proveedor:

- `flights`
- `flights_cluster_id`
- `flights_cluster_id_flightnum`
- `flights_small`

Estas tablas no fueron creadas ni modificadas por el proyecto. El pipeline consume
exclusivamente:

`databricks_airline_performance_data.v01.flights_small`

`flights_small` es una tabla Delta append-only de aproximadamente 131 MB, formada
por 17 archivos. Contiene 10,602,522 registros: 5,384,713 de 1998 y 5,217,809 de
1999. El proyecto toma solamente enero-junio de 1999, que produce 2,710,845 filas.

Las otras tres tablas son variantes entregadas por el mismo proveedor. No son
dependencias del pipeline y no debemos presentarlas como tablas creadas por
nosotros.

## 2. Qué representa una fila de `flights_small`

Una fila representa la operación de un vuelo en una fecha y ruta determinadas.
La tabla no declara una llave primaria y `FlightNum` no es único por sí solo.

### Fecha

| Columna original | Significado |
|---|---|
| `Year` | Año del vuelo. |
| `Month` | Mes del vuelo. |
| `DayofMonth` | Día del mes. |
| `DayOfWeek` | Día de la semana codificado numéricamente. |

### Horarios

`CRS` significa horario programado por el sistema de reservas.

| Columna original | Significado |
|---|---|
| `CRSDepTime` | Hora programada de salida. |
| `DepTime` | Hora real de salida. |
| `CRSArrTime` | Hora programada de llegada. |
| `ArrTime` | Hora real de llegada. |

### Aerolínea, vuelo y aeronave

| Columna original | Significado |
|---|---|
| `UniqueCarrier` | Código de la aerolínea, por ejemplo `AA`, `DL` o `WN`. No identifica un vuelo. |
| `FlightNum` | Número comercial del vuelo; se repite entre fechas y aerolíneas. |
| `TailNum` | Matrícula o identificador de la aeronave, cuando está disponible. |

### Ruta

| Columna original | Significado |
|---|---|
| `Origin` | Código del aeropuerto de origen. |
| `Dest` | Código del aeropuerto de destino. |
| `Distance` | Distancia de la ruta en millas. |

### Duraciones

| Columna original | Significado |
|---|---|
| `ActualElapsedTime` | Duración real total. |
| `CRSElapsedTime` | Duración total programada. |
| `AirTime` | Tiempo real en el aire. |
| `TaxiIn` | Tiempo de rodaje al llegar. |
| `TaxiOut` | Tiempo de rodaje antes de despegar. |

### Retrasos e irregularidades

| Columna original | Significado |
|---|---|
| `DepDelay` | Minutos de retraso de salida; un valor negativo significa salida anticipada. |
| `ArrDelay` | Minutos de retraso de llegada; un valor negativo significa llegada anticipada. |
| `Cancelled` | Indicador numérico de cancelación. |
| `CancellationCode` | Motivo codificado de cancelación, si está disponible. |
| `Diverted` | Indicador de vuelo desviado. |

### Causas y banderas de retraso

| Columna original | Significado |
|---|---|
| `CarrierDelay` | Retraso atribuido a la aerolínea. |
| `WeatherDelay` | Retraso atribuido al clima. |
| `NASDelay` | Retraso atribuido al sistema nacional de aviación. |
| `SecurityDelay` | Retraso atribuido a seguridad. |
| `LateAircraftDelay` | Retraso por llegada tardía de la aeronave anterior. |
| `IsArrDelayed` | Bandera textual de retraso en llegada. |
| `IsDepDelayed` | Bandera textual de retraso en salida. |

Varias métricas numéricas están almacenadas originalmente como `STRING`. Por eso
Silver las convierte explícitamente a `DOUBLE` o `INT`.

## 3. La tabla de vuelos no recibe CDC

La tabla del Marketplace se ingiere como hecho mediante `STREAM()`:

```sql
FROM STREAM(databricks_airline_performance_data.v01.flights_small)
WHERE Year = 1999 AND Month BETWEEN 1 AND 6
```

No afirmamos que tenga una llave primaria. En Silver se construye una llave
compuesta para deduplicar:

1. fecha del vuelo;
2. código de aerolínea;
3. número de vuelo;
4. aeropuerto de origen;
5. aeropuerto de destino;
6. hora programada de salida.

## 4. De dónde sale `carrier_code`

En la tabla original se llama `UniqueCarrier`. Silver lo normaliza y le da un
nombre más claro:

```sql
UPPER(TRIM(UniqueCarrier)) AS carrier_code
```

Por lo tanto:

`flights_small.UniqueCarrier` → `silver_flights.carrier_code`

`carrier_code` identifica una aerolínea, no un vuelo.

## 5. Qué datos creamos nosotros para el CDC

La rúbrica requiere demostrar eventos insert, update y delete sobre una dimensión.
Para ello se crean dos archivos JSON sintéticos en `data/cdc`.

Cada evento contiene:

| Campo sintético | Función |
|---|---|
| `carrier_code` | Llave de negocio de la dimensión de aerolíneas. |
| `carrier_name` | Nombre legible de la aerolínea. |
| `headquarters_region` | Región administrativa. |
| `service_tier` | Clasificación usada para segmentar. |
| `monitoring_status` | Estado de monitoreo. |
| `sequence_ts` | Orden temporal del CDC. |
| `operation` | `INSERT`, `UPDATE` o `DELETE`. |

AUTO CDC está configurado así:

```sql
KEYS (carrier_code)
APPLY AS DELETE WHEN operation = 'DELETE'
SEQUENCE BY sequence_ts
COLUMNS * EXCEPT (operation)
STORED AS SCD TYPE 2
```

Batch 1 crea la situación inicial. Batch 2:

- actualiza `AA` de `standard` a `priority`;
- inserta `WN` como Southwest Airlines;
- elimina lógicamente `ZZ`, el registro sintético de control.

## 6. Relación entre los dos flujos

El hecho y la dimensión se unen por el código de aerolínea:

```text
flights_small.UniqueCarrier
        ↓ normalización
silver_flights.carrier_code
        ↓ JOIN
dim_airline.carrier_code
```

La unión no pretende identificar vuelos individuales. Su propósito es enriquecer
cada vuelo con el nombre, categoría y estado vigentes de su aerolínea.

## 7. Tablas creadas por el proyecto

Todas viven en:

`dab_lab_dev.dev_luis_acuna11_airline_luis_acuna`

| Objeto | Tipo y función |
|---|---|
| `bronze_flights` | Streaming Table del extracto original de vuelos. |
| `bronze_airline_cdc` | Streaming Table creada por Auto Loader desde los JSON del Volume. |
| `dim_airline` | Streaming Table SCD Type 2 administrada por AUTO CDC. |
| `silver_flights` | Materialized View tipada, normalizada, deduplicada y validada. |
| `gold_airline_daily` | Materialized View con vuelos enriquecidos por la dimensión vigente. |
| `gold_airline_monthly` | Materialized View agregada por mes, aerolínea y ruta. |
| `airline_performance_metrics` | Metric View que expone medidas y dimensiones al dashboard. |
| `airline_pipeline_event_log` | Event Log del pipeline y sus expectations. |

## 8. Cómo se apega al proyecto

- Marketplace fact: `flights_small` ingresa como Bronze Streaming Table.
- CDC sintético: dos lotes JSON llegan a un Unity Catalog Volume.
- Auto Loader: crea `bronze_airline_cdc` de manera incremental.
- AUTO CDC: mantiene `dim_airline` como SCD Type 2.
- Medallion: Bronze, Silver y Gold están separadas.
- Calidad: Silver utiliza expectations `DROP`, `FAIL` y `WARN`.
- Semántica: la Metric View es la fuente prevista del dashboard.
- Orquestación: el Job ejecuta Pipeline, validación, If/Else y ForEach.
- Gobierno: los objetos están en Unity Catalog y se desplegarán mediante targets
  independientes de development y production.

## 9. Frase correcta para defender el diseño

La tabla de vuelos no tiene una llave primaria simple y no recibe CDC. Se ingiere
como un hecho streaming y se deduplica con una llave compuesta. El CDC se aplica a
una dimensión sintética cuyo grano es una fila por aerolínea; su llave
`carrier_code` corresponde al código `UniqueCarrier` del hecho.
