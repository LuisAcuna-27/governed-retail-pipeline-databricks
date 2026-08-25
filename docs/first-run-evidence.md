# Evidencia técnica de la primera ejecución

Fecha: 2026-08-24 (America/Costa_Rica)

## Recursos de development

- Pipeline: `b9104f7b-4016-485b-8e28-d46c63dd5c96`
- Job: `464705070988459`
- Catálogo y esquema: `dab_lab_dev.dev_luis_acuna11_airline_luis_acuna`
- Volume CDC: `airline_cdc`

## Pipeline con batch 1

La actualización completa `0f6ba186-9b28-46a0-b7ec-86726a596bfc` terminó en `COMPLETED`.
En el Volume solo estaba presente `batch_1.json`.

Conteos comprobados mediante Databricks SQL, statement
`01f1a01a-d5d5-1481-9198-1156fcd0cc4b`:

| Objeto | Filas |
|---|---:|
| `bronze_flights` | 2,710,845 |
| `bronze_airline_cdc` | 10 |
| `dim_airline` | 10 |
| `dim_airline` vigente (`__END_AT IS NULL`) | 10 |
| `silver_flights` | 2,710,845 |
| `gold_airline_daily` | 2,710,845 |
| `gold_airline_monthly` | 22,959 |

## Job orquestador

La corrida `578230174624557` terminó en `SUCCESS`.

- `run_airline_pipeline`: `SUCCESS`.
- `validate_gold`: `SUCCESS`.
- `gold_has_rows`: resultado `true`.
- `publish_ready`: `SUCCESS`.
- `publish_blocked`: `SKIPPED`, al no corresponder a la condición.

La primera tentativa reveló que `client: "1"` no era compatible con los
notebooks serverless de este workspace. Se eliminó esa fijación obsoleta y el Job
pasó a usar el entorno serverless predeterminado, única modalidad admitida por el
workspace.

La corrida posterior `747737519698738` validó además el `ForEach`: tres
iteraciones programadas y tres exitosas sobre Bronze, Silver y Gold.
