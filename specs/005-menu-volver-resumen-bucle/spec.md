# Spec 005 — Menú en línea: volver atrás, resumen antes de instalar y seguir instalando

## Contexto y objetivo

Tras la spec 004 (2026-10-28), el usuario pide tres mejoras del menú interactivo de `bootstrap.ps1` (one-liner):

1. No hay forma de volver al paso anterior: Esc cancela todo el programa.
2. La confirmación final es una sola línea con recuentos (`Apps=3`); no se ve qué programas se van a instalar.
3. Al terminar una instalación el programa acaba; para instalar otra categoría hay que volver a lanzar el one-liner.

Objetivo: que el usuario pueda corregir pasos, vea la lista completa antes de confirmar y pueda seguir instalando sin relanzar. Numeración: RF-50 a RF-57.

## Usuarios / actores

- Usuario final que usa el menú del one-liner (con consola y en el menú numerado de fallback).

## Historias de usuario

- H1: Como usuario quiero volver al paso anterior para cambiar algo sin empezar de cero.
- H2: Como usuario quiero ver todos los programas y configuraciones antes de instalar y confirmar que estoy seguro.
- H3: Como usuario quiero volver al menú al acabar una instalación para elegir qué más instalar.

## Requisitos funcionales (criterios de aceptación en EARS)

- RF-50: EL SISTEMA mostrará una opción "Back" en cada paso del menú salvo el primero, y Esc volverá también al paso anterior en vez de cancelar.
- RF-51: CUANDO el usuario vuelva atrás, EL SISTEMA conservará lo que eligió en ese paso (categoría resaltada, apps marcadas, datos de Git) para que solo cambie lo necesario.
- RF-52: EL SISTEMA ofrecerá "Exit" en el primer menú; Esc en el primer menú también sale, con código 0 y sin cambios.
- RF-53: CUANDO el usuario termine las preguntas, EL SISTEMA mostrará un resumen con cada app que se instalará agrupada por categoría (Base, Dev, Gaming) y cada configuración que se aplicará (Git con nombre y email, extensiones de VSCode, OpenCode, extensiones de Brave como política de equipo).
- RF-54: Tras el resumen, EL SISTEMA preguntará "Are you sure you want to install these programs?" con las opciones Install, Back y Cancel; solo Install instala.
- RF-55: CUANDO termine una instalación lanzada desde el menú, EL SISTEMA mostrará el resultado (correcto o con errores y la ruta del log) y ofrecerá "Install something else" o "Exit".
- RF-56: CUANDO el usuario elija "Install something else", EL SISTEMA volverá al primer menú sin volver a descargar el script.
- RF-57: AL salir del bucle, EL SISTEMA terminará con 1 si alguna instalación de la sesión falló y con 0 en otro caso.

## Requisitos no funcionales

- RNF-1: `install.ps1`, los módulos y el contrato de CLI no cambian. Con parámetros (`-Category`, `-Apps`, `-WhatIf`...) el comportamiento es el de hoy: una sola ejecución, sin menú ni bucle.
- RNF-2: El menú numerado de fallback ofrece lo mismo: "0" vuelve atrás y vacío sigue cancelando.
- RNF-3: Tests mockeados sin consola real, sin red y sin UAC (P6).
- RNF-4: Bajo `iex` ninguna salida cierra la consola (`return`, nunca `exit`).

## Casos límite

- Volver atrás desde la lista de apps a la categoría y elegir otra → la lista nueva sale entera marcada (la selección anterior era de otra categoría).
- Volver atrás desde el resumen → se vuelve a la última pregunta mostrada; si no hubo ninguna (p. ej. Gaming), a la lista de apps.
- Cancel en el resumen → sale con 0 sin instalar; en el bucle, cuenta como "Exit".
- Usuario sin admin: cada instalación del bucle pide UAC de nuevo, porque el menú corre en el proceso sin elevar y la instalación en uno elevado que termina.
- UAC rechazado en una vuelta → se muestra el error y se ofrece de nuevo "Install something else" / "Exit" (cuenta como fallo para RF-57).
- Reinstalar apps de una vuelta anterior → winget las detecta y las omite (idempotencia existente); no se marcan aparte.

## Fuera de alcance

- Mostrar en el resumen qué apps ya están instaladas (necesitaría winget antes de elevar).
- Elevar una sola vez para todo el bucle.
- Cambiar qué apps tiene cada categoría.

## Criterios de finalización

- RF-50 a RF-57 con test mockeado en verde (Runner y Pester) y trazados a tareas.
- `bootstrap -WhatIf`, `-Apps` sin menú y el one-liner vía `iex` sin errores; demo manual del menú por el usuario.

## Dudas abiertas

Aprobada por el usuario el 2026-10-28 con las dos propuestas:

- Se retira la opción "Simulate first (-WhatIf)" de la confirmación: el resumen de RF-53 ya muestra lo que se va a hacer.
- Se acepta UAC en cada vuelta del bucle (no se eleva una sola vez al principio).
- Aclaración de RF-56: "sin volver a descargar el script" significa que el usuario no relanza el one-liner; cada instalación descarga el ZIP como hoy.
- Sin dudas bloqueantes.
