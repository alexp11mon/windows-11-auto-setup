---
name: constitution-generator
description: Usa esta skill cuando el usuario pida crear, redactar o revisar la constitucion del proyecto (constitution.md). Guia una entrevista paso a paso y produce principios innegociables, stack permitido, convenciones y verificacion obligatoria.
---

# Generador de constitucion

Convierte expectativas dispersas en principios innegociables y verificables.
La constitucion es la ley del proyecto: manda sobre spec, plan, tareas y codigo.
Si hay conflicto entre un requisito y la constitucion, gana la constitucion.
Si algo no esta aqui, no se puede exigir despues.

Usa esta skill al inicio de un proyecto, al rescatar un proyecto sin reglas,
o cuando el usuario diga "define principios", "crea la constitucion" o "fija convenciones".

No la uses para definir funcionalidades concretas, disenar arquitectura
o planificar tareas. Eso va en spec, plan o tasks.

## Proceso

1. **Lee el contexto antes de preguntar.** Revisa README, AGENTS.md, `package.json`
   o `pyproject.toml`, codigo existente y `docs/constitution.md` si ya existe.
   Anota: lenguaje real en uso, gestor de dependencias, idioma de docs,
   estructura de carpetas y comandos de test o lint si existen.
   No preguntes lo que ya puedas deducir del repo. Solo pregunta lo que
   cambie reglas futuras.

2. **Entrevista al usuario.** Preguntas de **UNA en UNA**, maximo 6, esperando
   respuesta antes de la siguiente. No lances listas de preguntas ni
   cuestionarios multiples. Sigue este orden:
   a) Objetivo del proyecto en una frase: que es y que no es.
   b) Stack permitido y prohibido: lenguaje, version minima, dependencias
      aceptadas y prohibidas, herramientas obligatorias.
   c) Convenciones de codigo y estilo: formato, nombres, estructura,
      idioma de comentarios y docs.
   d) Verificacion obligatoria: que comando o revision marca una tarea
      como hecha (tests, lint, demo manual, revision humana).
   Prioriza preguntas cuya respuesta cambie decisiones futuras; descarta
   las que tengan una respuesta obvia por defecto. Si el usuario pregunta
   "que me recomiendas?", propone una opcion concreta y pide confirmacion,
   no dejes la decision en el aire.

3. **Sintetiza en principios numerados.** Convierte lo acordado en maximo 8
   principios P1, P2... Cada principio resume una regla innegociable.
   Ejemplos de categorias: stack, simplicidad, testing, estilo,
   seguridad, idioma, flujo SDD. Si dos reglas hablan de cosas distintas,
   son dos principios aunque esten relacionadas.

4. **Redacta** `docs/constitution.md` usando `constitution-template.md`
   de esta skill, sin saltarte secciones. Cada seccion debe quedar completa
   o marcada como pendiente. Cada principio debe ser verificable: si no se
   te ocurre como comprobar su incumplimiento con un comando, un test o
   una revision, esta mal escrito y debes reformularlo.

5. **Marca lo que no sepas** como `[NECESITA ACLARACION: pregunta concreta]`.
   Nunca inventes stack, versiones ni convenciones para rellenar huecos:
   un hueco visible es informacion, una suposicion silenciosa es deuda.
   Ejemplo correcto: `[NECESITA ACLARACION: version minima de Python, 3.10 o 3.12?]`.

6. **Pide aprobacion explicita** al terminar. Muestra el archivo completo
   y pregunta "Apruebas esta constitucion?". No pases a spec, plan, tareas
   ni escribas codigo hasta tener un "si" claro. Sin aprobacion, la
   constitucion no existe.

## Reglas

- La constitucion define **LIMITES y PRINCIPIOS**. Prohibido incluir requisitos
  funcionales RF, historias de usuario, diseno de modulos, esquemas de datos,
  algoritmos o listas de tareas: eso va en spec, plan o tasks.
- Maximo 8 principios, numerados P1, P2... Un principio, una frase principal
  mas su criterio de verificacion. Si necesitas un "y" para unir dos
  comportamientos distintos, son dos principios.
- Sin adjetivos no medibles: "limpio", "moderno", "bueno", "robusto",
  "rapido" no son principios. Escribe la regla concreta con umbral,
  herramienta o comando, o no la escribas.
- Todo principio debe indicar como se verifica. Formatos validos:
  "se verifica con `pytest` en verde", "se verifica con `npm run lint`
  sin errores", "se verifica en revision manual del diff".
- Stack cerrado: todo lo no permitido explicitamente requiere aprobacion
  en la spec. No dejes la puerta abierta con "se pueden usar otras
  librerias si hace falta".
- Idioma: el del usuario. Manten el mismo en todo el archivo y en
  futuros specs y planes.

## Como formular principios

Un buen principio tiene tres partes: regla + alcance + verificacion.

Ejemplo bien escrito:

> P1: Python 3.12 solo con biblioteca estandar. Se verifica inspeccionando
> imports: cualquier dependencia externa exige aprobacion explicita en la spec.

> P4: Toda funcionalidad entra con test primero. Se verifica con
> `pytest tests/ -q` en verde antes de dar la tarea por hecha.

> P6: Idioma del proyecto: espanol en docs y mensajes de usuario, ingles
> en identificadores de codigo. Se verifica en revision del diff.

Mal escrito, para contrastar:

> ~~P1: Usar buen codigo moderno y robusto.~~ Sin version, sin regla
> concreta, sin criterio verificable y con tres adjetivos no medibles.

> ~~P4: Hacer tests cuando se pueda y ser rapido.~~ Sin obligatoriedad,
> sin comando de verificacion, dos ideas en una frase.

## Guia de entrevista con ejemplos

No copies estas preguntas tal cual si ya tienes la respuesta en el repo.
Adaptalas y lanza solo UNA cada vez:

- "En una frase, que problema resuelve este proyecto y que queda fuera?"
- "Que stack es obligatorio y cual esta prohibido? Dime lenguaje, version y dependencias."
- "Que comandos definen que algo esta terminado? Por ejemplo: tests, lint, build, demo."
- "Que estilo exiges: formato automatico, nombres, idioma de comentarios?"
- "Que no debe hacer nunca este proyecto aunque parezca util?"

Si el usuario responde con vaguedades como "codigo limpio", repregunta:
"Como lo compruebo: que herramienta y que comando da verde o rojo?".

## Estructura obligatoria de constitution.md

Sigue `constitution-template.md` sin omitir secciones:

1. Contexto y objetivo: que es el proyecto en un parrafo y que no es.
2. Principios P1...Pn: lista numerada de reglas innegociables con verificacion.
3. Stack permitido y prohibido: lenguajes, versiones, dependencias, herramientas.
4. Convenciones: formato, nombres, estructura de carpetas, idioma.
5. Verificacion obligatoria: checklist o comandos que cierran cada tarea.
6. Dudas abiertas: lista de `[NECESITA ACLARACION]` pendientes.

## Errores comunes que debes evitar

- Mezclar constitucion con spec: si describes un RF o una pantalla, sacalo
  de aqui y llevalo a la spec.
- Principios decorativos: si un principio no cambia ninguna decision futura,
  eliminalo.
- Listas infinitas: mas de 8 principios significa que no priorizaste.
  Agrupa o elimina.
- Permitir excepciones implicitas: evita "en general", "normalmente",
  "si es necesario". O es regla o no lo es.

## Al revisar una constitucion existente

Si el usuario pide revisar en vez de crear, no reescribas: **detecta y lista**,
numerado, en tres bloques: (1) principios vagos o no verificables con cita
literal, (2) contradicciones con codigo, README o docs actuales, (3) huecos
criticos sin cubrir como stack, estilo o verificacion. No propongas
soluciones hasta que te lo pidan. Pide aprobacion explicita antes de
aplicar cualquier cambio.
