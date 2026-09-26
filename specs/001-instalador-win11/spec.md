# Spec 001 — Instalador Automático Windows 11

## Contexto y objetivo

Un usuario con un PC nuevo con Windows 11 necesita dejarlo listo (navegador, utilidades, herramientas dev, gaming, Git y VSCode) con un solo comando, re-ejecutable y simulable antes de tocar el sistema. Esta spec congela la v1 existente y añade la v2 de deuda documental pendiente.

## Usuarios / actores

- Usuario final con PC nuevo (uso diario, dev o gaming).
- Usuario avanzado que automatiza con parámetros sin interacción.
- Mantenedor del catálogo de apps y extensiones.

## Historias de usuario

- H1: Como usuario nuevo quiero instalar todo con un comando para no configurar a mano.
- H2: Como usuario avanzado quiero simular antes de instalar para ver qué haría sin riesgo.
- H3: Como desarrollador quiero que Git y VSCode queden configurados solo cuando pido Dev/All para no mezclar perfiles.
- H4: Como usuario en línea quiero un menú con flechas para elegir alcance sin clonar el repo.
- H5: Como mantenedor quiero deuda documental cerrada (comentarios, idioma, README, docs) para publicar el proyecto.

## Requisitos funcionales (criterios de aceptación en EARS)

- RF-1: EL SISTEMA instalará aplicaciones por categoría Base, Dev, Gaming o All (All = Base + Dev + Gaming).
- RF-2: CUANDO el usuario elija modo local, EL SISTEMA instalará desde el catálogo local sin descargar nada externo.
- RF-3: CUANDO el usuario elija modo en línea sin parámetros, EL SISTEMA mostrará menú de alcance, selección personalizada por app, configuración Git, configuración VSCode y confirmación (instalar / simular / cancelar).
- RF-4: DONDE el modo en línea sea invocado por tubería (`iex`), EL SISTEMA no cerrará la consola al terminar y dejará el resultado en `$LASTEXITCODE`.
- RF-5: CUANDO falten privilegios de administrador, EL SISTEMA solicitará elevación UAC y propagará el código de salida del instalador hijo.
- RF-6: MIENTRAS la categoría sea Dev o All, EL SISTEMA aplicará configuración de Git (`user.name`, `user.email`, `init.defaultBranch=main`, alias `tree`).
- RF-7: CUANDO se pasen nombre/email por parámetros, EL SISTEMA configurará Git sin preguntas; CUANDO se pase `-SkipGit`, EL SISTEMA omitirá dicha configuración.
- RF-8: SI el email tiene formato inválido o está vacío, ENTONCES EL SISTEMA omitirá la configuración de Git con aviso y continuará con el resto.
- RF-9: MIENTRAS la categoría sea Dev o All, EL SISTEMA instalará las extensiones de VSCode ausentes; DONDE se pase `-SkipVSCode`, EL SISTEMA las omitirá.
- RF-10: EL SISTEMA omitirá sin error toda app o extensión ya instalada (idempotencia).
- RF-11: MIENTRAS esté activo el modo simulación, EL SISTEMA describirá lo que haría sin descargar, instalar ni preguntar datos interactivos.
- RF-12: EL SISTEMA generará un log fechado por ejecución y devolverá salida 0 si no hubo `ERROR`, salida 1 si hubo alguno.
- RF-13: CUANDO una app por-usuario rechace la sesión elevada (ej. Spotify `-1978335146`), EL SISTEMA continuará con el resto y terminará con salida 1.
- RF-14 (v2): EL SISTEMA mantendrá comentarios de código concisos, sin explicaciones redundantes de IA.
- RF-15 (v2): EL SISTEMA mostrará comentarios, avisos y errores del código en inglés; la documentación de usuario seguirá en español.
- RF-16 (v2): EL SISTEMA documentará en README todas las formas de uso (local, en línea, categorías, Git no interactivo, códigos de salida) y el crédito de tests con IA.

## Requisitos no funcionales

- RNF-1: Plataforma exclusiva Windows 11 64-bit, Build >= 22000, detección independiente del idioma del SO.
- RNF-2: Ejecución exclusiva en PowerShell 7; abortar con mensaje claro en otro host.
- RNF-3: Re-ejecución segura: segunda pasada sin cambios termina en 0 si todo ya estaba instalado.
- RNF-4: Sin credenciales, tokens ni datos personales en el repositorio.
- RNF-5: Tests sin efectos: ninguna prueba instala software real.

## Casos límite

- SO con `OSArchitecture` localizada (`64 bits` vs `64-bit`).
- `apps.json` o `extensions.json` ausente o JSON inválido → `ERROR` y salida 1.
- Categoría vacía o ID vacío → aviso y continuar.
- `git`/`code` recién instalados aún no en `PATH` → refrescar sesión, si persiste omitir con aviso.
- Consola sin soporte de flechas (ISE, entrada redirigida) → menú numerado alternativo.
- Descarga ZIP falla 2 veces → `ERROR` y salida 1.
- Cancelación con `Esc`/vacío en cualquier menú → salida 0 sin cambios.

## Fuera de alcance

- Soporte a Windows 10, 32-bit, Linux o macOS.
- Gestores distintos a winget, desinstalación o actualización de apps.
- Interfaz gráfica, telemetría o auto-update del instalador.
- Gestión de licencias, dotfiles generales o configuración de red/sistema.
- Almacenamiento de credenciales Git o tokens.

## Criterios de finalización

- Todos los RF-1 a RF-13 con `tests/Runner-Mock.ps1` en verde y demo manual de `install -WhatIf` + `bootstrap -WhatIf`.
- RF-14 a RF-16 con revisión manual del diff (sin comentarios IA, inglés en código, README/docs actualizados).
- Log de ejecución real o simulada sin `ERROR` imprevisto.

## Dudas abiertas

- Sin dudas bloqueantes. La rama por defecto (`master`) y el repo remoto se parametrizan y no forman parte del contrato.
