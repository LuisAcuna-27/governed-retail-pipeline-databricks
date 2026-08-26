# Registro de decisiones

## D1. Migrar a Simulated Retail Customer Data

La alternativa aérea funcionaba técnicamente, pero complicaba la explicación:
el número de vuelo no era único, la fuente era antigua y la relación con una
dimensión sintética resultaba menos intuitiva. Se migró a retail porque
`sales_orders` ofrece `order_number`, productos embebidos y `product_id`, una
unión natural entre hechos y la dimensión gobernada.

La fuente retail también es histórica y simulada. Esto es aceptable porque la
pregunta se presenta como caso analítico de demostración y no como información
comercial vigente. Se documenta expresamente para evitar conclusiones engañosas.

## D2. Usar solamente `sales_orders`

El listing también contiene `customers` y `sales`, pero no son necesarias para
cumplir el alcance. Reducir la fuente a una sola tabla mantiene el linaje claro:
orden -> línea de producto -> dimensión de producto -> métricas mensuales.

## D3. CDC separado del hecho

`sales_orders` es una fuente de hechos de solo lectura. El estudiante genera la
dimensión `dim_product` en dos lotes JSON y la mantiene con AUTO CDC SCD2:

- llave de negocio: `product_id`;
- secuencia: `sequence_ts`;
- delete: `operation = 'DELETE'`;
- lote 1: 98 productos reales y un control sintético;
- lote 2: reclasificación, alta nueva y retiro del control.

El producto de control evita borrar del análisis un producto real únicamente
para demostrar el comportamiento DELETE.

## D4. Conservar el snapshot más reciente

La fuente contiene 4,074 filas para 4,000 números de orden. Silver aplica
`ROW_NUMBER()` por `order_number`, ordenado por `order_datetime DESC`, antes de
parsear y explotar `ordered_products`. Así la deduplicación ocurre en el grano
correcto y produce 7,997 líneas de producto.

## D5. Calidad con tres comportamientos

- `valid_order_key`: `FAIL UPDATE`, porque una línea sin orden invalida la carga.
- `valid_product_key`: `DROP ROW`, porque no puede unirse a la dimensión.
- `valid_commercial_values`: `WARN`, para observar cantidades o precios
  inválidos sin ocultar el resto de la actualización.

## D6. Estado anterior preservado

La rama remota `feature/airline-fallback` conserva el prototipo aéreo. Sus
recursos de Databricks no se destruyeron durante la migración; el proyecto retail
se desplegó con un nombre de Bundle y schema independientes.

## D7. Compartir únicamente el dashboard de producción

El acceso docente se limita al dashboard
`production-luis_acuna-retail-dashboard`. El usuario
`jg.moricem@gmail.com` recibe `CAN_READ` y el dashboard publicado usa
credenciales embebidas del principal de producción. Así puede consultar las
visualizaciones sin recibir acceso directo a Bronze, Silver, Gold, al catálogo
de desarrollo, al pipeline ni al Job.

La configuración queda declarada en `resources/dashboard.yml` para que el
permiso sea reproducible en cada despliegue del Bundle.

## D8. Repositorio público y ramas protegidas

El repositorio se publica después de revisar los archivos rastreados y todo el
historial en busca de tokens, secretos, claves privadas o archivos de
credenciales. Las credenciales OAuth M2M permanecen únicamente en GitHub
Environment secrets.

Las ramas `dev` y `main` se protegen para exigir Pull Request y su respectivo
check de validación antes del merge. Esto permite al docente revisar el
historial y las ejecuciones de GitHub Actions sin recibir credenciales o acceso
adicional al workspace.
