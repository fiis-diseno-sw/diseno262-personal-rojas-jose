# Actividad Individual: Toma de Decisiones sobre Manejo y Procesamiento de Datos
**Curso:** Diseño de Software  
**Proyecto:** Plataforma Modular para Emporios Comerciales (Sistema de Navegación, Catálogo e Inteligencia Comercial)  
**Rol:** Arquitecto de Datos / Estudiante de Ingeniería de Sistemas  

---

## 1. Taxonomía de Referencia

La toma de decisiones de arquitectura de datos se fundamenta estrictamente en la taxonomía técnica establecida:

* **Modelos de Datos:** Relacional (SQL), Documental (NoSQL), Clave / Valor, Columnar, Orientado a Grafos, y Motores Específicos (Geo-espacial, Series de Tiempo, Vectorial).
* **Formas de Procesamiento:** In-line (En línea / Tiempo real), Batch (Por lotes) y Streaming (Flujos continuos).

---

## 2. Propuesta Técnica por Módulos del Sistema

| Módulo | Modelo de Datos | Motor Elegido | Forma de Procesamiento |
| :--- | :--- | :--- | :--- |
| **M1: Navegación y UX** | Orientado a Grafos + Geo-espacial | Neo4j + PostGIS | In-line |
| **M2: Búsqueda y Catálogo** | Documental | MongoDB | In-line (con sincronización Batch) |
| **M3: Fidelización e Incentivos** | Relacional + Clave / Valor | PostgreSQL + Redis | In-line |
| **M4: Ingesta y Catastro** | Relacional + Geo-espacial | PostgreSQL + PostGIS | Batch |
| **M5: Gestión de Publicidad** | Relacional + Clave / Valor | PostgreSQL + Redis | In-line |
| **M6: Inteligencia de Mercado** | Columnar + Series de Tiempo | Snowflake / DuckDB + Timescale | Streaming + Batch |
| **M7: Plataforma y Gobernanza** | Relacional | PostgreSQL | In-line |

---

## 3. Detalle y Justificación Técnica por Módulo

### 1. Módulo de Navegación y Experiencia de Usuario (Core App)
* **Modelo de Datos:**
  * **Orientado a Grafos:** La red peatonal de galerías (pasajes interiores, escaleras, accesos) y jirones exteriores se modela naturalmente como nodos (intersecciones/stands) y aristas con pesos (distancias y accesibilidad).
  * **Geo-espacial:** Representación de polígonos de stands, extrusión de niveles/pisos y cálculo de proximidad.
* **Motor de Base de Datos:** **Neo4j** (para resolución de rutas complejas y transitabilidad) junto a **PostgreSQL (PostGIS)** para consultas de contornos espaciales.
* **Forma de Procesamiento:** **In-line (En línea / Tiempo real)**.
  * *Justificación:* El cálculo del camino óptimo ($A^*$) y el re-enrutamiento dinámico deben responder de forma instantánea conforme el usuario avanza dentro del emporio comercial.

---

### 2. Módulo de Búsqueda y Catálogo Comercial
* **Modelo de Datos:**
  * **Documental:** El catálogo textil y de calzado presenta esquemas heterogéneos y dinámicos (múltiples atributos variables según prenda: tallas, telas, temporadas, colores, guías de medidas) que resultarían ineficientes en un modelo relacional normalizado.
* **Motor de Base de Datos:** **MongoDB** (almacenamiento flexible en documentos BSON indexados por categorías, etiquetas y sinónimos comerciales).
* **Forma de Procesamiento:** **In-line**.
  * *Justificación:* Consultas multicriterio y fichas de producto consultadas directamente por los compradores con latencia sub-segundo; con procesos **Batch** programados fuera de hora punta para mantenimiento de índices y sinónimos.

---

### 3. Módulo de Gestión de Incentivos y Fidelización (Loyalty)
* **Modelo de Datos:**
  * **Relacional:** Manejo de billeteras digitales, saldos de puntos de recompensa y emisión de cupones de descuento donde se exige estricto cumplimiento **ACID** para prevenir doble gasto o inconsistencias contables.
  * **Clave / Valor:** Caché de tokens efímeros para invalidación atómica de cupones en el punto de venta.
* **Motor de Base de Datos:** **PostgreSQL** (modelo transaccional primario) complementado con **Redis** (bloqueos atómicos de canje de cupones mediante TTL).
* **Forma de Procesamiento:** **In-line (En línea / Tiempo real)**.
  * *Justificación:* El canje y acreditación de puntos deben ser inmediatos y consistentes para evitar fraudes en el momento de la compra física.

---

### 4. Módulo de Ingesta y Actualización de Datos (Onboarding & Catastro)
* **Modelo de Datos:**
  * **Relacional & Geo-espacial:** Estructura de padrones comerciales (asociación comerciante-local-galería) con rigidez referencial y geometrías vectoriales (polígonos sin solapamiento topológico).
* **Motor de Base de Datos:** **PostgreSQL con extensión PostGIS**.
* **Forma de Procesamiento:** **Batch (Por lotes)**.
  * *Justificación:* La incorporación de nuevos padrones de galerías se realiza mediante archivos masivos (CSV/Excel/GeoJSON). El procesamiento por lotes valida reglas de negocio, integridad referencial y topología antes de publicar los cambios en producción.

---

### 5. Módulo de Gestión de Publicidad (Merchant Panel & Ads)
* **Modelo de Datos:**
  * **Relacional:** Acreditación de titulares de stands, suscripciones B2B, contratos comerciales y facturación.
  * **Clave / Valor:** Almacén en memoria de campañas publicitarias activas y geofences para entrega ultrarrápida.
* **Motor de Base de Datos:** **PostgreSQL** (para administración y cobranza) y **Redis** (para resolución rápida de pautas por proximidad).
* **Forma de Procesamiento:** **In-line**.
  * *Justificación:* Operaciones transaccionales del panel de comerciantes (creación de anuncios, pagos con pasarela) y servido en tiempo real de anuncios contextuales a los usuarios concurrentes.

---

### 6. Módulo de Inteligencia de Mercado (Analytics & Telemetría)
* **Modelo de Datos:**
  * **Columnar:** Optimizado para agregaciones analíticas masivas (OLAP) sobre millones de lecturas de tránsito peatonal y dwell time sin saturar bases de datos transaccionales.
  * **Series de Tiempo:** Registro continuo de eventos temporales (pings de presencia y afluencia por franja horaria).
* **Motor de Base de Datos:** **Snowflake / DuckDB** (almacenamiento columnar analítico) junto con **Timescale** para métricas temporales de afluencia.
* **Forma de Procesamiento:** Híbrido (**Streaming + Batch**).
  * *Streaming:* Ingesta continua de telemetría y eventos de posición de la app.
  * *Batch:* Cálculo periódico de anonimización $K\text{-Anonymity}$ ($k \ge k_{min}$), generación de mapas de calor por galería y compilación de reportes comerciales B2B.

---

### 7. Módulo de Plataforma, Gobernanza y Administración Centralizada
* **Modelo de Datos:**
  * **Relacional:** Catálogo maestro de emporios (tenants), políticas de acceso jerárquico OIDC, asignación de celdas de infraestructura y bitácora de auditoría inmutable.
* **Motor de Base de Datos:** **PostgreSQL**.
* **Forma de Procesamiento:** **In-line**.
  * *Justificación:* Verificación obligatoria y síncrona de identidades, roles, aislamiento de datos y políticas de gobernanza en cada solicitud del sistema.

---

## 4. Conclusión Arquitectónica

La adopción de un enfoque de **Persistencia Políglota** (*Polyglot Persistence*) permite seleccionar el motor idóneo según la naturaleza del dato:
1. **Transaccionalidad crítica:** Relacional (PostgreSQL).
2. **Consultas de adyacencia y navegación:** Grafos + Geoespacial (Neo4j + PostGIS).
3. **Flexibilidad de catálogo:** Documental (MongoDB).
4. **Respuesta en sub-milisegundos:** Clave / Valor (Redis).
5. **Analítica masiva y privacidad:** Columnar y Series de Tiempo (Snowflake/DuckDB + Timescale) con procesamiento en Streaming y Batch.
