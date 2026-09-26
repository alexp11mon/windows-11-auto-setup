# Plan NNN - <Nombre de la funcionalidad>

<Spec de origen: specs/NNN-<nombre>/spec.md. Constitucion: docs/constitution.md.>

## Resumen de arquitectura
<Estilo en 3 lineas. Ejemplo: CLI en capas core + storage + cli, sin dependencias externas. Diagrama textual si ayuda.>

## Modulos y responsabilidades
<Cada modulo con: que hace, que no hace, RF que cubre. Ejemplo:>
- `core`: logica pura y calculos. Cubre: RF-3, RF-4.
- `storage`: carga y guardado atomico en JSON local. No valida negocio. Cubre: RF-2, RF-5.
- `cli`: parseo de comandos add, done, list y codigos de salida. Cubre: RF-1, RF-8.

## Modelo de datos
<Entidades, campos, validaciones y formato de persistencia. Ejemplo:>
- Habit { id, nombre normalizado, creado_en, dias_marcados[] }
- Validacion: nombre no vacio, unico ignorando mayusculas y espacios exteriores.
- Persistencia: JSON local con escritura atomica (tmp + rename).

## Contratos e interfaces
<Comandos, parametros, salidas y errores. Ejemplo:>
- `habits add <nombre>` -> salida 0 si crea, salida 1 si duplicado con mensaje en stderr.
- `habits done <nombre> [--fecha YYYY-MM-DD]` -> salida 0 si marca, salida 1 si no existe.
- `habits list` -> lista con racha actual, salida 0 siempre salvo corrupcion (salida 2).

## Flujo principal paso a paso
<Recorrido del caso central citando RF. Ejemplo:>
1. Usuario ejecuta add (RF-1) -> cli valida args -> core normaliza -> storage comprueba duplicado (RF-4) -> guarda.
2. Usuario ejecuta done (RF-2) -> core calcula racha (RF-3) -> storage persiste.

## Decisiones tecnicas
<Cada una con elegida, descartada y motivo. Ejemplo:>
- D1: argparse de stdlib. Descartado click por fuera de stack. Motivo: simplicidad y P1. Cubre: RF-1.
- D2: JSON local con atomic write. Descartado SQLite por migraciones innecesarias en MVP. Motivo: simplicidad. Cubre: RF-2, RF-5.

## Trazabilidad RF -> modulo
<Todo RF aparece al menos una vez. Ejemplo:>
- RF-1 -> cli
- RF-2 -> cli, storage
- RF-3 -> core
- RF-4 -> core, storage

## Riesgos y mitigaciones
<Riesgos sin cambiar RF. Ejemplo:>
- R1: JSON corrupto -> mitigacion: backup .bak y salida 2 con mensaje claro, sin perder datos si es posible.
- R2: Concurrencia -> mitigacion: fuera de alcance en MVP, documentado.

## Dudas abiertas
- [NECESITA ACLARACION] <pregunta tecnica concreta pendiente>
