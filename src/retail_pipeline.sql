-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Governed Retail Order Pipeline
-- MAGIC
-- MAGIC The Marketplace order fact is streamed directly into Bronze. Products
-- MAGIC embedded in each order are parsed and exploded in Silver. A product
-- MAGIC portfolio dimension is generated independently in two JSON batches and
-- MAGIC maintained by AUTO CDC as SCD Type 2.

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE bronze_orders
COMMENT 'Raw retail order snapshots streamed from the Marketplace table.'
AS
SELECT *
FROM STREAM(${source_table});

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE bronze_product_cdc
COMMENT 'Student-generated product portfolio changes ingested with Auto Loader.'
AS
SELECT *
FROM STREAM read_files(
  '${cdc_volume_path}',
  format => 'json',
  schema => 'product_id STRING, product_name STRING, portfolio_tier STRING, lifecycle_status STRING, monitoring_status STRING, sequence_ts TIMESTAMP, operation STRING'
);

-- COMMAND ----------

-- FAIL protects the order business key, DROP removes unusable product lines and
-- WARN exposes invalid commercial values without hiding the rest of the update.
CREATE OR REFRESH MATERIALIZED VIEW silver_order_items (
  CONSTRAINT valid_order_key EXPECT (
    order_number IS NOT NULL
  ) ON VIOLATION FAIL UPDATE,
  CONSTRAINT valid_product_key EXPECT (
    product_id IS NOT NULL AND product_name IS NOT NULL
  ) ON VIOLATION DROP ROW,
  CONSTRAINT valid_commercial_values EXPECT (
    quantity > 0 AND unit_price >= 0
  )
)
COMMENT 'Latest order snapshots parsed into typed, validated product-level facts.'
AS
WITH ranked_orders AS (
  SELECT
    CAST(order_number AS BIGINT) AS order_number,
    CAST(customer_id AS BIGINT) AS customer_id,
    INITCAP(TRIM(customer_name)) AS customer_name,
    CAST(number_of_line_items AS INT) AS declared_line_item_count,
    CAST(order_datetime AS BIGINT) AS order_epoch_seconds,
    ordered_products,
    promo_info,
    ROW_NUMBER() OVER (
      PARTITION BY order_number
      ORDER BY order_datetime DESC
    ) AS snapshot_rank
  FROM bronze_orders
), parsed_orders AS (
  SELECT
    *,
    TO_TIMESTAMP(FROM_UNIXTIME(order_epoch_seconds)) AS order_timestamp,
    FROM_JSON(
      ordered_products,
      'ARRAY<STRUCT<curr:STRING,id:STRING,name:STRING,price:STRING,promotion_info:STRUCT<promo_disc:DOUBLE,promo_id:STRING,promo_item:STRING,promo_qty:STRING>,qty:STRING,unit:STRING>>'
    ) AS product_items
  FROM ranked_orders
  WHERE snapshot_rank = 1
), exploded_items AS (
  SELECT
    order_number,
    customer_id,
    customer_name,
    order_timestamp,
    TO_DATE(order_timestamp) AS order_date,
    DATE_TRUNC('MONTH', order_timestamp) AS order_month,
    declared_line_item_count,
    SIZE(product_items) AS parsed_line_item_count,
    TRIM(item.id) AS product_id,
    TRIM(item.name) AS product_name,
    UPPER(TRIM(item.curr)) AS currency_code,
    TRY_CAST(item.price AS DECIMAL(18, 2)) AS unit_price,
    TRY_CAST(item.qty AS INT) AS quantity,
    LOWER(TRIM(item.unit)) AS quantity_unit,
    item.promotion_info.promo_disc AS promotion_discount_rate,
    item.promotion_info.promo_id AS promotion_id
  FROM parsed_orders
  LATERAL VIEW EXPLODE(product_items) product_rows AS item
)
SELECT
  *,
  ROUND(unit_price * quantity, 2) AS line_revenue,
  promotion_id IS NOT NULL AS has_promotion,
  declared_line_item_count = parsed_line_item_count AS line_item_count_matches
FROM exploded_items;

-- COMMAND ----------

CREATE OR REFRESH STREAMING TABLE dim_product;

CREATE FLOW product_scd2_flow AS AUTO CDC INTO dim_product
FROM STREAM(bronze_product_cdc)
KEYS (product_id)
APPLY AS DELETE WHEN operation = 'DELETE'
SEQUENCE BY sequence_ts
COLUMNS * EXCEPT (operation)
STORED AS SCD TYPE 2;

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW gold_retail_order_items
COMMENT 'Order item facts enriched with the current governed product portfolio.'
AS
SELECT
  f.*,
  COALESCE(d.product_name, f.product_name) AS governed_product_name,
  COALESCE(d.portfolio_tier, 'unclassified') AS portfolio_tier,
  COALESCE(d.lifecycle_status, 'unclassified') AS lifecycle_status,
  COALESCE(d.monitoring_status, 'not_in_portfolio') AS monitoring_status,
  d.__START_AT AS product_version_start_at
FROM silver_order_items f
LEFT JOIN dim_product d
  ON f.product_id = d.product_id
 AND d.__END_AT IS NULL;

-- COMMAND ----------

CREATE OR REFRESH MATERIALIZED VIEW gold_retail_monthly
COMMENT 'Monthly product portfolio metrics consumed by the semantic layer.'
AS
SELECT
  order_month,
  product_id,
  governed_product_name AS product_name,
  portfolio_tier,
  lifecycle_status,
  monitoring_status,
  currency_code,
  COUNT(DISTINCT order_number) AS order_count,
  COUNT(*) AS item_line_count,
  SUM(quantity) AS units_sold,
  ROUND(SUM(line_revenue), 2) AS gross_revenue,
  ROUND(AVG(unit_price), 2) AS avg_unit_price,
  ROUND(AVG(line_revenue), 2) AS avg_line_revenue,
  SUM(CASE WHEN has_promotion THEN 1 ELSE 0 END) AS promoted_line_count,
  ROUND(100.0 * SUM(CASE WHEN has_promotion THEN 1 ELSE 0 END) / COUNT(*), 2) AS promotion_rate_pct
FROM gold_retail_order_items
GROUP BY
  order_month,
  product_id,
  governed_product_name,
  portfolio_tier,
  lifecycle_status,
  monitoring_status,
  currency_code;
