---
name: tasks-generator
description: Usa esta skill cuando el usuario pida crear o revisar la lista de tareas (tasks.md) a partir de un plan.md aprobado. Desglosa en tareas T1, T2 ordenadas, pequenas y verificables con Hecho cuando.
---

# Generador de tareas

Convierte un plan aprobado en trabajo ejecutable paso a paso.
Una tarea es una unidad que se hace de una vez, con su test y su fin claro.
Si una tarea no tiene Hecho cuando medible, no existe. Si no cita RF y modulo, es alcance inventado.

Usa esta skill cuando el usuario diga "crea las tareas", "desglosa el plan" o pase un plan aprobado.
No la uses para cambiar requisitos, redisenar arquitectura o escribir codigo final. Eso va en spec, plan o implementacion.

## Proceso

1. **Lee el contexto obligatorio antes de preguntar.** Lee `specs/NNN-<nombre>/spec.md`, `specs/NNN-<nombre>/plan.md` y `docs/constitution.md` si existe. Anota: lista RF, modulos con responsabilidades, contratos, modelo de datos, trazabilidad RF -> modulo y verificacion exigida. Si el plan tiene `[NECESITA ACLARACION]` sin resolver o hay RF sin modulo, detente y pide clarificacion: sin plan limpio no hay tareas fiables.

2. **Entrevista solo si falta criterio de orden.** Preguntas de **UNA en UNA**, maximo 4, esperando respuesta antes de la siguiente. Centrate solo en prioridad y dependencias: que es demostrable primero, que bloquea a que, que va a validacion final. No reabras requisitos ni decisiones tecnicas. Si el usuario pide funcionalidad nueva, redirige a cambio de spec y detente.

3. **Desglosa** en `specs/NNN-<nombre>/tasks.md` usando `tasks-template.md` de esta skill, sin saltarte formato. Ordena por dependencias: primero base y modelo con su test, despues logica pura, despues storage, despues CLI o interfaz, al final validacion RF por RF. Cada tarea lleva: `- [ ] T1 verbo + resultado`, linea `Hecho cuando:` medible, y linea `Cubre: RF-X | Modulo: nombre`. Maximo 12 tareas por iteracion.

4. **Dimensiona cada tarea.** Cada tarea debe completarse en una sesion y tener un solo Hecho cuando comprobable con comando o test. Aplica tests primero segun README: la tarea incluye su test o cita el test que la cierra. Si una tarea necesita dos verificaciones distintas, dividela en dos. Si una tarea mezcla dos modulos con responsabilidades distintas, dividela.

5. **Marca lo que no sepas** como `[NECESITA ACLARACION: pregunta concreta]`. Nunca inventes alcance para rellenar ni adelantes implementacion. Ejemplo correcto: `[NECESITA ACLARACION: T5 depende de formato fecha en RF-2, confirmar YYYY-MM-DD antes de implementar]`.

6. **Pide aprobacion explicita** al terminar. Muestra la lista completa y pregunta "Apruebas estas tareas?". No implementes ninguna hasta tener un "si" claro. La implementacion se hace de una en una, tests primero, segun README. Sin aprobacion, las tareas no existen.

## Reglas

- Las tareas ejecutan **SOLO** lo acordado en spec y plan. Prohibido anadir funcionalidad, cambiar arquitectura o introducir stack nuevo desde tasks. Esta es la regla principal.
- Formato obligatorio: checkbox `- [ ]`, ID secuencial T1, T2 sin reutilizar numeros, titulo con verbo, linea `Hecho cuando:` medible, linea `Cubre: RF + Modulo`. Sin Hecho cuando, la tarea no existe.
- Un Hecho cuando, una comprobacion. Validos: `pytest tests/test_storage.py en verde`, `habits add leer con salida 0 y entrada creada`. Invalidos: funciona bien, rapido, limpio, robusto.
- Trazabilidad total: todo RF del spec aparece en al menos una tarea. Todo modulo del plan aparece en al menos una tarea. Lo que no traza, se elimina o va a aclaracion.
- Tamano y orden: maximo 12 tareas, ordenadas por dependencias, base primero y validacion al final. No paralelices lo que depende de otra tarea.
- Idioma: el del plan. Manten IDs T y RF estables sin renumerar.

## Como formular tareas

Una buena tarea tiene cuatro partes: ID + resultado + Hecho cuando + trazabilidad.

Ejemplo bien escrito:

> - [ ] T3 Persistir habitos en JSON local con escritura atomica
>   Hecho cuando: `pytest tests/test_storage.py` en verde y `habits add leer` crea entrada con salida 0. Cubre: RF-2, RF-4 | Modulo: storage

> - [ ] T8 Validar cobertura RF por RF
>   Hecho cuando: checklist RF-1 a RF-11 con test que lo cubre y demo manual del flujo add, done, list. Cubre: todos | Modulo: validacion

Mal escrito, para contrastar:

> ~~T3: Hacer storage robusto y rapido.~~ Sin Hecho cuando medible, sin trazabilidad, dos adjetivos no verificables y dos ideas mezcladas.

## Guia de entrevista con ejemplos

Lanza solo UNA cada vez y solo si cambia el orden:

- "Que tarea demuestra valor antes para validar el flujo add, done, list?"
- "Que dependencia manda: modelo antes que storage, storage antes que CLI?"
- "Que test cierra cada tarea segun tu verificacion obligatoria?"
- "Partimos T grande en dos para que cada una cierre en una sesion?"

Si el usuario pide "anade exportar", responde: "Eso es cambio de spec. Lo anadimos primero a spec y plan, luego genero su tarea. Te propongo el RF?".

## Estructura obligatoria de tasks.md

Sigue `tasks-template.md` sin omitir partes:

1. Cabecera con spec y plan de origen: `specs/NNN-<nombre>/`.
2. Lista T1...Tn con checkbox, titulo, Hecho cuando y Cubre.
3. Orden: base, core, storage, cli, validacion final.
4. Seccion Trazabilidad RF -> Tareas donde todo RF aparece.
5. Dudas abiertas con formato [NECESITA ACLARACION].

## Errores comunes que debes evitar

- Tareas sin test: toda tarea de codigo exige su test primero o cita test existente. Sin test, no es SDD segun README.
- Tareas gigantes: si no cabe en una sesion o tiene dos Hecho cuando, dividela.
- Tareas sin trazabilidad: sin RF ni modulo, es invento. Eliminala o pide cambio de spec.
- Adelantar codigo: en tasks solo describes y verificas, no escribes funciones finales.
- Reordenar por gusto: el orden lo dictan dependencias tecnicas, no preferencia.

## Al revisar un tasks existente

Si el usuario pide revisar en vez de crear, no reescribas: **detecta y lista**, numerado, en cuatro bloques: (1) tareas sin Hecho cuando medible, (2) tareas sin trazabilidad a RF o modulo, (3) tareas demasiado grandes o fuera de orden por dependencias, (4) tareas fuera de alcance de spec y plan. No propongas soluciones hasta que te lo pidan. Pide aprobacion explicita antes de aplicar cambios.
