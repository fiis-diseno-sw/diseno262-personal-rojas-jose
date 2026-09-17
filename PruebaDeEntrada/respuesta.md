# Prueba de Entrada: Diseño de Software

## Instrucciones

Responda con sus propias palabras cada una de las siguientes preguntas. El objetivo es medir sus conocimientos y experiencias previas sobre diseño de software. Está terminantemente prohibido el uso de IA para la resolución, ya que contradice el objetivo mencionado.
Cree una carpeta en su repo, use el mismo nombre que la carpeta actual, y agregue un archivo README.md con su solución.

---

## Preguntas

**1.** ¿Qué entiende por diseño de software?

Lo entiendo como el proceso para diseñar la arquitectura y comportamiento de un software, con un énfacis en los requisitos que debe de cumplir para satifacer las necesidades del negocio

**2.** ¿Qué entiende por patrones de diseño? ¿Los ha estudiado en algún curso universitario o por cuenta propia? Desarrolle brevemente los temas que conoce.

Entiendo que son algoritmos estandar para poder implementar cierto tipo de funcionalidades de manera correcta, es decir, esquemas ya probados y validados por la comunidad para resolver problemáticas comunes al momento de desarrollar un software. Los estudié durante el curso de Lenguaje de Programación 2 (POO), donde vimos varios patrones de diseño como los de construcción, estructura y comportamiento. En específico recuerdo los patrones de construcción, donde nos mostraban diferentes maneras de construir objetos (como el patrón building, singleton, prototipe, fachada, decorator, etc), que me ayudaron a poder instanciar adecuadamente mis objetos antes de utilizarlos.

**3.** Mencione dos aplicaciones con las que haya interactuado y conozca en profundidad: una que considere que tiene un buen diseño de software y otra que considere que tiene un mal diseño de software. Para cada una, indique: qué hace la aplicación, por qué la cataloga de esa manera y qué características concretas lo llevan a esa conclusión.

A mi paracer, la que tiene un buen diseño sería la plataforma de tiktok, ya que me parece increible como puede servir de videos a una cantidad abrumadora de usuarios con poco o nulo retraso; además de la alta disponibilidad que presenta, ya que he visto muchas más veces ver a páginas de la comunidad de software caer de las que lo he visto con tiktok, siendo un ejemplo de: una buena administración de la base de datos estructurados y no estructurados por igual, y de un manejo de los procesos asincronos. Por el lado del mal diseño, estaría el sistema de matrícula virtual de la universidad (aunque lo paran cambiando cada año), ya que este pocas veces cumple con los atributos de calidad básico que uno podría pensar, colapsando multiples veces en al momento de matricularse, no guardando adecuadamente el estado de la matrícula, e incluso permitiendo vulnerar el sistema, haciendo que te puedas matricular fuera de tu turno en cierto casos.

**4.** Piense en un problema que enfrenta la facultad actualmente o en un proceso de negocio dentro de ella que quisiera mejorar a través de la implementación de un software. Elabore una lista con al menos 5 requisitos del sistema software mencionado y, a partir de ellos, desarrolle un borrador de diseño utilizando las herramientas que considere más convenientes. Aproveche todo el tiempo disponible para lograr un diseño lo más detallado posible.

El mayor problema de la facultad actualmente es su sistema de matrículas, ya que no puede manejar adecuadamente el volumne de usuarios y las peticiones que realizan. 
* Requisitos funcionales:
- Poder mostrar en tiempo real la disponibilidad de los cursos
- Permitir a los alumnos matricularse aún con la concurrencia en una misma vacante

* Requisitos no funcionales:
- Tolerar la interacción simultanea de más de mil alumnos en los endpoints de consulta de vacantes
- Guardar adecuadamente el estado de matrícula una vez confirmado
- Validar los usuarios para que solos interactuen cuando su turno lo permita

Borrador:
- Primero tendría un diseño de base de datos ya formateado, es decir, ya tendría un conjunto de tickets (a manera de registros), ya creados, y a estos les iría asignando el usuario a manera de que se matriculen, para asi evitar el error de crear más vacantes de las que se permiten
- Por otro lado, implementaría un sistema de permisos para que solo si tienes el turno activo o el inmediato anterior puedas ver en tiempo real el estado de las vacantes, con el fin de evitar que las centenas de otros alumnos bombardeen este endpoint cuando realmente no lo necesitan ver
- Además, utilizaría una arquitectura de capas, para poder separar adecuadamente el componente de login (altamente utilizado por todos los que quieran entrar) y el del core, donde solo se manejarán los elementos de asignado de vacantes