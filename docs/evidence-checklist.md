# Checklist de evidencias

- [x] Pipeline ejecutado con batch 1 (`0f6ba186-9b28-46a0-b7ec-86726a596bfc`, `COMPLETED`).
- [x] Estado inicial de `dim_airline` SCD2: 10 eventos, 10 versiones y 10 registros vigentes.
- [x] Pipeline/Job ejecutado con batch 2 (`639754312255839`, `SUCCESS`).
- [x] Insert de Southwest visible y vigente desde `1999-07-01`.
- [x] Dos versiones de American Airlines: `standard` cerrada y `priority` vigente.
- [x] Registro sintético `ZZ` cerrado en `1999-07-01`.
- [ ] Event Log y métricas de expectations.
- [x] Gold y Metric View consultables (`airline_performance_metrics`).
- [ ] Dashboard con dos visualizaciones y texto explicativo.
- [x] Grafo del Job, If/Else y corrida exitosa (`578230174624557`, rama `publish_ready`).
- [x] Notificaciones de éxito y fallo configuradas en `resources/job.yml`.
- [ ] PR feature -> dev y check de validación.
- [ ] Deploy/run automático de development.
- [ ] PR dev -> main y validación production.
- [ ] Deploy/run automático de production.
- [ ] Branch protections de `dev` y `main`.
- [ ] Grant o Share limitado al objeto de producción.
- [ ] Diagrama de arquitectura en documento final.
