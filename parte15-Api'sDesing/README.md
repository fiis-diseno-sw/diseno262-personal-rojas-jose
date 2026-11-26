# Documentación de APIs (Swagger / OpenAPI) — Bloque 2 (ROJAS: Módulos 3 y 7)

Esta carpeta contiene el desarrollo de la **Sección 15 (Diseño de APIs y Servicios)** correspondiente **únicamente al Bloque 2 (Integrante 2: ROJAS)**, abarcando el **Módulo 3 (Gestión de Incentivos y Fidelización)** y el **Módulo 7 (Plataforma, Gobernanza y Administración Centralizada)** en coherencia con lo desarrollado en las carpetas [`10`](../10/10.2/10.2.md) a [`14`](../14/14.2/14.2.md) y [`9/9.3/`](../9/9.3/9.3.md).

---

## Contenido de la Carpeta

| Archivo | Propósito |
| :--- | :--- |
| [`15.2-diseno-apis-bloque2.md`](15.2-diseno-apis-bloque2.md) | Documento técnico completo con los 5 puntos exigidos: estilo y límites de servicio, endpoints principales por módulo, códigos HTTP + formato común de error conectado con AOP, convenciones de AuthN/AuthZ y versionamiento, y enlace a OpenAPI. |
| [`docs/openapi.yaml`](docs/openapi.yaml) | Especificación preliminar **OpenAPI 3.1.0** (Swagger) con los endpoints, esquemas de dominio (`10.2` / `12.2`), seguridad (`bearerAuth` OIDC + `X-Tenant-Id`) y respuestas de error RFC 7807 exclusivamente de los Módulos 3 y 7. |
| [`swagger.html`](swagger.html) | Interfaz **Swagger UI** lista para explorar interactivamente los endpoints de `docs/openapi.yaml`. |

---

## Cómo Visualizar en Swagger UI

Para evitar bloqueos CORS al cargar `./docs/openapi.yaml` desde el navegador, sirve la carpeta con cualquier servidor HTTP local:

```bash
npx serve . -p 8085
```

Luego abre en tu navegador:  
`http://localhost:8085/swagger.html`

*(Alternativamente, puedes abrir el contenido de [`docs/openapi.yaml`](docs/openapi.yaml) directamente en [editor.swagger.io](https://editor.swagger.io) o mediante la extensión **OpenAPI (Swagger) Editor** en VS Code).*
