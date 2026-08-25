# Databricks notebook source
# MAGIC %md
# MAGIC # Layer summary executed by For Each

# COMMAND ----------

dbutils.widgets.text("catalog", "dab_lab_dev")
dbutils.widgets.text("schema", "retail_luis_acuna")
dbutils.widgets.text("table_name", "bronze_orders")

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
table_name = dbutils.widgets.get("table_name")

allowed_tables = {"bronze_orders", "silver_order_items", "gold_retail_monthly"}
if table_name not in allowed_tables:
    raise ValueError(f"Unsupported table requested: {table_name}")

row_count = spark.table(f"{catalog}.{schema}.{table_name}").count()
print(f"{catalog}.{schema}.{table_name}: {row_count:,} rows")
