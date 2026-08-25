# Databricks notebook source
# MAGIC %md
# MAGIC # Initialize product CDC batch 1
# MAGIC
# MAGIC Creates the student-owned initial JSON batch only when it does not
# MAGIC already exist. This makes a clean CI/CD deployment reproducible while
# MAGIC keeping repeated Job runs idempotent.

# COMMAND ----------

import re

dbutils.widgets.text("catalog", "dab_lab_dev")
dbutils.widgets.text("schema", "retail_luis_acuna")
dbutils.widgets.text(
    "source_table",
    "databricks_simulated_retail_customer_data.v01.sales_orders",
)

catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")
source_table = dbutils.widgets.get("source_table")

identifier_pattern = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
multipart_pattern = re.compile(
    r"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*){2}$"
)

if not identifier_pattern.fullmatch(catalog):
    raise ValueError(f"Invalid catalog identifier: {catalog}")
if not identifier_pattern.fullmatch(schema):
    raise ValueError(f"Invalid schema identifier: {schema}")
if not multipart_pattern.fullmatch(source_table):
    raise ValueError(f"Invalid three-part source table: {source_table}")

batch_path = f"/Volumes/{catalog}/{schema}/product_cdc/batch_1"

try:
    existing_files = [entry for entry in dbutils.fs.ls(batch_path) if not entry.isDir()]
except Exception as error:
    if "FileNotFoundException" not in str(error) and "does not exist" not in str(error):
        raise
    existing_files = []

if existing_files:
    print(f"batch_1 already initialized at {batch_path}; no files were replaced")
    dbutils.jobs.taskValues.set(key="batch_1_status", value="already_exists")
else:
    batch_df = spark.sql(
        f"""
        WITH ranked_orders AS (
          SELECT *,
                 ROW_NUMBER() OVER (
                   PARTITION BY order_number
                   ORDER BY order_datetime DESC
                 ) AS snapshot_rank
          FROM {source_table}
        ), product_revenue AS (
          SELECT
            TRIM(item.id) AS product_id,
            MAX(TRIM(item.name)) AS product_name,
            SUM(
              TRY_CAST(item.price AS DECIMAL(18, 2)) *
              TRY_CAST(item.qty AS INT)
            ) AS revenue
          FROM ranked_orders o
          LATERAL VIEW EXPLODE(
            FROM_JSON(
              o.ordered_products,
              'ARRAY<STRUCT<id:STRING,name:STRING,price:STRING,qty:STRING>>'
            )
          ) product_rows AS item
          WHERE snapshot_rank = 1
          GROUP BY TRIM(item.id)
        ), ranked_products AS (
          SELECT *, NTILE(10) OVER (ORDER BY revenue DESC) AS revenue_decile
          FROM product_revenue
        ), initial_products AS (
          SELECT
            product_id,
            product_name,
            CASE
              WHEN revenue_decile = 1 THEN 'strategic'
              WHEN revenue_decile <= 4 THEN 'managed'
              ELSE 'standard'
            END AS portfolio_tier,
            'active' AS lifecycle_status,
            CASE
              WHEN revenue_decile = 1 THEN 'priority'
              ELSE 'routine'
            END AS monitoring_status,
            TIMESTAMP('2019-08-01T00:00:00Z') AS sequence_ts,
            'INSERT' AS operation
          FROM ranked_products
        ), control_product AS (
          SELECT
            'SYN-CONTROL-PRODUCT' AS product_id,
            'Synthetic Control Product' AS product_name,
            'control' AS portfolio_tier,
            'active' AS lifecycle_status,
            'control' AS monitoring_status,
            TIMESTAMP('2019-08-01T00:00:00Z') AS sequence_ts,
            'INSERT' AS operation
        )
        SELECT * FROM initial_products
        UNION ALL
        SELECT * FROM control_product
        """
    )

    generated_rows = batch_df.count()
    if generated_rows != 99:
        raise ValueError(f"Expected 99 initial CDC rows, generated {generated_rows}")

    # This branch only runs when the directory has no data files. Overwrite is
    # supported by serverless Spark Connect and also repairs an empty directory
    # left by an interrupted first initialization.
    batch_df.coalesce(1).write.mode("overwrite").json(batch_path)
    dbutils.jobs.taskValues.set(key="batch_1_status", value="created")
    print(f"created {generated_rows} JSON CDC records at {batch_path}")
