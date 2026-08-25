# Plan aprobado: pipeline gobernado de analítica retail

## Objetivo

Construir desde cero un pipeline que explique ingresos, unidades y pedidos por
mes, producto y nivel de portafolio. El resultado debe demostrar ingestión
streaming, calidad, CDC SCD Tipo 2, capa semántica, orquestación y CI/CD.

## Alcance de datos

- Hecho Marketplace: `databricks_simulated_retail_customer_data.v01.sales_orders`.
- Grano Bronze: un snapshot recibido por orden.
- Grano Silver: una línea de producto por orden, después de conservar el
  snapshot más reciente por `order_number`.
- Grano Gold: mes, producto, nivel de portafolio y estados gobernados.
- Llave del hecho: `order_number`; no se usa como llave CDC.
- Llave de la dimensión: `product_id`.
- Secuencia CDC: `sequence_ts`.
- Periodo de la fuente: agosto a noviembre de 2019; datos simulados.

## Entregables

1. Repositorio GitHub privado y ramas `dev`, `main` y de trabajo.
2. Bundle con schema, Volume, Lakeflow Pipeline y Lakeflow Job.
3. Bronze streaming del Marketplace y Bronze Auto Loader para CDC.
4. Silver tipada, deduplicada, derivada y validada con tres expectations.
5. `dim_product` con AUTO CDC SCD Tipo 2 y dos lotes JSON.
6. Gold enriquecida con la versión vigente de la dimensión.
7. Metric View con seis dimensiones y seis medidas.
8. Dashboard AI/BI consumiendo la Metric View.
9. GitHub Actions para validar PR y desplegar `dev`/`main`.
10. Documentación y evidencias reproducibles.

## Criterios de aceptación

- El pipeline se valida y ejecuta sin errores en desarrollo.
- El hecho entra por `STREAM()` y el CDC por Auto Loader.
- Las expectations incluyen `FAIL UPDATE`, `DROP ROW` y `WARN`.
- El lote 2 produce una versión cerrada y otra vigente del producto actualizado,
  retira el control sintético e incorpora un producto nuevo.
- El Job incluye Pipeline Task, If/Else, For Each, parámetros y notificaciones.
- La consulta de la Metric View devuelve ingresos y unidades por dimensiones.
- Los cambios pasan por Pull Request y no se despliega producción directamente.

## Fases

1. Selección y perfilado del dataset — completada.
2. Diseño del modelo y del CDC — completada.
3. Implementación del Bundle y pipeline — completada.
4. Prueba de lote 1 y orquestación — completada.
5. Prueba de lote 2 y SCD2 — completada.
6. Documentación y dashboard — completados.
7. CI/CD reproducible y credenciales OAuth — completado en desarrollo y producción.
