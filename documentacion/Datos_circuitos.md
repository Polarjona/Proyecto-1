# Datos de referencia

**Proyecto:** Tumble Rush
**Última revisión:** 19 de noviembre de 2026

Este documento es la **fuente única de las cifras compartidas** por el README y los informes: longitudes, checkpoints, medallas, configuración del torneo, recuentos de contenido y resultados de la batería. El resto de documentos enlaza aquí en vez de copiar la tabla. El detalle de producción de los actos (losas, pinchos, alturas y tuning) vive en [Torneo de circuitos](Torneo_cuatro_circuitos.md) y no se duplica aquí.

<a id="circuitos"></a>
## Circuitos

| Ronda | Modo    | id               | Circuito      | Escena                              | Longitud | Checkpoints | Oro / Plata / Bronce |
| ----- | ------- | ---------------- | ------------- | ----------------------------------- | -------- | ----------- | -------------------- |
| 1     | Torneo  | `pivot_push`     | Pivot Push    | `scenes/levels/pivot_push.tscn`     | 368 m    | 11          | 130 / 170 / 215 s    |
| 2     | Torneo  | `spin_go_round`  | Spin Go Round | `scenes/levels/spin_go_round.tscn`  | 339 m    | 12          | 115 / 145 / 185 s    |
| 3     | Torneo  | `glacier_gallop` | Glacier Gallop | `scenes/levels/glacier_gallop.tscn` | 367 m    | 9           | 145 / 180 / 225 s    |
| 4     | Torneo  | `lava_vortex`    | Lava Vortex   | `scenes/levels/lava_vortex.tscn`    | 510 m    | 0           | 84 / 100 / 116 s     |
| —     | Clásica | `abyss_run`      | Abyss Run     | `scenes/levels/abyss_run.tscn`      | 428 m    | 6           | 112 / 138 / 172 s    |

Las longitudes se muestran redondeadas al metro entero. `LevelInfo.course_length` de Lava Vortex guarda `509.5636739730835`; por eso el valor documentado es **510 m**, no 509.

<a id="configuracion-del-torneo"></a>
## Configuración del torneo

| Dato                         | Valor                                      |
| ---------------------------- | ------------------------------------------ |
| Rondas                       | 4                                          |
| Circuitos                    | Pivot Push → Spin Go Round → Glacier Gallop → Lava Vortex |
| Bots iniciales               | 7                                          |
| Bots máximos                 | 11                                         |
| Plazas que clasifican        | 3 → 3 → 2 → 1                              |
| Velocidad de bots por ronda  | +5 % acumulado                             |

<a id="recuentos-de-contenido"></a>
## Recuentos de contenido

| Elemento                              | Cantidad |
| ------------------------------------- | -------- |
| Circuitos                             | 5        |
| Circuitos del torneo                  | 4        |
| Escenas de obstáculo reutilizables    | 17       |
| Personajes                            | 10       |
| Cuerpos de personaje                  | 20       |
| SFX sintetizados                      | 15       |
| Tramos de la espiral de Lava Vortex   | 116      |

<a id="verificacion"></a>
## Verificación

Resultado de la última pasada con Godot 4.7.2 en esta máquina:

**Procedencia:** 19 de noviembre de 2026 · `cd proyecto && bash tools/run_tests.sh` (los tests largos se lanzan aparte con `--long`). El resumen local queda en `proyecto/tools/test-logs/summary.md`, que Git ignora; en CI se publica como artefacto del job.

| Comprobación                         | Resultado |
| ------------------------------------ | --------- |
| Suite obligatoria (`run_tests.sh`)   | 14/14 en verde |
| Escenas (`check_scenes`)             | 40/40 OK |
| Tests largos de bots                 | 3/3 OK |
| `levels_bots_test` — Spin Go Round   | 126,0 s |
| `levels_bots_test` — Glacier Gallop  | 183,0 s |
| `levels_bots_test` — Lava Vortex     | 116,5 s |

La lista de tests y los comandos están en [`proyecto/tools/README.md`](../proyecto/tools/README.md). Las capturas propias están en [`Capturas.md`](Capturas.md) y en `documentacion/capturas/`.

> Si cambia un circuito, una medalla, un recuento o el resultado de la suite, se actualiza **solo este documento** y se comprueba que los enlaces de los informes siguen apuntando aquí.
