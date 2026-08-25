# Databricks notebook source
# MAGIC %md
# MAGIC # Conditional publication status

# COMMAND ----------

dbutils.widgets.text("environment", "development")
dbutils.widgets.text("validation_status", "blocked")

environment = dbutils.widgets.get("environment")
validation_status = dbutils.widgets.get("validation_status")

message = f"Gold validation for {environment}: {validation_status}"
dbutils.jobs.taskValues.set(key="publication_status", value=validation_status)
print(message)

if validation_status != "ready":
    print("Publication remains blocked because the Gold row threshold was not met.")
