# Spec 004 — Menú en línea: selección de apps por categoría y preguntas según lo elegido

## Contexto y objetivo

Tras probar el one-liner (2026-10-28), el usuario reportó tres problemas del menú interactivo de `bootstrap.ps1`:

1. En "Custom per-app", pulsar Enter sobre una app cancela el programa. Causa confirmada: Enter solo confirma las apps marcadas antes con Espacio; si no hay ninguna marcada, la lista llega vacía y se trata como cancelación.
2. Al elegir una categoría (Base, Dev, Gaming, All) se instalan todas sus apps; no hay forma de elegir cuáles.
3. Con cualquier categoría (incluso Gaming o Base), el menú pregunta por Git, VSCode y OpenCode, aunque `install.ps1` solo los configura con Dev/All. Además, con "Custom per-app" se fuerza `Category=All`, así que una selección de solo Steam configura Git/VSCode/OpenCode e incluso instala Brave para aplicar sus extensiones.

Objetivo: que el menú pregunte y aplique solo lo que corresponde a las apps elegidas. Numeración: RF-43 a RF-49.

## Usuarios / actores

- Usuario final que usa el menú del one-liner.
- Usuario avanzado que usa `bootstrap.ps1 -Apps ...` sin menú.

## Historias de usuario

- H1: Como usuario quiero que Enter sobre una app la seleccione, no que cancele.
- H2: Como usuario quiero elegir qué apps instalar dentro de la categoría que elija.
- H3: Como usuario quiero que solo se me pregunte por Git, VSCode u OpenCode si voy a instalar lo que configuran.

## Requisitos funcionales (criterios de aceptación en EARS)

- RF-43: CUANDO el usuario pulse Enter en una lista de selección múltiple sin ninguna opción marcada, EL SISTEMA seleccionará la opción resaltada en vez de cancelar (Esc sigue cancelando).
- RF-44: CUANDO el usuario elija una categoría en el menú, EL SISTEMA mostrará las apps de esa categoría (todas para All) ya marcadas, para que desmarque las que no quiera.
- RF-45: EL SISTEMA retirará del menú la opción "Custom per-app", porque All + RF-44 cubre el mismo caso.
- RF-46: SI tras desmarcar no queda ninguna app, ENTONCES EL SISTEMA cancelará con salida 0 sin cambios.
- RF-47: MIENTRAS exista una selección de apps (menú o `-Apps`), EL SISTEMA solo preguntará y aplicará la configuración de Git si `Git.Git` está seleccionado, la de VSCode si `Microsoft.VisualStudioCode` está seleccionado, y las extensiones de Brave si `Brave.Brave` está seleccionado.
- RF-48: EL SISTEMA solo preguntará y aplicará OpenCode cuando el alcance incluya Dev: categoría Dev o All sin selección, o una selección con al menos una app de la lista Dev.
- RF-49: EL SISTEMA mostrará en el menú y en el README la ayuda de teclas actualizada (Espacio marca o desmarca, Enter confirma) y el nuevo flujo.

## Requisitos no funcionales

- RNF-1: `install.ps1` no cambia: `bootstrap.ps1` traduce la selección a los flags existentes (`-SkipGit`, `-SkipVSCode`, `-SkipOpenCode`, `-SkipBrave`, `-Apps`).
- RNF-2: Mismo contrato de CLI; ningún parámetro nuevo.
- RNF-3: Tests mockeados sin consola real ni red (P6).

## Casos límite

- Enter con algunas apps marcadas → se instalan solo las marcadas (comportamiento actual).
- Selección completa de la categoría sin desmarcar nada → equivale a la categoría (sin `-Apps`).
- Selección de solo Gaming → ninguna pregunta de Git, VSCode ni OpenCode y no se aplican extensiones de Brave.
- `-Apps` con IDs que no están en `apps.json` → se ignoran, como hoy; si no queda ninguno, aviso y lista completa (spec 003).
- Menú numerado (sin consola): las mismas reglas; vacío sigue cancelando porque no hay opción resaltada.

## Fuera de alcance

- Cambiar qué apps tiene cada categoría.
- Instalar OpenCode como app de winget o añadirlo a `apps.json`.
- Que la opción "Simulate first (-WhatIf)" del menú ejecute una simulación completa.
- Cambios en `install.ps1` y en los módulos.

## Criterios de finalización

- RF-43 a RF-49 con test mockeado en verde (Runner y Pester) y trazados a tareas.
- `bootstrap -WhatIf` y el one-liner vía `iex` sin errores; demo manual del menú por el usuario.

## Dudas abiertas

Aprobada por el usuario el 2026-10-28 con las dos propuestas:

- RF-45 resuelto: se retira "Custom per-app".
- RF-48 resuelto: OpenCode se pregunta y aplica solo si el alcance incluye Dev.
- Aclaración de implementación (RF-43 y RF-46): Enter sin marcas elige la opción resaltada solo si el usuario no ha tocado ninguna marca; si las ha desmarcado todas a propósito, cancela. Así ambos RF son compatibles en la lista preseleccionada.
- Sin dudas bloqueantes.
