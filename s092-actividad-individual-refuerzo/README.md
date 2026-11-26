# Desarrollo del Caso: BAP Móvil 3.0 — Banco Andino del Perú (BAP)

> **Entregable individual** correspondiente a la actividad de refuerzo sobre identificación de atributos de calidad, especificación de escenarios, decisiones de arquitectura (ADRs), modelado C4 y procesamiento de datos (batch vs. streaming).

---

## Declaración de supuestos adicionales

Para responder cuantitativamente y completar las decisiones técnicas sobre el caso, se asumen explícitamente los siguientes supuestos:

1. **Conectividad híbrida Lima – AWS `sa-east-1`:** Existe un enlace dedicado redundante **AWS Direct Connect** (con respaldo VPN IPsec) entre el datacenter on-premise de Lima (donde reside el core mainframe COBOL y MQ Series) y la VPC primaria en **AWS São Paulo (`sa-east-1`)**, con una latencia de ida y vuelta (RTT) promedio de ~60 ms.
2. **Distribución horaria del tráfico:** El 85% de los 45 millones de operaciones diarias y 80 millones de eventos ocurre en una ventana activa de 14 horas (07:00 a 21:00 UTC-5), concentrándose los picos sostenidos (1,200 TPS) en quincenas (días 15 y 30) y los picos instantáneos (2,500 TPS) en campañas como Fiestas Patrias, Navidad, Black Friday y Cyber Day.
3. **SLA de la CCE-BCRP:** La Cámara de Compensación Electrónica (CCE) del BCRP expone una interfaz interoperable (ISO 20022 / REST sobre TLS) con un tiempo de respuesta p95 ≤ 2.5 segundos, permitiendo que BAP cumpla el presupuesto total de **p95 ≤ 5 segundos** end-to-end (y el máximo regulatorio de 10 segundos).
4. **Resiliencia en redes móviles 3G/4G:** La app móvil BAP 3.0 opera con payloads JSON compactos, compresión HTTP/2 y generación local de `Idempotency-Key` por operación para tolerar microcortes de conectividad en zonas rurales del sur andino sin generar dobles débitos.
5. **Organización de los 6 squads y presupuesto:** Los 35 ingenieros distribuidos en 6 squads (Cuentas, Pagos, Créditos, Fraude, Plataforma, Mobile) despliegan servicios independientes sobre contenedores gestionados en AWS dentro del presupuesto aprobado de **USD 2.8 millones/año** (que cubre cómputo, almacenamiento, mensajería, red, observabilidad y entorno DR en `us-east-1`).

---

## Pregunta 1 — Atributos de calidad prioritarios

A continuación se presentan los **tres atributos de calidad más importantes** para **BAP Móvil 3.0**, ordenados por prioridad:

### 1. Disponibilidad y Continuidad Operacional (Prioridad 1)

- **Justificación:** La interoperabilidad de pagos con Yape, Plin y BIM vía CCE-BCRP exige operación **24/7/365**. El negocio establece una disponibilidad mínima de **99.95% mensual** (≤ 22 minutos de downtime al mes) y la **Circular G-139-2009** de la SBS exige **RTO ≤ 30 minutos** y **RPO ≤ 1 minuto**. Además, el tráfico alcanza **9 millones de sesiones diarias** en quincenas y fiestas sobre una base de 1.8 millones de clientes, mientras el sistema debe convivir con un core mainframe COBOL on-premise que tiene ventanas de mantenimiento y menor elasticidad.
- **Riesgo si no se aborda:** Interrupciones durante quincenas o campañas bloquean transferencias y pagos de planilla/MYPE, generan sanciones regulatorias de la SBS por incumplimiento de continuidad operacional, y aceleran la fuga del segmento joven (18–35 años) hacia billeteras competidoras.
- **Interacción con otros atributos:**
  - *Conflicto con Latencia / Desempeño:* Mantener un RPO = 0 entre regiones (`sa-east-1` y `us-east-1`) mediante replicación síncrona global añadiría ~120 ms de RTT en cada escritura, penalizando la latencia. Se equilibra usando replicación síncrona **Multi-AZ** dentro de `sa-east-1` y replicación asíncrona continua hacia `us-east-1` (RPO ≤ 1 min).
  - *Sinergia con Escalabilidad:* El desacoplamiento por colas/eventos y la separación de lecturas (CQRS) evitan que el core COBOL se convierta en punto único de falla o cuello de botella.

### 2. Desempeño y Escalabilidad (Latencia y Throughput) (Prioridad 2)

- **Justificación:** El sistema debe procesar transferencias interbancarias en **p95 ≤ 5 segundos** end-to-end (frente al límite de 10 s del BCRP), responder consultas de saldo en **p95 ≤ 800 ms** y ejecutar la detección de fraude en **< 2 segundos** antes de la acreditación. Asimismo, debe escalar de **120 TPS** promedio a **1,200 TPS** sostenidos (10x) y **2,500 TPS** instantáneos (~21x), manteniendo fluidez incluso en redes 3G/4G intermitentes.
- **Riesgo si no se aborda:** Tiempos de espera elevados provocan timeouts contra la CCE-BCRP, acumulación de cola en el motor de fraude (permitiendo acreditar operaciones fraudulentas si vence el tiempo), saturación del mainframe COBOL y abandono de la app por mala experiencia frente a Yape/Plin.
- **Interacción con otros atributos:**
  - *Conflicto con Seguridad y Auditabilidad:* Cifrado TLS 1.3, tokenización PCI-DSS v4, evaluación antifraude en línea (< 2 s) y emisión de ~80 millones de eventos diarios consumen CPU y añaden saltos de red. Se resuelve evaluando fraude en streaming en memoria (Apache Flink), cacheando saldos en Redis y emitiendo eventos de auditoría de forma asíncrona.
  - *Sinergia con Disponibilidad:* El autoescalado horizontal y el caché distribuido protegen la estabilidad del sistema durante picos estacionales de 5x–20x.

### 3. Seguridad y Cumplimiento Regulatorio (Confidencialidad, Integridad y Trazabilidad) (Prioridad 3)

- **Justificación:** El marco regulatorio peruano exige cumplimiento estricto de la **Ley N° 29733** (Protección de Datos Personales), **Resolución SBS N° 2660-2015** (PLAFT: reportes mensuales ROS y semanales ROU/ROM a la UIF-Perú) y **PCI-DSS v4** (tokenización de PAN para 1.6M tarjetas de débito y 380k de crédito). Además, los datos sensibles (DNI, cuentas, montos, geolocalización) deben viajar con **TLS 1.3** y reposar cifrados con **AES-256**, y el fraude debe bloquearse antes de acreditar (< 2 s).
- **Riesgo si no se aborda:** Pérdidas financieras directas por fraude sobre el patrimonio efectivo (S/ 1,850 millones), multas graves de SBS/UIF-Perú, filtración de datos personales y pérdida de cumplimiento PCI-DSS.
- **Interacción con otros atributos:**
  - *Conflicto con Desempeño:* La verificación criptográfica, tokenización y reglas antifraude en línea agregan sobrecarga por transacción.
  - *Sinergia con Integridad / Disponibilidad:* El uso de `Idempotency-Key` y firmas seguras previene duplicación de débitos ante reintentos en redes 3G/4G inestables.

---

## Pregunta 2 — Escenarios de calidad

A continuación se documentan **nueve escenarios** (tres por cada atributo prioritario) utilizando la estructura de seis partes:

### Escenarios de Disponibilidad y Continuidad Operacional

#### ESC-01 — Caída de una Zona de Disponibilidad (AZ) en `sa-east-1` durante pico de quincena <a id="esc-01"></a>
- **Fuente del estímulo:** Falla de hardware, red o energía en infraestructura cloud de AWS.
- **Estímulo:** Pérdida súbita de una Zona de Disponibilidad completa en la región primaria `sa-east-1`.
- **Artefacto:** Clúster de microservicios (Cuentas, Pagos, BFF), caché Redis y base transaccional RDS Oracle Multi-AZ.
- **Entorno:** Operación en horario pico de quincena con carga sostenida de **1,200 TPS**.
- **Respuesta:** Los balanceadores y health checks detectan la caída de la AZ, redirigen el tráfico hacia las AZs saludables restantes, promueven automáticamente la réplica síncrona standby de RDS/Redis y reescalan pods en las AZs activas.
- **Medida de respuesta:** Recuperación automática del enrutamiento en **< 60 segundos**, **0 transacciones confirmadas perdidas**, manteniendo la disponibilidad mensual **≥ 99.95%** (≤ 22 min/mes de downtime).

#### ESC-02 — Desastre regional completo en AWS `sa-east-1` <a id="esc-02"></a>
- **Fuente del estímulo:** Evento catastrófico o falla generalizada de la región AWS `sa-east-1`.
- **Estímulo:** Indisponibilidad total de los servicios y bases de datos en São Paulo.
- **Artefacto:** Plataforma completa BAP Móvil 3.0 y entorno Warm Standby en `us-east-1` (Norte de Virginia).
- **Entorno:** Operación productiva normal o en campaña (24/7/365).
- **Respuesta:** Se activa el plan de continuidad operacional (Circular G-139-2009): Route 53 conmuta el tráfico hacia `us-east-1`, se promueve la réplica de base de datos, se escalan los contenedores en standby y se habilita el enlace Direct Connect de respaldo hacia el core en Lima.
- **Medida de respuesta:** **RTO ≤ 30 minutos** para restablecer el canal móvil y **RPO ≤ 1 minuto** de datos transaccionales.

#### ESC-03 — Degradación o ventana de mantenimiento del Core Mainframe COBOL on-premise <a id="esc-03"></a>
- **Fuente del estímulo:** Equipo de TI on-premise / falla en enlace o mainframe COBOL en Lima.
- **Estímulo:** El core bancario deja de responder mensajes de IBM MQ durante 20 minutos en horario operativo.
- **Artefacto:** Adaptador ACL Core, Servicio de Cuentas y Saldos, Servicio de Pagos y API Gateway.
- **Entorno:** Operación 24/7 con usuarios realizando consultas y transferencias desde la app móvil.
- **Respuesta:** El ACL activa el patrón *Circuit Breaker* evitando el agotamiento de hilos; las consultas de saldos continúan atendiéndose desde el caché Redis / proyección CQRS; las operaciones contables diferibles se encolan en mensajería persistente para sincronización posterior y las transferencias que requieren core en línea devuelven degradación controlada sin tumbar el canal.
- **Medida de respuesta:** Disponibilidad de consultas de saldo **≥ 99.95%** (**p95 ≤ 800 ms**) y tasa de errores `5xx` no controlados en API Gateway **< 0.1%**.

---

### Escenarios de Desempeño y Escalabilidad

#### ESC-04 — Latencia de transferencia interbancaria interoperable bajo pico sostenido <a id="esc-04"></a>
- **Fuente del estímulo:** Cliente final desde la App Móvil BAP 3.0 en red 4G.
- **Estímulo:** Solicitud de transferencia interbancaria hacia billetera Yape/Plin/BIM vía CCE-BCRP.
- **Artefacto:** Mobile BFF, Servicio de Pagos (Saga), Motor de Fraude (Flink), Card Vault, BD Transaccional y conexión CCE-BCRP.
- **Entorno:** Pico sostenido de quincena durante 15 minutos con **1,200 TPS** concurrentes.
- **Respuesta:** El BFF autentica la sesión, el Servicio de Pagos valida idempotencia, consulta al Motor de Fraude (< 2 s), reserva fondos, envía la orden ISO 20022/REST a la CCE-BCRP y confirma la acreditación al cliente.
- **Medida de respuesta:** Latencia end-to-end **p95 ≤ 5 segundos** (cumpliendo el límite de < 10 s del BCRP).

#### ESC-05 — Avalancha de consultas de saldos y movimientos en días de pago <a id="esc-05"></a>
- **Fuente del estímulo:** Base de clientes móviles (1.2M MAU).
- **Estímulo:** **9 millones de sesiones diarias** con ráfagas de consultas de saldo y últimos movimientos tras el abono de planillas.
- **Artefacto:** API Gateway, Servicio de Cuentas y Saldos y Caché Distribuido (ElastiCache Redis).
- **Entorno:** Día de quincena o Fiestas Patrias con tráfico **5x** sobre el promedio.
- **Respuesta:** Las lecturas se resuelven directamente desde el caché Redis / réplica CQRS sin invocar al mainframe COBOL on-premise; el clúster de microservicios escala horizontalmente de forma automática.
- **Medida de respuesta:** Latencia de consulta de saldos **p95 ≤ 800 ms** y autoescalado de nuevas réplicas en **< 90 segundos**.

#### ESC-06 — Pico instantáneo de eventos transaccionales en campañas (Black Friday / Cyber Day) <a id="esc-06"></a>
- **Fuente del estímulo:** Tráfico masivo de clientes en campañas comerciales.
- **Estímulo:** Ráfaga instantánea de **2,500 TPS** generando **~80 millones de eventos diarios** (1.2 KB JSON por evento).
- **Artefacto:** Bus de Eventos (Amazon MSK / Kafka) y Motor de Fraude en streaming (Apache Flink).
- **Entorno:** Evento comercial masivo sin degradar el flujo transaccional de pagos.
- **Respuesta:** Los servicios publican eventos particionados por `customerId` en MSK de forma asíncrona (para analítica) y Flink procesa el stream en paralelo con ventanas de tiempo en memoria sin bloquear la base transaccional Oracle.
- **Medida de respuesta:** **0% de pérdida de eventos**, evaluación antifraude en **< 2 segundos** y ausencia de *backpressure* que eleve la latencia de pagos por encima de **5 segundos**.

---

### Escenarios de Seguridad y Cumplimiento Regulatorio

#### ESC-07 — Bloqueo preventivo de transferencia fraudulenta antes de acreditación <a id="esc-07"></a>
- **Fuente del estímulo:** Actor malicioso utilizando credenciales comprometidas desde dispositivo nuevo y geolocalización anómala.
- **Estímulo:** Intento de transferencia interbancaria de monto atípico hacia cuenta de destino sin historial previo.
- **Artefacto:** Servicio de Pagos (Saga) y Motor de Detección de Fraude (Apache Flink).
- **Entorno:** Operación en tiempo real 24/7 con flujo hacia CCE-BCRP.
- **Respuesta:** Antes de enviar la instrucción de acreditación definitiva a la CCE-BCRP, el Motor de Fraude evalúa reglas de velocidad, dispositivo y geolocalización, marca la operación como sospechosa, aborta la Saga, libera la reserva y genera una alerta en el Portal de Riesgos.
- **Medida de respuesta:** Detección y bloqueo en **< 2 segundos** desde el ingreso de la operación, con **100% de operaciones bloqueadas sin acreditación final en destino**.

#### ESC-08 — Protección de datos sensibles y PAN bajo PCI-DSS v4 y Ley N° 29733 <a id="esc-08"></a>
- **Fuente del estímulo:** Intento de intercepción de tráfico o acceso no autorizado a almacenamiento de datos.
- **Estímulo:** Exposición potencial de DNI, número de cuenta, montos, geolocalización o PAN de tarjetas (1.6M débito / 380k crédito).
- **Artefacto:** API Gateway, tráfico mTLS interno, Card Vault, RDS Oracle, Redis, MSK y S3.
- **Entorno:** Operación continua y auditorías de seguridad PCI-DSS v4 / SBS.
- **Respuesta:** Todo el tráfico externo usa **TLS 1.3**, el tráfico interno usa **mTLS**, los almacenes cifran datos en reposo con **AES-256** gestionado por AWS KMS y los números de tarjeta (PAN) se tokenizan en el Card Vault aislado antes de persistirse o emitirse como eventos.
- **Medida de respuesta:** **0% de PAN o datos sensibles almacenados o transmitidos en texto plano**; **100% de conformidad** con controles criptográficos de PCI-DSS v4 y Ley N° 29733.

#### ESC-09 — Generación trazable e íntegra de reportes PLAFT para UIF-Perú <a id="esc-09"></a>
- **Fuente del estímulo:** Calendario regulatorio de la SBS / UIF-Perú (Resolución SBS N° 2660-2015).
- **Estímulo:** Cierre semanal para reportes **ROU/ROM** y cierre mensual para reportes **ROS**.
- **Artefacto:** Data Lake (Amazon S3), motor batch (AWS Glue/Spark) y Portal de Riesgos y Cumplimiento.
- **Entorno:** Volumen acumulado de **~80M eventos/día** (**~35 TB/año** sin compresión) con conciliación contra core COBOL.
- **Respuesta:** El pipeline batch consolida, deduplica y cruza los eventos inmutables en S3 con los movimientos del core bancario, generando los archivos regulatorios firmados y auditables para revisión del Oficial de Cumplimiento.
- **Medida de respuesta:** **100% de completitud e integridad** de reportes ROU/ROM (semanales) y ROS (mensuales) entregados dentro del plazo legal sin discrepancias de conciliación.

---

## Pregunta 3 — Decisiones de arquitectura (ADRs)

Se documentaron **cinco decisiones de arquitectura (ADRs)** en la carpeta [`adrs/`](adrs/), cubriendo **cuatro categorías distintas** del marco de Bass et al. (*Asignación de responsabilidades*, *Coordinación*, *Datos*, *Mapeo / Gestión de recursos* y *Tecnología*).

| ID | Título de la Decisión | Categoría (Bass et al.) | Escenarios Trazados | Documento |
|---|---|---|---|---|
| **ADR-01** | Desacoplamiento del Core Bancario mediante CQRS y Anti-Corruption Layer (ACL) | Asignación de responsabilidades / Datos | [ESC-03](#esc-03), [ESC-04](#esc-04), [ESC-05](#esc-05) | [ADR-01-cqrs-acl-core-bancario.md](adrs/ADR-01-cqrs-acl-core-bancario.md) |
| **ADR-02** | Orquestación de Pagos en Tiempo Real con Patrón Saga, Idempotencia y Validación Antifraude Pre-Acreditación | Coordinación | [ESC-01](#esc-01), [ESC-04](#esc-04), [ESC-07](#esc-07) | [ADR-02-saga-idempotencia-pagos.md](adrs/ADR-02-saga-idempotencia-pagos.md) |
| **ADR-03** | Topología Multi-AZ Activo-Activo en `sa-east-1` y DR Warm Standby en `us-east-1` | Mapeo / Gestión de recursos | [ESC-01](#esc-01), [ESC-02](#esc-02), [ESC-05](#esc-05) | [ADR-03-multi-az-warm-standby-dr.md](adrs/ADR-03-multi-az-warm-standby-dr.md) |
| **ADR-04** | Plataforma de Streaming de Eventos (Amazon MSK + Flink) y Data Lake para Fraude y PLAFT | Tecnología / Coordinación | [ESC-06](#esc-06), [ESC-07](#esc-07), [ESC-09](#esc-09) | [ADR-04-streaming-msk-flink-datalake.md](adrs/ADR-04-streaming-msk-flink-datalake.md) |
| **ADR-05** | Seguridad Perimetral, Tokenización PCI-DSS v4 y Cifrado Centralizado con AWS KMS | Asignación de responsabilidades / Tecnología | [ESC-07](#esc-07), [ESC-08](#esc-08) | [ADR-05-seguridad-tokenizacion-pcidss-kms.md](adrs/ADR-05-seguridad-tokenizacion-pcidss-kms.md) |

---

## Pregunta 4 — Diagrama de Contexto y Contenedores en C4

### Diagrama de Contexto (C4 Nivel 1)

![Diagrama de Contexto C4 - BAP Móvil 3.0](diagrams/c4-contexto.svg)

*Fuente Structurizr DSL (vista `C4_Contexto`):* [`diagrams/workspace.dsl`](diagrams/workspace.dsl)

### Diagrama de Contenedores (C4 Nivel 2)

![Diagrama de Contenedores C4 - BAP Móvil 3.0](diagrams/c4-contenedores.svg)

*Fuente Structurizr DSL (vista `C4_Contenedores`):* [`diagrams/workspace.dsl`](diagrams/workspace.dsl)

### Leyenda

- **Cajas azul oscuro (personas):** Actores humanos que interactúan con el sistema (Cliente Final, Analista de Fraude, Oficial de Cumplimiento y Operador Back Office).
- **Cajas azules / cilindros (contenedores):** Aplicaciones, microservicios, almacenes de datos (RDS Oracle, Redis, S3) y bus de eventos (MSK) desplegados dentro de la frontera de **BAP Móvil 3.0** en AWS `sa-east-1` (con DR Warm Standby en `us-east-1`).
- **Cajas grises:** Sistemas externos fuera del control directo de BAP Móvil 3.0 (**CCE-BCRP**, **UIF-Perú / SBS**, **Centrales de Riesgo**) y el **Core Bancario Mainframe COBOL** on-premise en Lima.
- **Líneas continuas oscuras:** Comunicación **síncrona** (HTTPS/TLS 1.3, REST/mTLS, gRPC, JDBC, ISO 20022).
- **Líneas discontinuas ámbar:** Comunicación **asíncrona / batch** (eventos Kafka en MSK, mensajería IBM MQ/CDC y envío batch SFTP/API).
- **Recuadro discontinuo:** Frontera lógica del sistema **BAP Móvil 3.0** en AWS.

### Explicación de agrupamiento y coherencia con los ADRs

Los contenedores se agrupan por **responsabilidad de dominio y ciclo de vida de los 6 squads**, manteniendo una frontera clara en AWS `sa-east-1` separada del **Core Bancario COBOL** on-premise en Lima y de los entes externos (CCE-BCRP, UIF-Perú, Centrales de Riesgo). En el borde, el **API Gateway & Mobile BFF** concentra seguridad perimetral (TLS 1.3, OAuth2/OIDC, WAF) y el **Card Vault** aísla la tokenización de PAN conforme al **ADR-05**. Los servicios de negocio (*Cuentas y Saldos*, *Pagos e Interoperabilidad*, *Créditos*) se desacoplan del mainframe mediante el **Adaptador ACL Core** y separan lecturas rápidas en **Redis** (CQRS) de las escrituras transaccionales en **RDS Oracle Multi-AZ** (**ADR-01** y **ADR-03**).

Para garantizar la acreditación en **p95 ≤ 5 segundos** y el bloqueo antifraude en **< 2 segundos**, el **Servicio de Pagos** orquesta la transacción mediante el patrón **Saga** con `Idempotency-Key` (**ADR-02**), consultando de manera síncrona al **Motor de Fraude (Apache Flink)** antes de confirmar con la CCE-BCRP. Paralelamente, todos los cambios y eventos transaccionales (~80 millones/día) fluyen de forma asíncrona hacia **Amazon MSK (Kafka)** (**ADR-04**), alimentando tanto el análisis continuo en Flink como la ingesta hacia el **Data Lake (Amazon S3 + Glue/Spark)** para la generación auditable de reportes regulatorios **ROU/ROM** y **ROS**.

---

## Pregunta 5 — Necesidades de procesamiento de datos: batch vs. streaming

A partir del caso se identifican **dos necesidades concretas de procesamiento de datos** con requisitos opuestos de latencia y consolidación histórica:

---

### Necesidad 1: Detección de fraude en tiempo real sobre transferencias y pagos interoperables

1. **Descripción:**
   - **Entradas:** Eventos transaccionales en tiempo real (~80 millones/día, 1.2 KB JSON por evento, picos de 2,500 TPS) con monto, cuenta origen/destino, canal, dispositivo, IP y geolocalización, enriquecidos con ventanas históricas recientes del cliente.
   - **Salidas:** Score de riesgo y decisión (`APROBAR` / `BLOQUEAR` / `ALERTAR`) más alertas en vivo para el equipo de Riesgos.
   - **Consumidores:** Servicio de Pagos e Interoperabilidad (para bloqueo pre-acreditación) y Analistas de Fraude en el Portal de Riesgos.
   - **Periodicidad:** Continua, en tiempo real (**< 2 segundos** desde el ingreso de la operación).

2. **Análisis de procesamiento en Batch:**
   - *Pros:* Menor complejidad de implementación y operación; costo de cómputo predecible al ejecutarse en ventanas programadas; fácil reprocesamiento histórico ante cambios en reglas o modelos ML.
   - *Contras:* **Frescura insuficiente** (minutos u horas de retraso). Dado que las transferencias CCE-BCRP se acreditan en < 5–10 segundos, detectar el fraude después en batch solo permite análisis forense, cuando los fondos ya salieron del banco.

3. **Análisis de procesamiento en Streaming:**
   - *Pros:* **Latencia sub-segundo** (< 2 s), permitiendo bloquear la operación antes de la acreditación final; evalúa patrones temporales en ventanas deslizantes (ej. múltiples intentos desde distintos dispositivos en 5 minutos).
   - *Contras:* Mayor complejidad operativa (gestión de estado en memoria, *checkpointing* para tolerancia a fallos, *watermarks* para eventos fuera de orden y deduplicación por `eventId`); mayor costo de cómputo continuo 24/7 para soportar picos de 2,500 TPS.

4. **Enfoque recomendado:** **Streaming puro (arquitectura tipo Kappa)** sobre **Amazon MSK + Apache Flink**.
   - *Justificación:* Responde directamente a los atributos de **Seguridad** y **Desempeño** priorizados en la Pregunta 1 y al requisito explícito de bloquear operaciones sospechosas en **< 2 segundos** antes de la acreditación final (ESC-06 y ESC-07).

---

### Necesidad 2: Generación de reportes regulatorios PLAFT (ROU/ROM y ROS) para la UIF-Perú y conciliación contable

1. **Descripción:**
   - **Entradas:** Flujo completo de eventos transaccionales (~80 millones/día, **~35 TB/año** sin compresión), datos maestros de clientes/cuentas y archivos planos/mensajes de cierre del core bancario COBOL.
   - **Salidas:** Reportes regulatorios estructurados **ROU/ROM** (Operaciones Únicas y Múltiples), reportes **ROS** (Operaciones Sospechosas) y actas de conciliación contable.
   - **Consumidores:** Oficial de Cumplimiento, Gerencia de Operaciones y **UIF-Perú / SBS** (Resolución SBS N° 2660-2015).
   - **Periodicidad:** **Semanal** para ROU/ROM y **mensual** para ROS (con conciliación diaria).

2. **Análisis de procesamiento en Batch:**
   - *Pros:* **Exactitud y completitud** garantizadas al trabajar sobre conjuntos cerrados de datos ya conciliados con el core COBOL; facilita cruces complejos multi-tabla en ventanas largas (7 a 30 días); **reprocesamiento determinístico** ante observaciones de la SBS; bajo costo al ejecutar trabajos Spark/Glue en S3 Parquet comprimido solo cuando corresponde.
   - *Contras:* Frescura diferida (no genera alertas preventivas inmediatas si un cliente acumula operaciones fraccionadas durante el día).

3. **Análisis de procesamiento en Streaming:**
   - *Pros:* Permite detectar en vivo cuándo un usuario supera umbrales acumulados (alerta temprana de fraccionamiento / *smurfing* para el Analista de Riesgos).
   - *Contras:* Mantener estado exacto de ventanas de 30 días sobre ~2,400 millones de eventos mensuales en memoria resulta costoso y frágil; además, el reporte oficial ante la UIF requiere obligatoriamente conciliación con el cierre contable del mainframe COBOL, que sigue siendo batch/diferido.

4. **Enfoque recomendado:** **Enfoque Híbrido (Arquitectura Lambda)**.
   - *Justificación:* Combina una **capa de velocidad (Streaming en Flink)** para emitir alertas tempranas de comportamiento inusual PLAFT en tiempo real hacia la Gerencia de Riesgos, con una **capa Batch (Amazon S3 + AWS Glue/Spark)** que consolida, deduplica y concilia contra el core COBOL para producir los reportes oficiales **ROU/ROM semanales y ROS mensuales** con 100% de exactitud, auditabilidad y optimización de costos dentro del presupuesto de USD 2.8M/año (atributos de **Seguridad/Cumplimiento** y **Disponibilidad/Integridad**, ESC-09).
