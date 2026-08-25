# Guía completa del dataset retail

## 1. Qué instaló Marketplace

El listing `Simulated Retail Customer Data` creó el catálogo de solo lectura
`databricks_simulated_retail_customer_data`. En su schema `v01` existen:

| Tabla original | Filas | Uso en el proyecto |
|---|---:|---|
| `customers` | 28,813 | No se usa; está fuera del alcance. |
| `sales` | 360 | No se usa; es una agregación pequeña. |
| `sales_orders` | 4,074 | Fuente principal del hecho. |

La única tabla que el pipeline lee es:

`databricks_simulated_retail_customer_data.v01.sales_orders`

## 2. Qué representa una fila original

Una fila es un snapshot de una orden, no necesariamente una orden única. Hay
4,074 filas pero 4,000 valores distintos de `order_number`; por eso Silver
conserva la fila más reciente de cada orden.

| Columna | Significado |
|---|---|
| `order_number` | Identificador de la orden; llave para deduplicar el hecho. |
| `order_datetime` | Fecha/hora Unix en segundos; ordena los snapshots. |
| `customer_id` | Identificador del cliente. |
| `customer_name` | Nombre del cliente en el snapshot. |
| `number_of_line_items` | Cantidad declarada de líneas. |
| `ordered_products` | JSON con los productos, cantidades, precios y promoción. |
| `promo_info` | Información promocional adicional en texto. |
| `clicked_items` | Interacciones previas del cliente en texto. |

`ordered_products` contiene un arreglo. Cada elemento incluye `id`, `name`,
`price`, `qty`, `curr`, `unit` y un struct opcional `promotion_info`.

## 3. Llaves: qué identifica cada cosa

- `order_number` identifica y deduplica la orden.
- `product_id` identifica el producto después de explotar el JSON.
- La línea analítica se identifica por la combinación de orden y elemento
  explotado; no se inventa una llave primaria declarada en la fuente.
- `product_id` es la llave de negocio de `dim_product` y del AUTO CDC.
- `sequence_ts` no identifica; ordena las versiones CDC.

Por tanto, el CDC **no se hace por `order_number`**. Se hace en la dimensión por
`product_id`, secuenciado por `sequence_ts`.

## 4. Transformación por capas

| Objeto del proyecto | Tipo | Función |
|---|---|---|
| `bronze_orders` | Streaming Table | Copia streaming de los 4,074 snapshots. |
| `bronze_product_cdc` | Streaming Table | Auto Loader sobre los lotes JSON propios. |
| `silver_order_items` | Materialized View | Deduplica órdenes, tipa, parsea, explota y valida. |
| `dim_product` | Streaming Table SCD2 | Historial del portafolio por `product_id`. |
| `gold_retail_order_items` | Materialized View | Une cada línea con la versión vigente del producto. |
| `gold_retail_monthly` | Materialized View | Agrega mes, producto y atributos gobernados. |
| `retail_product_metrics` | Metric View | Expone medidas y dimensiones para AI/BI. |
| `retail_pipeline_event_log` | Event Log | Guarda progreso y métricas de expectations. |

Silver deriva `order_timestamp`, `order_date`, `order_month`, `line_revenue`,
`has_promotion` y `line_item_count_matches`. Después de la deduplicación y el
`EXPLODE`, produce 7,997 líneas pertenecientes a 4,000 órdenes y 98 productos.

## 5. Cómo funciona el CDC

El lote 1 no se copia manualmente desde Marketplace. El script
`sql/generate_batch_1.sql` obtiene los 98 productos reales y los clasifica según
su decil de ingresos:

- decil 1: `strategic`;
- deciles 2 a 4: `managed`;
- resto: `standard`.

También agrega `SYN-CONTROL-PRODUCT`, usado solo para demostrar un delete seguro.
El lote 2 contiene tres eventos:

1. UPDATE del producto de mayores ingresos de `strategic` a `critical`;
2. INSERT de `SYN-NEW-PRODUCT`;
3. DELETE de `SYN-CONTROL-PRODUCT`.

AUTO CDC conserva `__START_AT` y `__END_AT`. Gold filtra `__END_AT IS NULL`, por
lo que consume la versión vigente sin perder el historial auditable.

## 6. Cómo se apega a la rúbrica

- Hecho Marketplace: `sales_orders` entra a una Bronze Streaming Table.
- Datos propios: dos lotes JSON para la dimensión CDC.
- Auto Loader: ingestión incremental de los archivos del Volume.
- AUTO CDC: SCD Tipo 2 con llave, secuencia y delete explícitos.
- Silver: tipado, deduplicación, columnas derivadas y tres expectations con
  comportamientos FAIL, DROP y WARN.
- Gold: unión con la dimensión vigente y agregación de negocio.
- Semantic layer: seis dimensiones y seis medidas en la Metric View.
- Orquestación: Pipeline Task, If/Else, For Each, parámetros y correo.
- CI/CD: Bundle y GitHub Actions separados para `dev` y `main`.

## 7. Cómo verlo

Ejecuta [`../sql/explore_dataset.sql`](../sql/explore_dataset.sql) por secciones.
Las primeras consultas muestran las tablas originales y el JSON; las siguientes
recorren Bronze, Silver, SCD2, Gold, Metric View y Event Log.
