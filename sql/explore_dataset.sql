-- Ejecutar una sección a la vez en Databricks SQL.

-- 1. Tablas originales instaladas desde Marketplace.
SHOW TABLES IN databricks_airline_performance_data.v01;

-- 2. Esquema original completo.
DESCRIBE TABLE databricks_airline_performance_data.v01.flights_small;

-- 3. Muestra legible de los vuelos originales.
SELECT
  Year, Month, DayofMonth,
  UniqueCarrier, FlightNum, TailNum,
  Origin, Dest,
  CRSDepTime, DepTime,
  CRSArrTime, ArrTime,
  DepDelay, ArrDelay, Distance,
  Cancelled, Diverted
FROM databricks_airline_performance_data.v01.flights_small
ORDER BY Year, Month, DayofMonth
LIMIT 100;

-- 4. Perfil por año de la tabla completa.
SELECT
  Year,
  COUNT(*) AS row_count,
  COUNT(DISTINCT UniqueCarrier) AS airline_count,
  COUNT(DISTINCT Origin) AS origin_airport_count,
  COUNT(DISTINCT Dest) AS destination_airport_count
FROM databricks_airline_performance_data.v01.flights_small
GROUP BY Year
ORDER BY Year;

-- 5. Extracto exacto usado por el proyecto.
SELECT COUNT(*) AS selected_flight_count
FROM databricks_airline_performance_data.v01.flights_small
WHERE Year = 1999 AND Month BETWEEN 1 AND 6;

-- 6. Tablas generadas en development.
SHOW TABLES IN dab_lab_dev.dev_luis_acuna11_airline_luis_acuna;

-- 7. Bronze mantiene las columnas originales.
SELECT *
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.bronze_flights
LIMIT 100;

-- 8. Silver muestra los nombres normalizados y campos derivados.
SELECT
  flight_date,
  carrier_code,
  flight_number,
  origin_airport,
  destination_airport,
  route_code,
  scheduled_departure_hhmm,
  arrival_delay_minutes,
  is_delayed_over_15,
  operational_outcome
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.silver_flights
LIMIT 100;

-- 9. Eventos CDC originales leídos desde los JSON.
SELECT *
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.bronze_airline_cdc
ORDER BY sequence_ts, carrier_code;

-- 10. Historial SCD2 completo de los casos de demostración.
SELECT
  carrier_code,
  carrier_name,
  service_tier,
  monitoring_status,
  __START_AT,
  __END_AT
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.dim_airline
WHERE carrier_code IN ('AA', 'WN', 'ZZ')
ORDER BY carrier_code, __START_AT;

-- 11. Solo versiones vigentes de la dimensión.
SELECT *
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.dim_airline
WHERE __END_AT IS NULL
ORDER BY carrier_code;

-- 12. Gold: hechos enriquecidos con el nombre de la aerolínea.
SELECT
  flight_date,
  carrier_code,
  carrier_name,
  service_tier,
  route_code,
  arrival_delay_minutes,
  operational_outcome
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.gold_airline_daily
LIMIT 100;

-- 13. Gold agregado que alimenta la Metric View.
SELECT *
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.gold_airline_monthly
ORDER BY flight_month, carrier_name, route_code
LIMIT 100;

-- 14. Consulta correcta sobre la Metric View.
SELECT
  carrier_name,
  MEASURE(total_flights) AS total_flights,
  MEASURE(delayed_flights) AS delayed_flights,
  MEASURE(average_delay_rate_pct) AS average_delay_rate_pct
FROM dab_lab_dev.dev_luis_acuna11_airline_luis_acuna.airline_performance_metrics
GROUP BY carrier_name
ORDER BY total_flights DESC;
