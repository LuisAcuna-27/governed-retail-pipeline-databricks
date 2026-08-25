-- Recorrido reproducible. Ejecutar una sección a la vez en Databricks SQL.

-- 1. Tablas originales instaladas por Marketplace.
SHOW TABLES IN databricks_simulated_retail_customer_data.v01;

-- 2. Esquema exacto de la fuente elegida.
DESCRIBE TABLE databricks_simulated_retail_customer_data.v01.sales_orders;

-- 3. Filas originales y contenido JSON de ordered_products.
SELECT
  order_number,
  FROM_UNIXTIME(order_datetime) AS order_timestamp,
  customer_id,
  number_of_line_items,
  ordered_products
FROM databricks_simulated_retail_customer_data.v01.sales_orders
ORDER BY order_datetime
LIMIT 20;

-- 4. Perfil y rango temporal de la fuente.
SELECT
  COUNT(*) AS source_snapshots,
  COUNT(DISTINCT order_number) AS unique_orders,
  COUNT(DISTINCT customer_id) AS unique_customers,
  MIN(FROM_UNIXTIME(order_datetime)) AS first_order,
  MAX(FROM_UNIXTIME(order_datetime)) AS last_order
FROM databricks_simulated_retail_customer_data.v01.sales_orders;

-- 5. Objetos creados por el proyecto.
SHOW TABLES IN dab_lab_dev.dev_luis_acuna11_retail_luis_acuna;

-- 6. Bronze: snapshots recibidos por streaming.
SELECT COUNT(*) AS bronze_snapshots
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.bronze_orders;

-- 7. Silver: órdenes deduplicadas y productos explotados.
SELECT
  order_number,
  order_timestamp,
  product_id,
  product_name,
  quantity,
  unit_price,
  line_revenue,
  has_promotion
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.silver_order_items
ORDER BY order_timestamp, order_number
LIMIT 50;

-- 8. Conteos del grano Silver.
SELECT
  COUNT(*) AS item_lines,
  COUNT(DISTINCT order_number) AS unique_orders,
  COUNT(DISTINCT product_id) AS unique_products,
  ROUND(SUM(line_revenue), 2) AS gross_revenue
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.silver_order_items;

-- 9. Eventos CDC originales.
SELECT *
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.bronze_product_cdc
ORDER BY sequence_ts, product_id;

-- 10. Historial SCD2 de los tres productos demostrativos.
SELECT
  product_id,
  product_name,
  portfolio_tier,
  lifecycle_status,
  monitoring_status,
  __START_AT,
  __END_AT
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.dim_product
WHERE product_id IN (
  'AVqVGaCCU2_QcyX9Ozcf',
  'SYN-NEW-PRODUCT',
  'SYN-CONTROL-PRODUCT'
)
ORDER BY product_id, __START_AT;

-- 11. Gold agregado.
SELECT *
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.gold_retail_monthly
ORDER BY order_month, gross_revenue DESC
LIMIT 100;

-- 12. Consulta semántica: el dashboard debe usar este patrón.
SELECT
  portfolio_tier,
  MEASURE(total_revenue) AS total_revenue,
  MEASURE(total_units) AS total_units,
  MEASURE(product_order_occurrences) AS product_order_occurrences
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.retail_product_metrics
GROUP BY portfolio_tier
ORDER BY total_revenue DESC;

-- 13. Evidencia de expectations registrada por el pipeline.
SELECT
  timestamp,
  origin.flow_name,
  details:flow_progress:data_quality:expectations AS expectations
FROM dab_lab_dev.dev_luis_acuna11_retail_luis_acuna.retail_pipeline_event_log
WHERE event_type = 'flow_progress'
  AND origin.flow_name LIKE '%silver_order_items'
  AND details:flow_progress:data_quality:expectations IS NOT NULL
ORDER BY timestamp DESC
LIMIT 10;
