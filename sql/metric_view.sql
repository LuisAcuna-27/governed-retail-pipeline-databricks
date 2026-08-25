-- Execute after the pipeline has created gold_airline_monthly.
-- Replace ${catalog} and ${schema} with the selected Bundle target values.

CREATE OR REPLACE VIEW ${catalog}.${schema}.airline_performance_metrics
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: ${catalog}.${schema}.gold_airline_monthly

dimensions:
  - name: flight_month
    expr: flight_month
  - name: carrier_name
    expr: carrier_name
  - name: route_code
    expr: route_code
  - name: origin_airport
    expr: origin_airport
  - name: service_tier
    expr: service_tier
  - name: monitoring_status
    expr: monitoring_status

measures:
  - name: total_flights
    expr: SUM(flight_count)
  - name: delayed_flights
    expr: SUM(delayed_flight_count)
  - name: cancelled_flights
    expr: SUM(cancelled_flight_count)
  - name: average_arrival_delay_minutes
    expr: AVG(avg_arrival_delay_minutes)
  - name: average_delay_rate_pct
    expr: AVG(delay_rate_pct)
  - name: average_cancellation_rate_pct
    expr: AVG(cancellation_rate_pct)
$$;
