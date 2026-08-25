-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Governed Airline Performance Pipeline
-- MAGIC
-- MAGIC The Marketplace source is streamed directly into Bronze. The approved
-- MAGIC extract uses the first semester of 1999: it preserves every carrier
-- MAGIC and route in that period while keeping the workload manageable in
-- MAGIC Databricks Free Edition. Airline changes arrive as JSON in a Unity
-- MAGIC Catalog Volume and are processed with AUTO CDC as SCD Type 2.

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE bronze_flights
COMMENT 'Raw Airline Performance observations for the first semester of 1999.'
AS
SELECT *
FROM STREAM(${source_table})
WHERE Year = 1999
  AND Month BETWEEN 1 AND 6;

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE bronze_airline_cdc
COMMENT 'Synthetic airline portfolio changes ingested with Auto Loader.'
AS
SELECT *
FROM STREAM read_files(
  '${cdc_volume_path}',
  format => 'json',
  schema => 'carrier_code STRING, carrier_name STRING, headquarters_region STRING, service_tier STRING, monitoring_status STRING, sequence_ts TIMESTAMP, operation STRING'
);

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW silver_flights (
  CONSTRAINT valid_route EXPECT (
    origin_airport IS NOT NULL AND destination_airport IS NOT NULL
  ) ON VIOLATION DROP ROW,
  CONSTRAINT valid_distance EXPECT (
    distance_miles IS NULL OR distance_miles > 0
  ) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_delay_relationship EXPECT (
    is_cancelled OR is_diverted OR arrival_delay_minutes IS NOT NULL
  )
)
COMMENT 'Typed, normalized and deduplicated airline performance facts.'
AS
WITH normalized AS (
  SELECT
    MAKE_DATE(CAST(Year AS INT), CAST(Month AS INT), CAST(DayofMonth AS INT)) AS flight_date,
    CAST(Year AS INT) AS flight_year,
    CAST(Month AS INT) AS flight_month_number,
    CAST(DayofMonth AS INT) AS flight_day_of_month,
    CAST(DayOfWeek AS INT) AS flight_day_of_week,
    UPPER(TRIM(UniqueCarrier)) AS carrier_code,
    CAST(FlightNum AS STRING) AS flight_number,
    NULLIF(UPPER(TRIM(TailNum)), 'NA') AS tail_number,
    UPPER(TRIM(Origin)) AS origin_airport,
    UPPER(TRIM(Dest)) AS destination_airport,
    CONCAT(UPPER(TRIM(Origin)), '-', UPPER(TRIM(Dest))) AS route_code,
    CAST(CRSDepTime AS INT) AS scheduled_departure_hhmm,
    CAST(DepTime AS INT) AS actual_departure_hhmm,
    CAST(CRSArrTime AS INT) AS scheduled_arrival_hhmm,
    CAST(ArrTime AS INT) AS actual_arrival_hhmm,
    CAST(DepDelay AS DOUBLE) AS departure_delay_minutes,
    CAST(ArrDelay AS DOUBLE) AS arrival_delay_minutes,
    CAST(Distance AS DOUBLE) AS distance_miles,
    CAST(ActualElapsedTime AS DOUBLE) AS actual_elapsed_minutes,
    CAST(CRSElapsedTime AS DOUBLE) AS scheduled_elapsed_minutes,
    CAST(AirTime AS DOUBLE) AS air_time_minutes,
    CAST(TaxiIn AS DOUBLE) AS taxi_in_minutes,
    CAST(TaxiOut AS DOUBLE) AS taxi_out_minutes,
    CAST(Cancelled AS INT) = 1 AS is_cancelled,
    NULLIF(UPPER(TRIM(CancellationCode)), 'NA') AS cancellation_code,
    CAST(Diverted AS INT) = 1 AS is_diverted
  FROM bronze_flights
), ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY flight_date, carrier_code, flight_number,
                        origin_airport, destination_airport, scheduled_departure_hhmm
           ORDER BY actual_departure_hhmm, tail_number
         ) AS duplicate_rank
  FROM normalized
)
SELECT
  * EXCEPT (duplicate_rank),
  CASE
    WHEN scheduled_departure_hhmm BETWEEN 0 AND 2359
      THEN CAST(FLOOR(scheduled_departure_hhmm / 100) AS INT)
    ELSE NULL
  END AS scheduled_departure_hour,
  CASE WHEN arrival_delay_minutes > 15 THEN TRUE ELSE FALSE END AS is_delayed_over_15,
  CASE
    WHEN is_cancelled THEN 'cancelled'
    WHEN is_diverted THEN 'diverted'
    WHEN arrival_delay_minutes > 60 THEN 'severe_delay'
    WHEN arrival_delay_minutes > 15 THEN 'moderate_delay'
    ELSE 'on_time_or_early'
  END AS operational_outcome
FROM ranked
WHERE duplicate_rank = 1;

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE dim_airline;

CREATE FLOW airline_scd2_flow AS AUTO CDC INTO dim_airline
FROM STREAM(bronze_airline_cdc)
KEYS (carrier_code)
APPLY AS DELETE WHEN operation = 'DELETE'
SEQUENCE BY sequence_ts
COLUMNS * EXCEPT (operation)
STORED AS SCD TYPE 2;

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW gold_airline_daily
COMMENT 'Flight facts enriched with the current governed airline portfolio.'
AS
SELECT
  f.*,
  COALESCE(d.carrier_name, CONCAT('Carrier ', f.carrier_code)) AS carrier_name,
  COALESCE(d.headquarters_region, 'Unclassified') AS headquarters_region,
  COALESCE(d.service_tier, 'unclassified') AS service_tier,
  COALESCE(d.monitoring_status, 'not_in_portfolio') AS monitoring_status,
  d.__START_AT AS airline_version_start_at
FROM silver_flights f
LEFT JOIN dim_airline d
  ON f.carrier_code = d.carrier_code
 AND d.__END_AT IS NULL;

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW gold_airline_monthly
COMMENT 'Monthly route and carrier metrics consumed by the semantic layer.'
AS
SELECT
  DATE_TRUNC('MONTH', flight_date) AS flight_month,
  carrier_code,
  carrier_name,
  headquarters_region,
  service_tier,
  monitoring_status,
  origin_airport,
  destination_airport,
  route_code,
  COUNT(*) AS flight_count,
  SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END) AS cancelled_flight_count,
  SUM(CASE WHEN is_diverted THEN 1 ELSE 0 END) AS diverted_flight_count,
  SUM(CASE WHEN is_delayed_over_15 THEN 1 ELSE 0 END) AS delayed_flight_count,
  ROUND(AVG(arrival_delay_minutes), 2) AS avg_arrival_delay_minutes,
  ROUND(AVG(departure_delay_minutes), 2) AS avg_departure_delay_minutes,
  PERCENTILE_APPROX(arrival_delay_minutes, 0.95) AS p95_arrival_delay_minutes,
  ROUND(AVG(distance_miles), 2) AS avg_distance_miles,
  ROUND(100.0 * SUM(CASE WHEN is_delayed_over_15 THEN 1 ELSE 0 END) / COUNT(*), 2) AS delay_rate_pct,
  ROUND(100.0 * SUM(CASE WHEN is_cancelled THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_rate_pct
FROM gold_airline_daily
GROUP BY
  DATE_TRUNC('MONTH', flight_date),
  carrier_code,
  carrier_name,
  headquarters_region,
  service_tier,
  monitoring_status,
  origin_airport,
  destination_airport,
  route_code;
