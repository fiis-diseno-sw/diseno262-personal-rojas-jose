# Actividad Individual de Refuerzo

> **Modalidad:** Individual. El entregable debe colocarse en el **repositorio individual del estudiante**.
>
> **Propósito:** consolidar, sobre un caso de negocio común a toda la clase, las competencias trabajadas durante el ciclo: identificación de atributos de calidad, especificación de escenarios, decisiones de arquitectura, modelado de contenedores en C4 y diseño de procesamiento de datos (batch vs. streaming).

---

## 1. Contexto del caso: Banco Andino del Perú (BAP)

A continuación se describe el caso de negocio sobre el cual el estudiante debe trabajar. La empresa y los datos son ficticios pero proporcionan una referencia del sector. Si requiere asumir datos adicionales para responder alguna pregunta, debe declarar los supuestos explícitamente en su entregable.

### 1.1 Contexto del sector bancario peruano

La banca peruana opera bajo la regulación de la **Superintendencia de Banca, Seguros y AFP (SBS)** y del **Banco Central de Reserva del Perú (BCRP)**. El sistema financiero está fuertemente concentrado: cuatro bancos (BCP, BBVA Perú, Scotiabank e Interbank) administran cerca del 80% de los depósitos del sistema, y el resto se distribuye entre bancos medianos, cajas municipales, cajas rurales, financieras, edpymes y cooperativas. La banca digital ha crecido sostenidamente desde la pandemia: **Yape** (BCP) y **Plin** (interbancario) superan en conjunto los 20 millones de usuarios activos, y la **billetera Bim** opera bajo el modelo de dinero electrónico regulado por la Ley N° 29985.

Características relevantes del mercado peruano que condicionan el diseño de software bancario:

- **Alta informalidad económica.** Más del 70% de la PEA es informal; los clientes suelen tener ingresos variables, sin historial crediticio en centrales de riesgo tradicionales (Equifax, Sentinel) y con escasa documentación formal. Esto exige modelos de scoring alternativos basados en comportamiento transaccional.
- **Penetración móvil alta y bancarización media.** El 90% de adultos posee un smartphone, pero solo el 57% tiene una cuenta en el sistema financiero formal (BCRP, 2024). Los productos deben funcionar bien en redes 3G/4G con cobertura intermitente.
- **Marco regulatorio estricto.** La SBS exige:
  - Reporte regular de operaciones sospechosas a la **UIF-Perú** (Unidad de Inteligencia Financiera) en el marco de la **prevención de lavado de activos y financiamiento del terrorismo (PLAFT)**, conforme a la Resolución SBS N° 2660-2015.
  - **Encaje legal** sobre depósitos administrado por el BCRP.
  - Reporte diario de **posición de liquidez** y **calce de monedas** (soles / dólares).
  - Cumplimiento de la **Ley N° 29733 de Protección de Datos Personales** y su reglamento.
  - Continuidad operacional bajo la **Circular G-139-2009** (gestión de riesgo operacional).
- **Pagos en tiempo real.** Desde 2023 el BCRP impulsa la **interoperabilidad de billeteras digitales (CCE-BCRP)**: una transferencia entre Yape, Plin, BIM o cualquier billetera autorizada debe acreditarse en el destinatario en **menos de 10 segundos**, 24/7/365.
- **Estacionalidad y picos.** Las quincenas (15 y 30 de cada mes) concentran pagos de planilla; Fiestas Patrias (julio) y Navidad (diciembre) generan picos de hasta 5x el tráfico promedio.
- **Atención presencial todavía relevante.** A pesar de la digitalización, las agencias físicas siguen siendo el canal principal para apertura de cuentas de personas mayores de 50 años y operaciones de alto monto.

### 1.2 La empresa: Banco Andino del Perú (BAP)

**Banco Andino del Perú (BAP)** es un banco mediano peruano fundado en 2008, con sede en Lima y 62 agencias distribuidas en 14 departamentos. Atiende principalmente a **personas naturales de los segmentos C y D** y a **microempresas y pequeñas empresas (MYPE)** del interior del país. Su propuesta de valor histórica ha sido la cercanía con el cliente no bancarizado, con productos sencillos y atención bilingüe (español / quechua) en agencias del sur andino.

**Cifras clave (cierre 2025):**

| Indicador | Valor |
|---|---|
| Clientes activos | 1.8 millones |
| Cuentas de ahorro y corrientes | 2.4 millones |
| Tarjetas de débito vigentes | 1.6 millones |
| Tarjetas de crédito vigentes | 380 mil |
| Colaboradores | 2,100 |
| Agencias | 62 |
| Cajeros automáticos propios | 280 |
| Cajeros corresponsales (bodegas afiliadas) | 4,500 |
| Patrimonio efectivo | S/ 1,850 millones |
| Cartera de créditos | S/ 9,200 millones |

### 1.3 La iniciativa: "BAP Móvil 3.0"

Desde inicios de 2025, BAP enfrenta una pérdida sostenida de clientes jóvenes (18–35 años) hacia las billeteras digitales (Yape, Plin). El directorio ha aprobado la iniciativa **"BAP Móvil 3.0"**, un programa de transformación con tres frentes:

1. **App móvil renovada** que centralice todas las operaciones del cliente (consultas, transferencias intra e interbancarias, pagos de servicios, apertura de productos, solicitud de créditos preaprobados).
2. **Plataforma de pagos en tiempo real** interoperable con Yape, Plin, BIM y la CCE del BCRP, capaz de procesar transferencias en menos de 5 segundos.
3. **Motor de detección de fraude y prevención de lavado de activos** que opere sobre el flujo transaccional y genere alertas para el equipo de Riesgos y para el reporte regulatorio a la UIF.

El sistema debe convivir con el **core bancario actual** (un sistema mainframe COBOL de un proveedor regional con interfaces vía MQ y archivos planos), del cual no se puede prescindir en el corto plazo.

### 1.4 Datos necesarios para el diseño

**Volumetría esperada al estabilizar BAP Móvil 3.0 (proyección a 18 meses):**

- **Usuarios activos mensuales en la app:** 1.2 millones.
- **Sesiones diarias promedio:** 3.5 millones; sesiones diarias en picos (quincenas, fiestas): 9 millones.
- **Transferencias por segundo:**
  - Promedio: 120 TPS.
  - Pico sostenido (15 minutos en quincena): 1,200 TPS.
  - Pico instantáneo (eventos como Black Friday, Cyber Day): 2,500 TPS.
- **Operaciones diarias totales** (consultas + movimientos + pagos): ~45 millones.
- **Eventos transaccionales para analítica y fraude:** ~80 millones de eventos diarios (cada operación genera múltiples eventos: autenticación, validación, autorización, contabilización, notificación).
- **Tamaño promedio de evento:** 1.2 KB JSON.
- **Volumen anual de datos transaccionales:** ~35 TB sin compresión.

**Requisitos no funcionales declarados por el negocio y por regulación:**

- **Disponibilidad del canal móvil:** mínimo **99.95%** mensual (downtime tolerable ≤ 22 minutos/mes).
- **Latencia de transferencia interbancaria:** **p95 ≤ 5 segundos** end-to-end (desde que el usuario confirma hasta que recibe la respuesta de acreditación).
- **Latencia de consulta de saldos:** p95 ≤ 800 ms.
- **Tiempo de detección de fraude:** una operación marcada como sospechosa debe poder bloquearse **antes de su acreditación final** en el destinatario, es decir en **menos de 2 segundos** desde el ingreso de la operación.
- **Reporte regulatorio a la UIF:** los reportes de operaciones sospechosas (ROS) se entregan con periodicidad mensual; los reportes de operaciones únicas y múltiples (ROU/ROM) con periodicidad semanal.
- **RTO ≤ 30 minutos / RPO ≤ 1 minuto** para el sistema transaccional, según política de continuidad de BAP alineada a la Circular G-139.
- **Confidencialidad:** datos sensibles (DNI, número de cuenta, montos, geolocalización) cifrados en reposo (AES-256) y en tránsito (TLS 1.3). Tokenización de PAN según PCI-DSS v4.

**Equipo y restricciones organizacionales:**

- Equipo de ingeniería: 35 personas distribuidas en 6 squads (Cuentas, Pagos, Créditos, Fraude, Plataforma, Mobile).
- Stack actual: Java/Spring Boot en backend, Oracle como base transaccional, MQ Series para integración con core, Kotlin/Swift en mobile.
- Cloud aprobado por Comité de Riesgo Tecnológico: **AWS región São Paulo (sa-east-1)** como primaria y **AWS región Norte de Virginia (us-east-1)** como DR. El core bancario permanece on-premise en el datacenter de Lima.
- Presupuesto anual aprobado para infraestructura cloud: USD 2.8 millones.

**Stakeholders relevantes:**

- **Gerencia de Banca Digital** (sponsor).
- **Gerencia de Riesgos** (dueña del módulo de fraude y de PLAFT).
- **Gerencia de TI** (operación y continuidad).
- **Oficial de Cumplimiento** (interlocutor con SBS y UIF).
- **Gerencia de Operaciones** (back office, conciliaciones).
- **Equipo de Producto** (UX, growth, journey del cliente).

---

## 2. Preguntas

A partir del caso descrito, el estudiante debe responder las siguientes cinco preguntas en su entregable. Cada respuesta debe sustentarse en los datos del caso; cuando se asuma información adicional, declararla explícitamente.

### Pregunta 1 — Atributos de calidad prioritarios

Identifique los **tres atributos de calidad más importantes** para el sistema BAP Móvil 3.0. Ordene por importancia y, por cada atributo:

- Justifique su selección a partir del contexto del caso (volumetría, regulación, riesgos de negocio, expectativas del cliente).
- Explique qué se pone en riesgo si el atributo no se aborda adecuadamente en el diseño.
- Mencione al menos una **interacción** con otros atributos de calidad (sinergia o conflicto).

### Pregunta 2 — Escenarios de calidad

Documente **tres escenarios de atributo de calidad** por cada uno de los atributos identificados en la Pregunta 1 (nueve escenarios en total). Utilice la estructura de **seis partes** vista en clase: fuente del estímulo, estímulo, artefacto, entorno, respuesta y medida de respuesta. Los escenarios deben ser específicos al caso de BAP (no genéricos) y la medida de respuesta debe ser **cuantificable** y trazable a los requisitos no funcionales declarados en la sección 1.4.

### Pregunta 3 — Decisiones de arquitectura

Documente **al menos cinco decisiones de arquitectura** que permitan abordar los escenarios planteados en la Pregunta 2. Use el formato ADR visto en clase (Título, Categoría, Contexto, Alternativas, Criterios de Elección, Decisión, Sustento). Cada ADR debe:

- Estar **trazado explícitamente** a uno o más escenarios de la Pregunta 2 (indique a cuál(es) responde).
- Contemplar **al menos dos alternativas viables** y los trade-offs aceptados.
- Cubrir entre los tres ADR al menos **dos categorías distintas** del marco de Bass et al. (asignación de responsabilidades, coordinación, datos, gestión de recursos, mapeo, tiempo de enlace, tecnología).

### Pregunta 4 — Diagrama de contenedores en C4

Elabore el **diagrama de contexto y el diagram de contenedores (nivel 1 y 2 de C4)** del sistema BAP Móvil 3.0. El diagrama debe incluir como mínimo:

- Los **actores** relevantes (cliente final, oficial de cumplimiento, analista de fraude, sistemas externos como CCE-BCRP, UIF y centrales de riesgo).
- Los **contenedores** del sistema (apps móviles, BFF/API gateway, servicios, bases de datos, colas, motor de fraude, integraciones con el core, etc.).
- Las **relaciones** entre contenedores indicando protocolo, tecnología y modo de coordinación (síncrono / asíncrono).
- La **frontera del sistema** y la separación con el core bancario y con sistemas externos.

Acompañe el diagrama de una **leyenda** y de una **breve descripción** (1–2 párrafos) que explique las decisiones de agrupamiento y la coherencia del diagrama con los ADR de la Pregunta 3.

### Pregunta 5 — Necesidades de procesamiento de datos: batch vs. streaming

Identifique **dos necesidades concretas de procesamiento de datos** que se desprenden del caso (por ejemplo: detección de fraude, reportes regulatorios a la SBS/UIF, conciliación con el core, scoring crediticio, métricas de uso de producto, alertas operativas, etc.).

Por cada necesidad:

1. Descríbala brevemente (qué datos entran, qué se produce, quién la consume, con qué periodicidad).
2. Analice los **pros y contras de procesarla en batch** (frescura de datos, complejidad, costo, exactitud, reprocesos).
3. Analice los **pros y contras de procesarla en streaming** (latencia, complejidad, costo, manejo de orden y duplicados, tolerancia a fallos).
4. **Recomiende un enfoque** (batch, streaming o híbrido tipo lambda/kappa) y justifíquelo en función de los atributos de calidad priorizados en la Pregunta 1 y de los requisitos del caso.

---

## 3. Entregables

El estudiante debe publicar en su **repositorio individual**, dentro de una carpeta con el mismo nombre que la de este archivo README, los siguientes artefactos:

- `README.md` con el desarrollo de las cinco preguntas, en el orden indicado.
- Carpeta `adrs/` con un archivo markdown por cada ADR documentado en la Pregunta 3. Debe referenciarlos como links en el documento principal.
- Carpeta `diagrams/` con el diagrama de contenedores en formato imagen (`.png` o `.svg`) y, opcionalmente, el archivo fuente (`.dsl`, `.drawio`, `.mmd`).
- Declaración explícita de **supuestos adicionales** asumidos al inicio del documento, si los hubiera.
