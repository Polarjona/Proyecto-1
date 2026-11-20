# Herramientas y tests

Todo lo que hay aquí se ejecuta desde `proyecto/` (Godot, y Python para `check_docs.py`). La batería, los generadores y las sondas usan headless; `capture_docs.gd` necesita ventana. No forma parte del juego exportado: son la batería de pruebas, los generadores de mapas, las capturas y las sondas de un solo uso.

## Batería de tests

```bash
tools/run_tests.sh            # suite obligatoria
tools/run_tests.sh --long     # tests largos de bots
tools/run_tests.sh --all      # todo
```

Variables: `GODOT` (binario, por defecto `godot`), `TEST_TIMEOUT` (180 s) y
`LONG_TIMEOUT` (900 s). Cada test corre aislado con `timeout`; los logs y el
resumen quedan en `tools/test-logs/` (y en el resumen del job en GitHub Actions).

| Suite | Tests |
| --- | --- |
| Obligatoria | `persistence_test`, `check_scenes`, `smoke_test`, `flow_test`, `levels_test`, `lod_test`, `progression_test`, `settings_test`, `ux_test`, `features_test`, `iteration3_test`, `iteration4_test`, `iteration5_test`, `check_docs` |
| Larga | `levels_bots_test`, `bots_test`, `slow_test` |

Convenciones: cada test imprime `RESULT: …`, `SMOKE OK` o `TODO LOS …` y sale
con código 0 solo si pasa. `check_scenes` recorre `res://scenes` y carga cada
`.tscn`, así que una escena nueva entra sola en la prueba. `check_docs` es el
único test en Python: contrasta `Datos_circuitos.md` con escenas, scripts,
enlaces, imágenes y anclas, y no usa dependencias externas.

## Generadores y mantenimiento

| Fichero | Qué hace |
| --- | --- |
| `bake_csg.gd` (+ `csg_runner.tscn`) | Hornea los `CSGBox3D` de los mapas a malla + colisión estática. |
| `bake_abyss.gd` | Hornea Abyss Run en una escena con la geometría ya construida. |
| `build_levels.gd` (+ `build_levels.tscn`) | Genera los circuitos del torneo (`spin_go_round`, `glacier_gallop`, `lava_vortex`, `abyss_run`). |
| `extend_main.gd` | Añade el acto 3 de Pivot Push (la forja) a la escena original. |
| `split_acts.gd` (+ `acts_runner.tscn`) | Divide los circuitos generados en tres actos instanciados. |
| `generate_audio.py` | Sintetiza desde cero los `.wav`/`.mp3` del proyecto (sin samples de terceros). |
| `capture_docs.gd` | Genera las capturas propias de `documentacion/capturas/` con el render real y un perfil aislado. |

## Sondas de un solo uso

No están en la batería: se lanzan a mano cuando hace falta mirar algo concreto.

| Fichero | Qué mide |
| --- | --- |
| `audio_probe.gd` (+ `audio_probe.tscn`) | Pico de cada bus durante el menú y una carrera real. |
| `probe_catalog.gd` | Que cada personaje del catálogo instancia a la altura correcta y tiene sus clips. |
| `probe_models.gd` | Vuelca clips y tamaño de los modelos nuevos antes de meterlos al catálogo. |
| `perf_probe.gd` | Frame time (proceso, física y FPS) con Pivot Push cargado; con ventana mide FPS reales. |
| `probe_stage.gd` | Comprueba el encuadre de las peanas de vista previa del menú. |
| `seesaw_diag.gd` | Inclina el balancín desde varias posiciones y comprueba el estado. |

## Escenas de `tools/`

`acts_runner.tscn`, `csg_runner.tscn` y `audio_probe.tscn` son lanzadores de una
sola escena para los scripts de arriba. Viven fuera de `res://scenes` a
propósito: `check_scenes` solo valida las escenas del juego.
