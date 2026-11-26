# ADR-02: Orquestación de Pagos en Tiempo Real con Patrón Saga, Idempotencia y Validación Antifraude Pre-Acreditación

- **Estado:** Aceptado
- **Categoría (Bass et al.):** Coordinación
- **Escenarios trazados:** [ESC-01](../README.md#esc-01), [ESC-04](../README.md#esc-04), [ESC-07](../README.md#esc-07)

## Contexto

La regulación de interoperabilidad de la **CCE-BCRP** exige acreditar transferencias entre Yape, Plin, BIM y BAP en menos de 10 segundos (24/7/365), y el negocio fija un objetivo de **p95 ≤ 5 segundos** end-to-end. Simultáneamente, el motor de fraude debe poder **bloquear operaciones sospechosas en < 2 segundos** antes de la acreditación final en el destinatario. Además, los clientes en zonas rurales y segmentos C/D operan en redes 3G/4G intermitentes, lo que provoca reintentos frecuentes desde la app móvil.

## Alternativas consideradas

1. **Alternativa A — Transacciones distribuidas síncronas (2PC / XA) entre servicios, core COBOL y CCE-BCRP:**
   - *Pros:* Consistencia fuerte inmediata entre todos los participantes.
   - *Contras:* El protocolo 2PC bloquea recursos durante toda la llamada externa a la CCE-BCRP y al core COBOL, degradando severamente el throughput en picos de 1,200–2,500 TPS y generando bloqueos parciales ante caídas de red; incompatible con APIs externas REST/ISO 20022 de la CCE-BCRP.

2. **Alternativa B — Patrón Saga orquestado con `Idempotency-Key` y compuerta antifraude síncrona (< 2 s):**
   - *Pros:* Evita bloqueos distribuidos largos; ejecuta una secuencia explícita (1. Validación de idempotencia → 2. Evaluación antifraude < 2 s → 3. Reserva/débito de fondos → 4. Envío a CCE-BCRP → 5. Confirmación o compensación automática); garantiza exactamente-una-vez ante reintentos en redes 3G/4G.
   - *Contras:* Requiere diseñar acciones compensatorias (reversión de reserva si CCE-BCRP rechaza o expira) y mantener una tabla de estado de sagas.

## Criterios de elección

- Latencia end-to-end **p95 ≤ 5 segundos** en transferencias interbancarias.
- Capacidad de bloqueo antifraude **< 2 segundos** antes de acreditar al destinatario.
- Tolerancia a reintentos de clientes en redes móviles 3G/4G intermitentes sin doble débito.
- Trazabilidad completa de cada paso para auditoría y conciliación.

## Decisión

Se adopta la **Alternativa B**: el **Servicio de Pagos e Interoperabilidad** actuará como orquestador de **Saga** con clave de idempotencia (`Idempotency-Key`) obligatoria por operación, ejecutando la evaluación de fraude antes de emitir la instrucción de acreditación hacia la CCE-BCRP y aplicando compensaciones automáticas ante fallos o timeouts.

## Sustento

El patrón Saga orquestado permite mantener la consistencia financiera eventual controlada sin los cuellos de botella de 2PC, cumple el presupuesto de latencia de 5 segundos (dejando ≤ 2 s para fraude y ≤ 3 s para reserva + CCE-BCRP) y protege al usuario de cobros duplicados cuando su conexión 3G/4G se corta tras confirmar una transferencia.
