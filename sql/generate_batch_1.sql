-- Generate the student-owned initial product dimension after the Bundle creates
-- the target schema and product_cdc Volume. Replace placeholders before running.

INSERT OVERWRITE DIRECTORY '/Volumes/${catalog}/${schema}/product_cdc/batch_1'
USING JSON
WITH ranked_orders AS (
  SELECT *,
         ROW_NUMBER() OVER (
           PARTITION BY order_number
           ORDER BY order_datetime DESC
         ) AS snapshot_rank
  FROM databricks_simulated_retail_customer_data.v01.sales_orders
), product_revenue AS (
  SELECT
    TRIM(item.id) AS product_id,
    MAX(TRIM(item.name)) AS product_name,
    SUM(TRY_CAST(item.price AS DECIMAL(18, 2)) * TRY_CAST(item.qty AS INT)) AS revenue
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
    CASE WHEN revenue_decile = 1 THEN 'priority' ELSE 'routine' END AS monitoring_status,
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
SELECT * FROM control_product;
