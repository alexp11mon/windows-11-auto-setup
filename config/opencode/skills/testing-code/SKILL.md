---
name: testing-code
description: Use when user asks to test, probar, testear, or write tests for a file, function, module or project. Triggers on haz test de este código, testea esto, escribe tests. Use ONLY when testing is explicitly requested.
---

# Testing Code

Ejecuta un flujo completo y coherente de testing cuando el usuario lo pida explícitamente, sin necesidad de que explique cada vez cómo quiere que se haga.

## 1. Detección del lenguaje y framework

Antes de escribir ningún test:

- Detecta el lenguaje por la extensión del archivo y su contenido.
- Detecta el framework ya en uso mirando: `package.json`, `requirements.txt` / `pyproject.toml`, `go.mod`, `Gemfile`, `pom.xml` / `build.gradle`, carpetas `tests/` / `__tests__/` / `spec/`, y configs existentes (`jest.config`, `vitest.config`, `pytest.ini`, etc.).
- Si detectas un framework ya usado, úsalo siempre, sin preguntar.
- Si NO hay framework ni tests previos, usa el estándar de facto: `pytest` para Python, `Jest` o `Vitest` para JavaScript/TypeScript, `go test` para Go, `JUnit` para Java, `RSpec` para Ruby.
- Solo pregunta explícitamente por el framework si hay ambigüedad real (dos frameworks configurados, o varias opciones igual de comunes sin pistas). En otro caso decide tú y avisa en un comentario breve qué framework elegiste y por qué.

## 2. Alcance del test (completo por defecto)

Cuando no se indique lo contrario, cobertura exhaustiva, incluyendo siempre que aplique:

- Casos principales (happy path) con combinaciones de entradas típicas.
- Casos límite (mínimos, máximos, vacíos, cero, longitud 1, colecciones vacías, etc.).
- Valores nulos / `None` / `undefined` / `null` donde el tipo lo permita.
- Errores y excepciones esperadas (inputs inválidos, tipos incorrectos, fallos de validación), verificando que se lanza el error correcto.
- Condiciones de contorno en bucles, recursividad o condicionales (off-by-one, ramas no visitadas).
- Efectos secundarios y estado (si muta estado, comprueba antes y después).
- Dependencias externas (I/O, red, base de datos, tiempo/fecha, aleatoriedad): mockeadas o stubbeadas para que el test sea determinista y sin recursos externos.
- Código asíncrono (promesas, `async/await`, callbacks): cubre también rechazo / error asíncrono.

Solo reduce este alcance si el usuario lo pide explícitamente (por ejemplo `solo el happy path` o `un test rápido`).

## 3. Ejecución automática

1. Genera los tests.
2. Ejecútalos automáticamente con el comando del framework detectado.
3. Si algún test falla:
   - Analiza si es bug real en el código o error en el test.
   - Si es error en el test, corrígelo tú mismo y vuelve a ejecutar.
   - Si es bug real en el código, no lo corrijas sin preguntar: repórtalo claramente (qué falla, por qué y en qué línea) y espera confirmación antes de tocar producción, salvo autorización previa para corregir bugs automáticamente.
4. Repite generar → ejecutar → ajustar hasta que todo pase o quede un bug real pendiente de confirmación.
5. Al final muestra resumen breve: framework usado, número de tests creados, resultado (pasa/falla) y cobertura aproximada si la herramienta la reporta.

## 4. Estilo y ubicación de los tests

- Sigue la convención ya usada en el proyecto (por ejemplo `archivo.test.ts` junto al fuente, o `tests/test_archivo.py` en carpeta separada).
- Si no hay convención previa, usa la estándar del framework elegido.
- Nombres que describan qué comportamiento verifican (evitar `test1`, `test2`).
- Agrupa los relacionados (por función/método) con `describe` / `class` / `context` según el framework.
- No dupliques tests existentes: si ya hay tests para una función, amplíalos en vez de recrearlos, salvo que pidan rehacerlos.

## 5. Qué NO hacer

- No modifiques código de producción para "hacer pasar" un test si el fallo indica un bug real, sin confirmación previa.
- No elimines ni sobrescribas tests existentes sin avisar.
- No instales dependencias / frameworks nuevos sin decirlo primero si el proyecto no tiene ninguno y hay más de una opción razonable.
