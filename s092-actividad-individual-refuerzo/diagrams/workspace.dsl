workspace "BAP Móvil 3.0" "Arquitectura del sistema BAP Móvil 3.0 — Banco Andino del Perú (BAP)" {

    model {
        # Actores
        cliente = person "Cliente Final" "Personas naturales C/D y MYPE (1.8M clientes, 1.2M MAU)"
        analista = person "Analista de Fraude" "Gerencia de Riesgos: monitorea alertas y bloqueos (< 2 s)"
        oficial = person "Oficial de Cumplimiento" "Interlocutor SBS / UIF-Perú (PLAFT: ROS, ROU/ROM)"
        operador = person "Operador Back Office" "Gerencia de Operaciones: conciliaciones y soporte"

        # Sistemas Externos
        core = softwareSystem "Core Bancario Mainframe" "COBOL on-premise (Lima). Cuentas, saldos contables y movimientos (IBM MQ / archivos planos)" "External"
        cce = softwareSystem "CCE-BCRP" "Cámara de Compensación Electrónica: interoperabilidad con Yape, Plin y BIM (< 10 s, 24/7/365)" "External"
        uif = softwareSystem "UIF-Perú / SBS" "Recepción regulatoria de reportes ROS mensuales y ROU/ROM semanales" "External"
        centrales = softwareSystem "Centrales de Riesgo" "Equifax / Sentinel: consulta de historial crediticio" "External"

        # Sistema en estudio (Frontera en AWS sa-east-1 Multi-AZ | DR Warm Standby en us-east-1)
        bapMovil = softwareSystem "BAP Móvil 3.0" "Plataforma digital en AWS (sa-east-1 + DR us-east-1): app móvil, pagos en tiempo real (< 5 s), fraude en streaming (< 2 s) y analítica PLAFT (99.95% disp.)" {
            mobileApp = container "App Móvil BAP 3.0" "Operaciones, biometría, Idempotency-Key y soporte para redes 3G/4G intermitentes" "Kotlin / Swift" "Mobile"
            apiGateway = container "API Gateway & Mobile BFF" "Terminación TLS 1.3, OAuth2/OIDC, WAF, Rate Limiting y enrutamiento" "Spring Cloud Gateway"
            portalRiesgos = container "Portal Riesgos y Cumplimiento" "Tablero de alertas de fraude en vivo, conciliaciones y descarga de reportes ROS/ROU/ROM" "React SPA + BFF" "Web"

            svcCuentas = container "Servicio Cuentas y Saldos" "Consultas CQRS (p95 <= 800 ms) y gestión de cuentas" "Java / Spring Boot"
            svcPagos = container "Servicio Pagos e Interoperabilidad" "Orquestador Saga de pagos en tiempo real (p95 <= 5 s), idempotencia y compensación" "Java / Spring Boot"
            svcCreditos = container "Servicio Créditos y Onboarding" "Originación y scoring crediticio alternativo" "Java / Spring Boot"
            cardVault = container "Card Vault (PCI-DSS v4)" "Tokenización y resguardo aislado de PAN" "Java / HSM / AWS KMS"
            aclCore = container "Adaptador ACL Core" "Traducción REST/JSON <-> COBOL copybooks / IBM MQ y Circuit Breaker" "Java / Spring Boot"

            redisCache = container "Caché Saldos y Sesiones" "Lecturas rápidas CQRS (p95 <= 800 ms) y control de Idempotency-Key" "Amazon ElastiCache Redis" "Database"
            rdsOracle = container "BD Transaccional Operacional" "Estado de Sagas, pagos y proyecciones operacionales (cifrado AES-256)" "Amazon RDS Oracle Multi-AZ" "Database"
            mskBus = container "Bus de Eventos" "Streaming de ~80M eventos/día (1.2 KB JSON), picos de 2,500 TPS" "Amazon MSK (Apache Kafka)" "Queue"
            motorFraude = container "Motor de Fraude y PLAFT" "Evaluación y bloqueo en streaming < 2 s con ventanas temporales" "Apache Flink"
            dataLake = container "Data Lake y Motor Batch" "35 TB/año en Parquet comprimido; reportes ROS (mensual) y ROU/ROM (semanal)" "Amazon S3 + AWS Glue / Spark" "Database"
        }

        # Relaciones Actores -> Contenedores
        cliente -> mobileApp "Realiza consultas, transferencias, pagos y solicitudes" "UI Móvil (Síncrono)" "Sync"
        analista -> portalRiesgos "Monitorea alertas de fraude en tiempo real" "HTTPS / TLS 1.3 (Síncrono)" "Sync"
        oficial -> portalRiesgos "Revisa y descarga reportes PLAFT (ROS, ROU/ROM)" "HTTPS / TLS 1.3 (Síncrono)" "Sync"
        operador -> portalRiesgos "Ejecuta conciliaciones operativas" "HTTPS / TLS 1.3 (Síncrono)" "Sync"

        # Relaciones Borde -> Microservicios
        mobileApp -> apiGateway "Consume APIs móviles" "HTTPS / TLS 1.3 (Síncrono)" "Sync"
        apiGateway -> svcCuentas "Consultas de saldos y movimientos" "REST / mTLS (Síncrono)" "Sync"
        apiGateway -> svcPagos "Transferencias y pagos en tiempo real" "REST / mTLS (Síncrono)" "Sync"
        apiGateway -> svcCreditos "Solicitudes de crédito y onboarding" "REST / mTLS (Síncrono)" "Sync"

        # Relaciones Portal Interno
        portalRiesgos -> motorFraude "Consulta alertas y reglas activas" "REST / mTLS (Síncrono)" "Sync"
        portalRiesgos -> dataLake "Consulta reportes regulatorios y conciliación" "SQL / Athena (Síncrono)" "Sync"

        # Relaciones Microservicios -> Datos / Seguridad / Fraude / ACL
        svcCuentas -> redisCache "Lee saldos y movimientos (CQRS)" "TCP / TLS (Síncrono)" "Sync"
        svcCuentas -> rdsOracle "Lee y actualiza proyecciones de cuentas" "JDBC / TLS (Síncrono)" "Sync"

        svcPagos -> redisCache "Valida Idempotency-Key" "TCP / TLS (Síncrono)" "Sync"
        svcPagos -> rdsOracle "Persiste estado de Saga y pagos" "JDBC / TLS (Síncrono)" "Sync"
        svcPagos -> cardVault "Tokeniza / destokeniza PAN" "gRPC / mTLS (Síncrono)" "Sync"
        svcPagos -> motorFraude "Evaluación antifraude pre-acreditación (< 2 s)" "gRPC / REST (Síncrono)" "Sync"
        svcPagos -> aclCore "Reserva y contabilización en core" "REST / mTLS (Síncrono)" "Sync"

        # Relaciones hacia Bus de Eventos (Asíncrono)
        svcCuentas -> mskBus "Publica eventos de cuentas" "Kafka / TLS (Asíncrono)" "Async"
        svcPagos -> mskBus "Publica eventos transaccionales" "Kafka / TLS (Asíncrono)" "Async"
        svcCreditos -> mskBus "Publica eventos de originación" "Kafka / TLS (Asíncrono)" "Async"
        aclCore -> mskBus "Publica eventos CDC del core" "Kafka / TLS (Asíncrono)" "Async"

        mskBus -> motorFraude "Consume stream de eventos" "Kafka (Asíncrono)" "Async"
        mskBus -> dataLake "Ingesta continua de eventos" "Kafka Connect -> S3 (Asíncrono)" "Async"

        # Relaciones hacia Sistemas Externos
        svcPagos -> cce "Envía y confirma transferencias interbancarias" "ISO 20022 / REST TLS 1.3 (Síncrono)" "Sync"
        svcCreditos -> centrales "Consulta historial crediticio" "REST / TLS 1.3 (Síncrono)" "Sync"
        aclCore -> core "Envía movimientos y recibe CDC" "IBM MQ / Direct Connect (Síncrono / Asíncrono)" "Async"
        core -> aclCore "Notifica movimientos contables y cierres" "IBM MQ / Archivos planos (Asíncrono)" "Async"
        dataLake -> uif "Envía reportes ROS (mensual) y ROU/ROM (semanal)" "SFTP / API Segura (Asíncrono Batch)" "Async"
    }

    views {
        systemContext bapMovil "C4_Contexto" "Diagrama de Contexto (C4 Nivel 1) — BAP Móvil 3.0" {
            include *
            autoLayout tb
        }

        container bapMovil "C4_Contenedores" "Diagrama de Contenedores (C4 Nivel 2) — BAP Móvil 3.0 (AWS sa-east-1)" {
            include *
            autoLayout tb
        }

        styles {
            element "Person" {
                shape Person
                background #08427b
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Database" {
                shape Cylinder
                background #2b78c5
                color #ffffff
            }
            element "Queue" {
                shape Pipe
                background #3b82c4
                color #ffffff
            }
            element "Mobile" {
                shape MobileDevicePortrait
                background #438dd5
                color #ffffff
            }
            element "Web" {
                shape WebBrowser
                background #438dd5
                color #ffffff
            }
            relationship "Sync" {
                dashed false
                color #334155
            }
            relationship "Async" {
                dashed true
                color #b45309
            }
        }
    }

}
