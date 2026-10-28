# Plan 005 - Menú: volver atrás, resumen y seguir instalando

Spec de origen: `specs/005-menu-volver-resumen-bucle/spec.md`. Constitución: `docs/constitution.md`. Planes 001 a 004 siguen vigentes.

## Resumen de arquitectura

Solo cambia `bootstrap.ps1`. El modo interactivo pasa a ser un "front end" que nunca instala en su propio proceso:

1. `Invoke-InteractiveSetup` recorre los pasos como una pila (historial), con Back y memoria de respuestas, y devuelve las opciones elegidas o la decisión de salir.
2. `Invoke-InstallRound` lanza `bootstrap` con esas opciones como parámetros en un proceso hijo (elevado con UAC si hace falta, sin elevar si ya es admin) y devuelve su código de salida. El hijo sigue la ruta no interactiva de hoy (descarga ZIP, `install.ps1`, `Save-RunLogs`).
3. Un bucle muestra el resultado y ofrece "Install something else" o "Exit".

Con parámetros (`-Category`, `-Apps`, `-WhatIf`...) no hay menú ni bucle: el flujo de hoy no cambia (RNF-1).

## Módulos y responsabilidades

- `bootstrap.ps1`:
  - `Show-Menu`: Esc devuelve `$MenuBack` (antes `$null`). Parámetros nuevos `-Checked` (opciones marcadas al entrar; sustituye a `-Preselected`) y `-Start` (opción resaltada al entrar). Desmarcar todo + Enter sigue devolviendo `$null` (cancelar, RF-46). Cubre: RF-50, RF-51.
  - `Show-NumberedMenu`: "0" devuelve `$MenuBack`; vacío devuelve `$null` (cancelar). Cubre: RNF-2.
  - `Format-InstallSummary -Category -Apps -AppsData -Choices`: texto del resumen (apps agrupadas por categoría + configuraciones). Función pura. Cubre: RF-53.
  - `Invoke-InteractiveSetup -AppsData`: máquina de pasos `Category → Apps → Git → VSCode → OpenCode → Summary`, saltando los que no aplican según `Get-ConfigScope`. Back = volver al paso anterior del historial; en `Category`, Back/Exit = salir. Summary con Install / Back / Cancel. Devuelve `@{ Category; Apps; GitUserName; GitUserEmail; SkipGit; SkipVSCode; SkipOpenCode; SkipBrave }` o `$null` (salir). Cubre: RF-50 a RF-54.
  - `Invoke-InstallRound -Choices -IsAdmin`: construye el comando con `Get-ElevatedCommand` y lo lanza con `Start-Process pwsh -EncodedCommand ... -Wait -PassThru` (con `-Verb RunAs` si no es admin). Devuelve el código; UAC rechazado → 1. Reutiliza el aviso con las últimas 20 líneas del log. Cubre: RF-55, RF-56.
  - Bucle principal: `Invoke-InteractiveSetup` → `Invoke-InstallRound` → resultado → "Install something else" / "Exit"; guarda el peor código. Cubre: RF-55, RF-56, RF-57.
- `tests/`: teclas simuladas, `Read-Host` simulado, `Start-Process` simulado. Cubre: todos.
- `README.md`, `AGENTS.md`, `docs/estructura-proyecto.md`: flujo nuevo. Cubre: RF-50 a RF-57.

## Modelo de datos

- `$MenuBack = '<back>'`: valor centinela de "volver". `$null` = cancelar.
- Respuestas del menú (memoria de RF-51): hashtable con `CategoryIndex`, `Picked` (apps marcadas), `GitChoice`, `GitUserName`, `GitUserEmail`, `CodeChoice`, `OpenCodeChoice`. Si cambia la categoría, `Picked` se reinicia a la categoría completa.
- Historial: lista de nombres de paso visitados; Back quita el último.

## Contratos e interfaces

- CLI sin cambios.
- En cada menú de opción única salvo el primero se añade "Back" como última opción. El primero tiene "Exit".
- Resumen: título "Are you sure you want to install these programs?" y opciones `Install`, `Back`, `Cancel`. Se retira "Simulate first (-WhatIf)".
- Tras cada vuelta: "Installation finished (exit code N). Logs: ..." y opciones `Install something else`, `Exit`.

## Flujo principal paso a paso

1. Descargar `apps.json` una vez al entrar al modo interactivo.
2. Bucle:
   1. `Invoke-InteractiveSetup` → `$null` = salir.
   2. `Invoke-InstallRound` → código; `$worst = max($worst, código)`.
   3. Resultado + "Install something else" / "Exit" (Esc = Exit).
3. Salir con `$worst` (`return` bajo `iex`).

## Decisiones técnicas

- D32: El menú interactivo instala siempre vía proceso hijo con parámetros, también si ya es admin. Motivo: el flujo de instalación (descarga, `-Sha256`, limpieza, logs) queda en un solo sitio y el bucle no tiene que reiniciar estado global. Descartado convertir los pasos 3 a 7 en función: refactor mayor y más riesgo. Cubre: RF-55, RF-56.
- D33: Pasos como historial en vez de índices fijos: Back respeta los pasos saltados (p. ej. Gaming vuelve del resumen a la lista de apps). Cubre: RF-50.
- D34: Centinela `$MenuBack` en vez de cambiar `$null`: `$null` ya significa cancelar en el menú numerado y en la lista vacía. Cubre: RF-50, RNF-2.
- D35: `-Checked` sustituye a `-Preselected` (un solo parámetro sirve para "todo marcado" y para recordar la selección). Cubre: RF-51.
- D36: UAC en cada vuelta (aprobado). Cubre: RF-55.

## Trazabilidad RF -> módulo

- RF-50 -> `bootstrap.ps1` (`Show-Menu`, `Show-NumberedMenu`, `Invoke-InteractiveSetup`)
- RF-51 -> `bootstrap.ps1` (`Show-Menu -Checked -Start`, `Invoke-InteractiveSetup`)
- RF-52 -> `bootstrap.ps1` (`Invoke-InteractiveSetup`)
- RF-53 -> `bootstrap.ps1` (`Format-InstallSummary`)
- RF-54 -> `bootstrap.ps1` (`Invoke-InteractiveSetup`)
- RF-55 -> `bootstrap.ps1` (`Invoke-InstallRound`, bucle)
- RF-56 -> `bootstrap.ps1` (bucle)
- RF-57 -> `bootstrap.ps1` (bucle)

## Riesgos y mitigaciones

- R15: El hijo no elevado bajo `iex` vuelve a descargar `bootstrap.ps1` de `master` (no de la copia en memoria) → mitigación: es el mecanismo ya aprobado en spec 003 para la elevación; se usa el mismo `$Branch`.
- R16: Varias vueltas dejan varios logs → mitigación: cada `install.ps1` crea su log fechado; `Save-RunLogs` los copia todos.
- R17: Menú real con flechas solo se prueba en consola → mitigación: `Read-MenuKey` simulado + demo manual.

## Dudas abiertas

- Sin bloqueantes.
