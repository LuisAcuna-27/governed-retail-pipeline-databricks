# Checklist de evidencias

## Datos y pipeline

- [x] Listing retail instalado desde Databricks Marketplace.
- [x] `sales_orders` perfilada: 4,074 snapshots, 4,000 órdenes y 7,997 líneas.
- [x] Bronze del hecho creada como Streaming Table con `STREAM()`.
- [x] CDC JSON ingerido mediante Auto Loader.
- [x] Silver tipada, deduplicada, explotada y con columnas derivadas.
- [x] Tres expectations visibles en Event Log: 7,997 aprobados en cada una.
- [x] `dim_product` administrada por AUTO CDC como SCD Tipo 2.
- [x] Gold unida a la versión vigente de `dim_product`.
- [x] Metric View `retail_product_metrics` creada y consultable.

## Prueba CDC

- [x] Lote 1: 99 eventos, 99 versiones y 99 productos vigentes.
- [x] Lote 2: 102 eventos acumulados, 101 versiones y 99 vigentes.
- [x] Producto principal: versión `strategic` cerrada y `critical` vigente.
- [x] `SYN-NEW-PRODUCT` vigente desde `2019-11-15`.
- [x] `SYN-CONTROL-PRODUCT` cerrado desde `2019-11-15`.

## Orquestación y entrega

- [x] Job con Pipeline Task.
- [x] If/Else basado en el conteo Gold.
- [x] For Each para resumir Bronze, Silver y Gold.
- [x] Parámetros y correo de éxito/error.
- [x] Bundle validado para desarrollo y producción.
- [x] Workflows de PR, `dev` y `main` definidos.
- [x] Dashboard AI/BI desplegado con tres visualizaciones sobre la Metric View.
- [x] Credenciales OAuth M2M configuradas en GitHub Environments.
- [x] `CI_ENABLED=true` y validación de PR comprobada.
- [x] Despliegue y Job de desarrollo ejecutados desde GitHub Actions.
- [x] Despliegue y Job de producción ejecutados desde GitHub Actions.
- [x] Dashboard de producción compartido con `jg.moricem@gmail.com` como
  `CAN_READ`, sin acceso docente a las capas internas.
- [x] Dashboard publicado con credenciales embebidas para consumo gobernado.
