-- Execute after the pipeline has created gold_retail_monthly.
-- Replace ${catalog} and ${schema} with the selected Bundle target values.

CREATE OR REPLACE VIEW ${catalog}.${schema}.retail_product_metrics
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: ${catalog}.${schema}.gold_retail_monthly

dimensions:
  - name: order_month
    expr: order_month
  - name: product_name
    expr: product_name
  - name: portfolio_tier
    expr: portfolio_tier
  - name: lifecycle_status
    expr: lifecycle_status
  - name: monitoring_status
    expr: monitoring_status
  - name: currency_code
    expr: currency_code

measures:
  - name: total_revenue
    expr: SUM(gross_revenue)
  - name: total_units
    expr: SUM(units_sold)
  - name: product_order_occurrences
    expr: SUM(order_count)
  - name: promoted_lines
    expr: SUM(promoted_line_count)
  - name: average_unit_price
    expr: AVG(avg_unit_price)
  - name: average_line_revenue
    expr: AVG(avg_line_revenue)
$$;
