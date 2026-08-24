-- Execute after the pipeline has created gold_weather_monthly.
-- Replace ${catalog} and ${schema} with the selected Bundle target values.

CREATE OR REPLACE VIEW ${catalog}.${schema}.weather_metrics
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: ${catalog}.${schema}.gold_weather_monthly

dimensions:
  - name: observation_month
    expr: observation_month
  - name: country_code
    expr: country_code
  - name: region_name
    expr: region_name
  - name: coverage_tier
    expr: coverage_tier
  - name: monitoring_status
    expr: monitoring_status

measures:
  - name: total_observations
    expr: SUM(observation_count)
  - name: monitored_stations
    expr: SUM(station_count)
  - name: average_max_temperature_c
    expr: AVG(avg_max_temperature_c)
  - name: total_precipitation_mm
    expr: SUM(total_precipitation_mm)
  - name: hot_days
    expr: SUM(hot_day_count)
  - name: heavy_rain_days
    expr: SUM(heavy_rain_day_count)
$$;
