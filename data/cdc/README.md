# Lotes CDC de productos

- `batch_1` se genera con `sql/generate_batch_1.sql` directamente en el Volume
  de Unity Catalog. Incluye 98 productos reales y un control sintético.
- `batch_2.json` se carga después de la primera ejecución. Demuestra UPDATE,
  INSERT y DELETE con `sequence_ts = 2019-11-15`.

Auto Loader lee ambos lotes y AUTO CDC mantiene `dim_product` como SCD Tipo 2
usando `product_id` como llave de negocio.
