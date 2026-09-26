# Tasks NNN - <Nombre de la funcionalidad>

<Spec: specs/NNN-<nombre>/spec.md. Plan: specs/NNN-<nombre>/plan.md.>

## Tareas

- [ ] T1 Crear estructura base y modelo Habit con test
  Hecho cuando: `pytest tests/test_core.py` en verde con creacion y normalizacion. Cubre: RF-3, RF-4 | Modulo: core

- [ ] T2 Implementar calculo de racha con casos limite
  Hecho cuando: `pytest tests/test_racha.py` en verde incluyendo vacio, duplicado y dias no consecutivos. Cubre: RF-3 | Modulo: core

- [ ] T3 Persistir habitos en JSON local con escritura atomica
  Hecho cuando: `pytest tests/test_storage.py` en verde y `habits add leer` crea entrada con salida 0. Cubre: RF-2, RF-4 | Modulo: storage

- [ ] T4 Implementar CLI add y done con codigos de salida
  Hecho cuando: `habits add leer` salida 0, duplicado salida 1, `habits done leer` salida 0, inexistente salida 1. Cubre: RF-1, RF-2 | Modulo: cli

- [ ] T5 Implementar CLI list con racha
  Hecho cuando: `habits list` muestra racha correcta con salida 0 y `pytest tests/test_cli.py` en verde. Cubre: RF-5 | Modulo: cli

- [ ] T6 Manejar casos limite y corrupcion
  Hecho cuando: JSON corrupto devuelve salida 2 con mensaje claro y backup .bak, vacios rechazados con salida 1. Cubre: RF-6, RF-7 | Modulo: storage, cli

- [ ] T7 Validar fuera de alcance no implementado
  Hecho cuando: checklist confirma que nada de Fuera de alcance esta en codigo ni en CLI. Cubre: Fuera de alcance | Modulo: validacion

- [ ] T8 Validar cobertura RF por RF
  Hecho cuando: checklist RF-1 a RF-n con test que lo cubre y demo manual del flujo add, done, list. Cubre: todos | Modulo: validacion

## Trazabilidad RF -> Tareas
- RF-1 -> T4
- RF-2 -> T3, T4
- RF-3 -> T1, T2
- RF-4 -> T1, T3
- RF-5 -> T5

## Dudas abiertas
- [NECESITA ACLARACION] <pregunta pendiente de spec o plan que bloquea alguna tarea>
