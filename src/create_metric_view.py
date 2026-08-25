# Databricks notebook source
# MAGIC %md
# MAGIC # Create retail Metric View
# MAGIC
# MAGIC Recreates the governed semantic layer after Gold is available so a
# MAGIC clean deployment does not depend on a manual SQL Editor step.

# COMMAND ----------

import re

dbutils.widgets.text("catalog", "dab_lab_dev")
dbutils.widgets.text("schema", "retail_luis_acuna")

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")

identifier_pattern = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
if not identifier_pattern.fullmatch(catalog):
    raise ValueError(f"Invalid catalog identifier: {catalog}")
if not identifier_pattern.fullmatch(schema):
    raise ValueError(f"Invalid schema identifier: {schema}")

metric_view = f"`{catalog}`.`{schema}`.`retail_product_metrics`"
gold_source = f"{catalog}.{schema}.gold_retail_monthly"

spark.sql(
    f'''CREATE OR REPLACE VIEW {metric_view}
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1

source: {gold_source}

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
$$'''
)

measure_check = spark.sql(
    f"""
    SELECT MEASURE(total_revenue) AS total_revenue
    FROM {metric_view}
    """
).first()["total_revenue"]

if measure_check is None or measure_check <= 0:
    raise ValueError("Metric View validation returned no revenue")

dbutils.jobs.taskValues.set(key="metric_view_status", value="ready")
print(f"created {metric_view}; total_revenue={measure_check}")
