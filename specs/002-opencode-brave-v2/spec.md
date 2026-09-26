# Spec 002 — OpenCode + Brave V2

## Contexto y objetivo

El instalador automático (v1: apps winget + Git + VSCode) aún deja fuera tres bloques que hoy se hacen a mano: instalar OpenCode, copiar su configuración global (agentes, skills, plugins y ajustes) y reinstalar las extensiones de Brave. Esta V2 mejora el instalador para que los próximos usuarios reciban esos bloques automáticamente, manteniendo idempotencia, simulación y logs con salida 0/1.

## Usuarios / actores

- Usuario final con PC nuevo que ya usa OpenCode y Brave en su equipo actual.
- Usuario avanzado que automatiza con parámetros sin interacción.
- Mantenedor del catálogo de extensiones y de la copia versionada de la configuración de OpenCode.

## Historias de usuario

- H1: Como usuario de OpenCode quiero que quede instalado sin pasos manuales para trabajar nada más terminar el instalador.
- H2: Como usuario de OpenCode quiero que mi configuración global (agentes, skills, plugins y ajustes) quede aplicada para no copiarla a mano.
- H3: Como usuario de Brave quiero que mis extensiones queden instaladas automáticamente para no reinstalarlas una por una.
- H4: Como mantenedor quiero la documentación actualizada con los nuevos bloques para no responder las mismas preguntas.

## Requisitos funcionales (criterios de aceptación en EARS)

- RF-17: CUANDO la categoría sea Dev o All y OpenCode no esté instalado, EL SISTEMA lo instalará con el instalador oficial publicado por el proyecto OpenCode (excepción aprobada al principio P2 "solo winget").
- RF-18: CUANDO OpenCode ya esté instalado, EL SISTEMA omitirá la instalación sin error y continuará con la configuración.
- RF-19: MIENTRAS la categoría sea Dev o All, EL SISTEMA aplicará la configuración global de OpenCode (agentes, skills, plugins y ajustes) desde la copia versionada incluida en el repositorio.
- RF-20: SI el equipo destino ya contiene configuración global de OpenCode distinta a la copia versionada, ENTONCES EL SISTEMA fusionará ambas sin borrar ningún fichero existente del usuario (ante el mismo fichero con distinto contenido, se conserva el del usuario con aviso).
- RF-21: SI algún fichero de la copia versionada contuviera secretos o tokens, ENTONCES EL SISTEMA omitirá solo ese fichero con aviso y continuará con el resto.
- RF-22: MIENTRAS la categoría sea Base o All, EL SISTEMA dejará instaladas automáticamente las extensiones de Brave del usuario (uBlock Origin Lite, Dark Reader, Decentraleyes, Bitwarden y Privacy Badger), efectivas tras reiniciar Brave.
- RF-23: SI Brave no está instalado cuando corresponda aplicar sus extensiones, ENTONCES EL SISTEMA lo instalará primero y después aplicará las extensiones.
- RF-24: DONDE el usuario indique omisión de OpenCode o de Brave, EL SISTEMA omitirá el bloque correspondiente sin error.
- RF-25: SI la descarga del instalador oficial de OpenCode falla, ENTONCES EL SISTEMA reintentará una vez más y, si persiste el fallo, registrará ERROR y continuará con el resto (la ejecución terminará con salida 1).
- RF-26: MIENTRAS esté activo el modo simulación, EL SISTEMA describirá lo que haría con OpenCode y Brave sin descargar, instalar, modificar ni preguntar nada.
- RF-27: EL SISTEMA mantendrá actualizada la documentación de usuario en español con los nuevos bloques (instalación y omisión de OpenCode y Brave, lista de extensiones, excepción a P2).

## Requisitos no funcionales

- RNF-1: Los bloques nuevos solo corren en Windows 11 64-bit con PowerShell 7 y sesión de Administrador, como el resto del instalador.
- RNF-2: Re-ejecución segura: una segunda pasada sin cambios termina en 0 si todo ya estaba aplicado.
- RNF-3: Ninguna prueba instala software real ni modifica el equipo (todo mockeado).
- RNF-4: La copia versionada de la configuración de OpenCode no contendrá secretos, tokens ni datos personales.

## Casos límite

- OpenCode presente pero su comprobación de versión falla → se trata como no instalado (RF-17).
- Carpeta de configuración global inexistente en destino → se crea y se aplica la copia completa.
- Brave instalado pero sin perfil de usuario aún → las extensiones quedan programadas y se avisa del reinicio.
- Extensión ya aplicada → se omite sin error (idempotencia).
- Cancelación del menú en línea en las preguntas nuevas → salida 0 sin cambios, como el resto del menú.

## Fuera de alcance

- Actualizar una versión existente de OpenCode (solo se instala si está ausente).
- Sincronización bidireccional (el instalador no exporta cambios del PC nuevo al repositorio).
- Otros navegadores (Chrome, Edge, Firefox) u otras extensiones fuera de la lista de RF-22.
- Gestión de licencias, suscripciones o sesiones dentro de las extensiones (ej. cuenta de Bitwarden).
- Almacenamiento o migración de credenciales, claves API o tokens (prohibidos por P7).

## Criterios de finalización

- Todos los RF-17 a RF-27 con suite mockeada en verde y demo manual de `install -WhatIf` + `bootstrap -WhatIf` con salida 0.
- Log de ejecución simulada sin `ERROR` imprevisto.
- Documentación actualizada según RF-27.

## Dudas abiertas

- Sin dudas bloqueantes. RF-20 (conflicto de fusión) resuelto el 2026-09-26: se conserva el fichero del usuario con aviso.
