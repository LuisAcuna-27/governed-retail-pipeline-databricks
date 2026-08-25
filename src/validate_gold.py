# Databricks notebook source
# MAGIC %md
# MAGIC # Gold validation
# MAGIC
# MAGIC This task exposes the Gold row count as a task value. The following
# MAGIC If/Else task prevents publication when the pipeline produced no data.

# COMMAND ----------

dbutils.widgets.text("environment", "development")
dbutils.widgets.text("catalog", "dab_lab_dev")
dbutils.widgets.text("schema", "airline_luis_acuna")

environment = dbutils.widgets.get("environment")
catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")

gold_table = f"`{catalog}`.`{schema}`.`gold_airline_monthly`"
gold_row_count = spark.sql(f"SELECT COUNT(*) AS count FROM {gold_table}").first()["count"]

dbutils.jobs.taskValues.set(key="gold_row_count", value=int(gold_row_count))
print(f"environment={environment} table={gold_table} rows={gold_row_count}")
