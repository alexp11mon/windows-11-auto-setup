---
name: plan-generator
description: Usa esta skill cuando el usuario pida crear o revisar el plan tecnico (plan.md) a partir de un spec.md aprobado. Define arquitectura, modulos, modelo de datos y decisiones tecnicas sin cambiar requisitos.
---

# Generador de plan

Convierte un spec acordado en un COMO construible y verificable.
El plan es tecnico: explica arquitectura, modulos, datos, contratos y decisiones.
Si algo no esta en el spec, no se planifica. Si un RF no queda cubierto por el plan, el plan esta incompleto.

Usa esta skill cuando el usuario diga "crea el plan", "disena la arquitectura" o pase un spec aprobado.
No la uses para definir funcionalidades nuevas, cambiar RF, o escribir codigo. Eso va en spec o en implementacion.

## Proceso

1. **Lee el contexto obligatorio antes de preguntar.** Lee el `specs/NNN-<nombre>/spec.md` indicado, `docs/constitution.md` si existe, y specs previas en `specs/` para no contradecir decisiones ya tomadas. Anota: lista RF-1...RFn, fuera de alcance, casos limite, stack permitido y verificacion exigida. Si la spec tiene `[NECESITA ACLARACION]` sin resolver, detente y pide clarificacion: sin spec limpia no hay plan fiable.

2. **Entrevista solo si falta informacion tecnica.** Preguntas de **UNA en UNA**, maximo 5, esperando respuesta antes de la siguiente. Centrate solo en el COMO: persistencia concreta dentro de lo permitido, formato de datos, contratos CLI o API, manejo de errores tecnicos, restricciones no funcionales. No reabras el QUE: si el usuario pide cambiar un RF, redirige a actualizar la spec primero y detente.

3. **Confirma la ruta.** Usa siempre la misma carpeta que la spec: `specs/NNN-<nombre>/plan.md`. Nunca crees un numero nuevo para el plan ni renombres RF. La trazabilidad depende de mantener NNN y RF estables.

4. **Redacta** usando `plan-template.md` de esta skill, sin saltarte secciones: resumen de arquitectura, modulos y responsabilidades, modelo de datos, contratos e interfaces, flujo principal paso a paso, decisiones tecnicas con alternativa descartada, riesgos y tabla de trazabilidad RF -> modulo. Cada RF debe quedar cubierto por al menos un modulo o decision. Cada modulo debe justificar a que RF sirve. Un modulo sin RF es alcance inventado.

5. **Marca lo que no sepas** como `[NECESITA ACLARACION: pregunta concreta]`. Nunca inventes un requisito para justificar una decision tecnica ni elijas stack fuera de constitucion en silencio. Ejemplo correcto: `[NECESITA ACLARACION: JSON local o SQLite para persistencia? La spec no lo fija y cambia el modulo storage]`.

6. **Pide aprobacion explicita** al terminar. Muestra el plan completo y pregunta "Apruebas este plan?". No pases a tasks ni escribas codigo hasta tener un "si" claro. Sin aprobacion, el plan no existe.

## Reglas

- El plan describe **COMO**, nunca redefine el QUE. Prohibido alterar, anadir, eliminar o reinterpretar requisitos funcionales RF del spec. Esta es la regla principal. Si detectas un RF inviable o contradictorio, reportalo y detente, no lo arregles en silencio.
- Stack y convenciones solo los permitidos por la constitucion. Toda desviacion debe quedar registrada en Decisiones con motivo y aprobacion explicita.
- Una decision tecnica siempre incluye: opcion elegida, alternativa descartada y motivo en una frase. Sin motivo, no es decision. Sin alternativa, no evaluaste.
- Sin codigo fuente final. Solo nombres de modulos, responsabilidades, esquemas, contratos y pseudocodigo minimo de flujos criticos. La implementacion va despues, tarea por tarea.
- Un modulo, una responsabilidad. Si necesitas un "y" para describir dos responsabilidades distintas, son dos modulos.
- Idioma: el de la spec. Manten numeracion RF original sin renumerar ni renombrar.

## Como formular decisiones tecnicas

Una buena decision tiene tres partes: elegida + descartada + motivo verificable.

Ejemplo bien escrito:

> D2: Persistencia en JSON local con escritura atomica. Descartado SQLite por exigir migraciones para un MVP de un solo usuario. Cubre: RF-2, RF-5.

> D4: CLI con argparse de stdlib, subcomandos add, done, list con salida 0 en exito y 1 en error. Descartado click por estar fuera de stack permitido. Cubre: RF-1, RF-8.

Mal escrito, para contrastar:

> ~~D2: Usar una base de datos moderna y robusta.~~ Sin opcion concreta, sin alternativa, sin trazabilidad a RF y con dos adjetivos no medibles.

## Guia de entrevista con ejemplos

Lanza solo UNA cada vez y solo si el repo no la responde:

- "Dentro del stack permitido, que persistencia prefieres para estos datos y por que?"
- "Que contrato exponemos: comandos CLI, endpoints, formatos exactos de entrada y salida?"
- "Que flujo es critico y debe detallarse paso a paso en el plan?"
- "Que restriccion no funcional manda aqui: rendimiento, seguridad, portabilidad?"
- "Que riesgo tecnico ves y como lo mitigamos sin cambiar RF?"

Si el usuario pide cambiar un RF como "anade exportar a CSV", responde: "Eso es cambio de spec. Actualizamos primero la spec y luego retomo el plan. Te propongo el RF nuevo?".

## Estructura obligatoria de plan.md

Sigue `plan-template.md` sin omitir secciones:

1. Resumen de arquitectura: estilo en 3 lineas y diagrama textual si ayuda.
2. Modulos y responsabilidades: nombre, que hace, que no hace, RF que cubre.
3. Modelo de datos: entidades, campos, validaciones, formato de persistencia.
4. Contratos e interfaces: comandos, parametros, salidas, codigos de error.
5. Flujo principal paso a paso: recorrido del caso central con RF citados.
6. Decisiones tecnicas D1...Dn con elegida, descartada y motivo.
7. Trazabilidad RF -> modulo: tabla donde todo RF aparece al menos una vez.
8. Riesgos y mitigaciones sin cambiar RF.
9. Dudas abiertas con formato [NECESITA ACLARACION].

## Errores comunes que debes evitar

- Inventar alcance: modulo o endpoint sin RF que lo justifique. Eliminalo o pide cambio de spec.
- Dejar RF huerfanos: todo RF debe aparecer en trazabilidad. Si no sabes donde va, marca aclaracion.
- Bajar a codigo final: si escribes funciones completas, estas implementando, no planificando. Sube a contrato.
- Decisiones sin motivo: "usaremos X por ser mejor" no es motivo. Da criterio: stack, simplicidad, testabilidad, portabilidad.
- Cambiar la spec en silencio para que el plan encaje. Reporta y detente.

## Al revisar un plan existente

Si el usuario pide revisar en vez de crear, no reescribas: **detecta y lista**, numerado, en cuatro bloques: (1) RF del spec sin cobertura en el plan, (2) elementos del plan sin RF que los justifique, (3) contradicciones con la constitucion en stack o convenciones, (4) riesgos tecnicos no declarados. No propongas soluciones hasta que te lo pidan. Pide aprobacion explicita antes de aplicar cambios.
