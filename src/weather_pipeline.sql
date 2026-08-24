-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Governed Weather Lakeflow Declarative Pipeline
-- MAGIC
-- MAGIC The Marketplace table is read-only and acts as the raw source. The
-- MAGIC regional filter is deterministic, so every environment processes the
-- MAGIC same business scope. Station changes arrive as JSON files in a Unity
-- MAGIC Catalog Volume and are ingested with Auto Loader.

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE bronze_weather
COMMENT 'Raw NOAA observations for the approved tropical Americas scope.'
AS
SELECT *
FROM STREAM(${source_table})
WHERE date >= DATE '2022-01-01'
  AND latitude BETWEEN 5 AND 25
  AND longitude BETWEEN -100 AND -60;

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE bronze_station_cdc
COMMENT 'Synthetic station portfolio changes ingested from a Unity Catalog Volume.'
AS
SELECT *
FROM STREAM read_files(
  '${cdc_volume_path}',
  format => 'json',
  schema => 'station_id STRING, station_name STRING, country_code STRING, region_name STRING, coverage_tier STRING, monitoring_status STRING, sequence_ts TIMESTAMP, operation STRING'
);

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW silver_weather (
  CONSTRAINT valid_station EXPECT (station_id IS NOT NULL) ON VIOLATION DROP ROW,
  CONSTRAINT valid_coordinates EXPECT (
    latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180
  ) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_temperature_order EXPECT (
    temp_max_c IS NULL OR temp_min_c IS NULL OR temp_max_c >= temp_min_c
  )
)
COMMENT 'Typed, normalized, deduplicated daily weather observations.'
AS
WITH normalized AS (
  SELECT
    TRIM(station) AS station_id,
    CAST(date AS DATE) AS observation_date,
    CAST(latitude AS DOUBLE) AS latitude,
    CAST(longitude AS DOUBLE) AS longitude,
    CAST(elevation AS INT) AS elevation_m,
    TRIM(REGEXP_REPLACE(name, '\\s+', ' ')) AS source_station_name,
    SUBSTRING(TRIM(station), 1, 2) AS source_country_code,
    ROUND(CAST(temp_max AS DOUBLE) / 10.0, 1) AS temp_max_c,
    ROUND(CAST(temp_min AS DOUBLE) / 10.0, 1) AS temp_min_c,
    ROUND(CAST(precipitation AS DOUBLE) / 10.0, 1) AS precipitation_mm,
    CAST(snowfall AS DOUBLE) AS snowfall_mm,
    CAST(snow_depth AS DOUBLE) AS snow_depth_mm,
    temp_max_attrs,
    temp_min_attrs,
    precipitation_attrs,
    group_ AS source_group
  FROM bronze_weather
), ranked AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY station_id, observation_date
           ORDER BY source_station_name, latitude, longitude
         ) AS duplicate_rank
  FROM normalized
)
SELECT
  * EXCEPT (duplicate_rank),
  ROUND(temp_max_c - temp_min_c, 1) AS daily_temperature_range_c,
  CASE WHEN temp_max_c >= 35 THEN TRUE ELSE FALSE END AS is_hot_day,
  CASE WHEN precipitation_mm >= 50 THEN TRUE ELSE FALSE END AS is_heavy_rain_day,
  CASE
    WHEN temp_max_c IS NOT NULL AND temp_min_c IS NOT NULL AND precipitation_mm IS NOT NULL THEN 'complete'
    WHEN temp_max_c IS NOT NULL OR temp_min_c IS NOT NULL OR precipitation_mm IS NOT NULL THEN 'partial'
    ELSE 'missing_core_metrics'
  END AS data_completeness_status
FROM ranked
WHERE duplicate_rank = 1;

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE dim_station;

CREATE FLOW station_scd2_flow AS AUTO CDC INTO dim_station
FROM STREAM(bronze_station_cdc)
KEYS (station_id)
APPLY AS DELETE WHEN operation = 'DELETE'
SEQUENCE BY sequence_ts
COLUMNS * EXCEPT (operation)
STORED AS SCD TYPE 2;

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW gold_weather_daily
COMMENT 'Weather facts enriched with the currently governed station portfolio.'
AS
SELECT
  w.*,
  COALESCE(d.station_name, w.source_station_name) AS station_name,
  COALESCE(d.country_code, w.source_country_code) AS country_code,
  COALESCE(d.region_name, 'Unmanaged regional station') AS region_name,
  COALESCE(d.coverage_tier, 'unclassified') AS coverage_tier,
  COALESCE(d.monitoring_status, 'not_in_portfolio') AS monitoring_status,
  d.__START_AT AS station_version_start_at
FROM silver_weather w
LEFT JOIN dim_station d
  ON w.station_id = d.station_id
 AND d.__END_AT IS NULL;

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW gold_weather_monthly
COMMENT 'Monthly business metrics consumed by the semantic layer.'
AS
SELECT
  DATE_TRUNC('MONTH', observation_date) AS observation_month,
  country_code,
  region_name,
  coverage_tier,
  monitoring_status,
  COUNT(*) AS observation_count,
  COUNT(DISTINCT station_id) AS station_count,
  ROUND(AVG(temp_max_c), 2) AS avg_max_temperature_c,
  ROUND(AVG(temp_min_c), 2) AS avg_min_temperature_c,
  MAX(temp_max_c) AS extreme_max_temperature_c,
  ROUND(SUM(COALESCE(precipitation_mm, 0)), 2) AS total_precipitation_mm,
  SUM(CASE WHEN is_hot_day THEN 1 ELSE 0 END) AS hot_day_count,
  SUM(CASE WHEN is_heavy_rain_day THEN 1 ELSE 0 END) AS heavy_rain_day_count,
  ROUND(
    100.0 * SUM(CASE WHEN data_completeness_status = 'complete' THEN 1 ELSE 0 END) / COUNT(*),
    2
  ) AS complete_observation_pct
FROM gold_weather_daily
GROUP BY
  DATE_TRUNC('MONTH', observation_date),
  country_code,
  region_name,
  coverage_tier,
  monitoring_status;
