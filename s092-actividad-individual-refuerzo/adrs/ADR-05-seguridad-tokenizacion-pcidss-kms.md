# ADR-05: Seguridad Perimetral, Tokenización PCI-DSS v4 y Cifrado Centralizado con AWS KMS

- **Estado:** Aceptado
- **Categoría (Bass et al.):** Asignación de responsabilidades / Tecnología
- **Escenarios trazados:** [ESC-07](../README.md#esc-07), [ESC-08](../README.md#esc-08)

## Contexto

BAP administra **1.6 millones de tarjetas de débito** y **380 mil tarjetas de crédito**, además de datos personales sensibles (DNI, cuentas, montos, geolocalización) de 1.8 millones de clientes. La **Ley N° 29733** y los requisitos de seguridad del proyecto exigen cifrado en reposo (**AES-256**), cifrado en tránsito (**TLS 1.3**) y **tokenización de PAN según PCI-DSS v4**, sin degradar el desempeño del canal móvil.

## Alternativas consideradas

1. **Alternativa A — Gestión de autenticación, cifrado y almacenamiento de PAN distribuida en cada microservicio:**
   - *Pros:* Sin dependencia de un componente centralizado de tokenización.
   - *Contras:* Amplía el alcance de auditoría PCI-DSS v4 a todos los microservicios de los 6 squads; alto riesgo de inconsistencias criptográficas o exposición accidental de PAN en logs/eventos de Kafka.

2. **Alternativa B — API Gateway / Mobile BFF centralizado + Card Vault aislado (PCI-DSS v4) + AWS KMS (AES-256):**
   - *Pros:* Concentra TLS 1.3, WAF, rate limiting y validación OAuth2/OIDC + biometría en el borde (API Gateway/BFF); aísla los datos de tarjetas (PAN) en un contenedor dedicado (**Card Vault**) que entrega tokens opacos al resto de servicios (Cuentas, Pagos, Kafka); centraliza llaves en AWS KMS para cifrado AES-256 uniforme en RDS, S3, MSK y Redis.
   - *Contras:* Añade un salto de red interno hacia el Card Vault cuando una operación requiere destokenizar el PAN (mitigable cacheando tokens y operando con tokens en el 95% de los flujos internos).

## Criterios de elección

- Reducción estricta del alcance (scope) de certificación **PCI-DSS v4**.
- Cumplimiento de **Ley N° 29733** (protección de datos personales) con **AES-256** y **TLS 1.3**.
- Cero exposición de PAN en claro en bases analíticas, logs o tópicos de eventos.

## Decisión

Se adopta la **Alternativa B**: borde seguro mediante **API Gateway + Mobile BFF**, aislamiento del **Card Vault** para tokenización de PAN bajo **PCI-DSS v4**, y gestión centralizada de cifrado **AES-256** con **AWS KMS** y **mTLS** entre servicios internos.

## Sustento

Aislar el Card Vault reduce drásticamente el costo y riesgo de cumplimiento PCI-DSS v4 para los 6 squads, mientras que el cifrado uniforme con KMS y TLS 1.3/mTLS protege la confidencialidad e integridad de los datos sensibles en toda la plataforma.
