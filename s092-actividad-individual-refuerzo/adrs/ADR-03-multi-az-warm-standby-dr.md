# ADR-03: Topología Multi-AZ Activo-Activo en `sa-east-1` y DR Warm Standby en `us-east-1`

- **Estado:** Aceptado
- **Categoría (Bass et al.):** Mapeo / Gestión de recursos
- **Escenarios trazados:** [ESC-01](../README.md#esc-01), [ESC-02](../README.md#esc-02), [ESC-05](../README.md#esc-05)

## Contexto

BAP Móvil 3.0 requiere **disponibilidad ≥ 99.95%** mensual (≤ 22 minutos de downtime/mes) y cumplir la **Circular G-139-2009** de la SBS con **RTO ≤ 30 minutos** y **RPO ≤ 1 minuto**. El Comité de Riesgo Tecnológico aprobó **AWS `sa-east-1` (São Paulo)** como región primaria y **AWS `us-east-1` (Norte de Virginia)** como región de recuperación ante desastres (DR), con un presupuesto anual de infraestructura cloud de **USD 2.8 millones**.

## Alternativas consideradas

1. **Alternativa A — Activo-Activo Multi-Región (`sa-east-1` + `us-east-1`) con replicación síncrona de base de datos:**
   - *Pros:* RTO y RPO cercanos a cero ante caída regional completa.
   - *Contras:* La latencia de red entre São Paulo y Virginia (~110–140 ms RTT por cada escritura síncrona) penaliza todas las transacciones normales; duplica prácticamente el costo de cómputo y licenciamiento Oracle en standby activo, poniendo en riesgo el presupuesto de USD 2.8M/año.

2. **Alternativa B — Activo-Activo Multi-AZ (3 AZs) en `sa-east-1` + Warm Standby en `us-east-1`:**
   - *Pros:* Alta disponibilidad local (≥ 99.95%) y RPO = 0 ante caída de una AZ gracias a replicación síncrona Multi-AZ; replicación asíncrona continua hacia `us-east-1` mantiene **RPO ≤ 1 minuto** sin penalizar la latencia diaria; promoción automatizada (Route 53 + Runbooks) alcanza **RTO ≤ 30 minutos** dentro del presupuesto de USD 2.8M/año.
   - *Contras:* En un desastre total de `sa-east-1`, requiere ejecutar el failover regional (10–20 min) y puede existir una pérdida máxima acotada de hasta 1 minuto de transacciones aún no replicadas (mitigable con reintento/reconciliación).

3. **Alternativa C — Cold Standby (Backup & Restore) en `us-east-1`:**
   - *Pros:* Menor costo mensual en la región DR.
   - *Contras:* Restaurar bases de datos Oracle y levantar clústeres desde cero toma horas, incumpliendo el **RTO ≤ 30 minutos** y **RPO ≤ 1 minuto**.

## Criterios de elección

- Disponibilidad ≥ 99.95% mensual en operación normal y picos de quincena.
- Cumplimiento normativo de **RTO ≤ 30 min** y **RPO ≤ 1 min**.
- Mantenimiento de latencia **p95 ≤ 5 s** (transferencias) y **p95 ≤ 800 ms** (consultas).
- Ajuste al presupuesto anual aprobado de **USD 2.8 millones**.

## Decisión

Se adopta la **Alternativa B**: despliegue **Activo-Activo en 3 Zonas de Disponibilidad** dentro de `sa-east-1` (con autoescalado horizontal de contenedores y enlaces redundantes AWS Direct Connect hacia Lima) y estrategia **Warm Standby** en `us-east-1` con replicación asíncrona continua y pruebas trimestrales de failover.

## Sustento

Esta topología resuelve de forma costo-eficiente los dos niveles de falla: las fallas frecuentes (caída de nodo o de una AZ) se absorben automáticamente en segundos sin pérdida de datos, mientras que el escenario catastrófico regional cumple holgadamente los límites de la Circular G-139-2009 dentro del presupuesto asignado.
