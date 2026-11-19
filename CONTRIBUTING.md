# Cómo trabajar en Tumble Rush

Guía corta de proceso: cómo se nombran los commits, cómo se ejecutan los tests, qué hooks hay y cuándo se toca la documentación.

## 1. Mensajes de commit

Formato obligatorio:

```
tipo(área): resumen en imperativo
```

- **Asunto** de 72 caracteres como máximo, en minúscula, sin punto final y en imperativo («añade», «corrige», «quita»).
- **Tipos:** `feat` (funcionalidad nueva), `fix` (error corregido), `docs` (documentación), `refactor` (sin cambio de comportamiento), `perf` (rendimiento), `test` (tests) y `chore` (herramientas, configuración, dependencias).
- **Áreas:** `player`, `levels`, `bots`, `hud`, `ui`, `audio`, `tools`, `ci`, `docs`. Si el cambio cruza varias, se elige la principal.
- **Cuerpo** (opcional pero recomendado en cambios grandes): por qué se hace, no qué se toca. El «qué» ya se ve en el diff.
- **Un cambio por commit.** Mezclar un arreglo de física con un retoque de documentación hace el historial inservible.

Ejemplos:

```
feat(levels): divide los circuitos generados en tres actos
perf(player): limita la sombra de contacto a 25 Hz
fix(bots): devuelve al bot a su último checkpoint al caer
docs(readme): actualiza la verificación y el recuento de escenas
chore(ci): cachea Godot y la importación entre jobs
```

Evita mensajes como `si`, `mejora mapssss`, `bug fixing` o `por si acaso`: describen el estado de ánimo, no el cambio. Si un commit necesita un contexto largo, va en el cuerpo:

```bash
git commit -m "$(cat <<'EOF'
perf(levels): recorta el atrezo de los actos a distancia

Un acto del abismo tiene más de mil mallas de coral y algas: se dejan de
dibujar cuando ocupan menos de ~14 px, con desvanecido dither para que no se
vea el corte.
EOF
)"
```

## 2. Tests

La batería headless vive en `proyecto/tools/`:

```bash
cd proyecto
bash tools/run_tests.sh          # suite obligatoria (12 tests, ~5 min)
bash tools/run_tests.sh --long   # tests largos de bots
bash tools/run_tests.sh --all    # todo
```

- Cada test corre con `timeout` (180 s la suite, 900 s los largos): un cuelgue **falla**, no cuelga la máquina.
- El resumen se imprime, se guarda en `proyecto/tools/test-logs/summary.md` y, en CI, se publica en el resumen del job.
- Para un test suelto: `godot --headless --path . -s res://tools/levels_test.gd`.
- Los tests asumen que el proyecto se ha abierto una vez en Godot (importación hecha).

**Ningún test se quita de la lista para que la CI salga verde**, y los dos jobs de la CI (suite y tests largos) bloquean por igual. Si algo no termina, se arregla; si es una limitación conocida, se documenta en el informe con su medición.

## 3. Lint y formato

```bash
pip install pre-commit
pre-commit install
```

Los hooks (`.pre-commit-config.yaml`) son:

- `gdformat` — formato de GDScript.
- `gdlint` — estilo y errores: argumentos sin usar, expresiones sin efecto, orden de miembros, líneas largas, tabs y espacios mezclados.
- `sin-prints-de-depuracion` — rechaza `print()` en `proyecto/scripts/` (los dos archivos con diagnósticos a propósito están excluidos).

gdtoolkit **no** detecta variables locales sin usar: eso lo avisa el propio editor de Godot. Se pasan a mano cuando toque: `pre-commit run --all-files`.

## 4. Documentación

Cuando cambie algo visible del juego (circuito, mecánica, recuento de escenas, resultado de los tests), se actualizan en el mismo commit:

| Documento | Qué cubre |
| --- | --- |
| `README.md` | Cómo ejecutar, controles, características, arquitectura y verificación. |
| `documentacion/Segunda_iteracio.md` | Estado de la entrega actual y resultados reales de la batería. |
| `documentacion/Torneo_cuatro_circuitos.md` | Los circuitos del torneo, paletas y verificación. |
| `documentacion/Primera_entrega.md` | Histórico de la primera entrega (no se reescribe con datos nuevos). |
| `documentacion/Ideas_Mejora.md` | Banco de ideas: se marca lo que ya está hecho. |

Las cifras de los informes salen de los tests, no de la memoria: si `check_scenes` dice `40/40`, el informe dice `40/40`.
