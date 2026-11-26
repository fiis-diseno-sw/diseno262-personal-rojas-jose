# ADR-01: Desacoplamiento del Core Bancario mediante CQRS y Anti-Corruption Layer (ACL)

- **Estado:** Aceptado
- **Categoría (Bass et al.):** Asignación de responsabilidades / Datos
- **Escenarios trazados:** [ESC-03](../README.md#esc-03), [ESC-04](../README.md#esc-04), [ESC-05](../README.md#esc-05)

## Contexto

El sistema **BAP Móvil 3.0** debe soportar 1.2 millones de usuarios activos mensuales, 45 millones de operaciones diarias (9 millones de sesiones en quincenas) y picos instantáneos de hasta **2,500 TPS**, manteniendo una latencia de consulta de saldos **p95 ≤ 800 ms** y disponibilidad del canal móvil **≥ 99.95%**. Sin embargo, el core bancario actual es un mainframe COBOL on-premise en Lima integrado vía IBM MQ Series y archivos planos, que no puede escalar elásticamente en el corto plazo y puede presentar ventanas de mantenimiento o degradación.

## Alternativas consideradas

1. **Alternativa A — Integración directa síncrona contra el core COBOL para todas las lecturas y escrituras:**
   - *Pros:* Fuente única de verdad sin duplicación de datos; menor complejidad inicial de sincronización.
   - *Contras:* Satura el mainframe durante picos de consultas de saldo (que representan la mayoría de los 45M de operaciones diarias); la latencia de red Lima–São Paulo (~60 ms RTT) más el tiempo de procesamiento del mainframe compromete el p95 ≤ 800 ms; cualquier caída del core tumba inmediatamente la app móvil.

2. **Alternativa B — Patrón CQRS con Anti-Corruption Layer (ACL) y caché distribuido:**
   - *Pros:* Separa las lecturas (servidas desde Amazon ElastiCache Redis y réplicas de lectura en AWS `sa-east-1`) de las escrituras transaccionales; el ACL traduce modelos modernos (JSON/REST) a mensajería COBOL/MQ aislando el dominio de BAP Móvil 3.0; protege al core de picos de lectura y permite degradación controlada si el core entra en mantenimiento.
   - *Contras:* Introduce consistencia eventual (milisegundos/segundos) entre el core y la proyección de lectura; requiere mecanismos de reconciliación y manejo de colas MQ.

## Criterios de elección

- Cumplimiento estricto de latencia de lectura (**p95 ≤ 800 ms**) bajo picos de **2,500 TPS**.
- Protección del mainframe COBOL frente a avalanchas de consultas.
- Resiliencia del canal móvil (**≥ 99.95%**) ante indisponibilidad temporal del core on-premise.
- Aislamiento del equipo de 6 squads respecto a formatos legados (COBOL copybooks / archivos planos).

## Decisión

Se adopta la **Alternativa B**: implementar un **Anti-Corruption Layer (ACL)** dedicado para encapsular la comunicación vía IBM MQ Series hacia el core COBOL, combinado con **CQRS** en AWS `sa-east-1` usando **Amazon ElastiCache (Redis)** y base operacional **Amazon RDS for Oracle Multi-AZ** para servir consultas de saldos y movimientos sin impactar al mainframe.

## Sustento

El 80%+ del tráfico bancario móvil corresponde a consultas de saldos y movimientos. Mover esas lecturas a Redis + réplicas en `sa-east-1` elimina el cuello de botella del mainframe y garantiza respuestas por debajo de 800 ms incluso en quincenas. Asimismo, el ACL evita acoplar los microservicios Java/Spring Boot de los 6 squads al modelo de datos legado del core, facilitando la evolución gradual hacia el futuro reemplazo del core.
