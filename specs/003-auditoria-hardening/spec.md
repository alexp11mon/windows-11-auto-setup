# Spec 003 — Correcciones de la auditoría (hardening y fiabilidad)

## Contexto y objetivo

Una auditoría del repo (2026-10-28) encontró 15 hallazgos en el instalador v2: la auto-elevación de `bootstrap` no funciona, la selección "Custom per-app" se pierde al elevar, el script elevado se ejecuta desde una ruta escribible por el usuario, los logs del modo en línea se borran, el ZIP se ejecuta como admin sin verificación, y varios fallos menores de fiabilidad. Esta spec corrige los 15 sin cambiar el alcance funcional de las specs 001 y 002. Numeración: RF-28 a RF-42 (un RF por hallazgo, en el mismo orden que el informe).

## Usuarios / actores

- Usuario final que lanza `irm ... | iex` o `.\bootstrap.ps1` desde una terminal sin elevar.
- Usuario avanzado que usa `install.ps1` local o parámetros sin interacción.
- Mantenedor del repo (catálogos, snapshot de OpenCode, publicación de releases).

## Historias de usuario

- H1: Como usuario final quiero que el one-liner se eleve solo y funcione desde una terminal normal.
- H2: Como usuario final quiero que mi selección "Custom per-app" sea exactamente lo que se instala.
- H3: Como usuario final quiero que nada que corra como admin salga de una ruta que otro programa pueda alterar.
- H4: Como usuario final quiero conservar el log aunque la ejecución en línea falle.
- H5: Como mantenedor quiero fallos reales visibles (módulo ausente, ERROR de verdad) y ningún falso ERROR.
- H6: Como mantenedor quiero que el snapshot de OpenCode sea portable y su barrido de secretos no rompa por falsos positivos.

## Requisitos funcionales (criterios de aceptación en EARS)

- RF-28: CUANDO `bootstrap` se ejecute sin privilegios de Administrador, EL SISTEMA se relanzará elevado con `Start-Process -Verb RunAs -Wait -PassThru` sin parámetros `-Redirect*` (incompatibles con `-Verb`) y propagará el código de salida del hijo (hallazgo 1).
- RF-29: CUANDO el usuario elija "Custom per-app" y `bootstrap` deba elevarse, EL SISTEMA pasará la lista de IDs elegidos al proceso elevado, que instalará solo esos IDs (hallazgo 2).
- RF-30: MIENTRAS `bootstrap` corra bajo `iex` y necesite elevarse, EL SISTEMA no persistirá su código en una ruta escribible por procesos no elevados del usuario (hallazgo 3).
- RF-31: CUANDO termine una ejecución en línea (con éxito o con error), EL SISTEMA conservará los logs de `install.ps1` en una ruta estable fuera de la carpeta temporal que se borra, y mostrará esa ruta (hallazgo 4).
- RF-32: DONDE el usuario indique `-Sha256 <hash>`, EL SISTEMA verificará el ZIP descargado antes de extraerlo y abortará con ERROR y salida 1 si no coincide; EL SISTEMA documentará cómo usar un tag de release en `-Branch` (hallazgo 5).
- RF-33: EL SISTEMA no incluirá en el snapshot de OpenCode ficheros con rutas absolutas o nombres de usuario del autor (se retira `plugins/gk-hooks.js`) (hallazgo 6).
- RF-34: CUANDO el barrido de secretos (RF-21) examine el contenido de un fichero, EL SISTEMA marcará solo asignaciones tipo `clave = valor`/`clave: valor` con valor no vacío para `token|password|secret|api[_-]?key`, y no la mera aparición de esas palabras en texto libre (hallazgo 7).
- RF-35: EL SISTEMA aceptará comentarios `//` y `/* */` en `opencode.jsonc` al validarlo (hallazgo 8, no reproducido: PowerShell 7 ya los acepta; se fija con un test de no regresión).
- RF-36: SI `winget install` devuelve código distinto de 0 pero `winget list --exact` muestra la app instalada, ENTONCES EL SISTEMA registrará WARNING (con el código) en vez de ERROR y no marcará fallo global (hallazgo 9).
- RF-37: EL SISTEMA incluirá en la suite tests que validen la forma real de las llamadas a `Start-Process` (combinaciones de parámetros válidas) y que el log sobrevive a la limpieza de `bootstrap` (hallazgo 10).
- RF-38: SI falta un módulo `Config-*.ps1` requerido por `install.ps1`, ENTONCES EL SISTEMA registrará ERROR (salida 1) en vez de WARNING (hallazgo 11).
- RF-39: CUANDO falle cualquiera de los `git config` aplicados (`user.name`, `user.email`, `init.defaultBranch`, `alias.tree`), EL SISTEMA registrará ERROR indicando cuál falló (hallazgo 12).
- RF-40: EL SISTEMA leerá la lista de políticas de Brave una sola vez por ejecución y actualizará en memoria los huecos ocupados (hallazgo 13).
- RF-41: EL SISTEMA construirá el PATH de sesión sin duplicados con una estructura de conjunto en vez de recorridos lineales repetidos (hallazgo 14).
- RF-42: EL SISTEMA indicará en el menú en línea y en el README que las extensiones de Brave se fuerzan por política de equipo (no se pueden quitar desde Brave) (hallazgo 15).

## Requisitos no funcionales

- RNF-1: Mismo entorno que v1/v2 (Windows 11 64-bit, PowerShell 7, Administrador).
- RNF-2: Ninguna prueba instala software real ni pide elevación real (todo mockeado, P6).
- RNF-3: Los cambios no alteran los contratos de CLI existentes; los parámetros nuevos son opcionales (`-Sha256`, `-Apps`).
- RNF-4: Mensajes y logs en inglés, docs en español.

## Casos límite

- Elevación cancelada en UAC → ERROR claro, salida 1 (se mantiene).
- `-Sha256` con mayúsculas o minúsculas → comparación insensible.
- Selección Custom con 0 apps tras filtrar → sin cambios en `apps.json` y aviso.
- App ya instalada pero `winget install` devuelve código no cero → WARNING (RF-36), no ERROR.
- Fichero de texto libre que menciona "token" sin asignar valor → se aplica (RF-34).
- `logs/` vacío o inexistente al copiar logs → se omite sin error.

## Fuera de alcance

- Firmar scripts o publicar en un gestor de paquetes.
- Verificar la integridad del instalador oficial de OpenCode (la excepción RF-17 se mantiene sin cambios).
- Cambiar el mecanismo de políticas de Brave a por-usuario (solo se documenta, RF-42).
- Actualizar apps ya instaladas.

## Criterios de finalización

- RF-28 a RF-42 con test mockeado (Runner y Pester) en verde y trazados a tareas.
- Demo manual: `bootstrap -WhatIf` e `install -WhatIf` con salida 0; demo real de elevación desde terminal normal.
- Log sin `ERROR` imprevisto y docs actualizadas.

## Dudas abiertas

Aprobada la spec por el usuario el 2026-10-28, con estas dudas resueltas:

- RF-32 resuelto: tags con formato `vMAJOR.MINOR.PATCH`; el mantenedor publica el SHA256 del ZIP en las notas de cada release. `-Sha256` es opcional y el `-Branch` por defecto sigue siendo `master` (cambiarlo exige un tag existente; queda fuera de esta spec). El primer tag `v1.0.0` se crea tras T35.
- RF-30 resuelto: bajo `iex` el hijo elevado descarga el mismo `bootstrap.ps1` desde `raw.githubusercontent.com/$Repo/$Branch` (misma confianza que el ZIP). No se exige descarga previa a fichero.
- Hallazgo 8 retirado como bug: RF-35 solo añade un test de no regresión.
- Sin dudas bloqueantes.
