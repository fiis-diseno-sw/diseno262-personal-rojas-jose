# ADR-04: Plataforma de Streaming de Eventos (Amazon MSK + Flink) y Data Lake para Fraude y PLAFT

- **Estado:** Aceptado
- **Categoría (Bass et al.):** Tecnología / Coordinación
- **Escenarios trazados:** [ESC-06](../README.md#esc-06), [ESC-07](../README.md#esc-07), [ESC-09](../README.md#esc-09)

## Contexto

BAP Móvil 3.0 generará aproximadamente **80 millones de eventos diarios** (~1.2 KB JSON por evento, ~35 TB anuales sin compresión) con picos de **2,500 TPS**. Se requiere detectar y bloquear fraude en **< 2 segundos** antes de la acreditación, y al mismo tiempo conservar el historial completo e inmutable para generar los reportes regulatorios **ROU/ROM (semanales)** y **ROS (mensuales)** exigidos por la **UIF-Perú** (Resolución SBS N° 2660-2015), además de alimentar modelos de scoring alternativo para clientes informales.

## Alternativas consideradas

1. **Alternativa A — Evaluación de fraude por consultas directas a Oracle + procesos batch nocturnos:**
   - *Pros:* Usa tecnología ya conocida por el equipo (Oracle + procesos batch).
   - *Contras:* Ejecutar reglas con ventanas temporales (ej. "más de 5 transferencias en 10 minutos desde distinta geolocalización") sobre Oracle a 2,500 TPS degrada la base transaccional y supera fácilmente los 2 segundos; no escala para 35 TB/año de eventos analíticos.

2. **Alternativa B — Bus de eventos en Amazon MSK (Apache Kafka) + procesamiento en streaming (Apache Flink) + Data Lake en Amazon S3:**
   - *Pros:* Desacopla la captura de ~80M eventos/día mediante particionamiento por `customerId`/`accountId`; Apache Flink mantiene estado en ventanas de tiempo en memoria con latencia sub-segundo (< 2 s para bloqueo); los mismos eventos se descargan en paralelo a **Amazon S3 (Parquet comprimido)** para análisis batch, scoring crediticio alternativo y reportes UIF auditables.
   - *Contras:* Introduce curva de aprendizaje en operación de Kafka/Flink, manejo de duplicados (`eventId`) y *watermarks* para eventos fuera de orden.

## Criterios de elección

- Tiempo de detección y bloqueo antifraude **< 2 segundos**.
- Capacidad de absorber picos de **2,500 TPS** y **80M eventos/día** sin backpressure en pagos.
- Retención costo-eficiente y auditable de **~35 TB/año** para UIF-Perú y scoring alternativo.

## Decisión

Se adopta la **Alternativa B**: **Amazon MSK (Kafka)** como columna vertebral de eventos, **Apache Flink** para el motor de fraude y alertas PLAFT en tiempo real, y **Amazon S3 + AWS Glue/Spark** como repositorio analítico y regulatorio para los reportes semanales y mensuales.

## Sustento

Permite que un único flujo de eventos sirva simultáneamente al requisito de baja latencia (< 2 s) del negocio y al requisito regulatorio de trazabilidad histórica (ROU/ROM y ROS) sin sobrecargar la base transaccional Oracle.
