# Evaluación de Arquitectura de Software: Caso AgentHub

---

## Pregunta 1: Atributos de Calidad Priorizados

A continuación se presentan los **5 atributos de calidad más importantes** para AgentHub, ordenados estrictamente de **menor a mayor relevancia relativa** para el éxito técnico y comercial del negocio:


```
[Menos importante]                                                          [Más importante]
Modificabilidad  <  Escalabilidad  <  Interoperabilidad  <  Seguridad  <  Disponibilidad
```

### 5. Modificabilidad
* **Sustento:** La plataforma planea expandirse en 18 meses a múltiples jurisdicciones (Perú, Colombia, México y Chile), incorporar nuevos esquemas de cobro (suscripción, pago por uso, licencias) y admitir categorías de agentes aún no concebidas sin requerir refactorizaciones estructurales profundas. Si bien es vital para el crecimiento a mediano plazo, durante la etapa inicial del MVP la capacidad de aislar la integración fiscal (SUNAT, DIAN) y de pagos es secundaria frente a mantener la plataforma operativa y segura.

### 4. Escalabilidad
* **Sustento:** El marketplace prevé alojar entre 200 y 500 agentes y hasta 150 organizaciones durante su primer año, pero el tráfico de invocación programática puede experimentar picos abruptos si una organización despliega un agente en procesos batch o interfaces de atención masiva. El sistema de metering, registro de tokens y proxy de invocaciones debe crecer elásticamente en procesamiento sin degradar los costos de infraestructura ni colapsar la base de datos central.

### 3. Interoperabilidad
* **Sustento:** AgentHub actúa como un orquestador e intermediario técnico universal. Debe conectarse sin fricción hacia sistemas heterogéneos externos: proveedores de LLMs/agentes alojados en diversas nubes (GCP, AWS, Azure, on-premise de casas de software), pasarelas de pago, sistemas tributarios (SUNAT/OSE), y aplicaciones cliente mediante SDKs (Python, JS, Java) o conectores empresariales (Slack, Teams, Salesforce, SAP). Sin interoperabilidad estandarizada, el modelo de integración unificada no es viable.

### 2. Seguridad (Confidencialidad, Control de Acceso y No Repudio)
* **Sustento:** La plataforma procesa información corporativa altamente confidencial en los payloads de entrada y salida (contratos legales, datos bancarios, balances financieros, registros médicos). Asimismo, administra credenciales maestras (API Keys de organizaciones, secrets de agentes de desarrolladores) y procesa transacciones monetarias sujetas a auditoría y retención de comisión. Una filtración de datos de un cliente o el uso no autorizado de claves destruiría de forma irreversible la confianza corporativa en el marketplace.

### 1. Disponibilidad
* **Sustento:** Representa el atributo **más crítico**. Cuando las organizaciones integran agentes en sus operaciones críticas (atención a clientes 24/7, validación documental en tiempo real o detección de fraudes transaccionales), cualquier caída de AgentHub paraliza de forma directa los procesos de negocio de sus clientes corporativos. Si el proxy intermediario no responde, el cliente no puede desviar el tráfico de inmediato. La plataforma debe garantizar SLAs de alta disponibilidad para justificar el cobro de planes premium y retener a los clientes enterprise.

---

## Pregunta 2: Escenarios de Atributos de Calidad (Formato de 6 Partes)

Se seleccionaron los cuatro atributos prioritarios: **Disponibilidad**, **Seguridad**, **Interoperabilidad** y **Escalabilidad**.

### 1. Atributo de Calidad: Disponibilidad

#### Escenario DISP-01: Caída de un nodo en el clúster de ejecución e invocación
* **Fuente del Estímulo:** Fallo de hardware en el proveedor de nube o kernel panic en la instancia de cómputo.
* **Estímulo:** Uno de los pods principales del gateway de invocación de agentes queda inaccesible durante horario laboral pico.
* **Artefacto:** Cluster del Gateway de Invocación y Proxy de Agentes (*Agent Execution Gateway*).
* **Entorno:** Operación regular de producción con alta tasa de tráfico concurrente.
* **Respuesta:** Los balanceadores de carga detectan el fallo de health-check, retiran el nodo averiado del pool en menos de 2 segundos, redirigen el tráfico entrante a pods activos y el orquestador levanta una réplica de reemplazo.
* **Medida de Respuesta:** Cero peticiones de clientes abortadas (reintento automático a nivel proxy con error rate $< 0.01\%$) y tiempo de restauración completa de redundancia $\le 30\text{ segundos}$.

#### Escenario DISP-02: Indisponibilidad temporal o latencia excesiva del agente del desarrollador
* **Fuente del Estímulo:** Endpoint del desarrollador externo caído o severamente saturado.
* **Estímulo:** Invocación corporativa a un agente externo cuyo endpoint supera el timeout estipulado (ej. $> 15\text{ s}$) o responde con error HTTP 5xx.
* **Artefacto:** Mecanismo de Circuit Breaker y Enrutamiento del Gateway.
* **Entorno:** Invocación síncrona en producción realizada por una aplicación corporativa integrada.
* **Respuesta:** El gateway intercepta el fallo, abre el circuito para evitar saturación de hilos, devuelve un error normalizado con código semántico estandarizado e informa el incidente en las métricas de disponibilidad del agente.
* **Medida de Respuesta:** Apertura de circuito tras 5 fallos consecutivos, liberación de conexión hacia el cliente en $\le 500\text{ ms}$ y registro automático de degradación del SLA del desarrollador.

---

### 2. Atributo de Calidad: Seguridad

#### Escenario SEG-01: Inyección de payload no autorizado o uso de API Key revocada
* **Fuente del Estímulo:** Cliente desautorizado o atacante externo.
* **Estímulo:** Envío de una ráfaga de peticiones HTTP con una API Key vencida, manipulada o perteneciente a un agente no contratado.
* **Artefacto:** Filtro Perimetral de Autenticación y Autorización del API Gateway.
* **Entorno:** Conexión pública a través de Internet hacia los endpoints de integración.
* **Respuesta:** El filtro valida criptográficamente el token/hash de la API Key en memoria local (caché distribuida), comprueba el contrato activo en la matriz de suscripciones y rechaza la solicitud de inmediato sin transferir la carga al agente.
* **Medida de Respuesta:** $100\%$ de invocaciones no autorizadas bloqueadas con código `401 Unauthorized` o `403 Forbidden` en un tiempo de procesamiento perimetral $\le 15\text{ ms}$.

#### Escenario SEG-02: Protección y confidencialidad de datos corporativos en tránsito y reposo
* **Fuente del Estímulo:** Atacante con acceso interceptivo a la red interna o sniffing de comunicaciones.
* **Estímulo:** Intento de captura de payloads de entrada que contienen contratos legales y balances corporativos.
* **Artefacto:** Capa de Transporte Seguro y Motor de Registro de Auditoría (Metering).
* **Entorno:** Transmisión de peticiones hacia el agente externo y persistencia de logs de uso.
* **Respuesta:** Cifrado forzoso de extremo a extremo mediante TLS 1.3 con mTLS hacia endpoints calificados de desarrolladores; almacenamiento disociado donde los payloads sensibles no se guardan en claro en los logs de metering (solo se almacenan metadatos de tokens, tiempo y status).
* **Medida de Respuesta:** $0\%$ de exposición de datos confidenciales en bitácoras de depuración y cumplimiento normativo del $100\%$ de directrices de protección de datos personales.

---

### 3. Atributo de Calidad: Interoperabilidad

#### Escenario INT-01: Integración homogénea desde un conector empresarial (Salesforce / Slack)
* **Fuente del Estímulo:** Usuario final de una organización desde un canal de mensajería empresarial.
* **Estímulo:** Recepción de un mensaje en lenguaje natural desde un conector de Slack hacia un agente de atención al cliente.
* **Artefacto:** Módulo de Adaptadores y Webhooks de Integración Empresarial.
* **Entorno:** Conversación multi-turno con payload propietario de Slack.
* **Respuesta:** El adaptador normaliza el payload de Slack al esquema JSON estándar de AgentHub, añade el identificador de sesión/conversación, despacha la petición al agente y convierte la respuesta JSON devuelta al formato de bloques visuales de la plataforma cliente.
* **Medida de Respuesta:** Latencia agregada por transformación de formato $\le 40\text{ ms}$; compatibilidad garantizada del $100\%$ del esquema unificado de AgentHub con los 4 conectores oficiales.

#### Escenario INT-02: Emisión e interoperabilidad fiscal con SUNAT en transacciones
* **Fuente del Estímulo:** Motor de Facturación y Liquidación Periódica.
* **Estímulo:** Cierre de ciclo quincenal de liquidaciones y cobros a organizaciones con emisión de factura electrónica.
* **Artefacto:** Módulo de Integración Tributaria y Facturación Electrónica (PSE / OSE SUNAT).
* **Entorno:** Ejecución automática programada en cierre fiscal quincenal.
* **Respuesta:** Construir el documento XML bajo el estándar UBL 2.1, firmarlo digitalmente con certificado digital corporativo, enviarlo al OSE/SUNAT y recibir la Constancia de Recepción (CDR).
* **Medida de Respuesta:** Generación, validación y recepción de CDR conforme a ley para el $100\%$ de facturas generadas en un lapso $\le 5.0\text{ segundos}$ por comprobante.

---

### 4. Atributo de Calidad: Escalabilidad

#### Escenario ESC-01: Pico de consumo masivo de procesamiento batch por clientes corporativos
* **Fuente del Estímulo:** Múltiples aplicaciones corporativas procesando lotes nocturnos de documentos.
* **Estímulo:** Incremento intempestivo de 20 a 1,200 invocaciones concurrentes por segundo dirigidas a agentes de procesamiento documental.
* **Artefacto:** Agent Execution Gateway y Sistema de Autoscaling (KEDA / HPA).
* **Entorno:** Horas no hábiles durante cierres contables mensuales.
* **Respuesta:** Las políticas de autoscaling horizontal incrementan dinámicamente las réplicas de los contenedores de gateway y workers de mensajería, gestionando el rate limiting configurado por organización.
* **Medida de Respuesta:** Degradación de latencia atribuible a AgentHub $\le 80\text{ ms}$; tasa de error por agotamiento de recursos del sistema igual a $0\%$.

#### Escenario ESC-02: Registro masivo de métricas de metering sin bloqueo transaccional
* **Fuente del Estímulo:** Flujo constante de respuestas generadas por agentes de alta concurrencia.
* **Estímulo:** Ingreso sostenido de 5,000 eventos de consumo (tokens, latencia, costo estimado) por segundo.
* **Artefacto:** Pipeline Asíncrono de Métricas y Facturación (Cola de Eventos + Base de Datos de Series Temporales).
* **Entorno:** Operación regular en horario comercial.
* **Respuesta:** El gateway publica los metadatos de ejecución en un tópico particionado en memoria de forma no bloqueante; los consumidores ingieren por lotes (*batch*) en el almacén de series temporales/OLAP.
* **Medida de Respuesta:** Impacto sobre la latencia de respuesta de la invocación $\le 5\text{ ms}$; cero pérdida de eventos de cobro/liquidación ($100\%$ consistencia eventual garantizada).

---

## Pregunta 5: Justificación del Contenedor Seleccionado para Nivel 3

Para el Diagrama de Componentes (Nivel 3), se seleccionó el contenedor:
**`Agent Execution Gateway & Metering Engine` (Gateway de Ejecución y Motor de Medición)**.

### Justificación Técnica:
1. **Núcleo de Valor y Tráfico Crítico:** Este contenedor representa el componente central de AgentHub. Mientras que los portales administrativos y el catálogo atienden tráfico CRUD convencional, este contenedor procesa el 100% de las invocaciones operativas entre las organizaciones y los agentes de IA de terceros.
2. **Confluencia de Atributos de Calidad Más Exigentes:**
   - **Disponibilidad:** Si este contenedor falla, toda la integración en producción de las organizaciones se interrumpe.
   - **Seguridad:** Inspecciona y valida las API Keys corporativas, previene ataques DoS mediante limitación de cuotas (Token Bucket) y aísla los secrets hacia los endpoints de los agentes externos.
   - **Interoperabilidad:** Transforma los payloads genéricos corporativos hacia los contratos específicos de cada agente y gestiona los formatos multi-turno.
   - **Escalabilidad y Rendimiento:** Debe medir tokens y registrar costos de liquidación en tiempo real sin bloquear el pipeline de streaming HTTP/gRPC.
3. **Complejidad Arquitectónica Interna:** Requiere desacoplar claramente componentes de autenticación perimetral, gestión de cuotas/rate limiting, enrutamiento dinámico con circuit breaking, sandboxing de pruebas y publicación asíncrona de telemetría de facturación.